# FireRing - 烈焰环武器
# 以玩家为中心的燃烧环，周期性伤害周围敌人
extends "res://scripts/weapons/base_weapon.gd"

var _visual_ring: Sprite2D


func _initialize() -> void:
	weapon_id = "fire_ring"
	weapon_name = "烈焰环"
	base_damage = 8.0
	attack_speed = 0.5
	range = 80.0
	aoe_radius = 80.0
	target_range = 80.0
	max_level = 8

	_ring_visual()


func _ring_visual() -> void:
	_visual_ring = Sprite2D.new()
	var tex = _make_ring_texture(int(aoe_radius * 2))
	_visual_ring.texture = tex
	_visual_ring.modulate = Color(1.0, 0.4, 0.1, 0.5)
	add_child(_visual_ring)


static var _ring_tex_cache: Dictionary = {}  # {size: Texture2D}

func _make_ring_texture(size: int) -> Texture2D:
	if _ring_tex_cache.has(size):
		return _ring_tex_cache[size]
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = size / 2
	var cy = size / 2
	var outer_r = size / 2
	var inner_r = outer_r - 4
	for x in range(size):
		for y in range(size):
			var dx = x - cx
			var dy = y - cy
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= outer_r and dist >= inner_r:
				var alpha = 1.0 - abs(dist - (outer_r - 2)) / 4.0
				img.set_pixel(x, y, Color(1, 0.5, 0.1, alpha * 0.6))
	var tex = ImageTexture.create_from_image(img)
	_ring_tex_cache[size] = tex
	return tex


func _attack() -> void:
	var enemies = GameState.get_cached_group("enemy")
	var cc := get_total_crit_chance()
	var cm := get_total_crit_mult()
	var r := range * GameState.effective_range_mult()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < r:
			var is_crit := randf() < cc
			var fdmg := get_damage_with_bonus()  # 已含 ±10% 浮动（D-8：仅此一次）
			if is_crit:
				fdmg *= cm
			if enemy.has_method("take_damage"):
				enemy.take_damage(fdmg, is_crit)
				_apply_lifesteal(fdmg)
				# Lv7+ 灼烧 DOT（每秒 15% 武器伤害，超武翻倍），持续 3s
				if level >= 7 and enemy.has_method("apply_dot"):
					enemy.apply_dot(base_damage * (0.30 if is_super_weapon else 0.15), 3.0)
			EventBus.damage_number_requested.emit(enemy.global_position + Vector2(0, -16), fdmg, is_crit, 1)


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 12.0
		3: range = 110.0; aoe_radius = 110.0; _update_ring_size()
		4: attack_speed = 0.7
		5: base_damage = 18.0
		6: attack_speed = 0.9
		7: base_damage = 25.0; range = 140.0; aoe_radius = 140.0; _update_ring_size()
		8:  # 超武·炼狱（需 + 铁壁 MAX 合成）
			is_super_weapon = true
			super_weapon_name = "炼狱"
			base_damage = 30.0
			attack_speed = 1.5
			range = 220.0
			aoe_radius = 220.0
			_update_ring_size()


func _update_ring_size() -> void:
	if _visual_ring:
		_visual_ring.texture = _make_ring_texture(int(aoe_radius * 2))
		var s = aoe_radius / 80.0
		_visual_ring.scale = Vector2(s, s)

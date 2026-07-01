# IceStorm - 冰晶风暴
# 环绕玩家旋转的冰晶，碰撞敌人造成伤害并减速（满级冰冻）
extends "res://scripts/weapons/base_weapon.gd"

var crystal_count: int = 2
var rotation_rpm: float = 30.0
var orbit_radius: float = 70.0
var slow_enabled: bool = false
var freeze_enabled: bool = false

var _angle: float = 0.0
var _crystals: Array[Sprite2D] = []
var _hit_cd: Dictionary = {}          # 敌人 instance_id -> 剩余命中冷却
const HIT_INTERVAL: float = 0.4


func _initialize() -> void:
	weapon_id = "ice_storm"
	weapon_name = "冰晶风暴"
	base_damage = 6.0
	crystal_count = 2
	rotation_rpm = 30.0
	orbit_radius = 70.0
	max_level = 8
	_build_crystals()


func _build_crystals() -> void:
	for c in _crystals:
		if is_instance_valid(c):
			c.queue_free()
	_crystals.clear()
	for i in range(crystal_count):
		var s := Sprite2D.new()
		s.texture = _make_crystal_tex()
		add_child(s)
		_crystals.append(s)


static var _crystal_tex: ImageTexture = null

func _make_crystal_tex() -> Texture2D:
	if _crystal_tex:
		return _crystal_tex
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for x in range(size):
		for y in range(size):
			var d := Vector2(x - c, y - c).length()
			if d <= c - 1:
				img.set_pixel(x, y, Color(0.5, 0.8, 1.0, clampf(1.0 - d / float(c) + 0.3, 0.0, 1.0)))
	_crystal_tex = ImageTexture.create_from_image(img)
	return _crystal_tex


# 冰晶风暴用自定义环绕逻辑，不走 base 的 attack_timer
func _process(delta: float) -> void:
	if GameState.is_paused or GameState.is_game_over:
		return
	_angle += deg_to_rad(rotation_rpm * 6.0) * delta
	for i in range(_crystals.size()):
		var a := _angle + i * TAU / float(max(1, _crystals.size()))
		_crystals[i].position = Vector2(cos(a), sin(a)) * orbit_radius
	_damage_tick(delta)


func _damage_tick(delta: float) -> void:
	for k in _hit_cd.keys():
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0.0:
			_hit_cd.erase(k)

	var enemies := get_tree().get_nodes_in_group("enemy")
	var cc := get_total_crit_chance()
	var cm := get_total_crit_mult()
	for crystal in _crystals:
		var cpos := crystal.global_position
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var id := enemy.get_instance_id()
			if _hit_cd.has(id):
				continue
			if cpos.distance_to(enemy.global_position) < 22.0:
				var is_crit := randf() < cc
				var dmg := get_damage_with_bonus()
				if is_crit:
					dmg *= cm
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg, is_crit)
					_apply_lifesteal(dmg)
				EventBus.damage_number_requested.emit(enemy.global_position + Vector2(0, -16), dmg, is_crit, 1)
				if (slow_enabled or freeze_enabled) and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.3, 2.0)
				_hit_cd[id] = HIT_INTERVAL


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 9.0
		3:
			crystal_count = 3
			_build_crystals()
		4: rotation_rpm = 45.0
		5: base_damage = 14.0
		6:
			crystal_count = 4
			_build_crystals()
		7:
			rotation_rpm = 60.0
			slow_enabled = true
		8:  # 超武·冰河纪元
			is_super_weapon = true
			super_weapon_name = "冰河纪元"
			base_damage = 22.0
			crystal_count = 6
			rotation_rpm = 90.0
			freeze_enabled = true
			_build_crystals()

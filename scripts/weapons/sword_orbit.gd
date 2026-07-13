# SwordOrbit - 环绕剑刃（剑圣初始武器）
# 环绕玩家旋转的剑刃，近战 AOE 碰撞伤害
extends "res://scripts/weapons/base_weapon.gd"

var blade_count: int = 2
var rotation_rpm: float = 50.0
var orbit_radius: float = 60.0

var _angle: float = 0.0
var _blades: Array[Sprite2D] = []
var _hit_cd: Dictionary = {}
const HIT_INTERVAL: float = 0.3


func _initialize() -> void:
	weapon_id = "sword_orbit"
	weapon_name = "环绕剑刃"
	base_damage = 14.0
	blade_count = 2
	rotation_rpm = 50.0
	orbit_radius = 60.0
	max_level = 8
	_build_blades()


func _build_blades() -> void:
	for b in _blades:
		if is_instance_valid(b):
			b.queue_free()
	_blades.clear()
	for i in range(blade_count):
		var s := Sprite2D.new()
		s.texture = _make_blade_tex()
		add_child(s)
		_blades.append(s)


static var _blade_tex: ImageTexture = null

func _make_blade_tex() -> Texture2D:
	if _blade_tex:
		return _blade_tex
	var img := Image.create(6, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.92, 1.0, 0.95))
	_blade_tex = ImageTexture.create_from_image(img)
	return _blade_tex


func _process(delta: float) -> void:
	if GameState.is_paused or GameState.is_game_over:
		return
	_angle += deg_to_rad(rotation_rpm * 6.0) * delta
	for i in range(_blades.size()):
		var a := _angle + i * TAU / float(max(1, _blades.size()))
		_blades[i].position = Vector2(cos(a), sin(a)) * orbit_radius
		_blades[i].rotation = a + PI / 2.0
	_damage_tick(delta)


func _damage_tick(delta: float) -> void:
	for k in _hit_cd.keys():
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0.0:
			_hit_cd.erase(k)
	var cc := get_total_crit_chance()
	var cm := get_total_crit_mult()
	for blade in _blades:
		var bpos := blade.global_position
		for enemy in GameState.get_cached_group("enemy"):
			if not is_instance_valid(enemy):
				continue
			var id := enemy.get_instance_id()
			if _hit_cd.has(id):
				continue
			if bpos.distance_to(enemy.global_position) < 26.0:
				var is_crit := randf() < cc
				var dmg := get_damage_with_bonus()
				if is_crit:
					dmg *= cm
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg, is_crit)
					_apply_lifesteal(dmg)
				EventBus.damage_number_requested.emit(enemy.global_position + Vector2(0, -16), dmg, is_crit, 0)
				_hit_cd[id] = HIT_INTERVAL / attack_speed


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 20.0
		3:
			blade_count = 3
			_build_blades()
		4: rotation_rpm = 70.0
		5: base_damage = 30.0
		6:
			blade_count = 4
			_build_blades()
		7:
			orbit_radius = 80.0
			_build_blades()
		8:  # 超武·剑刃风暴
			is_super_weapon = true
			super_weapon_name = "剑刃风暴"
			base_damage = 45.0
			blade_count = 6
			rotation_rpm = 100.0
			_build_blades()

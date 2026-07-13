# MagicBolt - 魔法弹武器
# 基础远程武器，发射追踪光弹
extends "res://scripts/weapons/base_weapon.gd"

func _initialize() -> void:
	weapon_id = "magic_bolt"
	weapon_name = "魔法弹"
	base_damage = 12.0
	attack_speed = 0.8
	projectile_speed = 350.0
	penetration = 0
	range = 500.0
	target_range = 600.0
	max_level = 8  # 7级MAX + 超武 = 8级


func _attack() -> void:
	_shoot_projectile()


func _shoot_projectile() -> void:
	var proj = _get_projectile()
	if not proj:
		return

	var player_pos = get_parent().global_position
	proj.global_position = player_pos

	var dir := Vector2.RIGHT
	if target and is_instance_valid(target):
		dir = player_pos.direction_to(target.global_position)
	else:
		dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	proj.direction = dir
	proj.speed = projectile_speed
	proj.damage = get_damage_with_bonus()
	proj.penetration = penetration
	proj.lifetime = 3.0
	proj.crit_chance = get_total_crit_chance()
	proj.crit_mult = get_total_crit_mult()
	proj.lifesteal = get_total_lifesteal()
	if proj.has_method("set_projectile_color"):
		proj.set_projectile_color(Color(0.31, 0.76, 0.98))
	if proj.has_method("set_projectile_scale"):
		proj.set_projectile_scale(0.75)

	proj.activate()

	EventBus.screen_shake_requested.emit(1.0, 0.05)


func _get_projectile() -> Node2D:
	return _acquire_projectile()


func _apply_level_stats() -> void:
	match level:
		2:
			base_damage = 18.0  # +50%
		3:
			attack_speed = 1.1  # +37%
		4:
			penetration = 1
		5:
			base_damage = 25.0  # +40%
		6:
			attack_speed = 1.5  # +36%
		7:
			penetration = 2
		8:  # 超武
			is_super_weapon = true
			base_damage = 40.0
			attack_speed = 0.6
			penetration = 5


func can_synthesize_super() -> bool:
	return level >= 7  # Lv7 MAX可合成超武

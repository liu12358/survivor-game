# PiercingArrow - 穿透箭（弓手初始武器）
# 高速高穿透远程箭矢
extends "res://scripts/weapons/base_weapon.gd"

const PROJ_SCENE := "res://scenes/weapons/magic_bolt_projectile.tscn"


func _initialize() -> void:
	weapon_id = "piercing_arrow"
	weapon_name = "穿透箭"
	base_damage = 16.0
	attack_speed = 1.0
	projectile_speed = 600.0
	penetration = 3
	range = 650.0
	target_range = 650.0
	max_level = 8


func _attack() -> void:
	if not target or not is_instance_valid(target):
		return
	var proj = _acquire_projectile()
	if not proj:
		return
	proj.global_position = global_position
	proj.direction = global_position.direction_to(target.global_position)
	proj.speed = projectile_speed
	proj.damage = get_damage_with_bonus()
	proj.penetration = penetration
	proj.lifetime = 3.0
	proj.crit_chance = get_total_crit_chance()
	proj.crit_mult = get_total_crit_mult()
	proj.lifesteal = get_total_lifesteal()
	if proj.has_method("set_projectile_color"):
		if is_super_weapon:
			proj.set_projectile_color(Color(1.0, 0.95, 0.5))
		else:
			proj.set_projectile_color(Color(0.6, 1.0, 0.6))
	if proj.has_method("set_projectile_scale"):
		proj.set_projectile_scale(2.0 if is_super_weapon else 1.0)
	proj.activate()


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 24.0
		3: penetration = 4
		4: attack_speed = 1.3
		5: base_damage = 36.0
		6: penetration = 5
		7: attack_speed = 1.6
		8:  # 超武·万箭齐发
			is_super_weapon = true
			super_weapon_name = "万箭齐发"
			base_damage = 55.0
			penetration = 8
			attack_speed = 2.0

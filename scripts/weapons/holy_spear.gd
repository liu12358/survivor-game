# HolySpear - 圣光之矛
# 直线贯穿宽矛，高穿透高伤害（复用通用投射物）
extends "res://scripts/weapons/base_weapon.gd"

const PROJ_SCENE := "res://scenes/weapons/magic_bolt_projectile.tscn"


func _initialize() -> void:
	weapon_id = "holy_spear"
	weapon_name = "圣光之矛"
	base_damage = 20.0
	attack_speed = 0.6
	projectile_speed = 500.0
	penetration = 1
	range = 600.0
	target_range = 600.0
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
		proj.set_projectile_color(Color(1.0, 0.9, 0.4))
	if proj.has_method("set_projectile_scale"):
		proj.set_projectile_scale(2.4 if is_super_weapon else 1.6)
	proj.activate()


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 30.0
		3: pass            # 宽度提升（视觉，略）
		4: penetration = 2
		5: base_damage = 45.0
		6: pass
		7: penetration = 3
		8:  # 超武·圣裁
			is_super_weapon = true
			super_weapon_name = "圣裁"
			base_damage = 70.0
			penetration = 5
			crit_chance += 0.30

# PoisonCloud - 毒雾
# 周期性在目标处生成地面 DOT 区域（超武跟随玩家）
extends "res://scripts/weapons/base_weapon.gd"

const FIELD_SCRIPT := "res://scripts/weapons/poison_field.gd"


func _initialize() -> void:
	weapon_id = "poison_cloud"
	weapon_name = "毒雾"
	base_damage = 3.0          # 每秒
	attack_speed = 0.33        # 约每 3 秒释放一片
	aoe_radius = 60.0
	dot_duration = 3.0
	range = 350.0
	target_range = 350.0
	max_level = 8


func _requires_target() -> bool:
	return false  # AOE 毒雾区域，无需目标（目标仅影响落点）


func _attack() -> void:
	# 使用父节点（玩家）的世界坐标，而非自身局部坐标
	var pos := get_parent().global_position if get_parent() else global_position
	if target and is_instance_valid(target):
		pos = target.global_position
	_spawn_field(pos)


func _spawn_field(pos: Vector2) -> void:
	var field := Node2D.new()
	field.set_script(load(FIELD_SCRIPT))
	field.damage_per_sec = get_damage_with_bonus()
	field.radius = aoe_radius
	field.duration = dot_duration
	field.follow_player = is_super_weapon
	field.global_position = pos
	get_tree().current_scene.add_child(field)


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 5.0
		3: aoe_radius = 90.0
		4: dot_duration = 5.0
		5: base_damage = 8.0
		6: aoe_radius = 130.0
		7: dot_duration = 7.0
		8:  # 超武·瘟疫
			is_super_weapon = true
			super_weapon_name = "瘟疫"
			base_damage = 14.0
			aoe_radius = 200.0
			dot_duration = 10.0

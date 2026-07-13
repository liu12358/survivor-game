# LightningChain - 闪电链武器
# 连锁弹跳攻击多个敌人
extends "res://scripts/weapons/base_weapon.gd"

var chain_count: int = 3
var bounce_range: float = 170.0
var _chain_lines: Array[Line2D] = []
var _line_timer: float = 0.0


func _initialize() -> void:
	weapon_id = "lightning_chain"
	weapon_name = "闪电链"
	base_damage = 8.0
	attack_speed = 0.6
	range = 400.0
	target_range = 400.0
	chain_count = 3
	bounce_range = 170.0
	max_level = 8
	z_index = 5


func _attack() -> void:
	if not target or not is_instance_valid(target):
		return

	var dmg := get_damage_with_bonus()
	var hit_enemies: Array[Node2D] = [target]
	var cc := get_total_crit_chance()
	var cm := get_total_crit_mult()

	# 第一击
	var c1 := randf() < cc
	var d1 := dmg * (cm if c1 else 1.0)
	if target.has_method("take_damage"):
		target.take_damage(d1, c1)
		_apply_lifesteal(d1)
	EventBus.damage_number_requested.emit(target.global_position, d1, c1, 1)

	# 连锁弹跳
	var last_pos = target.global_position
	var current_dmg := dmg

	for i in range(chain_count - 1):
		var next = _find_nearest_enemy(hit_enemies, last_pos)
		if not next:
			break
		current_dmg *= 0.85  # 每跳衰减15%
		var ck := randf() < cc
		var dk := current_dmg * (cm if ck else 1.0)
		if next.has_method("take_damage"):
			next.take_damage(dk, ck)
			_apply_lifesteal(dk)
		EventBus.damage_number_requested.emit(next.global_position, dk, ck, 1)
		hit_enemies.append(next)
		last_pos = next.global_position

	# 画闪电特效线
	_draw_chain(hit_enemies)


func _find_nearest_enemy(exclude: Array[Node2D], from: Vector2) -> Node2D:
	var enemies = GameState.get_cached_group("enemy")
	var best: Node2D = null
	var best_dist = bounce_range
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in exclude:
			continue
		if "state" in enemy and (enemy.state == 4 or enemy.state == 5):
			continue
		var dist = from.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _draw_chain(hit: Array[Node2D]) -> void:
	var source = global_position
	for i in range(hit.size()):
		var line = Line2D.new()
		line.width = 2.5
		line.default_color = Color(0.5, 0.7, 1.0, 0.9)
		line.add_point(source)
		line.add_point(hit[i].global_position)
		get_tree().current_scene.add_child(line)

		var t = create_tween()
		t.tween_property(line, "default_color:a", 0.0, 0.25)
		t.tween_callback(line.queue_free)

		source = hit[i].global_position


func _apply_level_stats() -> void:
	match level:
		2: base_damage = 12.0
		3: chain_count = 3; bounce_range = 120.0
		4: bounce_range = 170.0
		5: base_damage = 18.0
		6: chain_count = 4; bounce_range = 170.0
		7: bounce_range = 220.0
		8:  # 超武·雷神之怒（需 + 疾步 MAX 合成）
			is_super_weapon = true
			super_weapon_name = "雷神之怒"
			chain_count = 6
			bounce_range = 300.0
			base_damage = 30.0


func can_synthesize_super() -> bool:
	return level >= 7

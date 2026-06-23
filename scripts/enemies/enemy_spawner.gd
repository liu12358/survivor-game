# EnemySpawner - 敌人生成器
# 按波次时间生成敌人，管理难度递增
class_name EnemySpawner
extends Node2D

## 生成配置
@export var spawn_interval: float = 1.5
@export var spawn_interval_min: float = 0.3
@export var max_enemies: int = 200
@export var spawn_bounds: Rect2 = Rect2(-900, -900, 1800, 1800)

# 内部状态
var _spawn_timer: float = 0.0
var _game_time: float = 0.0
var _active_enemies: Array[Node2D] = []
var _elite_spawn_timer: float = 0.0
var _elite_interval: float = 60.0
var _time_emit: float = 0.0           # game_time 信号降频累加器

# 敌人生成权重（随时间变化）
var _spawn_weights: Dictionary = {
	"slime_small": 50,
	"slime_big": 15,
	"bat": 35,
	"skeleton": 0,    # 3分钟后解锁
	"ghost": 0,       # 6分钟后解锁（暂无场景）
}

# 对象池
var _enemy_pools: Dictionary = {}   # {enemy_type: ObjectPool}
var _gem_pool: Node = null


func _ready() -> void:
	_setup_pools()
	_update_spawn_rate()
	add_to_group("spawner")
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_type: String, pos: Vector2, exp_val: int, gold_val: int) -> void:
	SaveSystem.record_kill(_type)
	spawn_exp_gem(pos, exp_val, gold_val)


func _setup_pools() -> void:
	# Phase 1: 简化版本（直接实例化），Phase 2 改为对象池
	pass


func _process(delta: float) -> void:
	if GameState.is_paused or GameState.is_game_over:
		return

	_game_time += delta
	GameState.survival_time = _game_time
	# 信号降频：每 0.5s 广播一次计时（原为每帧）
	_time_emit += delta
	if _time_emit >= 0.5:
		_time_emit = 0.0
		EventBus.game_time_updated.emit(_game_time)
	_update_spawn_rate()

	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_enemy()

	# 精英怪
	_elite_spawn_timer += delta
	if _elite_spawn_timer >= _elite_interval:
		_elite_spawn_timer = 0.0
		_spawn_elite()

	_cleanup_dead_enemies()


func _update_spawn_rate() -> void:
	var diff = GameState.get_difficulty_config()
	var base_interval = 1.5

	if _game_time < 60:
		spawn_interval = base_interval * 1.2
	elif _game_time < 180:
		spawn_interval = base_interval * 0.7
	elif _game_time < 360:
		spawn_interval = base_interval * 0.5
	elif _game_time < 600:
		spawn_interval = base_interval * 0.35
	else:
		spawn_interval = base_interval * 0.25

	# 难度修正
	spawn_interval /= diff["count_mult"]
	spawn_interval = max(spawn_interval, spawn_interval_min)

	# 解锁新敌人
	if _game_time > 180:
		_spawn_weights["skeleton"] = 20
	if _game_time > 360:
		_spawn_weights["ghost"] = 15

	# 无尽后期：怪物数量上限随时间提升（GDD 12.4）
	max_enemies = int(_time_scaling()["count"])


func _time_scaling() -> Dictionary:
	# 无尽后期数值阶梯（GDD 12.4）：相对前 15 分钟基线的额外倍率 + 数量上限
	var t := _game_time
	if t < 900.0:
		return {"hp": 1.0, "speed": 1.0, "count": 200}
	elif t < 1200.0:
		return {"hp": 1.7, "speed": 1.25, "count": 250}
	elif t < 1500.0:
		return {"hp": 2.7, "speed": 1.5, "count": 300}
	elif t < 1800.0:
		return {"hp": 4.0, "speed": 1.75, "count": 350}
	return {"hp": 5.0, "speed": 2.0, "count": 400}


func _spawn_enemy() -> void:
	if _active_enemies.size() >= max_enemies:
		return

	var type = _pick_enemy_type()
	var enemy: Node2D = _create_enemy(type)
	if not enemy:
		return

	var pos = _get_spawn_position()
	enemy.global_position = pos

	# 难度调整
	var diff = GameState.get_difficulty_config()
	var ts = _time_scaling()
	enemy.max_health *= diff["hp_mult"] * ts["hp"]
	enemy.move_speed *= diff["speed_mult"] * ts["speed"]
	enemy.current_health = enemy.max_health

	# 后期词条（10分钟后）
	if _game_time > 600:
		_apply_late_game_affix(enemy)

	add_child(enemy)
	_active_enemies.append(enemy)
	EventBus.enemy_spawned.emit(enemy)


func _pick_enemy_type() -> String:
	var total = 0
	for weight in _spawn_weights.values():
		total += weight

	if total == 0:
		return "slime_small"

	var roll = GameState.rng.randf() * total
	var cumulative = 0
	for type in _spawn_weights:
		cumulative += _spawn_weights[type]
		if roll < cumulative:
			return type

	return "slime_small"


func _create_enemy(type: String) -> Node2D:
	# Phase 1: 从场景文件加载
	var scene_path = "res://scenes/enemies/%s.tscn" % type
	if ResourceLoader.exists(scene_path):
		return load(scene_path).instantiate()
	return null


func _get_spawn_position() -> Vector2:
	var cam_pos = _get_camera_position()
	var angle = GameState.rng.randf() * TAU
	var dist = 800 + GameState.rng.randf() * 200  # 屏幕外
	return cam_pos + Vector2(cos(angle), sin(angle)) * dist


func _get_camera_position() -> Vector2:
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		return cameras[0].global_position
	# fallback: 使用玩家位置
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0].global_position
	return Vector2.ZERO


func _spawn_elite() -> void:
	if _active_enemies.size() >= max_enemies:
		return

	var affix: String
	if _game_time < 360:
		affix = "fast"
	elif _game_time < 600:
		affix = "tough"
	else:
		affix = ["fast", "tough", "reflect", "explode", "poison"].pick_random()

	var enemy: Node2D = _create_enemy("slime_big")
	if _game_time > 600:
		# 10分钟后精英也可能是幽灵
		var pool = ["slime_big", "ghost"]
		enemy = _create_enemy(pool[randi() % pool.size()])
	elif not enemy:
		enemy = _create_enemy("slime_big")
	if not enemy:
		enemy = _create_enemy("slime_small")
	if not enemy:
		return

	enemy.make_elite(affix)
	enemy.global_position = _get_spawn_position()

	add_child(enemy)
	_active_enemies.append(enemy)
	EventBus.enemy_spawned.emit(enemy)


func _apply_late_game_affix(enemy: Node2D) -> void:
	var affix_pool = {
		"fast": 0.20, "tough": 0.15, "reflect": 0.10,
		"explode": 0.10, "poison": 0.10, "summon": 0.05
	}
	for affix in affix_pool:
		if randf() < affix_pool[affix]:
			enemy.add_extra_affix(affix)


func _cleanup_dead_enemies() -> void:
	# 移除已销毁的敌人引用
	var cleaned: Array[Node2D] = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			cleaned.append(enemy)
	_active_enemies = cleaned


func get_enemy_count() -> int:
	return _active_enemies.size()


func spawn_exp_gem(position: Vector2, amount: int, gold: int = 0) -> void:
	var gem_scene = load("res://scenes/enemies/exp_gem.tscn")
	if not gem_scene:
		return

	# 宝石上限检查
	var gem_count = get_tree().get_nodes_in_group("gem").size()
	if gem_count > 200:
		return

	# 始终生成经验宝石（蓝色）
	var gem = gem_scene.instantiate()
	gem.exp_amount = amount
	gem.pickup_type = "exp"
	gem.global_position = position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	add_child.call_deferred(gem)   # 物理回调期间延迟入树，避免 flushing queries 错误（B-10）

	# 概率掉落特殊宝石
	var drop_bonus = 1.0 + GameState.drop_rate
	var roll = GameState.rng.randf()
	if roll < 0.05 * drop_bonus:  # 5% 治疗（红心）
		var heal = gem_scene.instantiate()
		heal.exp_amount = 0
		heal.pickup_type = "heal"
		heal.global_position = position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		add_child.call_deferred(heal)
	elif roll < 0.10 * drop_bonus:  # 5% 护盾（金盾）
		var shield = gem_scene.instantiate()
		shield.exp_amount = 0
		shield.pickup_type = "shield"
		shield.global_position = position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		add_child.call_deferred(shield)
	elif roll < (0.15 + 0.10 * GameState.drop_rate) * drop_bonus:  # 15%→25% 金币
		var gold_gem = gem_scene.instantiate()
		gold_gem.exp_amount = 0
		gold_gem.gold_amount = max(1, gold + randi() % 4)
		gold_gem.pickup_type = "gold"
		gold_gem.global_position = position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		add_child.call_deferred(gold_gem)

	# 增益 Buff 掉落（独立低概率，P2-14）
	if GameState.rng.randf() < 0.025 * drop_bonus:
		var buff_types = ["buff_damage", "buff_speed", "buff_exp", "invincible", "magnet", "clear_bomb"]
		var bg = gem_scene.instantiate()
		bg.exp_amount = 0
		bg.pickup_type = buff_types[randi() % buff_types.size()]
		bg.global_position = position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		add_child.call_deferred(bg)

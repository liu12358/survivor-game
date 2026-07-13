# EnemySpawner - 敌人生成器
# 按波次时间生成敌人，管理难度递增
class_name EnemySpawner
extends Node2D

## 生成配置
@export var spawn_interval: float = 1.5
@export var spawn_interval_min: float = 0.3
@export var max_enemies: int = 200
@export var spawn_bounds: Rect2 = Rect2(-800, -800, 1600, 1600)

# 内部状态
var _spawn_timer: float = 0.0
var _game_time: float = 0.0
var _active_enemies: Array[Node2D] = []
var _elite_spawn_timer: float = 0.0
var _elite_interval: float = 60.0
var _time_emit: float = 0.0           # game_time 信号降频累加器
var _gem_merge_timer: float = 0.0
const GEM_MERGE_INTERVAL: float = 1.5
const GEM_MERGE_THRESHOLD: int = 100
const GEM_MERGE_RANGE: float = 30.0

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
var _gem_pool: ObjectPool = null
const POOLED_ENEMIES := ["slime_small", "bat"]  # 接入池的基础怪物


func _ready() -> void:
	_setup_pools()
	_update_spawn_rate()
	add_to_group("spawner")
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_type: String, pos: Vector2, exp_val: int, gold_val: int) -> void:
	SaveSystem.record_kill(_type)
	GameState.add_kill_streak()
	spawn_exp_gem(pos, exp_val, gold_val)


func _setup_pools() -> void:
	# 经验宝石池（标准尺寸 200）
	var gem_pool := ObjectPool.new()
	gem_pool.scene = load("res://scenes/enemies/exp_gem.tscn")
	gem_pool.initial_size = 150
	gem_pool.max_size = 500
	gem_pool.add_to_group("gem_pool")
	add_child(gem_pool)
	_gem_pool = gem_pool

	# 基础怪物池（小史莱姆、蝙蝠）
	for etype in POOLED_ENEMIES:
		var path := "res://scenes/enemies/%s.tscn" % etype
		if not ResourceLoader.exists(path):
			continue
		var pool := ObjectPool.new()
		pool.scene = load(path)
		pool.initial_size = 100
		pool.max_size = 300
		pool.add_to_group("pool_" + etype)
		add_child(pool)
		_enemy_pools[etype] = pool


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

	# 宝石合并（同屏>100时启动）
	_gem_merge_timer += delta
	if _gem_merge_timer >= GEM_MERGE_INTERVAL:
		_gem_merge_timer = 0.0
		_merge_excess_gems()


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

	# 池化怪物已在池节点下，不需要再 add_child
	var from_pool := (type in POOLED_ENEMIES and _enemy_pools.has(type))
	if not from_pool:
		add_child(enemy)
	# 非池化怪物需要加入 _active_enemies（池化怪物已在 _create_enemy 中加入了）
	if not from_pool:
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
	# 池化怪物：从对象池获取
	if type in POOLED_ENEMIES and _enemy_pools.has(type):
		var pool = _enemy_pools[type]
		if pool and pool.has_method("acquire"):
			var obj = pool.acquire() as Node2D
			if obj:
				# 设置池引用 + 重置状态
				if obj.has_method("set_pool_ref"):
					obj.set_pool_ref(pool)
				if obj.has_method("reset_for_pool"):
					obj.reset_for_pool()
				if not obj.is_in_group("enemy"):
					obj.add_to_group("enemy")
				_active_enemies.append(obj)
				return obj

	# 非池化怪物：从场景文件加载
	var scene_path = "res://scenes/enemies/%s.tscn" % type
	if ResourceLoader.exists(scene_path):
		return load(scene_path).instantiate()
	return null


func _get_spawn_position() -> Vector2:
	var cam_pos = _get_camera_position()
	var angle = GameState.rng.randf() * TAU
	var dist = 500 + GameState.rng.randf() * 200  # 缩小生成距离
	var pos = cam_pos + Vector2(cos(angle), sin(angle)) * dist
	# 确保生成在地图边界内
	var boundary = 700.0
	if pos.length() > boundary:
		pos = pos.normalized() * boundary
	return pos


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
		affix = ["fast", "tough", "reflect", "explode", "poison"][GameState.rng.randi() % 5]

	var chosen_type: String = "slime_big"
	var enemy: Node2D = _create_enemy(chosen_type)
	if _game_time > 600:
		# 10分钟后精英也可能是幽灵
		var pool = ["slime_big", "ghost"]
		chosen_type = pool[GameState.rng.randi() % pool.size()]
		enemy = _create_enemy(chosen_type)
	elif not enemy:
		chosen_type = "slime_big"
		enemy = _create_enemy(chosen_type)
	if not enemy:
		chosen_type = "slime_small"
		enemy = _create_enemy(chosen_type)
	if not enemy:
		return

	enemy.make_elite(affix)
	enemy.global_position = _get_spawn_position()

	# 应用难度/时间倍率（与 _spawn_enemy 一致，否则精英缺少后期数值缩放）
	var diff = GameState.get_difficulty_config()
	var ts = _time_scaling()
	enemy.max_health *= diff["hp_mult"] * ts["hp"]
	enemy.move_speed *= diff["speed_mult"] * ts["speed"]
	enemy.current_health = enemy.max_health

	# 池化怪物已在池节点下，不需要再 add_child（否则会从池重parent到生成器）
	var from_pool := (chosen_type in POOLED_ENEMIES and _enemy_pools.has(chosen_type))
	if not from_pool:
		add_child(enemy)
	# 避免双重注册：_create_enemy 已为池化怪物 append 过 _active_enemies
	if not _active_enemies.has(enemy):
		_active_enemies.append(enemy)
	EventBus.enemy_spawned.emit(enemy)


func _apply_late_game_affix(enemy: Node2D) -> void:
	var affix_pool = {
		"fast": 0.20, "tough": 0.15, "reflect": 0.10,
		"explode": 0.10, "poison": 0.10, "summon": 0.05
	}
	for affix in affix_pool:
		if GameState.rng.randf() < affix_pool[affix]:
			enemy.add_extra_affix(affix)


func _cleanup_dead_enemies() -> void:
	# 使用倒序遍历安全删除，避免创建新数组
	var i := _active_enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(_active_enemies[i]):
			_active_enemies.remove_at(i)
		i -= 1


func get_enemy_count() -> int:
	return _active_enemies.size()


func register_enemy(enemy: Node2D) -> void:
	"""注册外部创建的敌人（分裂/召唤）到活跃列表，便于统一清理与计数"""
	if not is_instance_valid(enemy):
		return
	if _active_enemies.has(enemy):
		return
	_active_enemies.append(enemy)


func spawn_exp_gem(position: Vector2, amount: int, gold: int = 0) -> void:
	# 宝石上限检查
	var gem_count = get_tree().get_nodes_in_group("gem").size()
	if gem_count > 200:
		return

	# 经验宝石
	_spawn_gem_at(position, "exp", amount, gold, Vector2(GameState.rng.randf_range(-10, 10), GameState.rng.randf_range(-10, 10)))

	# 概率掉落特殊宝石
	var drop_bonus = 1.0 + GameState.drop_rate
	var roll = GameState.rng.randf()
	if roll < 0.05 * drop_bonus:  # 5% 治疗（红心）
		_spawn_gem_at(position, "heal", 0, 0, Vector2(GameState.rng.randf_range(-12, 12), GameState.rng.randf_range(-12, 12)))
	elif roll < 0.10 * drop_bonus:  # 5% 护盾
		_spawn_gem_at(position, "shield", 0, 0, Vector2(GameState.rng.randf_range(-12, 12), GameState.rng.randf_range(-12, 12)))
	elif roll < (0.15 + 0.10 * GameState.drop_rate) * drop_bonus:  # 15%→25% 金币
		_spawn_gem_at(position, "gold", 0, max(1, gold + GameState.rng.randi() % 4), Vector2(GameState.rng.randf_range(-15, 15), GameState.rng.randf_range(-15, 15)))

	# 增益 Buff 掉落
	if GameState.rng.randf() < 0.025 * drop_bonus:
		var buff_types = ["buff_damage", "buff_speed", "buff_exp", "invincible", "magnet", "clear_bomb"]
		_spawn_gem_at(position, buff_types[GameState.rng.randi() % buff_types.size()], 0, 0, Vector2(GameState.rng.randf_range(-15, 15), GameState.rng.randf_range(-15, 15)))


func _spawn_gem_at(pos: Vector2, ptype: String, exp: int, gld: int, offset: Vector2) -> void:
	var gem: ExpGem = _acquire_gem()
	if not gem:
		return
	gem.exp_amount = exp
	gem.gold_amount = gld
	gem.pickup_type = ptype
	gem.global_position = pos + offset
	# 池化宝石已在池节点下，不需要再 add_child；非池化需要
	if not gem._pool_ref:
		add_child.call_deferred(gem)
	gem.add_to_group("gem")


func _acquire_gem() -> ExpGem:
	if _gem_pool and _gem_pool.has_method("acquire"):
		var g = _gem_pool.acquire()
		if g and g is ExpGem:
			if g.has_method("reset_for_pool"):
				g.reset_for_pool()
			if g.has_method("set_pool_ref"):
				g.set_pool_ref(_gem_pool)
			return g
	var scene = load("res://scenes/enemies/exp_gem.tscn")
	if scene:
		return scene.instantiate()
	return null


# ─── 宝石多级合并 ───

func _merge_excess_gems() -> void:
	"""同屏宝石>阈值时，自动合并低阶宝石"""
	var all_gems = get_tree().get_nodes_in_group("gem")
	if all_gems.size() < GEM_MERGE_THRESHOLD:
		return

	# 只合并 exp 类型宝石，按距离排序（远的优先合并）
	var exp_gems: Array[Node] = []
	for g in all_gems:
		if is_instance_valid(g) and g.pickup_type == "exp":
			if "_mergeable" in g and g._mergeable:
				exp_gems.append(g)

	if exp_gems.size() < 2:
		return

	# 取玩家位置作为参考点
	var center = _get_camera_position()
	exp_gems.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) > b.global_position.distance_squared_to(center))

	# 远距离宝石两两合并
	var merged_count = 0
	var target_merge = max(0, exp_gems.size() - GEM_MERGE_THRESHOLD + 20)  # 合并到阈值以下

	for i in range(exp_gems.size() - 1):
		if merged_count >= target_merge:
			break
		var a = exp_gems[i]
		if not is_instance_valid(a) or not "_mergeable" in a or not a._mergeable:
			continue
		# 找最近的同类型宝石
		for j in range(i + 1, exp_gems.size()):
			var b = exp_gems[j]
			if not is_instance_valid(b) or not "_mergeable" in b or not b._mergeable:
				continue
			if a.global_position.distance_squared_to(b.global_position) < GEM_MERGE_RANGE * GEM_MERGE_RANGE:
				a.merge_into(b)
				merged_count += 1
				break  # a 已合并一次，跳过

# BaseEnemy - 敌人基类
# 所有敌人类型继承此类
# v2: 支持多种移动模式（直线/正弦/冲刺）+ 分裂 + 远程攻击
class_name BaseEnemy
extends CharacterBody2D

enum EnemyState { SPAWNING, CHASING, ATTACKING, HURT, DYING, DEAD }
enum MovePattern { STRAIGHT, SINE, CHARGE }

## 配置属性
@export var enemy_type: String = "slime_small"
@export var max_health: float = 15.0
@export var damage: float = 10.0
@export var move_speed: float = 80.0
@export var exp_value: int = 5
@export var gold_value: int = 1

# 移动模式
@export var move_pattern: int = MovePattern.STRAIGHT
@export var sine_amplitude: float = 30.0      # 正弦波振幅（蝙蝠用）
@export var sine_frequency: float = 3.0        # 正弦波频率
@export var charge_speed_mult: float = 3.0     # 冲刺速度倍率（骷髅用）
@export var charge_duration: float = 1.0       # 冲刺持续
@export var charge_cooldown: float = 3.0       # 冲刺冷却

# 死亡行为
@export var split_on_death: bool = false       # 死亡分裂（大史莱姆）
@export var split_count: int = 2
@export var split_type: String = "slime_small"

# 远程攻击（幽灵用）
@export var is_ranged: bool = false
@export var ranged_cooldown: float = 2.0
@export var ranged_damage: float = 15.0
@export var ranged_speed: float = 250.0
@export var preferred_distance: float = 200.0  # 保持距离
@export var projectile_scene: String = ""

# 运行时属性
var current_health: float = 0.0
var state: EnemyState = EnemyState.SPAWNING
var is_elite: bool = false

# 移动状态
var _sine_time: float = 0.0
var _charge_timer: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _ranged_timer: float = 0.0

# 受伤后退
var knockback_resistance: float = 0.0
var is_retreating: bool = false
var retreat_timer: float = 0.0

# 精英属性
var elite_affix: String = ""
var elite_hp_mult: float = 1.0
var elite_damage_mult: float = 1.0
var elite_exp_mult: float = 1.0

# 后期词条
var extra_affixes: Array[String] = []
var _slow_active: bool = false        # 冰系减速中（避免重复叠加重置基速）
var _summon_timer: float = 0.0        # 召唤词条计时
var _dot_dps: float = 0.0             # 灼烧/中毒每秒伤害
var _dot_time: float = 0.0
var _dot_tick: float = 0.0
var _slow_tween: Tween = null               # 减速 Tween 引用（reset_for_pool 时 kill）

# 接触伤害计时器
var _contact_damage_timer: float = 0.0
var _angle_offset: float = 0.0
const CONTACT_DAMAGE_INTERVAL: float = 0.5
const CONTACT_DAMAGE_RANGE: float = 42.0

# 对象池引用（池化怪物专用，非池化 = null）
var _pool_ref: Node = null

# 对象池：缓存初始数值，避免 reset_for_pool 后叠加倍率
var _base_max_health: float = 0.0
var _base_move_speed: float = 0.0
var _death_tween: Tween = null             # 死亡动画引用（reset_for_pool 时 kill，避免残留回调误释放）

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_flash_timer: Timer = $HitFlashTimer


func _ready() -> void:
	if _base_max_health == 0.0:
		_base_max_health = max_health
	if _base_move_speed == 0.0:
		_base_move_speed = move_speed
	current_health = max_health * elite_hp_mult
	state = EnemyState.CHASING
	_angle_offset = randf_range(-0.15, 0.15)
	_sine_time = randf() * TAU  # 随机相位
	_charge_timer = randf_range(0, charge_cooldown)  # 随机初始冷却
	_ranged_timer = randf_range(0, ranged_cooldown)
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	_process_dot(delta)
	match state:
		EnemyState.SPAWNING:
			pass
		EnemyState.CHASING:
			_handle_movement(delta)
			move_and_slide()
			_check_contact_damage(delta)
			_clamp_to_boundary_after_slide()
			if "summon" in extra_affixes:
				_summon_timer += delta
				if _summon_timer >= 10.0:
					_summon_timer = 0.0
					_summon_minion()
		EnemyState.HURT:
			if retreat_timer > 0:
				retreat_timer -= delta
			else:
				state = EnemyState.CHASING
			move_and_slide()
		EnemyState.DYING:
			pass
		EnemyState.DEAD:
			return


func _handle_movement(delta: float) -> void:
	var p = _get_player()
	if not p:
		return

	var to_player = global_position.direction_to(p.global_position)
	var dist = global_position.distance_to(p.global_position)

	# 远程怪：保持距离
	if is_ranged:
		_handle_ranged(delta, p, to_player, dist)
		return

	match move_pattern:
		MovePattern.STRAIGHT:
			_chase_straight(to_player)
		MovePattern.SINE:
			_chase_sine(delta, to_player)
		MovePattern.CHARGE:
			_chase_charge(delta, to_player)

	# 边界回弹
	_clamp_to_boundary()


# ─── 移动模式 ───

func _chase_straight(to_player: Vector2) -> void:
	var dir = to_player.rotated(_angle_offset)
	velocity = dir * move_speed


func _chase_sine(delta: float, to_player: Vector2) -> void:
	# 蝙蝠正弦移动
	_sine_time += delta
	var base_dir = to_player.rotated(_angle_offset)
	var perp = base_dir.orthogonal()
	var sine_offset = sin(_sine_time * sine_frequency * TAU) * sine_amplitude
	velocity = base_dir * move_speed + perp * sine_offset * 3.0
	# 限制最大速度
	if velocity.length() > move_speed * 1.5:
		velocity = velocity.normalized() * move_speed * 1.5


func _chase_charge(delta: float, to_player: Vector2) -> void:
	# 骷髅蓄力冲刺
	if _is_charging:
		velocity = _charge_dir * move_speed * charge_speed_mult
		_charge_timer -= delta
		if _charge_timer <= 0:
			_is_charging = false
			_charge_timer = charge_cooldown
	else:
		# 慢速追踪
		velocity = to_player.rotated(_angle_offset) * move_speed * 0.5
		_charge_timer -= delta
		if _charge_timer <= 0:
			# 开始冲刺
			_is_charging = true
			_charge_dir = to_player
			_charge_timer = charge_duration
			# 冲刺视觉：短暂闪烁
			if sprite:
				var t = create_tween()
				t.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.15)
				t.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func _clamp_to_boundary() -> void:
	var cfg = GameState.get_current_map_config()
	var boundary_radius: float = float(cfg.get("radius", 800.0))
	var dist = global_position.length()
	if dist > boundary_radius - 20.0:
		var push_dir = -global_position.normalized()
		velocity += push_dir * move_speed * 2.0


func _clamp_to_boundary_after_slide() -> void:
	var cfg = GameState.get_current_map_config()
	var boundary_radius: float = float(cfg.get("radius", 800.0))
	var dist = global_position.length()
	if dist > boundary_radius:
		global_position = global_position.normalized() * boundary_radius


# ─── 远程攻击（幽灵） ───

func _handle_ranged(delta: float, p: Node2D, to_player: Vector2, dist: float) -> void:
	# 保持距离
	if dist < preferred_distance * 0.7:
		# 后退
		velocity = -to_player * move_speed * 1.2
	elif dist > preferred_distance * 1.3:
		# 靠近
		velocity = to_player * move_speed * 0.8
	else:
		# 横向移动
		velocity = to_player.orthogonal() * move_speed * 0.5

	# 远程攻击
	_ranged_timer -= delta
	if _ranged_timer <= 0:
		_ranged_timer = ranged_cooldown
		_fire_ranged(p)


func _fire_ranged(target: Node2D) -> void:
	# 创建暗影弹
	var proj = Area2D.new()
	proj.collision_layer = 8  # boss_projectile层
	proj.collision_mask = 1   # 碰撞玩家

	var col_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8
	col_shape.shape = circle
	proj.add_child(col_shape)

	# 弹幕外观
	var rect = ColorRect.new()
	rect.color = Color(0.5, 0.2, 0.7, 0.9)
	rect.size = Vector2(10, 10)
	rect.pivot_offset = Vector2(5, 5)
	proj.add_child(rect)

	proj.global_position = global_position
	var dir = global_position.direction_to(target.global_position)
	var start_pos = global_position

	proj.body_entered.connect(func(body):
		if body and body.has_method("take_damage"):
			body.take_damage(ranged_damage)
			proj.queue_free()
	)

	get_tree().current_scene.add_child(proj)

	# 用 Tween 驱动飞行
	var t = proj.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(proj, "global_position", start_pos + dir * ranged_speed * 3.0, 3.0)
	t.tween_callback(proj.queue_free)


# ─── 原有移动（保持兼容） ───

func _chase_player() -> void:
	# 旧接口兼容
	_chase_straight(_get_player_direction())


func _get_player_direction() -> Vector2:
	var p = _get_player()
	if not p:
		return Vector2.ZERO
	return global_position.direction_to(p.global_position)


func _check_contact_damage(delta: float) -> void:
	_contact_damage_timer += delta
	if _contact_damage_timer < CONTACT_DAMAGE_INTERVAL:
		return
	var p = _get_player()
	if not p or not is_instance_valid(p):
		return
	if p.is_dead:
		# 玩家死亡时重置计时器，避免复活后瞬间被打
		_contact_damage_timer = 0.0
		return
	# 计时器到达间隔：无论是否在攻击范围内都重置，
	# 避免玩家不在范围时计时器持续累积导致进入范围瞬间受伤
	_contact_damage_timer = 0.0
	if global_position.distance_to(p.global_position) < CONTACT_DAMAGE_RANGE:
		if p.has_method("take_damage"):
			p.take_damage(damage * elite_damage_mult)


func _get_player() -> Node2D:
	var players = GameState.get_cached_group("player")
	if players.size() > 0:
		return players[0]
	return null


# ─── 受伤 ───

func take_damage(amount: float, is_crit: bool = false) -> void:
	if state == EnemyState.DYING or state == EnemyState.DEAD:
		return

	current_health -= amount
	GameState.total_damage_dealt += amount
	EventBus.enemy_damaged.emit(self, amount, is_crit)
	_hit_flash()

	# 反弹词条：受到伤害的 20% 反弹给玩家
	if "reflect" in extra_affixes:
		var rp = _get_player()
		if rp and is_instance_valid(rp) and rp.has_method("take_damage"):
			rp.take_damage(amount * 0.2)

	if knockback_resistance < 1.0:
		var p = _get_player()
		if p:
			var toward_player_dir = global_position.direction_to(p.global_position)
			velocity = -toward_player_dir * move_speed * 0.5
		state = EnemyState.HURT
		retreat_timer = 0.2

	if current_health <= 0:
		_die()


func _hit_flash() -> void:
	if sprite:
		sprite.modulate = Color(3, 3, 3, 1)
	# 受击闪光特效
	VFX.spawn_hit_flash(global_position)
	# 受击音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_hit()
	if hit_flash_timer:
		hit_flash_timer.start(0.1)
		if not hit_flash_timer.timeout.is_connected(_on_hit_flash_end):
			hit_flash_timer.timeout.connect(_on_hit_flash_end)


func _on_hit_flash_end() -> void:
	if sprite:
		sprite.modulate = Color.WHITE


func _die() -> void:
	state = EnemyState.DYING

	# 多米诺死亡连锁：推开周围敌人
	_domino_push()

	# 击杀音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_kill()

	EventBus.enemy_killed.emit(enemy_type, global_position, int(exp_value * elite_exp_mult), gold_value)

	_spawn_death_particles()

	# 自爆词条
	if "explode" in extra_affixes:
		_event_explode()
	if "poison" in extra_affixes:
		_leave_poison_cloud()

	# 死亡分裂
	if split_on_death:
		_split_on_death()

	# 精英击杀
	if is_elite:
		EventBus.elite_killed.emit(global_position, {"affix": elite_affix, "exp_bonus": exp_value})

	remove_from_group("enemy")
	# 敌人离组后刷新缓存
	GameState.invalidate_group_cache()

	# 死亡动画：缩小+淡出
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_death_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_death_tween.chain().tween_callback(func():
		if _pool_ref and _pool_ref.has_method("release"):
			_pool_ref.release(self)
		else:
			queue_free()
	)


func _split_on_death() -> void:
	"""死亡时分裂为小怪"""
	for i in range(split_count):
		var scene_path = "res://scenes/enemies/%s.tscn" % split_type
		if not ResourceLoader.exists(scene_path):
			continue
		var child_enemy = load(scene_path).instantiate()
		child_enemy.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		# 继承难度倍率
		var diff = GameState.get_difficulty_config()
		child_enemy.max_health *= diff["hp_mult"]
		child_enemy.move_speed *= diff["speed_mult"]
		child_enemy.current_health = child_enemy.max_health
		get_tree().current_scene.add_child.call_deferred(child_enemy)   # 同 B-10：延迟入树
		EventBus.enemy_spawned.emit(child_enemy)
		# 注册到生成器活跃列表，否则不会被 _cleanup_dead_enemies 跟踪
		var spawner = get_tree().get_first_node_in_group("spawner")
		if spawner and spawner.has_method("register_enemy"):
			spawner.register_enemy(child_enemy)


func _event_explode() -> void:
	EventBus.screen_shake_requested.emit(3.0, 0.15)
	var p = _get_player()
	if p and is_instance_valid(p) and not p.is_dead:
		if global_position.distance_to(p.global_position) < 100.0 and p.has_method("take_damage"):
			p.take_damage(20.0)


func _spawn_death_particles() -> void:
	if not SaveSystem.get_setting("particles"):
		return
	# VFX 星形爆散
	VFX.spawn_kill_burst(global_position, Color(1.0, 0.7, 0.2), 8)
	# 中心冲击波
	var wave := VFX.make_shockwave(Color(1.0, 0.5, 0.1, 0.6), 30.0)
	wave.global_position = global_position
	get_tree().current_scene.add_child(wave)
	var wt := wave.create_tween()
	wt.set_parallel(true)
	wt.tween_property(wave, "scale", Vector2.ONE * 2.0, 0.2)
	wt.tween_property(wave, "modulate:a", 0.0, 0.2)
	wt.chain().tween_callback(wave.queue_free)


func _leave_poison_cloud() -> void:
	var field = Node2D.new()
	field.set_script(load("res://scripts/weapons/poison_field.gd"))
	field.damage_per_sec = 5.0
	field.radius = 60.0
	field.duration = 3.0
	field.target_group = "player"
	field.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(field)


# ─── 精英/词条 ───

func make_elite(affix: String) -> void:
	is_elite = true
	elite_affix = affix
	match affix:
		"fast":
			move_speed *= 1.5
			if sprite:
				sprite.modulate = Color(1.5, 0.5, 0.5)
		"tough":
			elite_hp_mult = 3.0
			elite_exp_mult = 3.0
			if sprite:
				sprite.modulate = Color(0.8, 0.8, 1.2)
		"multishot":
			pass
	elite_damage_mult = 1.5 if affix != "tough" else 1.0
	current_health = max_health * elite_hp_mult
	scale *= 1.4
	_add_elite_star()


func add_extra_affix(affix: String) -> void:
	extra_affixes.append(affix)


# 冰系减速（供冰晶风暴等调用）；简化：减速期间忽略新的减速请求
func apply_slow(amount: float, duration: float) -> void:
	if _slow_active:
		return
	_slow_active = true
	var orig := move_speed
	move_speed *= (1.0 - amount)
	if _slow_tween and _slow_tween.is_valid():
		_slow_tween.kill()
	_slow_tween = create_tween()
	_slow_tween.tween_interval(duration)
	_slow_tween.tween_callback(func():
		move_speed = orig
		_slow_active = false
		_slow_tween = null
	)


# 持续伤害（灼烧/中毒），DOT 不暴击、紫色数字（GDD 8.2）
func apply_dot(dps: float, duration: float) -> void:
	# 用最新的 DOT 直接替换，避免 dps 与 duration 解耦叠加：
	# 旧实现 max(dps) + max(duration) 会让弱 DOT 延长强 DOT 的持续时间
	_dot_dps = dps
	_dot_time = duration


func _process_dot(delta: float) -> void:
	if _dot_time <= 0.0 or state == EnemyState.DYING or state == EnemyState.DEAD:
		return
	_dot_time -= delta
	_dot_tick += delta
	if _dot_tick >= 1.0:
		_dot_tick -= 1.0
		current_health -= _dot_dps
		EventBus.damage_number_requested.emit(global_position + Vector2(0, -14), _dot_dps, false, 2)
		if current_health <= 0.0:
			_die()
	if _dot_time <= 0.0:
		_dot_dps = 0.0


func _add_elite_star() -> void:
	var star = Label.new()
	star.text = "★"
	star.add_theme_font_size_override("font_size", 14)
	star.modulate = Color(1.0, 0.9, 0.2)
	star.position = Vector2(-7, -38)
	star.z_index = 10
	add_child(star)


func _summon_minion() -> void:
	var scene = load("res://scenes/enemies/slime_small.tscn")
	if not scene:
		return
	var m = scene.instantiate()
	m.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	get_tree().current_scene.add_child.call_deferred(m)
	EventBus.enemy_spawned.emit(m)
	# 注册到生成器活跃列表
	var spawner = get_tree().get_first_node_in_group("spawner")
	if spawner and spawner.has_method("register_enemy"):
		spawner.register_enemy(m)


# ─── 多米诺击退连锁 ───

func _domino_push() -> void:
	"""死亡时推开周围敌人，形成多米诺骨牌效应"""
	const PUSH_RADIUS := 80.0
	const PUSH_FORCE := 150.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy == self:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < PUSH_RADIUS and dist > 0.1:
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			var force: float = PUSH_FORCE * (1.0 - dist / PUSH_RADIUS)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(dir * force)


func reset_for_pool() -> void:
	"""从池中重新激活时重置状态"""
	# 恢复初始数值，避免 spawner 每次生成时叠加倍率
	max_health = _base_max_health
	move_speed = _base_move_speed
	# 重置精英属性，避免池化后残留/叠加
	elite_hp_mult = 1.0
	elite_damage_mult = 1.0
	elite_exp_mult = 1.0
	elite_affix = ""
	is_elite = false
	current_health = max_health * elite_hp_mult
	state = EnemyState.CHASING
	is_retreating = false
	retreat_timer = 0.0
	_is_charging = false
	_charge_timer = 0.0
	_ranged_timer = 0.0
	_summon_timer = 0.0
	_slow_active = false
	_dot_dps = 0.0
	_dot_time = 0.0
	_dot_tick = 0.0
	extra_affixes.clear()
	_contact_damage_timer = 0.0
	# 杀死残留死亡 Tween，避免重新激活后回调误触发 release/queue_free
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
		_death_tween = null
	# 杀死残留减速 Tween，避免回调用过期 orig 覆盖 reset 后的 move_speed
	if _slow_tween and _slow_tween.is_valid():
		_slow_tween.kill()
		_slow_tween = null
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func set_pool_ref(pool: Node) -> void:
	_pool_ref = pool


func apply_knockback(force: Vector2) -> void:
	"""被推开（Shield Gate / 爆炸连锁 等调用）"""
	if knockback_resistance >= 0.5:
		return  # 高韧性敌人不受强力推开
	velocity += force
	state = EnemyState.HURT
	retreat_timer = 0.15

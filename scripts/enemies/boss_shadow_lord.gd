# BossShadowLord - 暗影领主 BOSS
# 3阶段战斗：弹幕→环形→狂暴
# Phase1: 直线弹幕  Phase2: 环形弹幕  Phase3: 狂暴+召唤小怪
extends CharacterBody2D

enum BossPhase { PHASE1, PHASE2, PHASE3, DYING, DEAD }

const TOTAL_HP: float = 800.0
const PHASE2_HP: float = 400.0   # 50%
const PHASE3_HP: float = 200.0   # 25%
const MOVE_SPEED: float = 40.0

@export var current_hp: float = TOTAL_HP

var phase: BossPhase = BossPhase.PHASE1
var _attack_timer: float = 0.0
var _phase2_angle: float = 0.0
var _summon_timer: float = 0.0
var _is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_timer_node: Timer = $AttackTimer
@onready var hurt_timer: Timer = $HurtTimer


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	current_hp = TOTAL_HP
	phase = BossPhase.PHASE1
	_enter_phase1()
	EventBus.boss_hp_changed.emit(TOTAL_HP, TOTAL_HP)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if GameState.is_paused or GameState.is_game_over:
		return

	_chase_player()
	move_and_slide()

	_attack_timer += delta
	match phase:
		BossPhase.PHASE1:
			if _attack_timer > 0.8:
				_attack_timer = 0.0
				_shoot_linear_barrage()
		BossPhase.PHASE2:
			if _attack_timer > 0.6:
				_attack_timer = 0.0
				_shoot_circular()
			_phase2_angle += delta * 0.5
			sprite.rotation = sin(_phase2_angle) * 0.1
		BossPhase.PHASE3:
			if _attack_timer > 0.4:
				_attack_timer = 0.0
				_shoot_spiral()
			_summon_timer += delta
			if _summon_timer > 3.0:
				_summon_timer = 0.0
				_summon_minions()
		BossPhase.DYING:
			pass
		BossPhase.DEAD:
			return


func _chase_player() -> void:
	var p = _get_player()
	if not p:
		return
	var dir = global_position.direction_to(p.global_position)
	velocity = dir * MOVE_SPEED


func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


# ─── 阶段切换 ───

func take_damage(amount: float, _is_crit: bool = false) -> void:
	if _is_dead:
		return
	current_hp -= amount
	EventBus.boss_hp_changed.emit(maxf(0.0, current_hp), TOTAL_HP)
	EventBus.damage_number_requested.emit(global_position + Vector2(0, -50), amount, _is_crit, 3)
	_flash()

	if current_hp <= 0:
		_die()
	elif current_hp <= PHASE3_HP and phase != BossPhase.PHASE3:
		_enter_phase3()
	elif current_hp <= PHASE2_HP and phase != BossPhase.PHASE2:
		_enter_phase2()


func _flash() -> void:
	sprite.modulate = Color(3, 3, 3)
	if hurt_timer:
		hurt_timer.stop()
		if hurt_timer.timeout.is_connected(_on_flash_end):
			hurt_timer.timeout.disconnect(_on_flash_end)
		hurt_timer.timeout.connect(_on_flash_end)
		hurt_timer.start(0.1)


func _on_flash_end() -> void:
	sprite.modulate = Color.WHITE


func _enter_phase1() -> void:
	phase = BossPhase.PHASE1
	sprite.modulate = Color(0.9, 0.5, 1.0)
	EventBus.boss_phase_changed.emit(1)


func _enter_phase2() -> void:
	phase = BossPhase.PHASE2
	sprite.modulate = Color(1.0, 0.3, 0.8)
	sprite.scale = Vector2(1.2, 1.2)
	EventBus.boss_phase_changed.emit(2)
	EventBus.screen_shake_requested.emit(6.0, 0.3)


func _enter_phase3() -> void:
	phase = BossPhase.PHASE3
	sprite.modulate = Color(1.0, 0.15, 0.15)
	sprite.scale = Vector2(1.4, 1.4)
	EventBus.boss_phase_changed.emit(3)
	EventBus.screen_shake_requested.emit(10.0, 0.5)


func _die() -> void:
	_is_dead = true
	phase = BossPhase.DYING
	sprite.modulate = Color(0.3, 0.3, 0.3)
	EventBus.screen_shake_requested.emit(15.0, 0.8)
	# BOSS 死亡音效（参考 base_enemy._die 的位置：在 emit 之前播放）
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_boss_die()
	EventBus.boss_killed.emit()
	EventBus.enemy_killed.emit("boss_shadow_lord", global_position, 500, 50)
	_drop_feather()

	# 死亡动画后销毁
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0, 0), 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# ─── 攻击模式 ───

func _shoot_linear_barrage() -> void:
	var p = _get_player()
	if not p:
		return
	for i in range(3):
		var offset = (i - 1) * 0.3
		var dir = global_position.direction_to(p.global_position).rotated(offset)
		_spawn_projectile(dir, 250.0, 8.0, Color(0.6, 0.3, 1.0))


func _shoot_circular() -> void:
	for i in range(8):
		var angle = _phase2_angle + i * TAU / 8
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_projectile(dir, 180.0, 6.0, Color(1.0, 0.2, 0.5))


func _shoot_spiral() -> void:
	for i in range(12):
		var angle = _phase2_angle + i * TAU / 12
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_projectile(dir, 220.0, 10.0, Color(1.0, 0.1, 0.1))


static var _projectile_tex: ImageTexture = null

func _spawn_projectile(dir: Vector2, speed: float, dmg: float, col: Color) -> void:
	var proj = BossProjectile.new()
	proj.direction = dir
	proj.speed = speed
	proj.damage = dmg
	proj.collision_layer = 8
	proj.collision_mask = 1

	var pshape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	pshape.shape = circle
	proj.add_child(pshape)

	var psprite = Sprite2D.new()
	if not _projectile_tex:
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_projectile_tex = ImageTexture.create_from_image(img)
	psprite.texture = _projectile_tex
	psprite.modulate = col
	psprite.scale = Vector2(0.6, 0.6)
	psprite.name = "Sprite2D"
	proj.add_child(psprite)

	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)


func _summon_minions() -> void:
	var scene = load("res://scenes/enemies/slime_small.tscn")
	if not scene:
		return
	for i in range(3):
		var pos = global_position + Vector2(GameState.rng.randf_range(-80, 80), GameState.rng.randf_range(-80, 80))
		var slime = scene.instantiate()
		slime.global_position = pos
		get_tree().current_scene.add_child(slime)
		EventBus.enemy_spawned.emit(slime)
		# 注册到生成器活跃列表，否则不会被 _cleanup_dead_enemies 跟踪
		var spawner = get_tree().get_first_node_in_group("spawner")
		if spawner and spawner.has_method("register_enemy"):
			spawner.register_enemy(slime)


# 击杀 BOSS 掉落复活羽毛（D-6）— 复用对象池
func _drop_feather() -> void:
	var spawner = get_tree().get_first_node_in_group("spawner")
	var gem: Node = null
	if spawner and spawner.has_method("spawn_exp_gem"):
		spawner.spawn_exp_gem(global_position, 0, 0)
		# spawn_exp_gem 内部会创建 feather 类型宝石，但默认创建的是 exp 类型
		# 需手动设置最后创建的宝石为 feather 类型
		var all_gems = get_tree().get_nodes_in_group("gem")
		if all_gems.size() > 0:
			gem = all_gems[-1]
			if gem is ExpGem:
				gem.pickup_type = "feather"
				gem.exp_amount = 0
				gem.gold_amount = 0
				gem._set_color_by_type()
	else:
		var gem_scene = load("res://scenes/enemies/exp_gem.tscn")
		if not gem_scene:
			return
		gem = gem_scene.instantiate()
		gem.pickup_type = "feather"
		gem.exp_amount = 0
		gem.global_position = global_position
		get_tree().current_scene.add_child.call_deferred(gem)

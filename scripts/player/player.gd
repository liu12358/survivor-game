# Player - 玩家控制器
# 处理移动输入、碰撞伤害、无敌帧、状态机
class_name Player
extends CharacterBody2D

const INVINCIBLE_TIME: float = 0.5
const BASE_SPEED: float = 200.0
const MAGNET_PULSE_INTERVAL: float = 0.3

# HP / 护盾以 GameState 为唯一数据源（D-1）。此处为代理属性，外部引用（heal/take_damage/复活/拾取）无需改动。
var max_health: float:
	get: return GameState.max_hp
	set(v): GameState.max_hp = v
var current_health: float:
	get: return GameState.current_hp
	set(v): GameState.current_hp = v
var shield_health: float:
	get: return GameState.shield_hp
	set(v): GameState.shield_hp = v

var invincible_timer: float = 0.0
var is_dead: bool = false
var _skin_color: Color = Color.WHITE
var _spawn_protected: bool = true

# Shield Gate（护盾破裂保护）
var _shield_gate_active: bool = false           # 本帧已触发 shield gate，防递归
const SHIELD_GATE_DURATION: float = 0.15        # 破盾微无敌帧时长
const SHIELD_GATE_PUSH_RADIUS: float = 120.0    # 推开波半径
const SHIELD_GATE_PUSH_FORCE: float = 200.0     # 推开力度

# 状态枚举
enum PlayerState { NORMAL, HURT, LEVELING, DEAD, STUNNED }
var state: PlayerState = PlayerState.NORMAL

# 异常状态
var is_slowed: bool = false
var slow_amount: float = 0.0
var burn_stacks: int = 0
var is_stunned: bool = false
var _trail_timer: float = 0.0
var _magnet_pulse: float = 0.0

# 死亡慢动作 Tween 引用：重复死亡时先 kill 旧 tween，避免回调提前触发（Task 40）
var _death_tween: Tween = null
var _slow_tween: Tween = null
var _stun_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_timer: Timer = $HurtTimer
@onready var pickup_area: Area2D = $PickupArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_init_player()
	_setup_signals()


func _init_player() -> void:
	# HP / 移速由 GameState 提供（单一数据源 D-1），开局值已在 Main._start_game 中重置
	_update_pickup_range()
	# 应用皮肤（纯换色，不影响数值）
	var skin = GameState.SKINS.get(GameState.selected_skin, GameState.SKINS["default"])
	_skin_color = skin["color"]
	sprite.modulate = _skin_color
	# 发光光晕（程序化，跟随皮肤色，柔和呼吸）
	var glow := VFX.make_glow(_skin_color, 74.0, 0.45)
	add_child(glow)
	var gt := create_tween().set_loops()
	gt.tween_property(glow, "modulate:a", 0.6, 1.1).set_trans(Tween.TRANS_SINE)
	gt.tween_property(glow, "modulate:a", 0.28, 1.1).set_trans(Tween.TRANS_SINE)


func _setup_signals() -> void:
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	EventBus.screen_shake_requested.connect(_on_screen_shake)


func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	if state == PlayerState.DEAD or state == PlayerState.LEVELING or state == PlayerState.STUNNED:
		return

	# 开局位置保护：未输入前强制留在原点，防止瞬移/滑出
	if _spawn_protected:
		var pdir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if pdir.length() > 0.2:
			var js = get_tree().get_first_node_in_group("joystick")
			if js and js.has_method("get_direction"):
				var jd = js.get_direction()
				if jd.length() > 0.15:
					pdir = jd
		if pdir.length() > 0.2:
			_spawn_protected = false
		else:
			global_position = Vector2.ZERO
			velocity = Vector2.ZERO
			EventBus.player_moved.emit(global_position)
			_magnetize_nearby_gems(_delta)
			_spawn_trail(_delta)
			_update_timers(_delta)
			_apply_regen(_delta)
			return

	var spd = GameState.effective_move_speed()
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir.length() < 0.2:
		var js = get_tree().get_first_node_in_group("joystick")
		if js and js.has_method("get_direction"):
			var jd = js.get_direction()
			if jd.length() > 0.15:
				input_dir = jd

	if input_dir.length() > 0.2:
		velocity = input_dir * spd
	else:
		velocity = velocity.move_toward(Vector2.ZERO, spd * 5.0)

	move_and_slide()
	_clamp_to_boundary()
	EventBus.player_moved.emit(global_position)
	_magnetize_nearby_gems(_delta)
	_spawn_trail(_delta)
	_update_timers(_delta)
	_apply_regen(_delta)


func _update_timers(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer -= delta


func _apply_regen(delta: float) -> void:
	if GameState.hp_regen > 0 and current_health < max_health:
		var regen_amount = GameState.hp_regen * delta
		heal(regen_amount)


func _magnetize_nearby_gems(delta: float) -> void:
	_magnet_pulse += delta
	if _magnet_pulse < MAGNET_PULSE_INTERVAL:
		return
	_magnet_pulse = 0.0
	var gems = get_tree().get_nodes_in_group("gem")
	for gem in gems:
		if not is_instance_valid(gem):
			continue
		if global_position.distance_to(gem.global_position) < GameState.pickup_range:
			if gem.has_method("enable_magnet"):
				gem.enable_magnet(self)


func _on_hurt_timer_timeout() -> void:
	#
	if state == PlayerState.HURT:
		state = PlayerState.NORMAL

# ─── 受伤 ───

func take_damage(amount: float) -> void:
	if is_dead or invincible_timer > 0.0 or GameState.invincible_buff or GameState.cheat_godmode:
		return
	# 新手引导期间无敌（避免怪物在指引未点时攻击）
	if GameState.tutorial_active:
		return

	# ─── Shield Gate: 扣盾前记录旧值 ───
	var shield_before := shield_health

	# 先扣护盾
	var remaining = amount
	if shield_health > 0:
		var shield_dmg = min(remaining, shield_health)
		shield_health -= shield_dmg
		remaining -= shield_dmg

	# ─── Shield Gate: 盾从 >0 到 <=0 → 触发微无敌 + 推开波 ───
	var shield_just_broken := (shield_before > 0.0 and shield_health <= 0.0 and not _shield_gate_active)
	if shield_just_broken:
		_shield_gate_active = true
		invincible_timer = SHIELD_GATE_DURATION
		_shield_gate_push()
		# 非阻塞延迟一帧释放标志：避免 await 把 HP 扣减/信号发射整体延后一帧（Task 15）
		get_tree().create_timer(0.0).timeout.connect(func() -> void: _shield_gate_active = false, CONNECT_ONE_SHOT)

	# 扣HP
	if remaining > 0:
		var actual_damage = max(1.0, remaining - GameState.armor)
		current_health -= actual_damage
		GameState.total_damage_taken += actual_damage

	if current_health <= 0:
		_die()
		return

	# 受伤状态（shield gate 期间不计入完整无敌帧，避免覆盖）
	if not shield_just_broken:
		invincible_timer = INVINCIBLE_TIME
		state = PlayerState.HURT
		hurt_timer.start(INVINCIBLE_TIME)
	else:
		state = PlayerState.HURT
		hurt_timer.start(SHIELD_GATE_DURATION)

	# 受伤音效（仅在实际受伤且未死亡时播放）
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_player_hurt()

	# 视觉效果
	_flash_red()

	# 信号
	EventBus.player_damaged.emit(amount, current_health, max_health)


func _flash_red() -> void:
	#
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", _skin_color, 0.1)
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", _skin_color, 0.1)


# ─── Shield Gate: 破盾推开波 ───

func _shield_gate_push() -> void:
	# 推开周围敌人
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < SHIELD_GATE_PUSH_RADIUS and dist > 0.1:
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			# 力度随距离衰减
			var force := SHIELD_GATE_PUSH_FORCE * (1.0 - dist / SHIELD_GATE_PUSH_RADIUS)
			if enemy.has_method("apply_knockback"):
				enemy.apply_knockback(dir * force)
	# 视觉反馈：微型白色光圈
	var ring := Sprite2D.new()
	ring.texture = _make_push_ring_tex()
	ring.global_position = global_position
	ring.modulate = Color(1.0, 1.0, 1.0, 0.6)
	get_tree().current_scene.add_child(ring)
	var t := create_tween()
	t.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.15)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.15)
	t.tween_callback(ring.queue_free)


static var _push_ring_tex: ImageTexture = null

func _make_push_ring_tex() -> Texture2D:
	if _push_ring_tex:
		return _push_ring_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for x in range(size):
		for y in range(size):
			var d := Vector2(x - c, y - c).length()
			if d <= c - 1 and d >= c - 4:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.8))
	_push_ring_tex = ImageTexture.create_from_image(img)
	return _push_ring_tex


func _die() -> void:
	is_dead = true
	state = PlayerState.DEAD
	collision_shape.set_deferred("disabled", true)
	# 死亡慢动作：重复死亡时先 kill 旧 tween，避免旧回调把 time_scale 提前归位（Task 40）
	Engine.time_scale = 0.3
	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_death_tween.tween_interval(0.3)
	_death_tween.tween_callback(func(): Engine.time_scale = 1.0)
	# 玩家死亡音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_player_die()
	EventBus.player_died.emit()

# ─── 治疗 ───

func heal(amount: float) -> void:
	var old = current_health
	current_health = min(current_health + amount, max_health)
	EventBus.player_healed.emit(current_health - old, current_health)

# ─── 护盾 ───

func add_shield(amount: float) -> void:
	shield_health = min(shield_health + amount, max_health * 0.5)

# ─── 异常状态 ───

func apply_slow(amount: float, duration: float) -> void:
	is_slowed = true
	slow_amount = max(slow_amount, amount)
	GameState.slow_amount = clampf(slow_amount, 0.0, 0.6)
	if _slow_tween and _slow_tween.is_valid():
		_slow_tween.kill()
	_slow_tween = create_tween()
	_slow_tween.tween_callback(_clear_slow).set_delay(duration)


func _clear_slow() -> void:
	is_slowed = false
	slow_amount = 0.0
	GameState.slow_amount = 0.0
	_slow_tween = null


func apply_stun(duration: float) -> void:
	is_stunned = true
	state = PlayerState.STUNNED
	if _stun_tween and _stun_tween.is_valid():
		_stun_tween.kill()
	_stun_tween = create_tween()
	_stun_tween.tween_callback(_clear_stun).set_delay(duration)


func _clear_stun() -> void:
	is_stunned = false
	state = PlayerState.NORMAL
	_stun_tween = null

# ─── 工具 ───

func _spawn_trail(delta: float) -> void:
	if not SaveSystem.get_setting("particles"):
		return
	if velocity.length() < 10:
		return
	_trail_timer += delta
	if _trail_timer < 0.05:
		return
	_trail_timer = 0.0
	var p = ColorRect.new()
	p.color = Color(0.3, 0.6, 0.9, 0.5)
	p.size = Vector2(6, 6)
	p.pivot_offset = Vector2(3, 3)
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	var t = create_tween()
	t.tween_property(p, "color:a", 0.0, 0.4)
	t.parallel().tween_property(p, "size", Vector2(2, 2), 0.4)
	t.tween_callback(p.queue_free)


func _update_pickup_range() -> void:
	var shape: CircleShape2D = pickup_area.get_node("CollisionShape2D").shape
	shape.radius = GameState.pickup_range


func _on_screen_shake(_amplitude: float, _duration: float) -> void:
	# 震屏由MainCamera处理
	pass


func set_leveling_state(active: bool) -> void:
	if active:
		state = PlayerState.LEVELING
	else:
		state = PlayerState.NORMAL


func _clamp_to_boundary() -> void:
	# 与 main.gd MAP_RADIUS=800 保持一致，避免玩家可在边界外缘卡位（Task 42）
	var boundary_radius: float = 800.0
	var dist = global_position.length()
	if dist > boundary_radius:
		global_position = global_position.normalized() * boundary_radius

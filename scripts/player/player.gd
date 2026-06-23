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

# 状态枚举
enum PlayerState { NORMAL, HURT, LEVELING, DEAD, STUNNED }
var state: PlayerState = PlayerState.NORMAL

# 异常状态
var is_slowed: bool = false
var slow_amount: float = 0.0
var is_burning: bool = false
var burn_stacks: int = 0
var is_frozen: bool = false
var is_stunned: bool = false
var _trail_timer: float = 0.0
var _magnet_pulse: float = 0.0

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


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	match state:
		PlayerState.NORMAL:
			_handle_movement()
			_update_timers(delta)
			_apply_regen(delta)
		PlayerState.HURT:
			_update_timers(delta)
			_apply_regen(delta)
		PlayerState.LEVELING:
			pass  # 暂停中，不处理
		PlayerState.DEAD:
			return
		PlayerState.STUNNED:
			_update_timers(delta)
			_apply_regen(delta)

	move_and_slide()
	EventBus.player_moved.emit(global_position)
	_magnetize_nearby_gems(delta)
	_spawn_trail(delta)


func _handle_movement() -> void:
	var spd := GameState.effective_move_speed()
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 键盘无输入时回退到触屏摇杆
	if input_dir.length() < 0.2:
		var js = get_tree().get_first_node_in_group("joystick")
		if js and js.has_method("get_direction"):
			var jd: Vector2 = js.get_direction()
			if jd.length() > 0.15:
				input_dir = jd
	if input_dir.length() > 0.2:
		velocity = input_dir * spd
	else:
		velocity = velocity.move_toward(Vector2.ZERO, spd * 5.0)


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

	# 先扣护盾
	var remaining = amount
	if shield_health > 0:
		var shield_dmg = min(remaining, shield_health)
		shield_health -= shield_dmg
		remaining -= shield_dmg

	# 扣HP
	if remaining > 0:
		var actual_damage = max(1.0, remaining - GameState.armor)
		current_health -= actual_damage

	if current_health <= 0:
		_die()
		return

	# 受伤状态
	invincible_timer = INVINCIBLE_TIME
	state = PlayerState.HURT
	hurt_timer.start(INVINCIBLE_TIME)

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


func _die() -> void:
	is_dead = true
	state = PlayerState.DEAD
	collision_shape.set_deferred("disabled", true)
	# 死亡慢动作
	Engine.time_scale = 0.3
	var t = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_interval(0.3)
	t.tween_callback(func(): Engine.time_scale = 1.0)
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
	var t = create_tween()
	t.tween_callback(_clear_slow).set_delay(duration)


func _clear_slow() -> void:
	is_slowed = false
	slow_amount = 0.0
	GameState.slow_amount = 0.0


func apply_stun(duration: float) -> void:
	is_stunned = true
	state = PlayerState.STUNNED
	var t = create_tween()
	t.tween_callback(_clear_stun).set_delay(duration)


func _clear_stun() -> void:
	is_stunned = false
	state = PlayerState.NORMAL

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

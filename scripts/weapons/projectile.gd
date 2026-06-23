# Projectile - 通用投射物
# 所有武器子弹共用此类
class_name Projectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 10.0
var penetration: int = 0
var remaining_pen: int = 0
var lifetime: float = 3.0
var _time_alive: float = 0.0
var enable_split: bool = false
# 暴击 / 吸血由发射武器设置（D-5）
var crit_chance: float = 0.0
var crit_mult: float = 1.5
var lifesteal: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _glow: Sprite2D = null


func _ready() -> void:
	remaining_pen = penetration
	body_entered.connect(_on_body_entered)
	_glow = VFX.make_glow(Color.WHITE, 26.0, 0.5)
	add_child(_glow)


func activate() -> void:
	_time_alive = 0.0
	remaining_pen = penetration
	set_process(true)
	visible = true
	if sprite:
		sprite.visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if _glow:
		_glow.visible = true


func _process(delta: float) -> void:
	_time_alive += delta
	if _time_alive > lifetime:
		_deactivate()
		return

	global_position += direction * speed * delta

	# 边界检测（相对摄像机）
	var cam = get_viewport().get_camera_2d()
	var bounds: Rect2
	if cam:
		var cam_pos = cam.global_position
		var view_size = get_viewport().get_visible_rect().size
		bounds = Rect2(cam_pos - view_size * 0.6, view_size * 1.2)
	else:
		bounds = get_viewport().get_visible_rect().grow(400)

	if not bounds.has_point(global_position):
		_deactivate()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return

	if body.has_method("take_damage"):
		var is_crit = randf() < crit_chance
		var final_dmg = damage
		if is_crit:
			final_dmg *= crit_mult

		body.take_damage(final_dmg, is_crit)

		# 弹伤害数字
		EventBus.damage_number_requested.emit(body.global_position + Vector2(0, -32), final_dmg, is_crit, 0)

		# 吸血
		if lifesteal > 0:
			var heal_amount = final_dmg * lifesteal
			var p = _get_player()
			if p and p.has_method("heal"):
				p.heal(heal_amount)

		# 穿透判定
		if remaining_pen > 0:
			remaining_pen -= 1
		else:
			_deactivate()
			return

		# 击退
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction * 100)


func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func _deactivate() -> void:
	set_process(false)
	if sprite:
		sprite.visible = false
	if _glow:
		_glow.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	# 对象池回收 or 直接销毁
	var pool = get_parent()
	if pool and pool.has_method("release"):
		pool.release(self)
	else:
		queue_free()


func set_projectile_color(col: Color) -> void:
	if sprite:
		sprite.modulate = col
	if _glow:
		_glow.modulate = Color(col.r, col.g, col.b, 0.5)


func set_projectile_scale(scl: float) -> void:
	if sprite:
		sprite.scale = Vector2(scl, scl)
	if _glow:
		_glow.scale = Vector2.ONE * (26.0 / 64.0) * scl

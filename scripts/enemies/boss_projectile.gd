# BossProjectile - 暗影领主弹幕
# 自驱动移动的 Boss 投射物，尊重暂停/游戏结束状态
class_name BossProjectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var damage: float = 8.0
var lifetime: float = 5.0
var _time_alive: float = 0.0
var _consumed: bool = false


@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _consumed:
		return
	if GameState.is_paused or GameState.is_game_over:
		return
	_time_alive += delta
	if _time_alive > lifetime:
		_deactivate()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _consumed:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	EventBus.screen_shake_requested.emit(2.0, 0.1)
	_deactivate()


func _deactivate() -> void:
	_consumed = true
	set_process(false)
	if sprite:
		sprite.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	queue_free()

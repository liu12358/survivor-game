# ExpGem - 经验宝石
# 击杀敌人掉落，靠近自动拾取
class_name ExpGem
extends Area2D

@export var exp_amount: int = 5
@export var gold_amount: int = 0
@export var pickup_type: String = "exp"  # exp / gold / heal / shield / buff

var is_magnetized: bool = false
var magnet_speed: float = 800.0
var fly_speed: float = 0.0
var _lifetime: float = 30.0  # 30秒后自动消失
var _time_alive: float = 0.0
var target_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	add_to_group("gem")
	_set_color_by_type()
	# 发光（用类型对应的颜色）
	var glow := VFX.make_glow(sprite.modulate, 28.0, 0.55)
	add_child(glow)


func _process(delta: float) -> void:
	_time_alive += delta
	if _time_alive > _lifetime:
		queue_free()
		return

	if is_magnetized:
		if not target_player or not is_instance_valid(target_player):
			is_magnetized = false
			return
		var dir = global_position.direction_to(target_player.global_position)
		global_position += dir * magnet_speed * delta
	elif fly_speed > 0:
		# 生成时的小弹跳
		var falloff = _time_alive / 0.5
		if falloff < 1.0:
			global_position += Vector2(randf_range(-1, 1), -1).normalized() * fly_speed * (1.0 - falloff) * delta


func _on_area_entered(area: Area2D) -> void:
	# 被玩家拾取范围检测到
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_pickup(parent)


func _pickup(player: Node2D) -> void:
	match pickup_type:
		"exp":
			EventBus.exp_collected.emit(exp_amount)
		"gold":
			EventBus.gold_collected.emit(gold_amount)
		"heal":
			if player.has_method("heal"):
				player.heal(player.max_health * 0.2)
			EventBus.item_picked_up.emit("heal", {"amount": player.max_health * 0.2})
		"shield":
			if player.has_method("add_shield"):
				player.add_shield(player.max_health * 0.3)
			EventBus.item_picked_up.emit("shield", {"amount": player.max_health * 0.3})
		"buff_damage":
			# 由Main处理buff
			EventBus.item_picked_up.emit("buff_damage", {"duration": 8.0, "effect": 0.5})
		"buff_speed":
			EventBus.item_picked_up.emit("buff_speed", {"duration": 8.0, "effect": 0.4})
		"buff_exp":
			EventBus.item_picked_up.emit("buff_exp", {"duration": 10.0})
		"invincible":
			EventBus.item_picked_up.emit("invincible", {"duration": 5.0})
		"magnet":
			EventBus.item_picked_up.emit("magnet", {})
		"clear_bomb":
			EventBus.item_picked_up.emit("clear_bomb", {})
		"feather":
			GameState.max_revive_count += 1
			EventBus.item_picked_up.emit("feather", {"max_revives": GameState.max_revive_count})

	EventBus.screen_shake_requested.emit(1.0, 0.05)
	queue_free()


func enable_magnet(player_ref: Node2D) -> void:
	is_magnetized = true
	target_player = player_ref


func _set_color_by_type() -> void:
	match pickup_type:
		"exp":    sprite.modulate = Color(0.3, 0.6, 1.0)   # 蓝
		"gold":   sprite.modulate = Color(1.0, 0.85, 0.2)  # 金
		"heal":   sprite.modulate = Color(1.0, 0.2, 0.2)   # 红
		"shield": sprite.modulate = Color(1.0, 0.85, 0.2)  # 金
		"buff_damage": sprite.modulate = Color(1.0, 0.5, 0.1)   # 橙（增伤）
		"buff_speed":  sprite.modulate = Color(0.3, 1.0, 0.4)   # 绿（加速）
		"buff_exp":    sprite.modulate = Color(0.5, 0.8, 1.0)   # 亮蓝（经验翻倍）
		"invincible":  sprite.modulate = Color(1.0, 1.0, 0.6)   # 亮黄（无敌）
		"magnet":      sprite.modulate = Color(0.4, 0.6, 1.0)   # 蓝（磁铁）
		"clear_bomb":  sprite.modulate = Color(1.0, 0.3, 0.3)   # 红（清屏）
		"feather": sprite.modulate = Color(1.0, 1.0, 1.0)  # 白（复活羽毛）
		_:        sprite.modulate = Color(0.9, 0.9, 1.0)   # 其它

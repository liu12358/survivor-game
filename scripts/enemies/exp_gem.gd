# ExpGem - 经验宝石
# 击杀敌人掉落，靠近自动拾取
class_name ExpGem
extends Area2D

@export var exp_amount: int = 5
@export var gold_amount: int = 0
@export var pickup_type: String = "exp"  # exp / gold / heal / shield / buff
@export var gem_tier: int = 1            # 宝石阶级: 1=绿(低) 2=蓝(中) 3=紫(高)

var is_magnetized: bool = false
var magnet_speed: float = 800.0
var fly_speed: float = 0.0
var _lifetime: float = 30.0
var _time_alive: float = 0.0
var target_player: Node2D = null
var _pool_ref: Node = null
var _initial_dist: float = 0.0           # 磁吸起始距离
var _arc_offset: float = 0.0             # 弧形摆动偏移
var _mergeable: bool = true              # 可被合并
var _picked_up: bool = false             # 拾取幂等守卫（磁吸+碰撞/动画+超时同帧触发）
var _released: bool = false              # 释放幂等守卫（防止 tween 回调与超时双重释放）
var _fx_tween: Tween = null              # 拾取动画引用（reset_for_pool 时 kill，避免残留回调误释放）

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
		_release_to_pool()
		return

	if is_magnetized:
		if not target_player or not is_instance_valid(target_player):
			is_magnetized = false
			return
		var to_player = target_player.global_position - global_position
		var dist = to_player.length()
		if dist < 5.0:
			# 已被玩家拾取区域捕获，直接触发
			_pickup(target_player)
			return

		var dir = to_player.normalized()

		# Ease-In 二次加速曲线: 距离越近飞得越快
		var t = clamp(1.0 - dist / max(_initial_dist, 0.01), 0.0, 1.0)
		var speed = magnet_speed * (1.0 + t * t * 2.0)

		# 靠近 10px 内触发弧形摆动
		var arc = 0.0
		if dist < 50.0:
			var arc_factor = clamp(1.0 - (dist - 5.0) / 45.0, 0.0, 1.0)
			arc = sin(_time_alive * 14.0 + _arc_offset) * 3.0 * arc_factor * arc_factor

		var movement = dir * speed * delta
		movement += dir.orthogonal() * arc * delta * 60.0
		global_position += movement
	elif fly_speed > 0:
		var falloff = _time_alive / 0.5
		if falloff < 1.0:
			global_position += Vector2(randf_range(-1, 1), -1).normalized() * fly_speed * (1.0 - falloff) * delta


func _on_area_entered(area: Area2D) -> void:
	# 被玩家拾取范围检测到
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_pickup(parent)


func _pickup(player: Node2D) -> void:
	if _picked_up:
		return
	if not is_inside_tree():
		return
	_picked_up = true
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

	# 拾取动画
	_pickup_fx()
	# 拾取音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_pickup()
	# 拾取后刷新缓存（宝石即将消失）
	GameState.invalidate_group_cache()


func _pickup_fx() -> void:
	# 小粒子爆散
	if SaveSystem.get_setting("particles"):
		for i in range(4):
			var p = ColorRect.new()
			p.color = sprite.modulate
			p.color.a = 0.8
			p.size = Vector2(3, 3)
			p.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			get_tree().current_scene.add_child(p)
			var t = create_tween()
			t.set_parallel(true)
			t.tween_property(p, "global_position", global_position + Vector2(randf_range(-15, 15), randf_range(-20, -5)), 0.2)
			t.tween_property(p, "color:a", 0.0, 0.2)
			t.tween_callback(p.queue_free)

	# 缩放消失（释放由 tween 回调触发，避免双重释放）
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.set_parallel(true)
	_fx_tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.1).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "modulate:a", 0.0, 0.1)
	_fx_tween.chain().tween_callback(_release_to_pool)

	EventBus.screen_shake_requested.emit(1.0, 0.05)


func _release_to_pool() -> void:
	if _released:
		return
	_released = true
	remove_from_group("gem")
	is_magnetized = false
	target_player = null
	_time_alive = 0.0
	# 宝石离组后刷新缓存
	GameState.invalidate_group_cache()
	if _pool_ref and _pool_ref.has_method("release"):
		_pool_ref.release(self)
	else:
		queue_free()


func set_pool_ref(pool: Node) -> void:
	_pool_ref = pool


func reset_for_pool() -> void:
	"""从池中重用时重置"""
	# 杀死残留拾取 Tween，避免重新激活后回调误触发 _release_to_pool
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
		_fx_tween = null
	_picked_up = false
	_released = false
	_time_alive = 0.0
	is_magnetized = false
	fly_speed = 0.0
	target_player = null
	exp_amount = 5
	gold_amount = 0
	pickup_type = "exp"
	gem_tier = 1
	_initial_dist = 0.0
	_arc_offset = 0.0
	_mergeable = true
	_set_color_by_type()
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if get_child_count() < 2:
		var glow := VFX.make_glow(sprite.modulate, 28.0, 0.55)
		add_child(glow)
	add_to_group("gem")


func enable_magnet(player_ref: Node2D) -> void:
	is_magnetized = true
	target_player = player_ref
	_initial_dist = global_position.distance_to(player_ref.global_position)
	_arc_offset = randf() * TAU


func merge_into(other_gem: Node) -> bool:
	"""吸收另一个同类型宝石，等量叠加并升级"""
	if not other_gem.has_method("merge_into") or not _mergeable:
		return false
	if pickup_type != other_gem.pickup_type:
		# 不同类型不合并（exp 只能合 exp）
		return false
	if pickup_type == "exp":
		exp_amount += other_gem.exp_amount
		gold_amount += other_gem.gold_amount
		# 经验累计>50 → tier2, >200 → tier3
		if exp_amount >= 200 and gem_tier < 3:
			gem_tier = 3
		elif exp_amount >= 50 and gem_tier < 2:
			gem_tier = 2
		_set_tier_appearance()
	elif pickup_type == "gold":
		gold_amount += other_gem.gold_amount + other_gem.exp_amount
		if gold_amount >= 50:
			gem_tier = 2
		_set_tier_appearance()
	# 让被合并的宝石消失
	other_gem._mergeable = false
	if other_gem.has_method("_release_to_pool"):
		other_gem._release_to_pool()
	else:
		other_gem.queue_free()
	return true


func _set_tier_appearance() -> void:
	"""根据阶级调整外观"""
	match gem_tier:
		1: sprite.scale = Vector2(1.0, 1.0)
		2: sprite.scale = Vector2(1.3, 1.3)
		3: sprite.scale = Vector2(1.6, 1.6)


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

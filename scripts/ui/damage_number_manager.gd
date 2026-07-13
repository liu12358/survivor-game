# DamageNumberManager - 浮动伤害数字（合并版本）
# 监听 damage_number_requested 信号，创建浮动数字
# 0.1s 时间内同位置+同类型伤害自动合并累加
extends CanvasLayer

const FLOAT_DURATION: float = 0.8
const FLOAT_DISTANCE: float = 40.0
const FADE_START: float = 0.5
const CLUSTER_WINDOW: float = 0.1     # 合并时间窗口
const CLUSTER_GRID: float = 30.0       # 位置格网大小（像素）

# 合并缓存: {grid_key: {amount: float, is_crit: bool, dmg_type: int, label: Label, timer: float}}
var _cluster_cache: Dictionary = {}

# 伤害类型颜色
const DMG_COLORS = {
	0: Color(1, 0.95, 0.7, 1),  # 物理=浅黄（提高对比度）
	1: Color(0.4, 0.7, 1, 1),    # 魔法=蓝
	2: Color(0.7, 0.3, 1, 1),    # DOT=紫
	3: Color(1, 0.85, 0.2, 1),   # 真实=金
}


func _ready() -> void:
	layer = 5
	EventBus.damage_number_requested.connect(_on_damage_number)


func _on_damage_number(pos: Vector2, amount: float, is_crit: bool, dmg_type: int) -> void:
	if not SaveSystem.get_setting("damage_numbers"):
		return

	# 格网化位置作为合并 key
	var gx := int(pos.x / CLUSTER_GRID) * CLUSTER_GRID
	var gy := int(pos.y / CLUSTER_GRID) * CLUSTER_GRID
	var key := "%d_%d_%d" % [gx, gy, dmg_type]

	var entry = _cluster_cache.get(key)
	var now := Time.get_ticks_msec() / 1000.0

	if entry and (now - entry.timer) < CLUSTER_WINDOW:
		if not is_instance_valid(entry.label):
			_cluster_cache.erase(key)
			entry = null
		else:
			# 合并：累加数值 + 触发缩放抖动
			entry.amount += int(amount)
			entry.timer = now
			entry.label.text = "%d" % int(entry.amount)
			if is_crit and not entry.is_crit:
				entry.is_crit = true
				_set_crit_style(entry.label)
			# 缩放抖动
			var pulse := create_tween()
			pulse.tween_property(entry.label, "scale", Vector2(1.35, 1.35), 0.04)
			pulse.tween_property(entry.label, "scale", Vector2(1.0, 1.0), 0.08)
			return
	# entry 为 null、已过期或 label 失效 → 走下方创建新数字逻辑

	# 创建新数字
	var label = Label.new()
	label.text = str(int(amount))
	label.add_theme_font_size_override("font_size", 14 if not is_crit else 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = DMG_COLORS.get(dmg_type, Color.WHITE)
	if is_crit:
		_set_crit_style(label)
	# 描边阴影，提高可读性
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

	# 暴击首次出现弹跳动画
	if is_crit:
		label.scale = Vector2(1.4, 1.4)
		create_tween().tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 世界坐标转屏幕坐标（用相机投影，自动处理 zoom/旋转/偏移）
	var cam = get_viewport().get_camera_2d()
	if cam:
		label.global_position = cam.unproject_position(pos)
	else:
		label.global_position = pos

	# 缓存条目
	var entry_data = {
		"amount": int(amount),
		"is_crit": is_crit,
		"dmg_type": dmg_type,
		"label": label,
		"timer": now
	}
	_cluster_cache[key] = entry_data

	# 上浮动画
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION)
	var par = tween.parallel()
	par.tween_property(label, "position:y", label.position.y - FLOAT_DISTANCE, FLOAT_DURATION)
	par.tween_property(label, "position:x", label.position.x + randf_range(-15, 15), FLOAT_DURATION)
	tween.tween_callback(func():
		label.queue_free()
		_cluster_cache.erase(key)
	)


func _set_crit_style(label: Label) -> void:
	label.text += "!"
	label.modulate = Color(1, 0.85, 0.2, 1)
	label.add_theme_font_size_override("font_size", 20)

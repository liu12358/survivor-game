# DamageNumberManager - 浮动伤害数字
# 监听 damage_number_requested 信号，创建浮动数字
extends CanvasLayer

const FLOAT_DURATION: float = 0.8
const FLOAT_DISTANCE: float = 40.0
const FADE_START: float = 0.5

# 伤害类型颜色
const DMG_COLORS = {
	0: Color(1, 1, 1, 1),       # 物理=白
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
	var label = Label.new()
	label.text = str(int(amount))
	label.add_theme_font_size_override("font_size", 14 if not is_crit else 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = DMG_COLORS.get(dmg_type, Color.WHITE)
	if is_crit:
		label.text += "!"
		label.modulate = Color(1, 0.85, 0.2, 1)  # 暴击金色
	add_child(label)

	# 世界坐标转屏幕坐标
	var cam = get_viewport().get_camera_2d()
	if cam:
		label.global_position = pos - cam.global_position + get_viewport().get_visible_rect().size / 2
	else:
		label.global_position = pos

	# 上浮动画
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION)
	var par = tween.parallel()
	par.tween_property(label, "position:y", label.position.y - FLOAT_DISTANCE, FLOAT_DURATION)
	par.tween_property(label, "position:x", label.position.x + randf_range(-15, 15), FLOAT_DURATION)
	tween.tween_callback(label.queue_free)

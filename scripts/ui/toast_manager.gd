# ToastManager - 全局提示通知
# 屏幕顶部居中弹出，自动淡出
extends CanvasLayer

var _toasts: Array[Control] = []
const TOAST_DURATION: float = 2.5
const TOAST_FADE: float = 0.4
var _next_y: float = 60.0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("toast_manager")


func show_toast(text: String, color: Color = Color.WHITE, duration: float = TOAST_DURATION) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = _next_y
	label.offset_left = -250
	label.offset_right = 250
	label.custom_minimum_size = Vector2(500, 36)
	label.z_index = 60
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_toasts.append(label)

	# 入场
	var enter := create_tween()
	enter.tween_property(label, "modulate:a", 1.0, TOAST_FADE)

	# 停留
	var wait := create_tween()
	wait.set_parallel(false)
	wait.tween_interval(duration - TOAST_FADE * 2)

	# 退场
	var exit := create_tween()
	exit.tween_property(label, "modulate:a", 0.0, TOAST_FADE)
	exit.tween_callback(func():
		_toasts.erase(label)
		label.queue_free()
		_recalculate_positions()
	)


func _recalculate_positions() -> void:
	_next_y = 60.0
	for t in _toasts:
		if is_instance_valid(t):
			t.offset_top = int(_next_y)
			_next_y += 40.0


# 便捷方法：显示系统提示
func show_system(text: String) -> void:
	show_toast("💡 " + text, Color(0.7, 0.9, 1.0), 3.0)


# 便捷方法：显示战斗提示
func show_combat(text: String) -> void:
	show_toast("⚔️ " + text, Color(1.0, 0.8, 0.4), 2.0)


# 便捷方法：显示收集提示
func show_pickup(text: String) -> void:
	show_toast("✨ " + text, Color(0.5, 1.0, 0.7), 2.0)

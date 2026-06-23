# VirtualJoystick - 触屏虚拟摇杆 + 暂停按钮
# 左半屏按下创建摇杆，输出归一化方向供 Player 读取；右上角暂停按钮。
# 仅触屏事件触发，PC 键盘操作不受影响。
extends CanvasLayer

const MAX_RADIUS: float = 80.0

var _touch_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO

var _base: TextureRect
var _knob: TextureRect
var _pause_btn: Button


func _ready() -> void:
	layer = 8
	add_to_group("joystick")
	_build_ui()


func get_direction() -> Vector2:
	return _direction


func _build_ui() -> void:
	_base = _make_circle(120, Color(0.4, 0.6, 0.9, 0.22))
	_base.visible = false
	add_child(_base)
	_knob = _make_circle(56, Color(0.5, 0.7, 1.0, 0.5))
	_knob.visible = false
	add_child(_knob)

	_pause_btn = Button.new()
	_pause_btn.text = "⏸"
	_pause_btn.add_theme_font_size_override("font_size", 26)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.offset_left = -74
	_pause_btn.offset_top = 12
	_pause_btn.offset_right = -12
	_pause_btn.offset_bottom = 74
	_pause_btn.modulate = Color(1, 1, 1, 0.6)
	_pause_btn.pressed.connect(_on_pause_pressed)
	add_child(_pause_btn)


func _make_circle(size: int, col: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _circle_tex(size, col)
	tr.size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _circle_tex(size: int, col: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for x in range(size):
		for y in range(size):
			if Vector2(x - c, y - c).length() <= c - 1:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var half := get_viewport().get_visible_rect().size.x * 0.5
		if touch.pressed:
			if touch.position.x < half and _touch_index == -1:
				_touch_index = touch.index
				_start_pos = touch.position
				_base.position = touch.position - _base.size * 0.5
				_knob.position = touch.position - _knob.size * 0.5
				_base.visible = true
				_knob.visible = true
		elif touch.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		var delta := drag.position - _start_pos
		_direction = delta / MAX_RADIUS
		if _direction.length() > 1.0:
			_direction = _direction.normalized()
		_knob.position = _start_pos + delta.limit_length(MAX_RADIUS) - _knob.size * 0.5


func _reset() -> void:
	_touch_index = -1
	_direction = Vector2.ZERO
	_base.visible = false
	_knob.visible = false


func _on_pause_pressed() -> void:
	# 仅负责"进入暂停"（退出由暂停菜单按钮/ESC 处理）
	if get_tree().paused or GameState.modal_active or GameState.is_game_over:
		return
	get_tree().paused = true
	GameState.is_paused = true
	EventBus.game_paused.emit()

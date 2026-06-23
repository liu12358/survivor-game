# PauseMenu - 暂停菜单
# ESC暂停时显示，提供继续/重开/退出选项
extends CanvasLayer

var _overlay: ColorRect
var _panel: Panel
var _is_paused: bool = false
var _seed_label: Label

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍可操作菜单（D-2）
	_create_ui()
	visible = false
	EventBus.game_paused.connect(_on_paused)
	EventBus.game_resumed.connect(_on_resumed)


func _create_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(320, 260)
	center.add_child(_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.20, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var title = Label.new()
	title.text = "⏸ 暂停"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_seed_label = Label.new()
	_seed_label.add_theme_font_size_override("font_size", 12)
	_seed_label.modulate = Color(0.6, 0.7, 0.8)
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_seed_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var resume_btn = Button.new()
	resume_btn.text = "▶ 继续游戏"
	resume_btn.custom_minimum_size = Vector2(240, 40)
	resume_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(resume_btn)
	resume_btn.pressed.connect(_on_resume)

	var restart_btn = Button.new()
	restart_btn.text = "🔄 重新开始"
	restart_btn.custom_minimum_size = Vector2(240, 40)
	restart_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart)

	var menu_btn = Button.new()
	menu_btn.text = "🏠 返回主菜单"
	menu_btn.custom_minimum_size = Vector2(240, 40)
	menu_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(menu_btn)
	menu_btn.pressed.connect(_on_to_menu)

	var quit_btn = Button.new()
	quit_btn.text = "🚪 退出游戏"
	quit_btn.custom_minimum_size = Vector2(240, 40)
	quit_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(quit_btn)
	quit_btn.pressed.connect(_on_quit)


func _on_paused() -> void:
	_is_paused = true
	visible = true
	if _seed_label:
		_seed_label.text = "🌱 种子: " + GameState.game_seed


func _on_resumed() -> void:
	_is_paused = false
	visible = false


func _on_resume() -> void:
	get_tree().paused = false
	GameState.is_paused = false
	EventBus.game_resumed.emit()
	visible = false


func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().quit()


func _on_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if GameState.modal_active or GameState.is_game_over:
		return  # 升级/结算模态显示中，不响应暂停切换
	if get_tree().paused:
		_on_resume()
	else:
		_pause_now()


func _pause_now() -> void:
	get_tree().paused = true
	GameState.is_paused = true
	EventBus.game_paused.emit()

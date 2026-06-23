# GameOverPanel - 死亡/通关结算面板
# 玩家死亡或通关时弹出，显示统计数据
extends CanvasLayer

var _overlay: ColorRect
var _panel: Panel
var _title_label: Label
var _stats_container: VBoxContainer
var _restart_button: Button

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍可点击结算按钮（D-2）
	_create_ui()
	visible = false
	EventBus.game_over.connect(_on_game_over)


func _create_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.8)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(450, 380)
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

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 8)
	_stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_stats_container)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	_restart_button = Button.new()
	_restart_button.text = "再战一局"
	_restart_button.custom_minimum_size = Vector2(200, 44)
	_restart_button.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_restart_button)
	_restart_button.pressed.connect(_on_restart)

	var menu_btn = Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(menu_btn)
	menu_btn.pressed.connect(_on_main_menu)


func _on_game_over(reason: String, stats: Dictionary) -> void:
	_show_game_over(reason, stats)


func _show_game_over(reason: String, stats: Dictionary) -> void:
	# 清除旧统计
	for child in _stats_container.get_children():
		child.queue_free()

	var kills = stats.get("kills", GameState.kills)
	var survival = stats.get("survival_time", GameState.survival_time)
	var gold = stats.get("gold", GameState.gold_earned)
	var level = stats.get("level", GameState.player_level)

	match reason:
		"victory":
			_title_label.text = "🌟 通关！"
			_title_label.modulate = Color(0.4, 1.0, 0.6)
		"death":
			if GameState.current_mode == "infinite":
				_title_label.text = "💀 无尽模式结束"
				_title_label.modulate = Color(0.8, 0.4, 0.8)
			else:
				_title_label.text = "💀 你倒下了"
				_title_label.modulate = Color(1.0, 0.4, 0.4)
		_:
			_title_label.text = "游戏结束"
			_title_label.modulate = Color(0.8, 0.8, 0.8)

	_add_stat("存活时间", _format_time(survival))
	_add_stat("击杀数", "%d 只" % kills)
	_add_stat("玩家等级", "Lv.%d" % level)
	_add_stat("获得金币", "%d 💰" % gold)

	# 结算文案
	var comment = Label.new()
	comment.text = _get_comment(survival, reason)
	comment.add_theme_font_size_override("font_size", 15)
	comment.modulate = Color(0.8, 0.8, 0.9)
	comment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_container.add_child(comment)

	visible = true
	Engine.time_scale = 1.0   # 取消死亡慢动作残留（暂停由 paused 负责）
	get_tree().paused = true
	GameState.is_paused = true
	GameState.modal_active = true


func _add_stat(label_text: String, value_text: String) -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	var l = Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(0.7, 0.75, 0.85)
	l.custom_minimum_size = Vector2(100, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)

	var v = Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 18)
	v.modulate = Color(1.0, 1.0, 1.0)
	v.custom_minimum_size = Vector2(100, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(v)

	_stats_container.add_child(row)


func _get_time_from_seconds(sec: float) -> String:
	return _format_time(sec)


func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d分%d秒" % [mins, secs]


func _get_comment(survival: float, reason: String) -> String:
	if reason == "victory":
		return "🌟 星屑守护者！你封印了裂隙！"
	if GameState.current_mode == "infinite":
		if survival < 300:
			return "初入无尽，星屑远未熄灭…"
		elif survival < 900:
			return "无尽征途上的传奇！星光为你闪耀 ⭐"
		elif survival < 1800:
			return "你在无尽中留下了不朽之名！"
		else:
			return "👑 永恒守护者！没人比你站得更久！"
	else:
		if survival < 180:
			return "星屑还没热起来呢…再来一局？"
		elif survival < 600:
			return "不错！星光在你手中闪耀 ⭐"
		elif survival < 900:
			return "传奇！你几乎和暗影领主五五开！"
		else:
			return "🌟 星屑守护者！你封印了裂隙！"


func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	GameState.modal_active = false
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	GameState.modal_active = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_main_menu()

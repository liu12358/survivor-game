# SettingsPanel - 设置菜单
# 音量/震动/粒子/伤害数字 开关 + 全屏
extends Control


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.10, 0.15)
	add_child(bg)

	var title = Label.new()
	title.text = "⚙️ 设置"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 40
	add_child(title)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_top = -40
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# 主音量滑块
	var vol = _add_slider_row(vbox, "🔊 主音量", "master_volume", 0.0, 1.0)
	vol.value = SaveSystem.get_setting("master_volume")
	vol.value_changed.connect(func(v):
		SaveSystem.set_setting("master_volume", v)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v) if v > 0 else -80)
	)

	# 屏幕震动开关
	_add_toggle_row(vbox, "📳 屏幕震动", "screen_shake")

	# 粒子特效开关
	_add_toggle_row(vbox, "✨ 粒子特效", "particles")

	# 伤害数字开关
	_add_toggle_row(vbox, "🔢 伤害数字", "damage_numbers")

	# 全屏开关
	var fs = _add_toggle_row(vbox, "🖥️ 全屏", "fullscreen")
	fs.toggled.connect(func(b):
		SaveSystem.set_setting("fullscreen", b)
		if b:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# 返回按钮
	var back_btn = Button.new()
	back_btn.text = "← 返回主菜单"
	back_btn.custom_minimum_size = Vector2(200, 44)
	back_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(back_btn)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))

	# 初始化音量
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(SaveSystem.get_setting("master_volume")) if SaveSystem.get_setting("master_volume") > 0 else -80)


func _add_slider_row(parent: Control, label_text: String, key: String, min_v: float, max_v: float) -> HSlider:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl = Label.new()
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % int(v * 100))
	slider.value = SaveSystem.get_setting(key)
	val_lbl.text = "%d%%" % int(slider.value * 100)

	return slider


func _add_toggle_row(parent: Control, label_text: String, key: String) -> CheckButton:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)

	var toggle = CheckButton.new()
	toggle.button_pressed = SaveSystem.get_setting(key)
	toggle.toggled.connect(func(b): SaveSystem.set_setting(key, b))
	row.add_child(toggle)

	return toggle

# MainMenu - 主菜单（局前设置可折叠）
extends Control


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.12)
	add_child(bg)

	var title = Label.new()
	title.text = "🌟 星屑割草"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 50
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Starfall Survivor"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.5, 0.6, 0.8)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 100
	add_child(subtitle)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 50
	center.offset_bottom = -28
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	# 主操作：开始按钮
	var level_btn = _make_button("🏰 关卡模式 — 存活15分钟", Color(0.2, 0.5, 0.8))
	level_btn.pressed.connect(func(): _on_start("level"))
	vbox.add_child(level_btn)

	var inf_btn = _make_button("♾️ 无尽模式 — 挑战极限", Color(0.7, 0.3, 0.6))
	inf_btn.pressed.connect(func(): _on_start("infinite"))
	vbox.add_child(inf_btn)

	# 局前设置（折叠）
	var settings_toggle = _make_button("⚙️ 局前设置 ▼", Color(0.3, 0.4, 0.5))
	vbox.add_child(settings_toggle)
	var settings_box = VBoxContainer.new()
	settings_box.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_box.add_theme_constant_override("separation", 5)
	settings_box.visible = false
	vbox.add_child(settings_box)
	settings_toggle.pressed.connect(func():
		settings_box.visible = not settings_box.visible
		settings_toggle.text = "⚙️ 局前设置 ▲" if settings_box.visible else "⚙️ 局前设置 ▼"
	)

	_build_difficulty(settings_box)
	_build_character(settings_box)
	_build_skin(settings_box)
	_build_seed(settings_box)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer1)

	var shop_btn = _make_button("🛒 星尘商店", Color(0.6, 0.4, 0.1))
	shop_btn.pressed.connect(_on_shop)
	vbox.add_child(shop_btn)

	var codex_btn = _make_button("📖 图鉴 · 超武/怪物", Color(0.3, 0.5, 0.5))
	codex_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/codex.tscn"))
	vbox.add_child(codex_btn)

	var settings_btn = _make_button("⚙️ 设置", Color(0.3, 0.3, 0.4))
	settings_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/settings.tscn"))
	vbox.add_child(settings_btn)

	var quit_btn = _make_button("🚪 退出", Color(0.3, 0.1, 0.1))
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

	var stats_label = Label.new()
	var s = SaveSystem.data
	stats_label.text = "累计金币: %d  |  最高存活: %d秒  |  总局数: %d" % [s["total_gold"], int(s["highest_survival"]), s["total_games"]]
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.modulate = Color(0.5, 0.6, 0.7)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stats_label.offset_bottom = -36
	add_child(stats_label)


func _build_difficulty(box: VBoxContainer) -> void:
	var diff_label = Label.new()
	diff_label.text = "难度: " + _get_diff_name()
	diff_label.add_theme_font_size_override("font_size", 14)
	diff_label.modulate = Color(0.6, 0.7, 0.8)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(diff_label)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for d in [{"id": "easy", "name": "🌱简单"}, {"id": "normal", "name": "⚔️普通"}, {"id": "hard", "name": "💀困难"}, {"id": "nightmare", "name": "🔥噩梦"}, {"id": "starfall", "name": "⭐星陨"}]:
		var btn = Button.new()
		btn.text = d["name"]
		btn.custom_minimum_size = Vector2(70, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(id=d["id"]):
			GameState.current_difficulty = id
			diff_label.text = "难度: " + _get_diff_name()
		)
		row.add_child(btn)


func _build_character(box: VBoxContainer) -> void:
	var char_label = Label.new()
	char_label.text = "角色: " + _get_char_name()
	char_label.add_theme_font_size_override("font_size", 14)
	char_label.modulate = Color(0.6, 0.7, 0.8)
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(char_label)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var unlocked_chars = SaveSystem.data.get("unlocked_characters", ["mage"])
	for c in [{"id": "mage", "name": "🧙法师"}, {"id": "argo", "name": "⚔️剑圣"}, {"id": "selene", "name": "🏹弓手"}]:
		var cbtn = Button.new()
		var is_unlocked = c["id"] in unlocked_chars
		cbtn.text = c["name"] if is_unlocked else c["name"] + "🔒"
		cbtn.disabled = not is_unlocked
		cbtn.custom_minimum_size = Vector2(82, 28)
		cbtn.add_theme_font_size_override("font_size", 12)
		if is_unlocked:
			cbtn.pressed.connect(func(id=c["id"]):
				GameState.current_character = id
				char_label.text = "角色: " + _get_char_name()
			)
		row.add_child(cbtn)


func _build_skin(box: VBoxContainer) -> void:
	var skin_label = Label.new()
	skin_label.text = "皮肤: " + _get_skin_name()
	skin_label.add_theme_font_size_override("font_size", 14)
	skin_label.modulate = Color(0.6, 0.7, 0.8)
	skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(skin_label)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	var btns := {}
	for sid in GameState.SKINS:
		var sbtn = Button.new()
		sbtn.custom_minimum_size = Vector2(74, 26)
		sbtn.add_theme_font_size_override("font_size", 11)
		sbtn.modulate = GameState.SKINS[sid]["color"]
		row.add_child(sbtn)
		btns[sid] = sbtn
		sbtn.pressed.connect(func(id=sid):
			if id in SaveSystem.data["unlocked_skins"]:
				SaveSystem.select_skin(id)
			elif SaveSystem.buy_skin(id):
				pass
			skin_label.text = "皮肤: " + _get_skin_name()
			_refresh_skin_btns(btns)
		)
	_refresh_skin_btns(btns)


func _refresh_skin_btns(btns: Dictionary) -> void:
	for sid in btns:
		var sk = GameState.SKINS[sid]
		var is_unlocked = sid in SaveSystem.data.get("unlocked_skins", ["default"])
		if not is_unlocked:
			btns[sid].text = "%s🔒%d" % [sk["name"], int(sk["price"])]
		elif sid == GameState.selected_skin:
			btns[sid].text = "✓" + str(sk["name"])
		else:
			btns[sid].text = str(sk["name"])


func _build_seed(box: VBoxContainer) -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var seed_input = LineEdit.new()
	seed_input.placeholder_text = "🌱 种子(留空随机)"
	seed_input.custom_minimum_size = Vector2(200, 28)
	seed_input.text = GameState.game_seed
	seed_input.text_changed.connect(func(t): GameState.game_seed = t)
	row.add_child(seed_input)


func _make_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 46)
	btn.add_theme_font_size_override("font_size", 19)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _on_start(mode: String = "level") -> void:
	GameState.current_mode = mode
	SaveSystem.apply_meta_to_gamestate()
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")


func _on_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/meta_shop.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _get_diff_name() -> String:
	match GameState.current_difficulty:
		"easy": return "🌱 简单"
		"hard": return "💀 困难"
		"nightmare": return "🔥 噩梦"
		"starfall": return "⭐ 星陨"
		_: return "⚔️ 普通"


func _get_char_name() -> String:
	match GameState.current_character:
		"argo": return "⚔️ 剑圣"
		"selene": return "🏹 弓手"
		_: return "🧙 法师"


func _get_skin_name() -> String:
	return GameState.SKINS.get(GameState.selected_skin, {}).get("name", "星蓝")

# MainMenu - 主菜单
extends Control

var gt: Tween = null  # 标题光效循环 tween


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	# 深色渐变背景
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.1)
	add_child(bg)

	# 顶部光晕装饰
	var glow_top = ColorRect.new()
	glow_top.set_anchors_preset(PRESET_TOP_WIDE)
	glow_top.offset_bottom = 200
	glow_top.color = Color(0.1, 0.2, 0.4, 0.15)
	add_child(glow_top)

	# 底部光晕装饰
	var glow_bottom = ColorRect.new()
	glow_bottom.set_anchors_preset(PRESET_BOTTOM_WIDE)
	glow_bottom.offset_top = -150
	glow_bottom.color = Color(0.15, 0.1, 0.25, 0.1)
	add_child(glow_bottom)

	# 标题
	var title = Label.new()
	title.text = "星屑割草"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 40
	title.modulate = Color(0.9, 0.95, 1.0)
	add_child(title)

	# 标题发光效果
	var title_glow = Label.new()
	title_glow.text = "星屑割草"
	title_glow.add_theme_font_size_override("font_size", 48)
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_glow.offset_top = 40
	title_glow.modulate = Color(0.3, 0.5, 0.9, 0.3)
	title_glow.z_index = -1
	add_child(title_glow)
	gt = create_tween().set_loops()
	gt.tween_property(title_glow, "modulate:a", 0.15, 1.5)
	gt.tween_property(title_glow, "modulate:a", 0.35, 1.5)

	var subtitle = Label.new()
	subtitle.text = "2D 俯视角割草生存 Roguelike"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.45, 0.55, 0.75)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 95
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

	var level_btn = _make_button("🏰 关卡模式 — 存活 15 分钟", Color(0.2, 0.5, 0.8))
	level_btn.pressed.connect(func(): _start_game("level"))
	vbox.add_child(level_btn)

	var inf_btn = _make_button("♾️ 无尽模式 — 无限挑战", Color(0.7, 0.3, 0.6))
	inf_btn.pressed.connect(func(): _start_game("infinite"))
	vbox.add_child(inf_btn)

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
	_build_map(settings_box)
	_build_character(settings_box)
	_build_skin(settings_box)
	_build_seed(settings_box)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer1)

	var shop_btn = _make_button("🛒 星尘商店", Color(0.6, 0.4, 0.1))
	shop_btn.pressed.connect(_on_shop)
	vbox.add_child(shop_btn)

	var codex_btn = _make_button("📖 图鉴 · 武器/怪物", Color(0.3, 0.5, 0.5))
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
	stats_label.text = "总金币: %d  |  最长存活: %d秒  |  总局数: %d" % [s["total_gold"], int(s["highest_survival"]), s["total_games"]]
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
	var diff_list = [
		{"id": "easy", "text": "🌱 简单"},
		{"id": "normal", "text": "⚔️ 普通"},
		{"id": "hard", "text": "💀 困难"},
		{"id": "nightmare", "text": "🔥 噩梦"},
		{"id": "starfall", "text": "⭐ 星落"},
	]
	for d in diff_list:
		var btn = Button.new()
		btn.text = d["text"]
		btn.custom_minimum_size = Vector2(70, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(id=d["id"]):
			GameState.current_difficulty = id
			diff_label.text = "难度: " + _get_diff_name()
		)
		row.add_child(btn)


func _build_map(box: VBoxContainer) -> void:
	var map_label = Label.new()
	map_label.text = "地图: " + _get_map_name()
	map_label.add_theme_font_size_override("font_size", 14)
	map_label.modulate = Color(0.6, 0.7, 0.8)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(map_label)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for map_id in GameState.MAPS:
		var cfg = GameState.MAPS[map_id]
		var btn = Button.new()
		btn.text = cfg["name"]
		btn.custom_minimum_size = Vector2(80, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(mid=map_id):
			GameState.current_map = mid
			map_label.text = "地图: " + _get_map_name()
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx_ui_click()
		)
		if GameState.current_map == map_id:
			btn.modulate = Color(1.2, 1.2, 1.2)
		row.add_child(btn)


func _build_character(box: VBoxContainer) -> void:
	var char_label = Label.new()
	char_label.text = "角色: " + _get_char_name()
	char_label.add_theme_font_size_override("font_size", 14)
	char_label.modulate = Color(0.6, 0.7, 0.8)
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(char_label)

	# 被动能力描述
	var passive_desc = Label.new()
	passive_desc.text = _get_char_passive()
	passive_desc.add_theme_font_size_override("font_size", 11)
	passive_desc.modulate = Color(0.4, 0.7, 0.9)
	passive_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(passive_desc)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var unlocked_chars = SaveSystem.data.get("unlocked_characters", ["mage"])
	var char_list = [
		{"id": "mage", "text": "🧙 法师", "hint": "初始可用", "passive": "⭐ 星尘共鸣：每5级武器范围+5%"},
		{"id": "argo", "text": "⚔️ 剑圣", "hint": "击杀BOSS", "passive": "⚔️ 剑气纵横：近战击杀10%触发360°剑气"},
		{"id": "selene", "text": "🏹 弓手", "hint": "累计杀1万只", "passive": "🎯 鹰眼：射程+25%，暴击+10%"},
		{"id": "little_fried_egg", "text": "🍳 小煎蛋", "hint": "累计5局", "passive": "🌋 炽热之心：灼烧持续时间翻倍"},
	]
	for c in char_list:
		var cbtn = Button.new()
		var is_unlocked = c["id"] in unlocked_chars
		cbtn.text = c["text"] if is_unlocked else c["text"] + "🔒"
		cbtn.disabled = not is_unlocked
		cbtn.custom_minimum_size = Vector2(82, 28)
		cbtn.add_theme_font_size_override("font_size", 12)
		cbtn.tooltip_text = c["hint"] if not is_unlocked else ""
		if is_unlocked:
			var cid = c["id"]
			var cpassive = c["passive"]
			cbtn.pressed.connect(func():
				GameState.current_character = cid
				char_label.text = "角色: " + _get_char_name()
				passive_desc.text = cpassive
				# 角色选择按钮点击音效
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx_ui_click()
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
		# 用 StyleBoxFlat 设置按钮背景色为皮肤颜色（替代 modulate 整体染色，保证文字可读）
		var skin_style = StyleBoxFlat.new()
		skin_style.bg_color = GameState.SKINS[sid]["color"]
		skin_style.corner_radius_top_left = 6
		skin_style.corner_radius_top_right = 6
		skin_style.corner_radius_bottom_left = 6
		skin_style.corner_radius_bottom_right = 6
		sbtn.add_theme_stylebox_override("normal", skin_style)
		var skin_hover = skin_style.duplicate()
		skin_hover.bg_color = GameState.SKINS[sid]["color"].lightened(0.2)
		sbtn.add_theme_stylebox_override("hover", skin_hover)
		# 文字保持白色
		sbtn.add_theme_color_override("font_color", Color.WHITE)
		sbtn.add_theme_color_override("font_hover_color", Color.WHITE)
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
	seed_input.placeholder_text = "🌱 种子（留空随机）"
	seed_input.custom_minimum_size = Vector2(200, 28)
	seed_input.text = GameState.game_seed
	seed_input.text_changed.connect(func(t): GameState.game_seed = t)
	row.add_child(seed_input)


func _make_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", 18)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.95)
	hover.border_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = style.duplicate()
	pressed.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed)

	# 按钮点击音效
	btn.pressed.connect(func():
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx_ui_click()
	)

	return btn


func _start_game(mode: String = "level") -> void:
	# 停止标题光效循环 tween，避免切换场景后仍在后台运行
	if gt:
		gt.kill()
	gt = null
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
		"starfall": return "⭐ 星落"
		_: return "⚔️ 普通"


func _get_map_name() -> String:
	var cfg = GameState.MAPS.get(GameState.current_map, {})
	return cfg.get("name", GameState.current_map)


func _get_char_name() -> String:
	match GameState.current_character:
		"argo": return "⚔️ 剑圣"
		"selene": return "🏹 弓手"
		"little_fried_egg": return "🍳 小煎蛋"
		_: return "🧙 法师"


func _get_char_passive() -> String:
	match GameState.current_character:
		"argo": return "⚔️ 剑气纵横：近战击杀10%触发360°剑气"
		"selene": return "🎯 鹰眼：射程+25%，暴击+10%"
		"little_fried_egg": return "🌋 炽热之心：灼烧持续时间翻倍"
		_: return "⭐ 星尘共鸣：每5级武器范围+5%"


func _get_skin_name() -> String:
	return GameState.SKINS.get(GameState.selected_skin, {}).get("name", "星蓝")

# MetaShop - 元商店
# 花费金币购买永久属性加成
extends Control


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.10, 0.15)
	add_child(bg)

	var title = Label.new()
	title.text = "🛒 星尘商店"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 40
	add_child(title)

	var gold_label = Label.new()
	gold_label.text = "💰 持有金币: %d" % SaveSystem.data["total_gold"]
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	gold_label.offset_top = 90
	gold_label.name = "GoldLabel"
	add_child(gold_label)

	# 升级列表
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_top = 0.15
	scroll.anchor_bottom = 0.85
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var upgrades = [
		{"id": "hp", "name": "❤️ 生命强化", "desc": "最大HP +5"},
		{"id": "damage", "name": "⚔️ 伤害强化", "desc": "伤害 +3%"},
		{"id": "speed", "name": "👟 速度强化", "desc": "移速 +2%"},
		{"id": "magnet", "name": "🧲 磁铁强化", "desc": "拾取范围 +5%"},
		{"id": "exp", "name": "💎 经验强化", "desc": "经验获取 +3%"},
		{"id": "armor", "name": "🛡️ 护甲强化", "desc": "减伤 +1"},
	]

	for u in upgrades:
		var row = _make_upgrade_row(u["id"], u["name"], u["desc"])
		vbox.add_child(row)

	# 返回按钮 — 固定在底部中央
	var back_btn = Button.new()
	back_btn.text = "← 返回主菜单"
	back_btn.custom_minimum_size = Vector2(200, 44)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.anchor_left = 0.5
	back_btn.anchor_top = 1.0
	back_btn.anchor_right = 0.5
	back_btn.anchor_bottom = 1.0
	back_btn.offset_left = -100
	back_btn.offset_right = 100
	back_btn.offset_bottom = -16
	back_btn.offset_top = -60
	add_child(back_btn)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))


func _make_upgrade_row(upgrade_id: String, name: String, desc: String) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl = Label.new()
	var lv = SaveSystem.get_upgrade_level(upgrade_id)
	var cost = SaveSystem.get_upgrade_cost(upgrade_id)
	lbl.text = "%s | %s Lv.%d" % [name, desc, lv]
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d 💰" % cost
	cost_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(cost_lbl)

	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(80, 30)
	buy_btn.pressed.connect(func():
		if SaveSystem.buy_upgrade(upgrade_id):
			var new_lv = SaveSystem.get_upgrade_level(upgrade_id)
			var new_cost = SaveSystem.get_upgrade_cost(upgrade_id)
			lbl.text = "%s | %s Lv.%d" % [name, desc, new_lv]
			cost_lbl.text = "%d 💰" % new_cost
			var gl = get_node_or_null("GoldLabel")
			if gl: gl.text = "💰 持有金币: %d" % SaveSystem.data["total_gold"]
	)
	row.add_child(buy_btn)

	return row

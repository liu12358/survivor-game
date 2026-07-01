# CheatMenu - 金手指（调试作弊菜单），按 F3 呼出/隐藏
extends CanvasLayer

var _panel: PanelContainer
var _god_label: Label
var _speed_label: Label
var _f3_pressed: bool = false
var _weapon_option: OptionButton

const WEAPON_LIST = [
	["magic_bolt", "🔮 魔法弹"],
	["fire_ring", "🔥 烈焰环"],
	["lightning_chain", "⚡ 闪电链"],
	["ice_storm", "❄️ 冰晶风暴"],
	["holy_spear", "🏹 圣光矛"],
	["poison_cloud", "☠️ 毒雾"],
	["sword_orbit", "⚔️ 环绕剑"],
	["piercing_arrow", "🎯 穿透箭"],
	["lava_zone", "🌋 岩浆"],
]

const BG_COLOR := Color(0.1, 0.12, 0.18, 0.92)
const ACCENT_COLOR := Color(0.3, 0.6, 1.0)
const BTN_NORMAL := Color(0.15, 0.18, 0.25)
const BTN_HOVER := Color(0.22, 0.28, 0.38)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("cheat")
	_build()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F3 and event.pressed and not event.echo:
		_toggle_panel()


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -220
	_panel.offset_top = 8
	_panel.offset_right = -8
	_panel.offset_bottom = 10
	_panel.custom_minimum_size = Vector2(212, 0)
	_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = Color(0.25, 0.4, 0.65, 0.6)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(0, 420)
	_panel.add_child(scroll)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	# ─── 标题 ───
	var title := Label.new()
	title.text = "🎮 金手指"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = ACCENT_COLOR
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "F3 键切换"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.5, 0.55, 0.65)
	vb.add_child(subtitle)

	vb.add_child(_make_separator())

	# ─── 状态行 ───
	_god_label = _make_status_label("无敌：关")
	vb.add_child(_god_label)
	_update_god_label()

	_speed_label = _make_status_label("速度：1.0x")
	vb.add_child(_speed_label)
	_update_speed_label()

	vb.add_child(_make_separator())

	# ─── 功能按钮 ───
	_add_btn(vb, "♾️ 无敌 开/关", _cheat_god, Color(0.6, 0.3, 0.3))
	_add_btn(vb, "⏩ 双倍速度 开/关", _cheat_speed, Color(0.3, 0.5, 0.2))
	_add_btn(vb, "💰 +1000 金币", _cheat_gold, Color(0.6, 0.5, 0.1))
	_add_btn(vb, "⭐ +5 级经验", _cheat_level, Color(0.4, 0.3, 0.6))
	_add_btn(vb, "❤️ 满血", _cheat_heal, Color(0.6, 0.2, 0.2))
	_add_btn(vb, "💥 清屏杀怪", _cheat_kill, Color(0.7, 0.3, 0.1))
	_add_btn(vb, "🔓 解锁全角色", _cheat_unlock, Color(0.3, 0.5, 0.6))

	# ─── 武器下拉菜单 ───
	vb.add_child(_make_separator())

	var w_title := Label.new()
	w_title.text = "🔫 刷武器"
	w_title.add_theme_font_size_override("font_size", 13)
	w_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_title.modulate = Color(0.8, 0.75, 0.5)
	vb.add_child(w_title)

	_weapon_option = OptionButton.new()
	_weapon_option.custom_minimum_size = Vector2(0, 32)
	_weapon_option.add_theme_font_size_override("font_size", 13)

	var opt_style = StyleBoxFlat.new()
	opt_style.bg_color = BTN_NORMAL
	opt_style.corner_radius_top_left = 5
	opt_style.corner_radius_top_right = 5
	opt_style.corner_radius_bottom_left = 5
	opt_style.corner_radius_bottom_right = 5
	opt_style.content_margin_left = 8
	opt_style.content_margin_right = 8
	opt_style.content_margin_top = 4
	opt_style.content_margin_bottom = 4
	_weapon_option.add_theme_stylebox_override("normal", opt_style)

	var opt_hover = opt_style.duplicate()
	opt_hover.bg_color = BTN_HOVER
	_weapon_option.add_theme_stylebox_override("hover", opt_hover)

	for w in WEAPON_LIST:
		_weapon_option.add_item(w[1])
	_weapon_option.selected = 0
	vb.add_child(_weapon_option)

	# 下方放一个确认按钮
	_add_btn(vb, "✅ 刷出选中武器", _cheat_weapon, Color(0.3, 0.5, 0.6))

	# ─── 浮动开关按钮 ───
	var toggle_btn = Button.new()
	toggle_btn.text = "🐞"
	toggle_btn.add_theme_font_size_override("font_size", 20)
	toggle_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_btn.offset_left = -52
	toggle_btn.offset_top = -52
	toggle_btn.offset_right = -10
	toggle_btn.offset_bottom = -10

	var toggle_style = StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.15, 0.18, 0.25, 0.7)
	toggle_style.corner_radius_top_left = 20
	toggle_style.corner_radius_top_right = 20
	toggle_style.corner_radius_bottom_left = 20
	toggle_style.corner_radius_bottom_right = 20
	toggle_btn.add_theme_stylebox_override("normal", toggle_style)

	var toggle_hover = toggle_style.duplicate()
	toggle_hover.bg_color = Color(0.25, 0.3, 0.4, 0.85)
	toggle_btn.add_theme_stylebox_override("hover", toggle_hover)

	toggle_btn.pressed.connect(_toggle_panel)
	add_child(toggle_btn)


func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 0)
	return sep


func _make_status_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.7, 0.7, 0.7)
	return lbl


func _add_btn(parent: Node, text: String, cb: Callable, tint: Color = Color.WHITE) -> void:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 32)

	var style = StyleBoxFlat.new()
	style.bg_color = BTN_NORMAL
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = BTN_HOVER
	hover.border_color = tint * 0.5
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	b.add_theme_stylebox_override("hover", hover)

	b.pressed.connect(cb)
	parent.add_child(b)


func _update_god_label() -> void:
	if GameState.cheat_godmode:
		_god_label.text = "无敌：开 ✅"
		_god_label.modulate = Color(0.4, 1.0, 0.5)
	else:
		_god_label.text = "无敌：关"
		_god_label.modulate = Color(0.6, 0.6, 0.6)


func _update_speed_label() -> void:
	var spd = GameState.game_speed_mult
	_speed_label.text = "速度：%.1fx" % spd
	if spd > 1.0:
		_speed_label.modulate = Color(1.0, 0.8, 0.3)
	else:
		_speed_label.modulate = Color(0.6, 0.6, 0.6)


func _cheat_god() -> void:
	GameState.cheat_godmode = not GameState.cheat_godmode
	_update_god_label()


func _cheat_speed() -> void:
	if GameState.game_speed_mult >= 2.0:
		GameState.game_speed_mult = 1.0
	else:
		GameState.game_speed_mult = 2.0
	Engine.time_scale = GameState.game_speed_mult
	_update_speed_label()


func _cheat_gold() -> void:
	EventBus.gold_collected.emit(1000)


func _cheat_level() -> void:
	EventBus.exp_collected.emit(int(GameState.exp_to_next_level * 5))


func _cheat_heal() -> void:
	GameState.current_hp = GameState.max_hp
	EventBus.player_healed.emit(0.0, GameState.current_hp)


func _cheat_kill() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999.0)


func _cheat_unlock() -> void:
	SaveSystem.unlock_character("argo")
	SaveSystem.unlock_character("selene")


func _cheat_weapon() -> void:
	var idx = _weapon_option.selected
	if idx < 0 or idx >= WEAPON_LIST.size():
		return
	var wid: String = WEAPON_LIST[idx][0]

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	if GameState.active_weapons.has(wid):
		GameState.active_weapons[wid] += 1
		for child in player.get_children():
			var child_id = child.get("weapon_id") if child.has_method("get") else ""
			if child_id == wid:
				if child.has_method("level_up"):
					child.level_up()
				elif child.has_method("upgrade"):
					child.upgrade()
				break
	else:
		var path := "res://scenes/weapons/%s.tscn" % wid
		if not ResourceLoader.exists(path):
			return
		var weapon: Node = load(path).instantiate()
		player.add_child(weapon)
		GameState.active_weapons[wid] = 1

	# 刷新 HUD 装备栏
	EventBus.upgrade_selected.emit(wid)

# CheatMenu - 金手指（调试作弊菜单），按 F3 呼出/隐藏
extends CanvasLayer

var _panel: Panel
var _god_label: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("cheat")
	_build()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_panel.visible = not _panel.visible


func _build() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -190
	_panel.offset_top = 96
	_panel.offset_right = -10
	_panel.offset_bottom = 380
	_panel.visible = false
	add_child(_panel)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 5)
	vb.offset_left = 8
	vb.offset_top = 8
	vb.offset_right = -8
	vb.offset_bottom = -8
	_panel.add_child(vb)

	var t = Label.new()
	t.text = "🐞 金手指 (F3 开关)"
	t.add_theme_font_size_override("font_size", 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)

	_god_label = Label.new()
	_god_label.add_theme_font_size_override("font_size", 12)
	_god_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_god_label)
	_update_god_label()

	_add_btn(vb, "♾️ 无敌 开/关", _cheat_god)
	_add_btn(vb, "💰 +1000 金币", _cheat_gold)
	_add_btn(vb, "⭐ +5 级经验", _cheat_level)
	_add_btn(vb, "❤️ 满血", _cheat_heal)
	_add_btn(vb, "💥 清屏杀怪", _cheat_kill)
	_add_btn(vb, "🔓 解锁全角色", _cheat_unlock)

	# 手机用：屏幕右下角开关按钮（替代 F3）
	var toggle_btn = Button.new()
	toggle_btn.text = "🐞"
	toggle_btn.add_theme_font_size_override("font_size", 18)
	toggle_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_btn.offset_left = -54
	toggle_btn.offset_top = -54
	toggle_btn.offset_right = -12
	toggle_btn.offset_bottom = -12
	toggle_btn.modulate = Color(1, 1, 1, 0.5)
	toggle_btn.pressed.connect(func(): _panel.visible = not _panel.visible)
	add_child(toggle_btn)


func _add_btn(parent: Node, text: String, cb: Callable) -> void:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(cb)
	parent.add_child(b)


func _update_god_label() -> void:
	_god_label.text = "无敌：%s" % ("开 ✅" if GameState.cheat_godmode else "关")
	_god_label.modulate = Color(0.4, 1.0, 0.4) if GameState.cheat_godmode else Color(0.7, 0.7, 0.7)


func _cheat_god() -> void:
	GameState.cheat_godmode = not GameState.cheat_godmode
	_update_god_label()


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

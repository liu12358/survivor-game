# PauseMenu - 暂停菜单
# ESC暂停时显示，提供继续/重开/退出选项
extends CanvasLayer

var _overlay: ColorRect
var _panel: Panel
var _is_paused: bool = false
var _seed_label: Label
var _weapon_label: Label
var _passive_label: Label
var _pause_tween: Tween = null

const _WEAPON_NAMES := {
	"magic_bolt": "🔮魔法弹", "fire_ring": "🔥烈焰环", "lightning_chain": "⚡闪电链",
	"ice_storm": "❄️冰晶风暴", "holy_spear": "🏹圣光矛", "poison_cloud": "☠️毒雾",
	"sword_orbit": "⚔️环绕剑", "piercing_arrow": "🎯穿透箭", "lava_zone": "🌋岩浆"
}

const _PASSIVE_NAMES := {
	"max_hp": "❤️生命", "speed": "👟疾步", "magnet": "🧲磁铁",
	"armor": "🛡️铁壁", "exp_bonus": "💎经验", "crit": "🎯锐眼",
	"lifesteal": "🩸吸血", "luck": "🍀幸运", "shield_max": "🔰护盾"
}

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
	_panel.custom_minimum_size = Vector2(320, 420)
	center.add_child(_panel)

	_panel.add_theme_stylebox_override("panel", GameState.get_shared_panel_style())

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

	# ─── Build 概览 ───
	var build_sep = HSeparator.new()
	vbox.add_child(build_sep)

	var build_title = Label.new()
	build_title.text = "📋 当前 Build"
	build_title.add_theme_font_size_override("font_size", 14)
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_title.modulate = Color(0.6, 0.8, 1.0)
	vbox.add_child(build_title)

	var build_container = VBoxContainer.new()
	build_container.add_theme_constant_override("separation", 4)
	vbox.add_child(build_container)

	# 武器列表
	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", 12)
	_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_weapon_label)

	# 被动列表
	_passive_label = Label.new()
	_passive_label.add_theme_font_size_override("font_size", 12)
	_passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_passive_label)

	var build_sep2 = HSeparator.new()
	vbox.add_child(build_sep2)

	# 首次填充 Build 概览（后续在 _on_paused 中刷新）
	_update_build_overview()

	# 按钮样式
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.25, 0.35, 0.9)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.4, 0.5, 0.7, 0.5)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.35, 0.5, 0.95)
	btn_hover.border_color = Color(0.5, 0.7, 1.0, 0.7)

	var resume_btn = Button.new()
	resume_btn.text = "▶ 继续游戏"
	resume_btn.custom_minimum_size = Vector2(240, 42)
	resume_btn.add_theme_font_size_override("font_size", 16)
	resume_btn.add_theme_stylebox_override("normal", btn_style)
	resume_btn.add_theme_stylebox_override("hover", btn_hover)
	vbox.add_child(resume_btn)
	resume_btn.pressed.connect(_on_resume)

	var restart_btn = Button.new()
	restart_btn.text = "🔄 重新开始"
	restart_btn.custom_minimum_size = Vector2(240, 42)
	restart_btn.add_theme_font_size_override("font_size", 16)
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.add_theme_stylebox_override("hover", btn_hover)
	vbox.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart)

	var menu_btn = Button.new()
	menu_btn.text = "🏠 返回主菜单"
	menu_btn.custom_minimum_size = Vector2(240, 42)
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.add_theme_stylebox_override("normal", btn_style)
	menu_btn.add_theme_stylebox_override("hover", btn_hover)
	vbox.add_child(menu_btn)
	menu_btn.pressed.connect(_on_to_menu)

	var quit_btn = Button.new()
	quit_btn.text = "🚪 退出游戏"
	quit_btn.custom_minimum_size = Vector2(240, 42)
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.add_theme_stylebox_override("normal", btn_style)
	quit_btn.add_theme_stylebox_override("hover", btn_hover)
	vbox.add_child(quit_btn)
	quit_btn.pressed.connect(_on_quit)


func _on_paused() -> void:
	_is_paused = true
	if _seed_label:
		_seed_label.text = "🌱 种子: " + GameState.game_seed
	_update_build_overview()
	# 出现动画：淡入 + 缩放
	_panel.pivot_offset = _panel.size / 2
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	visible = true
	if _pause_tween:
		_pause_tween.kill()
	_pause_tween = create_tween()
	_pause_tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_pause_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.15)


func _update_build_overview() -> void:
	# 重新读取 GameState 并刷新武器/被动文本
	if not _weapon_label or not _passive_label:
		return

	# 武器
	var weapons_text := "武器: "
	var first := true
	for wid in GameState.active_weapons:
		if not first:
			weapons_text += " "
		weapons_text += _WEAPON_NAMES.get(wid, wid) + "Lv" + str(int(GameState.active_weapons[wid]))
		if GameState.super_weapons.has(wid):
			weapons_text += "★"
		first = false
	if GameState.active_weapons.is_empty():
		weapons_text += "无"
	_weapon_label.text = weapons_text

	# 被动
	var passives_text := "被动: "
	first = true
	for pid in GameState.active_passives:
		if not first:
			passives_text += " "
		passives_text += _PASSIVE_NAMES.get(pid, pid) + "Lv" + str(int(GameState.active_passives[pid]))
		first = false
	if GameState.active_passives.is_empty():
		passives_text += "无"
	_passive_label.text = passives_text


func _on_resumed() -> void:
	_is_paused = false
	# 消失动画：淡出 + 缩放，完成后隐藏
	if _pause_tween:
		_pause_tween.kill()
	_pause_tween = create_tween()
	_pause_tween.tween_property(_panel, "modulate:a", 0.0, 0.1)
	_pause_tween.parallel().tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.1)
	_pause_tween.tween_callback(func(): visible = false)


func _on_resume() -> void:
	get_tree().paused = false
	GameState.is_paused = false
	EventBus.game_resumed.emit()


func _on_restart() -> void:
	_settle_if_in_game()
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	get_tree().reload_current_scene()


func _on_quit() -> void:
	_settle_if_in_game()
	get_tree().quit()


func _on_to_menu() -> void:
	_settle_if_in_game()
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _settle_if_in_game() -> void:
	# 游戏进行中提前退出时结算本局，避免 total_games 不增长（小煎蛋解锁依赖）
	if GameState.is_game_over:
		return
	var main = get_tree().current_scene
	if main and main.has_method("request_exit_game"):
		main.request_exit_game()

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

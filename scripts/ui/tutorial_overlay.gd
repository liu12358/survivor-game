# TutorialOverlay - 新手引导遮罩层
# 半透明遮罩 + 箭头/高亮 + 文字说明，首次游戏时逐步弹出
extends CanvasLayer

var _panel: PanelContainer
var _title: Label
var _desc: Label
var _step_label: Label
var _current_step: int = 0
var _tutorial_active: bool = false

const LAYER: int = 55
const TUTORIAL_STEPS := {
	"first_move": {
		"title": "移动",
		"desc": "使用 WASD 或方向键移动角色\n收集蓝色经验宝石升级！",
		"highlight_rect": null,
	},
	"first_level_up": {
		"title": "升级！",
		"desc": "升级时从 3 个选项中选择一个\n武器和被动都可以升级",
		"highlight_rect": null,
	},
	"first_enemy": {
		"title": "遭遇敌人",
		"desc": "红色敌人会自动追击你\n你的武器会自动攻击范围内敌人",
		"highlight_rect": null,
	},
	"first_gold": {
		"title": "金币与商店",
		"desc": "击杀敌人掉落金币\n在主菜单可以用金币购买皮肤和 Meta 强化",
		"highlight_rect": null,
	},
	"first_boss": {
		"title": "BOSS 来袭",
		"desc": "10 分钟时会出现 BOSS\n击杀 BOSS 可解锁新角色！",
		"highlight_rect": null,
	},
}

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	# 初始化全局 Toast（复用本层，无需额外节点）
	if not get_tree().get_first_node_in_group("toast_manager"):
		var tm := Node.new()
		tm.name = "ToastManager"
		tm.set_script(load("res://scripts/ui/toast_manager.gd"))
		add_child(tm)
	add_to_group("tutorial")


func _build() -> void:
	# 全屏背景按钮（捕获面板外点击，用于"点击外部 advancing"）
	var bg_btn = Button.new()
	bg_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_btn.flat = true
	bg_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_btn.pressed.connect(_advance)
	add_child(bg_btn)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_top = -120
	_panel.offset_right = 280
	_panel.offset_bottom = 120
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.18, 0.95)
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 12)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.modulate = Color(0.5, 0.6, 0.8)
	vb.add_child(_step_label)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate = Color(1.0, 0.9, 0.6)
	vb.add_child(_title)

	_desc = Label.new()
	_desc.add_theme_font_size_override("font_size", 15)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(0, 60)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_desc)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	vb.add_child(btn_row)

	var skip_btn = Button.new()
	skip_btn.text = "跳过引导"
	skip_btn.custom_minimum_size = Vector2(100, 36)
	skip_btn.add_theme_font_size_override("font_size", 13)
	skip_btn.pressed.connect(_skip_all)
	btn_row.add_child(skip_btn)

	var next_btn = Button.new()
	next_btn.text = "下一步 →"
	next_btn.custom_minimum_size = Vector2(120, 36)
	next_btn.add_theme_font_size_override("font_size", 14)
	next_btn.pressed.connect(_advance)
	btn_row.add_child(next_btn)


func start_tutorial() -> void:
	_current_step = 0
	_tutorial_active = true
	GameState.tutorial_active = true
	get_tree().paused = true
	_show_current_step()
	show()


func _show_current_step() -> void:
	var step_keys = TUTORIAL_STEPS.keys()
	if _current_step >= step_keys.size():
		_complete_tutorial()
		return
	var key = step_keys[_current_step]
	var step = TUTORIAL_STEPS[key]
	_title.text = step["title"]
	_desc.text = step["desc"]
	_step_label.text = "%d / %d" % [_current_step + 1, step_keys.size()]
	_panel.visible = true
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _advance() -> void:
	var step_keys = TUTORIAL_STEPS.keys()
	if _current_step < step_keys.size():
		var key = step_keys[_current_step]
		GameState.tutorial_completed[key] = true
	_current_step += 1
	if _current_step >= step_keys.size():
		_complete_tutorial()
	else:
		var t := create_tween()
		t.tween_property(_panel, "modulate:a", 0.0, 0.15)
		t.tween_callback(_show_current_step)


func _skip_all() -> void:
	var step_keys = TUTORIAL_STEPS.keys()
	for key in step_keys:
		GameState.tutorial_completed[key] = true
	_complete_tutorial()


func _complete_tutorial() -> void:
	_tutorial_active = false
	GameState.tutorial_active = false
	get_tree().paused = false
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		_panel.visible = false
		hide()
	)


func is_active() -> bool:
	return _tutorial_active


# 检查是否应该显示某一步引导
func should_show(step_id: String) -> bool:
	return not GameState.tutorial_completed.get(step_id, false) and not _tutorial_active


# 检查是否有任何引导未完成
func has_pending() -> bool:
	for key in TUTORIAL_STEPS:
		if not GameState.tutorial_completed.get(key, false):
			return true
	return false

# PerformancePanel - 性能监控面板
# 按 F4 切换显示，包含 FPS / 实体数 / 内存等信息
extends CanvasLayer

var _panel: PanelContainer
var _labels: Dictionary = {}
var _visible: bool = false
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.5

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	add_to_group("performance_panel")


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 8
	_panel.offset_top = 8
	_panel.custom_minimum_size = Vector2(220, 0)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.85)
	style.border_color = Color(0.3, 0.4, 0.6, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	_panel.add_child(vb)

	var title = Label.new()
	title.text = "📊 性能监控 (F4 切换)"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.6, 0.8, 1.0)
	vb.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	vb.add_child(sep)

	var stats = [
		"fps", "frame_time", "enemies", "gems", "projectiles",
		"objects", "memory", "physics_fps"
	]
	for s in stats:
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.7, 0.8, 0.9)
		vb.add_child(lbl)
		_labels[s] = lbl


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F4 and event.pressed and not event.echo:
		toggle()


func _process(delta: float) -> void:
	if not _visible:
		return
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_stats()


func toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_update_stats()


func _update_stats() -> void:
	if not _visible:
		return

	var fps := Engine.get_frames_per_second()
	var frame_ms := Engine.get_frames_per_second()
	if frame_ms > 0:
		frame_ms = 1000.0 / frame_ms

	var enemies := 0
	var gems := 0
	var projectiles := 0
	var tree := get_tree()
	if tree:
		enemies = tree.get_nodes_in_group("enemy").size()
		gems = tree.get_nodes_in_group("gem").size()
		projectiles = tree.get_nodes_in_group("projectile").size()

	var mem := 0
	if OS.has_feature("editor"):
		mem = OS.get_static_memory_usage() / (1024 * 1024)

	var phys_fps := Engine.physics_ticks_per_second

	_set_stat("fps", "FPS: %d" % fps, fps < 30)
	_set_stat("frame_time", "帧耗时: %.1f ms" % frame_ms, frame_ms > 20.0)
	_set_stat("enemies", "敌人: %d" % enemies, enemies > 150)
	_set_stat("gems", "宝石: %d" % gems, gems > 120)
	_set_stat("projectiles", "投射物: %d" % projectiles, projectiles > 200)
	_set_stat("objects", "场景节点: %d" % tree.get_node_count(), false)
	_set_stat("memory", "内存: %d MB" % mem, mem > 200)
	_set_stat("physics_fps", "物理频率: %d Hz" % phys_fps, false)


func _set_stat(key: String, text: String, warn: bool) -> void:
	var lbl = _labels.get(key)
	if lbl:
		lbl.text = text
		if warn:
			lbl.modulate = Color(1.0, 0.5, 0.4)
		else:
			lbl.modulate = Color(0.7, 0.85, 0.75) if key == "fps" and int(text.split(":")[1]) >= 55 else Color(0.7, 0.8, 0.9)

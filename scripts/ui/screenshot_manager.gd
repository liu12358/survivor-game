# ScreenshotManager - 截图功能
# 按 F12 截图并保存到用户目录 / 项目根目录
extends Node

const SAVE_DIR := "user://screenshots"
const FORMAT := Image.FORMAT_RGBA8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("screenshot_manager")
	# 确保目录存在
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed and not event.echo:
		_take_screenshot()


func _take_screenshot() -> void:
	var viewport := get_viewport()
	if not viewport:
		return

	var tex := viewport.get_texture()
	if not tex:
		return

	var img := tex.get_image()
	if not img:
		return

	# 水平翻转（Godot viewport texture 默认镜像）
	img.flip_x()

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "starfall_%s.png" % timestamp
	var path := SAVE_DIR.path_join(filename)

	var err := img.save_png(path)
	if err == OK:
		print("[Screenshot] 截图已保存: %s" % path)
		# 显示提示
		var tm := get_tree().get_first_node_in_group("toast_manager")
		if tm and tm.has_method("show_system"):
			tm.show_system("📸 截图已保存: %s" % filename)
	else:
		printerr("[Screenshot] 保存失败: %s (error %d)" % [path, err])

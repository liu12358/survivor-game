# VFX - 程序化视觉特效工具
# 用代码生成径向渐变光晕 + additive 混合，跨渲染器一致
class_name VFX
extends RefCounted

static var _glow_tex: GradientTexture2D = null
static var _add_mat: CanvasItemMaterial = null
static var _ring_tex: ImageTexture = null
static var _star_tex: ImageTexture = null


static func _glow_texture() -> GradientTexture2D:
	if _glow_tex != null:
		return _glow_tex
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_glow_tex = tex
	return _glow_tex


static func _additive_mat() -> CanvasItemMaterial:
	if _add_mat != null:
		return _add_mat
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


# 生成发光光晕精灵
static func make_glow(color: Color, diameter: float, alpha: float = 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _glow_texture()
	s.material = _additive_mat()
	s.modulate = Color(color.r, color.g, color.b, alpha)
	s.scale = Vector2.ONE * (diameter / 64.0)
	s.z_index = -1
	return s


# 生成冲击波环
static func make_shockwave(color: Color, radius: float) -> Sprite2D:
	if _ring_tex == null:
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := size / 2.0
		for x in range(size):
			for y in range(size):
				var d := Vector2(x - c, y - c).length()
				if d >= c - 8 and d <= c:
					var t := (d - (c - 8)) / 8.0
					img.set_pixel(x, y, Color(1, 1, 1, lerpf(0.9, 0.0, t)))
		_ring_tex = ImageTexture.create_from_image(img)

	var s := Sprite2D.new()
	s.texture = _ring_tex
	s.material = _additive_mat()
	s.modulate = color
	s.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	return s


# 生成星形粒子
static func make_star(color: Color, size: float) -> Sprite2D:
	if _star_tex == null:
		var img_size := 16
		var img := Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
		var c := img_size / 2.0
		for x in range(img_size):
			for y in range(img_size):
				var d := Vector2(x - c, y - c).length()
				if d < c:
					img.set_pixel(x, y, Color(1, 1, 1, lerpf(1.0, 0.0, d / c)))
		_star_tex = ImageTexture.create_from_image(img)

	var s := Sprite2D.new()
	s.texture = _star_tex
	s.material = _additive_mat()
	s.modulate = color
	s.scale = Vector2.ONE * (size / 16.0)
	return s


# 击杀爆散效果
static func spawn_kill_burst(pos: Vector2, color: Color, count: int = 8) -> void:
	var scene = Engine.get_main_loop().current_scene
	for i in range(count):
		var p := make_star(color, randf_range(4, 8))
		p.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		scene.add_child(p)
		var angle := randf() * TAU
		var dist := randf_range(20, 50)
		var target := pos + Vector2(cos(angle), sin(angle)) * dist
		var t := p.create_tween()
		t.set_parallel(true)
		t.tween_property(p, "global_position", target, 0.25).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "modulate:a", 0.0, 0.25)
		t.tween_property(p, "scale", Vector2.ZERO, 0.25)
		t.chain().tween_callback(p.queue_free)


# 受击闪光效果
static func spawn_hit_flash(pos: Vector2) -> void:
	var scene = Engine.get_main_loop().current_scene
	var flash := Sprite2D.new()
	flash.texture = _glow_texture()
	flash.material = _additive_mat()
	flash.modulate = Color(1, 1, 1, 0.8)
	flash.scale = Vector2.ONE * 0.5
	flash.global_position = pos
	scene.add_child(flash)
	var t := flash.create_tween()
	t.set_parallel(true)
	t.tween_property(flash, "scale", Vector2.ONE * 1.5, 0.1)
	t.tween_property(flash, "modulate:a", 0.0, 0.1)
	t.chain().tween_callback(flash.queue_free)

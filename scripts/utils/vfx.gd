# VFX - 程序化视觉特效工具（无需任何美术资源）
# 用代码生成径向渐变光晕 + additive 混合，跨渲染器一致：
# Web 走 Compatibility 渲染器不支持后处理辉光，但这种叠加精灵在任何渲染器都生效。
# 贴图与材质静态共享，成千上万个光晕也只占一份 GPU 资源。
class_name VFX
extends RefCounted

static var _glow_tex: GradientTexture2D = null
static var _add_mat: CanvasItemMaterial = null


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


# 生成一个发光光晕精灵。color=颜色，diameter=直径(像素)，alpha=强度。
# 默认 z_index=-1 渲染在主体下方，形成环绕主体的光晕。
static func make_glow(color: Color, diameter: float, alpha: float = 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _glow_texture()
	s.material = _additive_mat()
	s.modulate = Color(color.r, color.g, color.b, alpha)
	s.scale = Vector2.ONE * (diameter / 64.0)
	s.z_index = -1
	return s

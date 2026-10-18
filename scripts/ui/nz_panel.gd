class_name NzPanel
extends PanelContainer
## Panel im Stil „Obsidian & Gold“: Glas mit Rauschen, Goldkante, Eck-Ornamenten und
## optionalem violettem Leuchten – per Shader gezeichnet, daher in jeder Auflösung scharf.

const SHADER := preload("res://assets/shaders/ui_panel.gdshader")
const PAD := 16.0

var mat := ShaderMaterial.new()
var glow := 0.0:
	set(v):
		glow = v
		mat.set_shader_parameter("glow_amt", v)


func _init(margin: Vector4 = Vector4(14, 10, 14, 10), bg: Color = Color(0.035, 0.02, 0.06, 0.86), gold: Color = Palette.GOLD,
		corners: bool = true, radius: float = 8.0) -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	add_theme_stylebox_override("panel", sb)
	mat.shader = SHADER
	mat.set_shader_parameter("bg", bg)
	mat.set_shader_parameter("gold", gold)
	mat.set_shader_parameter("corners", 1.0 if corners else 0.0)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("pad", PAD)
	material = mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func():
		mat.set_shader_parameter("size", size)
		queue_redraw())


func set_param(n: String, v: Variant) -> NzPanel:
	mat.set_shader_parameter(n, v)
	return self


func _draw() -> void:
	draw_rect(Rect2(Vector2(-PAD, -PAD), size + Vector2(PAD * 2, PAD * 2)), Color.WHITE)

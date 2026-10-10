class_name NazarickBackground
extends Control
## Vollbild-Hintergrund: echtes Bild (falls vorhanden) oder animierter Shader,
## darüber aufsteigende Glut- und Seelenfunken (CPUParticles2D).

const SHADER := "res://assets/shaders/nazarick_bg.gdshader"

var image_path := ""
var architecture := true


func _init(img: String = "", with_architecture: bool = true) -> void:
	image_path = img
	architecture = with_architecture
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if image_path != "" and ResourceLoader.exists(image_path):
		var tr := TextureRect.new()
		tr.texture = load(image_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tr)
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.0, 0.04, 0.35)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
	else:
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER)
		mat.set_shader_parameter("architecture", 1.0 if architecture else 0.0)
		rect.material = mat
		add_child(rect)
	_add_particles(Palette.GOLD_BRIGHT, 60, 2.5)
	_add_particles(Palette.VIOLET_GLOW, 40, 3.5)
	resized.connect(_layout_particles)


func _add_particles(color: Color, amount: int, size_max: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = size_max
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.2, Color(color, 0.8))
	ramp.add_point(0.7, Color(color, 0.4))
	p.color_ramp = ramp
	add_child(p)
	_layout_particles()


func _layout_particles() -> void:
	for c in get_children():
		if c is CPUParticles2D:
			c.position = Vector2(size.x / 2.0, size.y + 10)
			c.emission_rect_extents = Vector2(size.x / 2.0, 20)

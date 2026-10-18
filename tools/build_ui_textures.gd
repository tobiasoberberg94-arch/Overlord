extends Node
## Rendert die 9-Slice-Texturen des Themes „Obsidian & Gold“ aus assets/shaders/ui_panel.gdshader
## nach res://assets/ui/gen/ (mit Fenster, da gerendert wird). Danach Theme neu bauen:
##   godot --path . res://tools/build_ui_textures.tscn
##   godot --headless --path . --script res://tools/build_theme.gd

const OUT := "res://assets/ui/gen/"
const PAD := 12

## Name → [Innengröße, Hintergrund, Gold, Leuchten, Ecken, Radius, Innenlinie]
var specs := {
	"panel": [Vector2(160, 160), Color(0.035, 0.02, 0.06, 0.88), Color("8a6c22"), 0.0, true, 10.0, true],
	"card": [Vector2(120, 120), Color(0.06, 0.035, 0.09, 0.95), Color("6b5320"), 0.0, true, 9.0, false],
	"tooltip": [Vector2(80, 60), Color(0.03, 0.015, 0.05, 0.97), Color("b8932e"), 0.0, false, 6.0, false],
	"btn": [Vector2(120, 48), Color(0.07, 0.04, 0.11, 0.96), Color("7a5f1e"), 0.0, true, 7.0, false],
	"btn_hover": [Vector2(120, 48), Color(0.12, 0.07, 0.18, 0.98), Color("e2bd4a"), 0.7, true, 7.0, true],
	"btn_pressed": [Vector2(120, 48), Color(0.04, 0.02, 0.07, 0.98), Color("f5d77a"), 1.0, true, 7.0, true],
	"btn_disabled": [Vector2(120, 48), Color(0.05, 0.045, 0.06, 0.8), Color("3a3440"), 0.0, false, 7.0, false],
	"btn_primary": [Vector2(120, 48), Color(0.17, 0.10, 0.03, 0.97), Color("d4af37"), 0.0, true, 7.0, true],
	"btn_primary_hover": [Vector2(120, 48), Color(0.24, 0.15, 0.05, 0.98), Color("f5d77a"), 0.8, true, 7.0, true],
	"btn_danger": [Vector2(120, 48), Color(0.16, 0.02, 0.05, 0.97), Color("8b0016"), 0.0, true, 7.0, false],
	"btn_danger_hover": [Vector2(120, 48), Color(0.24, 0.03, 0.07, 0.98), Color("d11a3a"), 0.8, true, 7.0, true],
	"btn_success": [Vector2(120, 48), Color(0.04, 0.13, 0.07, 0.97), Color("2f7a45"), 0.0, true, 7.0, false],
	"btn_success_hover": [Vector2(120, 48), Color(0.06, 0.19, 0.10, 0.98), Color("6fdc8c"), 0.7, true, 7.0, true],
	"btn_warning": [Vector2(120, 48), Color(0.16, 0.10, 0.02, 0.97), Color("8a5d12"), 0.0, true, 7.0, false],
	"btn_warning_hover": [Vector2(120, 48), Color(0.23, 0.15, 0.03, 0.98), Color("f2b43c"), 0.7, true, 7.0, true],
	"btn_card": [Vector2(140, 64), Color(0.07, 0.04, 0.11, 0.93), Color("5b2a8c"), 0.0, true, 9.0, false],
	"btn_card_hover": [Vector2(140, 64), Color(0.13, 0.07, 0.2, 0.97), Color("d4af37"), 0.8, true, 9.0, true],
	"slot": [Vector2(64, 64), Color(0.03, 0.015, 0.05, 0.92), Color("7a5f1e"), 0.0, true, 6.0, true],
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var shader: Shader = load("res://assets/shaders/ui_panel.gdshader")
	for n in specs:
		var sp: Array = specs[n]
		var inner: Vector2 = sp[0]
		var vp := SubViewport.new()
		vp.size = Vector2i(inner) + Vector2i(PAD * 2, PAD * 2)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var cr := ColorRect.new()
		cr.size = Vector2(vp.size)
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("size", inner)
		m.set_shader_parameter("pad", float(PAD))
		m.set_shader_parameter("bg", sp[1])
		m.set_shader_parameter("gold", sp[2])
		m.set_shader_parameter("glow_amt", sp[3])
		m.set_shader_parameter("corners", 1.0 if sp[4] else 0.0)
		m.set_shader_parameter("radius", sp[5])
		m.set_shader_parameter("inner_line", 1.0 if sp[6] else 0.0)
		cr.material = m
		vp.add_child(cr)
		add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
		vp.queue_free()
	print("UI-Texturen gespeichert: ", specs.size())
	get_tree().quit()

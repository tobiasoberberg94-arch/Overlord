extends Control
## Minikarte unten rechts: runder Ausschnitt der Ortsdraufsicht um den Spieler (Norden oben, ±46 m), Goldring mit
## „N“, Spielerpfeil in Blickrichtung, Zeichen wie im Kompassband (Gate, Türen, Auftraggeber, Funde, Gegner).
## Wichtige Zeichen außerhalb des Ausschnitts bleiben am Rand stehen. Ohne Karte (Aufnahme fehlgeschlagen) dunkel.

const RADIUS_M := 46.0
const SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear_mipmap;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool has_map = false;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	if (r > 1.0) {
		discard;
	}
	vec3 c = vec3(0.03, 0.025, 0.04);
	if (has_map) {
		vec2 uv = region.xy + UV * region.zw;
		if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			c = texture(map_tex, uv).rgb;
		}
	}
	c *= mix(1.0, 0.5, smoothstep(0.72, 1.0, r));
	COLOR = vec4(c, 0.93);
}
"""

var map_tex: Texture2D
var map_rect := Rect2()
var origin := Vector3.ZERO
var heading := 0.0                 ## wie HudCompass: 0 = Norden, im Uhrzeigersinn
var markers: Array = []
var _mat := ShaderMaterial.new()
var _map := ColorRect.new()
var _over := Control.new()
var _font: Font
var _glyph_font: Font


func _init() -> void:
	custom_minimum_size = Vector2(210, 210)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = NazarickTheme.display_font(700)
	_glyph_font = NazarickTheme.body_font(700)
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_map.material = _mat
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)


func set_map(tex: Texture2D, rect: Rect2) -> void:
	map_tex = tex
	map_rect = rect
	_mat.set_shader_parameter("map_tex", tex)
	_mat.set_shader_parameter("has_map", tex != null and rect.size.x > 1.0)


func update_view() -> void:
	if map_tex != null and map_rect.size.x > 1.0:
		var u0 := (origin.x - RADIUS_M - map_rect.position.x) / map_rect.size.x
		var v0 := (origin.z - RADIUS_M - map_rect.position.y) / map_rect.size.y
		_mat.set_shader_parameter("region", Vector4(u0, v0, RADIUS_M * 2.0 / map_rect.size.x, RADIUS_M * 2.0 / map_rect.size.y))
	_over.queue_redraw()


func _draw_over() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	# Zeichen
	for m in markers:
		var v: Vector3 = (m.pos as Vector3) - origin
		var p := Vector2(v.x, v.z) / RADIUS_M * (r - 8.0)
		var big: bool = m.get("big", false)
		if p.length() > r - 9.0:
			if not big:
				continue
			p = p.normalized() * (r - 9.0)
		var col: Color = m.color
		var glyph: String = m.glyph
		var fs := 15 if big else 12
		var gs := _glyph_font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var q := c + p + Vector2(-gs.x * 0.5, fs * 0.36)
		_over.draw_string_outline(_glyph_font, q, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		_over.draw_string(_glyph_font, q, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Spielerpfeil in Blickrichtung
	var f := Vector2(sin(heading), -cos(heading))
	var s := Vector2(-f.y, f.x)
	var tip := c + f * 11.0
	var pts := PackedVector2Array([tip, c - f * 7.0 + s * 7.0, c - f * 3.0, c - f * 7.0 - s * 7.0])
	_over.draw_colored_polygon(pts, Palette.GOLD_BRIGHT)
	_over.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.85), 1.5)
	# Goldring, Norden
	_over.draw_arc(c, r - 1.5, 0.0, TAU, 72, Color(Palette.GOLD, 0.9), 2.5, true)
	_over.draw_arc(c, r - 5.0, 0.0, TAU, 72, Color(0, 0, 0, 0.55), 1.5, true)
	var ns := _font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var np := Vector2(c.x - ns.x * 0.5, 15.0)
	_over.draw_circle(Vector2(c.x, 10.0), 10.0, Color(0.03, 0.02, 0.05, 0.9))
	_over.draw_string(_font, np, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.CRIMSON.lightened(0.25))

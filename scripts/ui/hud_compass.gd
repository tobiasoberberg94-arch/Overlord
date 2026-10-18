class_name HudCompass
extends Control
## Kompassband oben in der Mitte (wie Skyrim/Elden Ring): Himmelsrichtungen, Teilstriche und
## Markierungen für Gate, Figuren, Objekte und Gegner. Norden = −Z der Welt.

const FOV := PI * 0.9            ## sichtbarer Winkel des Bandes

var heading := 0.0               ## Blickrichtung (Bogenmaß, 0 = Norden, im Uhrzeigersinn)
var origin := Vector3.ZERO
var markers: Array = []          ## [{pos: Vector3, glyph, color, label}]
var _font: Font
var _glyph_font: Font
const DIRS := [[0.0, "N"], [45.0, "NO"], [90.0, "O"], [135.0, "SO"], [180.0, "S"], [225.0, "SW"], [270.0, "W"], [315.0, "NW"]]


func _init() -> void:
	custom_minimum_size = Vector2(620, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = NazarickTheme.display_font(700)
	_glyph_font = NazarickTheme.body_font(700)


func _x_for(bearing: float) -> float:
	var rel := wrapf(bearing - heading, -PI, PI)
	return size.x * 0.5 + rel / FOV * size.x


func _alpha_at(x: float) -> float:
	var e := minf(x, size.x - x) / (size.x * 0.22)
	return clampf(e, 0.0, 1.0)


func _draw() -> void:
	var w := size.x
	var y := 16.0
	# Band mit weich auslaufenden Enden
	var band := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 24
	for i in n + 1:
		var x := w * i / n
		var a := _alpha_at(x) * 0.62
		band.append(Vector2(x, 2))
		cols.append(Color(0.02, 0.01, 0.04, a))
	for i in range(n, -1, -1):
		var x := w * i / n
		band.append(Vector2(x, 30))
		cols.append(Color(0.02, 0.01, 0.04, _alpha_at(x) * 0.62))
	draw_polygon(band, cols)
	for yy in [2.0, 30.0]:
		for i in n:
			var x0 := w * i / n
			var x1 := w * (i + 1) / n
			draw_line(Vector2(x0, yy), Vector2(x1, yy), Color(Palette.GOLD, 0.55 * _alpha_at((x0 + x1) * 0.5)), 1.0)
	# Teilstriche alle 15°
	for deg in range(0, 360, 15):
		var x := _x_for(deg_to_rad(deg))
		if x < 0 or x > w:
			continue
		var a := _alpha_at(x)
		var major := deg % 45 == 0
		if not major:
			draw_line(Vector2(x, 12), Vector2(x, 20), Color(Palette.PARCHMENT, 0.35 * a), 1.0)
	for d in DIRS:
		var x := _x_for(deg_to_rad(d[0]))
		if x < -20 or x > w + 20:
			continue
		var a := _alpha_at(x)
		var fs := 17 if d[1].length() == 1 else 12
		var col: Color = Palette.CRIMSON.lightened(0.2) if d[1] == "N" else Palette.GOLD_BRIGHT
		var ts := _font.get_string_size(d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := Vector2(x - ts.x * 0.5, y + fs * 0.36)
		draw_string_outline(_font, p, d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8 * a))
		draw_string(_font, p, d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
	# Markierungen
	var best_label := ""
	var best_d := 1e9
	var best_x := 0.0
	for m in markers:
		var v: Vector3 = m.pos - origin
		var dist := Vector2(v.x, v.z).length()
		if dist < 0.5:
			continue
		var b := atan2(v.x, -v.z)
		var x := _x_for(b)
		if x < 4 or x > w - 4:
			continue
		var a := _alpha_at(x)
		var col: Color = m.color
		var glyph: String = m.glyph
		var fs := 15 if m.get("big", false) else 12
		var gs := _glyph_font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := Vector2(x - gs.x * 0.5, 39 + fs * 0.3)
		draw_string_outline(_glyph_font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85 * a))
		draw_string(_glyph_font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		var off := absf(x - w * 0.5)
		if m.get("label", "") != "" and off < 40.0 and off < best_d:
			best_d = off
			best_label = "%s · %d m" % [m.label, int(dist)]
			best_x = x
	# Mittelmarke
	var cx := w * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 6, 0), Vector2(cx + 6, 0), Vector2(cx, 7)]), Palette.GOLD_BRIGHT)
	draw_line(Vector2(cx, 7), Vector2(cx, 26), Color(Palette.GOLD_BRIGHT, 0.5), 1.0)
	if best_label != "":
		var ts := _font.get_string_size(best_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var p := Vector2(clampf(best_x - ts.x * 0.5, 0, w - ts.x), 62)
		draw_string_outline(_font, p, best_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.85))
		draw_string(_font, p, best_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.PARCHMENT)

class_name HudBar
extends Control
## Schlanker Ornament-Balken (Leben/Mana/Ausdauer/Ziel): Goldrahmen mit Rauten-Enden, Verlaufsfüllung
## mit Glanzkante, nachlaufender „Schadensbalken“ und Aufleuchten bei Heilung.

var color := Color(0.85, 0.12, 0.2)
var value := 1.0
var max_value := 1.0
var show_text := true
var ticks := 0.0                ## Teilstriche alle n Punkte (0 = keine)
var _trail := 1.0               ## nachlaufender Anteil (0..1)
var _trail_wait := 0.0
var _heal := 0.0
var _font: Font


func _init(c: Color = Color(0.85, 0.12, 0.2), h: float = 14.0, w: float = 300.0) -> void:
	color = c
	custom_minimum_size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = NazarickTheme.display_font(700)


func set_values(v: float, mx: float) -> void:
	mx = maxf(mx, 1.0)
	var old := value / max_value
	var now := clampf(v / mx, 0.0, 1.0)
	if now < old - 0.0001:
		_trail = maxf(_trail, old)
		_trail_wait = 0.45
	elif now > old + 0.02:
		_heal = 1.0
	value = v
	max_value = mx
	queue_redraw()


func _process(delta: float) -> void:
	var f := clampf(value / max_value, 0.0, 1.0)
	var dirty := false
	if _trail > f:
		if _trail_wait > 0.0:
			_trail_wait -= delta
		else:
			_trail = maxf(f, _trail - delta * 0.6)
		dirty = true
	else:
		_trail = f
	if _heal > 0.0:
		_heal = maxf(0.0, _heal - delta * 2.0)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var f := clampf(value / max_value, 0.0, 1.0)
	var inset := 2.0
	var r := Rect2(Vector2.ZERO, size)
	# Rahmen
	var frame := NazarickTheme.box(Color(0.02, 0.01, 0.03, 0.82), Color(Palette.GOLD_DARK, 0.95), 1, 3, Color(0, 0, 0, 0.6), 4, 0)
	draw_style_box(frame, r)
	var inner := Rect2(Vector2(inset, inset), Vector2(w - inset * 2, h - inset * 2))
	# Nachlauf
	if _trail > f:
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * f, 0), Vector2(inner.size.x * (_trail - f), inner.size.y)),
			Color(color.lightened(0.55), 0.55))
	# Füllung mit Verlauf (oben hell, unten dunkel)
	if f > 0.0:
		var fw := inner.size.x * f
		var p := inner.position
		var top := color.lightened(0.28 + _heal * 0.4)
		var bot := color.darkened(0.35)
		draw_polygon(PackedVector2Array([p, p + Vector2(fw, 0), p + Vector2(fw, inner.size.y), p + Vector2(0, inner.size.y)]),
			PackedColorArray([top, top, bot, bot]))
		draw_line(p + Vector2(1, 1), p + Vector2(fw - 1, 1), Color(1, 1, 1, 0.35), 1.0)
		# leuchtende Kante am Füllende
		draw_rect(Rect2(p + Vector2(fw - 2, 0), Vector2(2, inner.size.y)), Color(color.lightened(0.6), 0.9))
	# Teilstriche
	if ticks > 0.0 and max_value > ticks:
		var n := int(max_value / ticks)
		for i in range(1, n + 1):
			var x := inner.position.x + inner.size.x * (i * ticks / max_value)
			if x < inner.end.x - 2:
				draw_line(Vector2(x, inner.position.y + 1), Vector2(x, inner.end.y - 1), Color(0, 0, 0, 0.45), 1.0)
	# Rauten an den Enden
	for x in [0.0, w]:
		var c := Vector2(x, h * 0.5)
		var s := minf(h * 0.55, 7.0) + 1.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Palette.GOLD_DARK)
		s -= 1.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), Palette.GOLD)
	# Zahlenwert
	if show_text and h >= 11.0:
		var txt := "%d / %d" % [int(ceilf(value)), int(max_value)]
		var fs := int(clampf(h - 3.0, 10.0, 14.0))
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(w - tw - 10.0, h * 0.5 + fs * 0.36)
		draw_string_outline(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PARCHMENT)

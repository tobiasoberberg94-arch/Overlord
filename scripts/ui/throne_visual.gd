class_name ThroneVisual
extends Control
## Zeichnet den Thron von Nazarick mit dem Overlord darauf.
## Liegt ein Bild unter res://assets/backgrounds/throne.png, wird stattdessen dieses
## angezeigt (z. B. ein Artwork des Thronsaals mit Ainz).

const ASSET := "res://assets/backgrounds/throne.png"

var _tex: Texture2D
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ASSET):
		_tex = load(ASSET)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if _tex:
		var ts := _tex.get_size()
		var s := minf(w / ts.x, h / ts.y)
		var dst := Rect2((size - ts * s) / 2.0, ts * s)
		draw_texture_rect(_tex, dst, false)
		return
	var cx := w * 0.5
	var base := h * 0.98
	var s := minf(h / 360.0, w / 520.0)
	var glow := 0.5 + 0.5 * sin(_t * 1.3)

	# Aura hinter dem Thron
	for i in 14:
		draw_circle(Vector2(cx, base - 220 * s), (260 - i * 16) * s, Color(Palette.VIOLET_GLOW, 0.018 + 0.004 * glow))
	# Stufen
	for i in 4:
		var sw := (420 - i * 60) * s
		var sh := 14 * s
		var y := base - (i + 1) * sh
		draw_rect(Rect2(cx - sw / 2, y, sw, sh), Color("120a1c").lightened(i * 0.03))
		draw_line(Vector2(cx - sw / 2, y), Vector2(cx + sw / 2, y), Color(Palette.GOLD, 0.55), 1.5)
	var seat_y := base - 56 * s
	# Rückenlehne mit gotischen Spitzen
	var back := PackedVector2Array([
		Vector2(cx - 95 * s, seat_y), Vector2(cx - 95 * s, seat_y - 190 * s), Vector2(cx - 70 * s, seat_y - 240 * s),
		Vector2(cx - 45 * s, seat_y - 215 * s), Vector2(cx, seat_y - 300 * s), Vector2(cx + 45 * s, seat_y - 215 * s),
		Vector2(cx + 70 * s, seat_y - 240 * s), Vector2(cx + 95 * s, seat_y - 190 * s), Vector2(cx + 95 * s, seat_y)])
	draw_colored_polygon(back, Color("1a0f26"))
	draw_polyline(back, Color(Palette.GOLD, 0.85), 2.5, true)
	var inner := PackedVector2Array()
	for p in back:
		inner.append(Vector2(cx, seat_y - 130 * s) + (p - Vector2(cx, seat_y - 130 * s)) * 0.78)
	draw_polyline(inner, Color(Palette.GOLD, 0.3), 1.2, true)
	# Gildenwappen auf der Lehne
	_draw_emblem(Vector2(cx, seat_y - 225 * s), 18 * s, glow)

	# Armlehnen
	for sx in [-1.0, 1.0]:
		var arm := Rect2(cx + sx * 95 * s - 14 * s, seat_y - 46 * s, 28 * s, 56 * s)
		draw_rect(arm, Color("1a0f26"))
		draw_rect(arm, Color(Palette.GOLD, 0.6), false, 1.5)

	# Der Overlord (Silhouette in Robe)
	var robe := PackedVector2Array([
		Vector2(cx - 70 * s, seat_y + 10 * s), Vector2(cx - 48 * s, seat_y - 105 * s), Vector2(cx - 22 * s, seat_y - 120 * s),
		Vector2(cx + 22 * s, seat_y - 120 * s), Vector2(cx + 48 * s, seat_y - 105 * s), Vector2(cx + 70 * s, seat_y + 10 * s)])
	draw_colored_polygon(robe, Color("0b0612"))
	draw_polyline(robe, Color(Palette.VIOLET_GLOW, 0.5), 1.5, true)
	for sx in [-1.0, 1.0]:
		draw_colored_polygon([Vector2(cx + sx * 20 * s, seat_y - 118 * s), Vector2(cx + sx * 62 * s, seat_y - 175 * s),
			Vector2(cx + sx * 52 * s, seat_y - 100 * s)], Color("170b26"))
		draw_line(Vector2(cx + sx * 20 * s, seat_y - 118 * s), Vector2(cx + sx * 62 * s, seat_y - 175 * s), Palette.GOLD, 2.0)
	# Schädel
	var head := Vector2(cx, seat_y - 140 * s)
	draw_circle(head, 21 * s, Color("e9e1cf"))
	draw_circle(head + Vector2(0, 14 * s), 12 * s, Color("e9e1cf"))
	for sx in [-1.0, 1.0]:
		draw_circle(head + Vector2(sx * 8 * s, -1 * s), 5.5 * s, Color("0b0612"))
		draw_circle(head + Vector2(sx * 8 * s, -1 * s), (1.6 + glow * 1.2) * s, Color("ff2a4f"))
	# Rote Kugel & Stab von Ainz Ooal Gown
	draw_circle(Vector2(cx, seat_y - 70 * s), 9 * s, Color("c4102c"))
	draw_circle(Vector2(cx, seat_y - 70 * s), (14 + glow * 4) * s, Color(1, 0.1, 0.2, 0.12))
	var staff_x := cx + 82 * s
	draw_line(Vector2(staff_x, seat_y + 20 * s), Vector2(staff_x, seat_y - 200 * s), Palette.GOLD, 3.0 * s)
	for i in 7:
		var a := _t * 0.8 + i * TAU / 7.0
		draw_circle(Vector2(staff_x + cos(a) * 16 * s, seat_y - 215 * s + sin(a) * 6 * s), 4 * s,
			Color.from_hsv(i / 7.0, 0.7, 1.0, 0.9))


func _draw_emblem(c: Vector2, r: float, glow: float) -> void:
	draw_circle(c, r * 1.4, Color(Palette.GOLD, 0.12 + glow * 0.08))
	draw_arc(c, r, 0, TAU, 32, Palette.GOLD, 2.0, true)
	for i in 8:
		var a := i * TAU / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.4, c + Vector2(cos(a), sin(a)) * r, Color(Palette.GOLD, 0.8), 1.5)

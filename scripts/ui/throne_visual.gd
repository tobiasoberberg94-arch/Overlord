class_name ThroneVisual
extends Control
## Blick auf den Thron von Nazarick.
##
## Mit Artwork (assets/backgrounds/throne_room.*) wird das Bild als „Fenster“
## mit Goldrahmen gezeigt und Ainz (assets/characters/ainz.*) davor eingeblendet.
## Ohne Artwork wird ein stilisierter Thron prozedural gezeichnet.

var _room: Texture2D
var _lord: Texture2D
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room = Content.find_image("backgrounds", "throne_room")
	_lord = Portrait.find_texture("ainz")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 10 or size.y < 10:
		return
	if _room:
		_draw_artwork()
	else:
		_draw_procedural()


func _draw_artwork() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var ts := _room.get_size()
	# Ausschnitt um den Thron (Bildmitte, leicht oberhalb)
	var aspect := size.x / size.y
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > aspect:
		src.size.x = ts.y * aspect
		src.position.x = (ts.x - src.size.x) / 2.0
	else:
		src.size.y = ts.x / aspect
		src.position.y = (ts.y - src.size.y) * 0.55
	# sanfter Zoom („atmender“ Raum)
	var zoom := 1.0 + 0.015 * sin(_t * 0.4)
	var c := src.get_center()
	src.size /= zoom
	src.position = c - src.size / 2.0
	draw_texture_rect_region(_room, r, src)
	# Vignette
	for i in 6:
		var a := 0.06 * (6 - i)
		draw_rect(Rect2(i * 6, i * 6, size.x - i * 12, size.y - i * 12), Color(0, 0, 0, a), false, 6.0)
	draw_polygon([Vector2(0, size.y * 0.7), Vector2(size.x, size.y * 0.7), size, Vector2(0, size.y)],
		[Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0, 0.04, 0.85), Color(0.02, 0, 0.04, 0.85)])
	# Der Overlord vor dem Thron
	if _lord:
		var glow := 0.5 + 0.5 * sin(_t * 1.4)
		var lh := size.y * 0.92
		var ls := _lord.get_size()
		var lw := lh * ls.x / ls.y
		var pos := Vector2((size.x - lw) / 2.0, size.y - lh)
		for i in 8:
			draw_circle(Vector2(size.x / 2.0, size.y * 0.45), size.y * (0.55 - i * 0.05), Color(0.6, 0.25, 1.0, 0.025 + 0.01 * glow))
		draw_texture_rect(_lord, Rect2(pos, Vector2(lw, lh)), false)
	# Goldrahmen
	draw_rect(r.grow(-1), Color(Palette.GOLD, 0.85), false, 2.0)
	draw_rect(r.grow(-6), Color(Palette.GOLD, 0.25), false, 1.0)


func _draw_procedural() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var base := h * 0.98
	var s := minf(h / 360.0, w / 520.0)
	var glow := 0.5 + 0.5 * sin(_t * 1.3)
	for i in 14:
		draw_circle(Vector2(cx, base - 220 * s), (260 - i * 16) * s, Color(Palette.VIOLET_GLOW, 0.018 + 0.004 * glow))
	for i in 4:
		var sw := (420 - i * 60) * s
		var sh := 14 * s
		var y := base - (i + 1) * sh
		draw_rect(Rect2(cx - sw / 2, y, sw, sh), Color("120a1c").lightened(i * 0.03))
		draw_line(Vector2(cx - sw / 2, y), Vector2(cx + sw / 2, y), Color(Palette.GOLD, 0.55), 1.5)
	var seat_y := base - 56 * s
	var back := PackedVector2Array([
		Vector2(cx - 95 * s, seat_y), Vector2(cx - 95 * s, seat_y - 190 * s), Vector2(cx - 70 * s, seat_y - 240 * s),
		Vector2(cx - 45 * s, seat_y - 215 * s), Vector2(cx, seat_y - 300 * s), Vector2(cx + 45 * s, seat_y - 215 * s),
		Vector2(cx + 70 * s, seat_y - 240 * s), Vector2(cx + 95 * s, seat_y - 190 * s), Vector2(cx + 95 * s, seat_y)])
	draw_colored_polygon(back, Color("1a0f26"))
	draw_polyline(back, Color(Palette.GOLD, 0.85), 2.5, true)
	for sx in [-1.0, 1.0]:
		var arm := Rect2(cx + sx * 95 * s - 14 * s, seat_y - 46 * s, 28 * s, 56 * s)
		draw_rect(arm, Color("1a0f26"))
		draw_rect(arm, Color(Palette.GOLD, 0.6), false, 1.5)
	var robe := PackedVector2Array([
		Vector2(cx - 70 * s, seat_y + 10 * s), Vector2(cx - 48 * s, seat_y - 105 * s), Vector2(cx - 22 * s, seat_y - 120 * s),
		Vector2(cx + 22 * s, seat_y - 120 * s), Vector2(cx + 48 * s, seat_y - 105 * s), Vector2(cx + 70 * s, seat_y + 10 * s)])
	draw_colored_polygon(robe, Color("0b0612"))
	draw_polyline(robe, Color(Palette.VIOLET_GLOW, 0.5), 1.5, true)
	var head := Vector2(cx, seat_y - 140 * s)
	draw_circle(head, 21 * s, Color("e9e1cf"))
	draw_circle(head + Vector2(0, 14 * s), 12 * s, Color("e9e1cf"))
	for sx in [-1.0, 1.0]:
		draw_circle(head + Vector2(sx * 8 * s, -1 * s), 5.5 * s, Color("0b0612"))
		draw_circle(head + Vector2(sx * 8 * s, -1 * s), (1.6 + glow * 1.2) * s, Color("ff2a4f"))
	draw_circle(Vector2(cx, seat_y - 70 * s), 9 * s, Color("c4102c"))

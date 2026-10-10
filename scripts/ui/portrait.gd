class_name Portrait
extends Control
## Charakter-Portrait mit Rahmen.
##
## Liegt unter res://assets/characters/<id>.png (oder .jpg/.webp) ein Bild, wird es
## formatfüllend (oben ausgerichtet) dargestellt. Andernfalls zeichnet das Portrait
## einen stilisierten Platzhalter in den Farben des Charakters – so ist das Spiel
## ohne Art-Assets voll spielbar, und echte Bilder können jederzeit eingesetzt werden.

const ASSET_DIR := "res://assets/characters/"
const EXTENSIONS := ["png", "webp", "jpg", "jpeg"]

@export var char_id: String = "":
	set(v):
		char_id = v
		_texture = find_texture(v)
		queue_redraw()
@export var framed: bool = true
@export var show_symbol: bool = true
@export var dimmed: bool = false:
	set(v):
		dimmed = v
		queue_redraw()

var _texture: Texture2D


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func find_texture(cid: String) -> Texture2D:
	for ext in EXTENSIONS:
		var p := "%s%s.%s" % [ASSET_DIR, cid, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if size.x < 4 or size.y < 4:
		return
	if _texture:
		_draw_texture_cover(r)
	else:
		_draw_placeholder(r)
	if dimmed:
		draw_rect(r, Color(0, 0, 0, 0.55))
	if framed:
		_draw_frame(r)


func _draw_texture_cover(r: Rect2) -> void:
	var ts := _texture.get_size()
	var target_aspect := r.size.x / r.size.y
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > target_aspect:
		src.size.x = ts.y * target_aspect
		src.position.x = (ts.x - src.size.x) / 2.0
	else:
		src.size.y = ts.x / target_aspect
	draw_texture_rect_region(_texture, r, src)
	# leichter Verlauf nach unten für lesbare Namensleisten
	draw_polygon([Vector2(0, r.size.y * 0.6), Vector2(r.size.x, r.size.y * 0.6), r.size, Vector2(0, r.size.y)],
		[Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6)])


func _draw_frame(r: Rect2) -> void:
	var gold := Palette.GOLD
	draw_rect(r.grow(-1), Color(gold, 0.9), false, 2.0)
	draw_rect(r.grow(-5), Color(gold, 0.25), false, 1.0)
	var d := minf(r.size.x, r.size.y) * 0.06
	for corner in [Vector2(0, 0), Vector2(r.size.x, 0), Vector2(0, r.size.y), r.size]:
		var c: Vector2 = corner + (r.size / 2.0 - corner).normalized() * 6.0
		draw_colored_polygon([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)], gold)


# ---------------------------------------------------------------------------
#  Prozeduraler Platzhalter
# ---------------------------------------------------------------------------

func _draw_placeholder(r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cd := Content.char_data(char_id)
	var col: Color = Color(cd.get("color", "#e9e1cf")) if not cd.is_empty() else Color("e9e1cf")
	var acc: Color = Color(cd.get("accent", "#5b2a8c")) if not cd.is_empty() else Palette.VIOLET
	if char_id == "ainz":
		col = Color("e9e1cf")
		acc = Palette.VIOLET

	# Hintergrund: Verlauf von der Akzentfarbe ins Schwarz
	draw_polygon([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)],
		[acc.darkened(0.35), acc.darkened(0.55), Palette.VOID, Palette.VOID])
	# Lichtschein hinter dem Kopf
	var hc := Vector2(w * 0.5, h * 0.40)
	var hr := minf(w * 0.17, h * 0.13)
	for i in 10:
		draw_circle(hc, hr * (4.0 - i * 0.3), Color(col, 0.025))
	# Großer Initialbuchstabe im Hintergrund
	var font := get_theme_default_font()
	var nm: String = cd.get("name", "Ainz Ooal Gown")
	var fsize := int(h * 0.62)
	draw_string(font, Vector2(w * 0.08, h * 0.72), nm.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(col, 0.07))

	var sil := col.darkened(0.72)
	var rim := Color(col, 0.75)
	_features_back(hc, hr, w, h, col, sil)

	# Körper (Schultern) + Hals
	var body := PackedVector2Array([
		Vector2(w * 0.05, h), Vector2(w * 0.14, h * 0.80), Vector2(w * 0.36, h * 0.66),
		Vector2(w * 0.64, h * 0.66), Vector2(w * 0.86, h * 0.80), Vector2(w * 0.95, h)])
	draw_colored_polygon(body, sil)
	draw_polyline(body, rim, 1.6, true)
	draw_rect(Rect2(hc.x - hr * 0.35, hc.y + hr * 0.6, hr * 0.7, hr * 1.0), sil)
	# Kopf
	_head(hc, hr, col, sil, rim)
	_features_front(hc, hr, w, h, col, sil)

	if show_symbol:
		var sym: String = cd.get("symbol", "☠")
		draw_string(font, Vector2(w * 0.07, h * 0.15), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.09), Color(col, 0.85))


func _head(hc: Vector2, hr: float, col: Color, sil: Color, rim: Color) -> void:
	match char_id:
		"pandora":
			draw_set_transform(hc, 0.0, Vector2(0.85, 1.15))
			draw_circle(Vector2.ZERO, hr, Color("e8c9a8"))
			draw_set_transform(Vector2.ZERO)
			for p in [Vector2(-0.35, -0.1), Vector2(0.35, -0.1), Vector2(0, 0.45)]:
				draw_circle(hc + p * hr, hr * 0.17, Color("1a0f08"))
			return
		"cocytus":
			draw_set_transform(hc, 0.0, Vector2(0.8, 1.2))
			draw_circle(Vector2.ZERO, hr, sil.lightened(0.15))
			draw_arc(Vector2.ZERO, hr, 0, TAU, 40, rim, 1.5, true)
			draw_set_transform(Vector2.ZERO)
		"ainz":
			draw_circle(hc, hr, Color("e9e1cf"))
			draw_circle(hc + Vector2(0, hr * 0.85), hr * 0.55, Color("e9e1cf"))
			for sx in [-1.0, 1.0]:
				draw_circle(hc + Vector2(sx * hr * 0.38, -hr * 0.05), hr * 0.25, Color("0b0612"))
				draw_circle(hc + Vector2(sx * hr * 0.38, -hr * 0.05), hr * 0.08, Color("ff2a4f"))
			draw_colored_polygon([hc + Vector2(-hr * 0.1, hr * 0.35), hc + Vector2(hr * 0.1, hr * 0.35), hc + Vector2(0, hr * 0.15)], Color("0b0612"))
			return
		_:
			draw_circle(hc, hr, sil.lightened(0.08))
			draw_arc(hc, hr, 0, TAU, 40, rim, 1.5, true)
	# Augen (leuchtend in der Charakterfarbe; Zwillinge mit verschiedenfarbigen Augen)
	var eye_l := col.lightened(0.3)
	var eye_r := col.lightened(0.3)
	if char_id == "aura":
		eye_l = Color("4fb3ff"); eye_r = Color("6fdc5c")
	elif char_id == "mare":
		eye_l = Color("6fdc5c"); eye_r = Color("4fb3ff")
	elif char_id == "shalltear":
		eye_l = Color("ff2a4f"); eye_r = Color("ff2a4f")
	draw_circle(hc + Vector2(-hr * 0.36, 0), hr * 0.11, eye_l)
	draw_circle(hc + Vector2(hr * 0.36, 0), hr * 0.11, eye_r)


func _features_back(hc: Vector2, hr: float, w: float, h: float, col: Color, sil: Color) -> void:
	match char_id:
		"albedo":
			# schwarze Schwingen
			for sx in [-1.0, 1.0]:
				var base := Vector2(w * 0.5 + sx * w * 0.12, h * 0.70)
				var wing := PackedVector2Array([base, Vector2(w * 0.5 + sx * w * 0.52, h * 0.18),
					Vector2(w * 0.5 + sx * w * 0.47, h * 0.42), Vector2(w * 0.5 + sx * w * 0.55, h * 0.5),
					Vector2(w * 0.5 + sx * w * 0.42, h * 0.62), Vector2(w * 0.5 + sx * w * 0.45, h * 0.75)])
				draw_colored_polygon(wing, Color("0a0710"))
				draw_polyline(wing, Color(Palette.VIOLET_GLOW, 0.6), 1.5, true)
			# langes dunkles Haar
			draw_colored_polygon([hc + Vector2(-hr * 1.15, -hr * 0.2), hc + Vector2(hr * 1.15, -hr * 0.2),
				hc + Vector2(hr * 1.3, hr * 3.0), hc + Vector2(-hr * 1.3, hr * 3.0)], Color("140c1c"))
		"shalltear":
			draw_colored_polygon([hc + Vector2(-hr * 1.05, -hr * 0.3), hc + Vector2(hr * 1.05, -hr * 0.3),
				hc + Vector2(hr * 1.0, hr * 2.4), hc + Vector2(-hr * 1.0, hr * 2.4)], Color("cfd2dc"))
			# große Schleife
			var top := hc + Vector2(0, -hr * 1.05)
			for sx in [-1.0, 1.0]:
				draw_colored_polygon([top, top + Vector2(sx * hr * 1.4, -hr * 0.8), top + Vector2(sx * hr * 1.3, hr * 0.5)], Color("2a0008"))
			draw_circle(top, hr * 0.3, Palette.CRIMSON)
		"narberal":
			draw_circle(hc + Vector2(0, -hr * 0.6), hr * 0.55, Color("0e0e18"))
			draw_colored_polygon([hc + Vector2(-hr * 0.2, -hr * 0.4), hc + Vector2(hr * 0.2, -hr * 0.4),
				hc + Vector2(hr * 0.35, hr * 3.2), hc + Vector2(-hr * 0.35, hr * 3.2)], Color("0e0e18"))
		"demiurge":
			# Teufelsschwanz
			var pts := PackedVector2Array()
			for i in 16:
				var t := i / 15.0
				pts.append(Vector2(w * (0.12 + 0.1 * sin(t * 3.0)), h * (0.98 - 0.55 * t)))
			draw_polyline(pts, Color("b3b0a8"), 4.0, true)
			var tip := pts[pts.size() - 1]
			draw_colored_polygon([tip + Vector2(0, -10), tip + Vector2(7, 4), tip + Vector2(-7, 4)], Color("d9d6cf"))
		"cocytus":
			# zusätzliche Arme & Eiskristalle
			for sx in [-1.0, 1.0]:
				draw_line(Vector2(w * 0.5 + sx * w * 0.22, h * 0.74), Vector2(w * 0.5 + sx * w * 0.47, h * 0.52), Color(col, 0.7), 5.0)
				draw_line(Vector2(w * 0.5 + sx * w * 0.26, h * 0.82), Vector2(w * 0.5 + sx * w * 0.5, h * 0.72), Color(col, 0.5), 4.0)
			for p in [Vector2(0.15, 0.25), Vector2(0.85, 0.3), Vector2(0.8, 0.12)]:
				_snowflake(Vector2(w * p.x, h * p.y), w * 0.04, Color(col, 0.6))


func _features_front(hc: Vector2, hr: float, w: float, h: float, col: Color, sil: Color) -> void:
	match char_id:
		"albedo":
			for sx in [-1.0, 1.0]:
				draw_colored_polygon([hc + Vector2(sx * hr * 0.55, -hr * 0.75), hc + Vector2(sx * hr * 0.95, -hr * 0.55),
					hc + Vector2(sx * hr * 1.35, -hr * 1.45), hc + Vector2(sx * hr * 1.0, -hr * 1.0)], Color("efe6d0"))
			draw_arc(hc + Vector2(0, -hr * 0.15), hr * 1.02, PI * 1.05, PI * 1.95, 24, Color("140c1c"), hr * 0.35)
		"shalltear":
			for sx in [-1.0, 1.0]:
				draw_colored_polygon([hc + Vector2(sx * hr * 0.16, hr * 0.48), hc + Vector2(sx * hr * 0.06, hr * 0.48),
					hc + Vector2(sx * hr * 0.11, hr * 0.68)], Color.WHITE)
			# Rüschen am Kragen
			for i in 7:
				draw_circle(Vector2(w * (0.36 + i * 0.047), h * 0.68), w * 0.03, Color("3a0010"))
		"demiurge":
			for sx in [-1.0, 1.0]:
				draw_arc(hc + Vector2(sx * hr * 0.36, 0), hr * 0.24, 0, TAU, 24, Palette.GOLD, 2.0, true)
			draw_line(hc + Vector2(-hr * 0.12, 0), hc + Vector2(hr * 0.12, 0), Palette.GOLD, 2.0)
			draw_arc(hc, hr * 1.0, PI * 1.1, PI * 1.9, 24, Color("1a1410"), hr * 0.3)
			draw_colored_polygon([Vector2(w * 0.44, h * 0.68), Vector2(w * 0.56, h * 0.68), Vector2(w * 0.5, h * 0.85)], Color("f0ece0"))
			draw_colored_polygon([Vector2(w * 0.48, h * 0.7), Vector2(w * 0.52, h * 0.7), Vector2(w * 0.5, h * 0.82)], Color("b33a00"))
		"cocytus":
			for sx in [-1.0, 1.0]:
				draw_colored_polygon([hc + Vector2(sx * hr * 0.25, hr * 0.85), hc + Vector2(sx * hr * 0.75, hr * 0.95),
					hc + Vector2(sx * hr * 0.2, hr * 1.45)], Color(col, 0.9))
		"aura", "mare":
			for sx in [-1.0, 1.0]:
				draw_colored_polygon([hc + Vector2(sx * hr * 0.85, -hr * 0.1), hc + Vector2(sx * hr * 1.75, -hr * 0.75),
					hc + Vector2(sx * hr * 0.9, hr * 0.3)], Color("c08a62"))
			var hair := Color("e6c25a") if char_id == "aura" else Color("d9b44a")
			if char_id == "mare":
				draw_arc(hc + Vector2(0, hr * 0.1), hr * 1.0, PI * 0.9, PI * 2.1, 28, hair, hr * 0.42)
			else:
				draw_arc(hc, hr * 1.0, PI * 1.05, PI * 1.95, 24, hair, hr * 0.4)
		"sebas":
			draw_arc(hc, hr * 1.0, PI * 1.1, PI * 1.9, 24, Color("d8d8d8"), hr * 0.32)
			draw_colored_polygon([hc + Vector2(-hr * 0.55, hr * 0.45), hc + Vector2(hr * 0.55, hr * 0.45),
				hc + Vector2(hr * 0.3, hr * 1.15), hc + Vector2(-hr * 0.3, hr * 1.15)], Color("e0e0e0"))
			draw_colored_polygon([Vector2(w * 0.44, h * 0.68), Vector2(w * 0.56, h * 0.68), Vector2(w * 0.5, h * 0.84)], Color("f4f4f4"))
		"narberal":
			draw_arc(hc + Vector2(0, -hr * 0.1), hr * 1.0, PI * 1.05, PI * 1.95, 24, Color("0e0e18"), hr * 0.38)
			draw_arc(hc + Vector2(0, -hr * 0.3), hr * 1.1, PI * 1.2, PI * 1.8, 16, Color.WHITE, 3.0)
		"pandora":
			var cap_y := hc.y - hr * 0.95
			draw_colored_polygon([Vector2(hc.x - hr * 0.9, cap_y), Vector2(hc.x + hr * 0.9, cap_y),
				Vector2(hc.x + hr * 1.1, cap_y - hr * 0.7), Vector2(hc.x - hr * 1.1, cap_y - hr * 0.7)], Color("2b2f1a"))
			draw_rect(Rect2(hc.x - hr * 1.05, cap_y - hr * 0.08, hr * 2.1, hr * 0.2), Color("111208"))
			draw_circle(Vector2(hc.x, cap_y - hr * 0.35), hr * 0.16, Palette.GOLD)
			for i in 4:
				draw_line(Vector2(w * 0.4, h * (0.74 + i * 0.05)), Vector2(w * 0.6, h * (0.74 + i * 0.05)), Color(Palette.GOLD, 0.6), 2.0)
		"ainz":
			# Robe mit hohem Kragen und roter Kugel
			for sx in [-1.0, 1.0]:
				draw_colored_polygon([Vector2(w * 0.5 + sx * w * 0.14, h * 0.66), Vector2(w * 0.5 + sx * w * 0.42, h * 0.38),
					Vector2(w * 0.5 + sx * w * 0.36, h * 0.72)], Color("1a0d29"))
				draw_line(Vector2(w * 0.5 + sx * w * 0.14, h * 0.66), Vector2(w * 0.5 + sx * w * 0.42, h * 0.38), Palette.GOLD, 2.0)
			draw_circle(Vector2(w * 0.5, h * 0.82), w * 0.06, Color("c4102c"))
			draw_circle(Vector2(w * 0.5, h * 0.82), w * 0.025, Color("ff9aa8"))
			for i in 5:
				var x := hc.x + (i - 2) * hr * 0.35
				draw_colored_polygon([Vector2(x - hr * 0.12, hc.y - hr * 0.9), Vector2(x + hr * 0.12, hc.y - hr * 0.9),
					Vector2(x, hc.y - hr * (1.4 if i == 2 else 1.2))], Palette.GOLD)


func _snowflake(c: Vector2, s: float, color: Color) -> void:
	for i in 3:
		var a := i * PI / 3.0
		var d := Vector2(cos(a), sin(a)) * s
		draw_line(c - d, c + d, color, 1.5)

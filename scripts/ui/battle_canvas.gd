class_name BattleCanvas
extends Control
## Zeichnet das Schlachtfeld: zwei Heere aus Einheiten-Marken, die aufeinander
## zustürmen. Gefallene Marken verblassen, Treffer blitzen auf.

var ours: Array = []      ## [{glyph, color}] je Marke
var theirs: Array = []
var ours_alive := 0
var theirs_alive := 0
var charge := 0.0         ## 0 = Aufstellung, 1 = Zusammenprall
var _flashes: Array = []  ## [pos, age, color]
var _numbers: Array = []  ## [pos, age, text, color]
var _t := 0.0
var _bg: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = Content.find_image("backgrounds", "battlefield")


## Baut die Marken aus der eigenen Armee und der Feindstärke.
func setup(army: Dictionary, enemy_strength: int) -> void:
	ours.clear()
	theirs.clear()
	for k in army.get("units", {}):
		var u := Military.unit(k)
		var per := maxi(1, int(u.strength) / 10)
		for i in int(army.units[k]) * per:
			ours.append({"glyph": u.get("icon", "⚔"), "color": Color("b98cff")})
	var n := clampi(enemy_strength / 10, 4, 120)
	for i in n:
		theirs.append({"glyph": ["⚔", "✠", "♞", "☩"][i % 4], "color": Color("ff6070")})
	ours = ours.slice(0, 120)
	ours_alive = ours.size()
	theirs_alive = theirs.size()


func _process(delta: float) -> void:
	_t += delta
	for f in _flashes:
		f[1] += delta
	for n in _numbers:
		n[1] += delta
	_flashes = _flashes.filter(func(f): return f[1] < 0.6)
	_numbers = _numbers.filter(func(n): return n[1] < 1.2)
	queue_redraw()


func hit(side_ours: bool, amount: int) -> void:
	var x := size.x * (0.35 if side_ours else 0.65)
	for i in 6:
		_flashes.append([Vector2(x + randf_range(-90, 90), size.y * randf_range(0.3, 0.8)), 0.0,
			Color(1.0, 0.85, 0.4) if side_ours else Color(0.8, 0.5, 1.0)])
	_numbers.append([Vector2(x, size.y * 0.25), 0.0, "−%d" % amount, Palette.DANGER if side_ours else Palette.GOLD_BRIGHT])


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _bg:
		var ts := _bg.get_size()
		var s := maxf(size.x / ts.x, size.y / ts.y)
		var src := Rect2((ts - size / s) / 2.0, size / s)
		draw_texture_rect_region(_bg, r, src, Color(0.75, 0.7, 0.8))
	draw_rect(r, Color(0.02, 0.0, 0.04, 0.35))
	var font := get_theme_default_font()
	_draw_army(ours, ours_alive, true, font)
	_draw_army(theirs, theirs_alive, false, font)
	for f in _flashes:
		var a: float = 1.0 - f[1] / 0.6
		draw_circle(f[0], 6.0 + f[1] * 40.0, Color(f[2], 0.6 * a))
		draw_circle(f[0], 3.0, Color(1, 1, 1, a))
	for n in _numbers:
		var a: float = 1.0 - n[1] / 1.2
		var p: Vector2 = n[0] - Vector2(20, n[1] * 50.0)
		draw_string_outline(font, p, n[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0, a))
		draw_string(font, p, n[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(n[3], a))
	draw_rect(r, Color(Palette.GOLD, 0.7), false, 2.0)


func _draw_army(units: Array, alive: int, left: bool, font: Font) -> void:
	var cols := clampi(int(size.y / 30.0) - 1, 6, 14)
	var spacing := Vector2(28, 28)
	var base_x := size.x * (0.08 if left else 0.92)
	var dir := 1.0 if left else -1.0
	var advance := charge * size.x * 0.24
	for i in units.size():
		var col := i / cols
		var row := i % cols
		var bob := sin(_t * 6.0 + i) * 2.0 * charge
		var p := Vector2(base_x + dir * (col * spacing.x + advance), size.y * 0.08 + row * spacing.y + bob)
		var dead := i >= alive
		var c: Color = units[i].color
		if dead:
			c = Color(0.3, 0.3, 0.3, 0.35)
		draw_circle(p, 11, Color(0, 0, 0, 0.6))
		draw_arc(p, 11, 0, TAU, 20, c, 1.5, true)
		draw_string(font, p + Vector2(-6, 5), units[i].glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)

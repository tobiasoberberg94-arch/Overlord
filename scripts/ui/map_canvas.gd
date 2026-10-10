class_name MapCanvas
extends Control
## Zeichnet die Weltkarte: Wege, Regionen (Einfluss-Ring, Unruhe, Bedrohungen),
## eigene Legionen (violett) und feindliche Heere (rot) samt Marschrouten.
## Klick auf eine Region → region_clicked; Klick auf eine Legion → army_clicked.

signal region_clicked(id: String)
signal army_clicked(uid: String)

var selected_region := ""
## Bruchteil eines Tages für flüssige Marschanimation (0…1), gesetzt von der Zeitsteuerung
var anim_frac := 0.0
var selected_army := ""
var _tex: Texture2D
var _t := 0.0
var _hover := ""


func _init() -> void:
	_tex = Content.find_image("backgrounds", "world_map")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Rechteck, in dem die Karte (seitenverhältnistreu) liegt.
func map_rect() -> Rect2:
	if _tex == null:
		return Rect2(Vector2.ZERO, size)
	var ts := _tex.get_size()
	var s := minf(size.x / ts.x, size.y / ts.y)
	var ms := ts * s
	return Rect2((size - ms) / 2.0, ms)


func region_pos(id: String) -> Vector2:
	var r := World.region(id)
	var mr := map_rect()
	var p: Array = r.get("pos", [0.5, 0.5])
	return mr.position + Vector2(float(p[0]), float(p[1])) * mr.size


func _draw() -> void:
	var mr := map_rect()
	if _tex:
		draw_texture_rect(_tex, mr, false)
		draw_rect(mr, Color(0.03, 0.0, 0.06, 0.28))
	var font := get_theme_default_font()
	# Wege
	for l in Content.region_links:
		var a := World.rs(l[0])
		var b := World.rs(l[1])
		var known: bool = a.discovered or b.discovered
		_dashed(region_pos(l[0]), region_pos(l[1]), Color(Palette.GOLD, 0.55 if known else 0.15), 2.0 if known else 1.0)
		if known:
			var mid := (region_pos(l[0]) + region_pos(l[1])) / 2.0
			draw_string(font, mid + Vector2(-6, 4), "%dT" % int(l[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Palette.GOLD_BRIGHT, 0.6))
	# Marschrouten
	for a in Game.state.armies:
		_draw_route(a, Color("b98cff"))
	for e in Game.state.enemy_armies:
		_draw_route(e, Color("ff4a5a"))
	# Regionen
	for r in Content.regions:
		_draw_region(r, font)
	# Armeen – unterwegs gleiten sie entlang ihres Wegstücks
	var i := 0
	for a in Game.state.armies:
		_draw_banner(army_pos(a) + Vector2(-34, -30 - (i % 2) * 10), Color("6a32b8"), str(Military.strength(a)), a.uid == selected_army, a.get("commander", ""))
		i += 1
	for e in Game.state.enemy_armies:
		_draw_banner(army_pos(e) + Vector2(14, -30), Color("a1061e"), str(int(e.strength)), false, "")
		_draw_dust(army_pos(e))
	for a in Game.state.armies:
		if not a.get("path", []).is_empty():
			_draw_dust(army_pos(a))


## Aktuelle Kartenposition einer Armee (interpoliert zwischen zwei Regionen).
func army_pos(a: Dictionary) -> Vector2:
	var from := region_pos(a.location)
	if a.get("path", []).is_empty():
		return from
	var to := region_pos(a.path[0])
	var t := Military.leg_progress(a, anim_frac)
	return from.lerp(to, t)


func _draw_dust(p: Vector2) -> void:
	for k in 5:
		var a := _t * 2.0 + k * 1.3
		var off := Vector2(cos(a) * 14.0, 10.0 + sin(a * 1.7) * 4.0)
		draw_circle(p + off, 2.0 + k * 0.6, Color(0.75, 0.65, 0.5, 0.18))


func _draw_region(r: Dictionary, font: Font) -> void:
	var id: String = r.id
	var st := World.rs(id)
	var p := region_pos(id)
	var rad := 15.0
	var sel := id == selected_region or id == _hover
	if not st.discovered:
		draw_circle(p, rad, Color(0.1, 0.08, 0.12, 0.85))
		draw_arc(p, rad, 0, TAU, 32, Color(0.6, 0.6, 0.65, 0.6), 1.5, true)
		draw_string(font, p + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.8, 0.85))
	else:
		var infl := float(st.influence) / 100.0
		var hostile: bool = r.get("hostile", false)
		var base := Color("2a1342") if not hostile else Color("3a0a14")
		draw_circle(p, rad + 4, Color(0, 0, 0, 0.6))
		draw_circle(p, rad, base.lerp(Color("6a32b8"), infl))
		draw_arc(p, rad + 3, -PI / 2, -PI / 2 + TAU * infl, 40, Palette.GOLD_BRIGHT, 3.0, true)
		if st.unrest >= 35:
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(p, rad + 8, 0, TAU, 32, Color(1, 0.3, 0.2, 0.3 + 0.5 * pulse), 2.0, true)
		if r.get("home", false):
			draw_string(font, p + Vector2(-7, 7), "♛", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.GOLD_BRIGHT)
		else:
			draw_string(font, p + Vector2(-9, 5), "%d" % st.influence, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# Bedrohung
	for t in Game.state.threats:
		if t.region == id:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_string(font, p + Vector2(10, -12), "⚠", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.3, 0.3, 0.6 + 0.4 * pulse))
	if sel:
		draw_arc(p, rad + 12, 0, TAU, 40, Color(Palette.GOLD_BRIGHT, 0.6 + 0.4 * sin(_t * 3.0)), 2.0, true)
	# Name auf dunklem Schild (nur bekannte Regionen)
	if not st.discovered and id != _hover:
		return
	var label: String = r.short if st.discovered else "Unerforscht"
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var lp := p + Vector2(-w / 2.0, rad + 24)
	draw_rect(Rect2(lp + Vector2(-6, -15), Vector2(w + 12, 21)), Color(0.04, 0.01, 0.07, 0.82))
	draw_rect(Rect2(lp + Vector2(-6, -15), Vector2(w + 12, 21)), Color(Palette.GOLD, 0.45), false, 1.0)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.GOLD_BRIGHT if st.discovered else Palette.MUTED)


func _draw_route(a: Dictionary, col: Color) -> void:
	if a.get("path", []).is_empty():
		return
	var cur: Vector2 = army_pos(a)
	for n in a.path:
		var nxt := region_pos(n)
		_arrow(cur, nxt, col)
		cur = nxt


func _draw_banner(pos: Vector2, col: Color, text: String, selected: bool, commander: String) -> void:
	var w := 34.0
	var h := 40.0
	var pts := PackedVector2Array([pos, pos + Vector2(w, 0), pos + Vector2(w, h * 0.75), pos + Vector2(w / 2, h), pos + Vector2(0, h * 0.75)])
	draw_colored_polygon(pts, col)
	pts.append(pos)
	draw_polyline(pts, Palette.GOLD_BRIGHT if selected else Palette.GOLD, 2.5 if selected else 1.5, true)
	draw_line(pos, pos + Vector2(0, -10), Palette.GOLD, 2.0)
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, pos + Vector2((w - tw) / 2.0, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if commander != "":
		var sym: String = Content.char_data(commander).get("symbol", "★")
		draw_string(font, pos + Vector2(w / 2 - 6, 33), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Content.char_color(commander))


func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(len, 1.0)
	var d := 0.0
	while d < len:
		draw_line(a + dir * d, a + dir * minf(d + 8.0, len), col, width)
		d += 14.0


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	var dir := (b - a).normalized()
	var s := a + dir * 20.0
	var e := b - dir * 22.0
	var flow := fmod(_t * 30.0, 16.0)
	var len := s.distance_to(e)
	var d := flow
	while d < len:
		draw_line(s + dir * d, s + dir * minf(d + 8.0, len), col, 3.0)
		d += 16.0
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon([e + dir * 10, e + n * 7, e - n * 7], col)


func _hit(pos: Vector2) -> Dictionary:
	for a in Game.state.armies:
		var bp := army_pos(a) + Vector2(-34, -30)
		if Rect2(bp - Vector2(0, 12), Vector2(36, 54)).has_point(pos):
			return {"army": a.uid}
	for r in Content.regions:
		if region_pos(r.id).distance_to(pos) < 24:
			return {"region": r.id}
	return {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit(event.position)
		_hover = h.get("region", "")
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not h.is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var h := _hit(event.position)
		if h.has("army"):
			army_clicked.emit(h.army)
		elif h.has("region"):
			region_clicked.emit(h.region)

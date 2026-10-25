extends Overlay
## Ortskarte (Taste L): die ganze Draufsicht des Ortes mit Spielerpfeil und Beschriftungen der wichtigen Stellen –
## Gate, Türen (Häuser, Treppen, Verliese), Auftraggeber, Truhen und unentdeckte Funde in der Nähe. Schließt mit L
## oder ESC.

var _tex: Texture2D
var _rect := Rect2()
var _world: Node
var _canvas := Control.new()
var _font: Font
var _glyph_font: Font
var _labels: Array = []             ## [{pos, text, glyph, color, big}]


func _init(world: Node, tex: Texture2D, rect: Rect2) -> void:
	super(Vector2(980, 900))
	_world = world
	_tex = tex
	_rect = rect
	_font = NazarickTheme.display_font(700)
	_glyph_font = NazarickTheme.body_font(700)
	var loc: Dictionary = world.loc
	content.add_child(make_header(String(loc.get("name", "Ort")), "Lageplan · Norden oben · [L] schließen"))
	_canvas.custom_minimum_size = Vector2(700, 700)
	_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	content.add_child(_canvas)
	_collect()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_L:
		get_viewport().set_input_as_handled()
		close()
		return
	super(event)


## Stellen mit Namen: Türen und Gate aus den Figuren/Objekten des Ortes, Auftraggeber mit Zeichen, Truhen, Funde
func _collect() -> void:
	var a: Dictionary = _world.anchors
	if a.has("gate"):
		_labels.append({"pos": a.gate, "text": "Gate", "glyph": "◈", "color": Palette.VIOLET_GLOW.lightened(0.2), "big": true})
	for act in _world.actors:
		if not is_instance_valid(act):
			continue
		var node := act as Node3D
		if act.has_meta("door"):
			var d: Dictionary = act.get_meta("door")
			_labels.append({"pos": node.global_position, "text": String(d.get("name", "Tür")), "glyph": "▲", "color": Color("ffd75a"), "big": true})
		elif String(act.kind) == "object":
			if String(act.id) != "gate":
				_labels.append({"pos": node.global_position, "text": String(act.label), "glyph": "■", "color": Color("7fd8ff"), "big": false})
		else:
			var mk := Quests.marker_for(String(act.id))
			var glyph := mk if mk in ["!", "?"] else ("◆" if String(act.kind) == "char" else "●")
			var col: Color = Palette.GOLD_BRIGHT if mk == "!" else (Color(0.55, 1.0, 0.6) if mk == "?" else (Palette.GOLD if String(act.kind) == "char" else Palette.PARCHMENT))
			_labels.append({"pos": node.global_position, "text": String(act.label), "glyph": glyph, "color": col, "big": mk != ""})
	for p in _world.quest_world.pickups:
		if not is_instance_valid(p):
			continue
		var pn := p as Node3D
		if String(p.kind) == "chest":
			_labels.append({"pos": pn.global_position, "text": "", "glyph": "▣", "color": Palette.GOLD, "big": false})
		elif String(p.kind) in ["lore", "shrine"] and not bool(p.get_meta("done", false)):
			_labels.append({"pos": pn.global_position, "text": "", "glyph": "?", "color": p.color, "big": false})


func _draw_map() -> void:
	var s := _canvas.size
	var side := minf(s.x, s.y)
	var o := Vector2((s.x - side) * 0.5, (s.y - side) * 0.5)
	var box := Rect2(o, Vector2(side, side))
	_canvas.draw_rect(box.grow(4.0), Color(0.02, 0.0, 0.04, 0.9))
	if _tex:
		_canvas.draw_texture_rect(_tex, box, false)
	else:
		var t := "Keine Karte für diesen Ort"
		var ts := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		_canvas.draw_string(_font, box.get_center() - ts * 0.5, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.MUTED)
	_canvas.draw_rect(box.grow(4.0), Color(Palette.GOLD, 0.8), false, 2.0)
	var to_px := func(p: Vector3) -> Vector2:
		return o + Vector2((p.x - _rect.position.x) / _rect.size.x, (p.z - _rect.position.y) / _rect.size.y) * side
	# Beschriftungen (zuerst die Zeichen, darüber die Namen der großen Stellen)
	for l in _labels:
		var q: Vector2 = to_px.call(l.pos)
		if not box.has_point(q):
			continue
		var fs := 18 if l.big else 13
		var gs := _glyph_font.get_string_size(String(l.glyph), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var gp := q + Vector2(-gs.x * 0.5, fs * 0.36)
		_canvas.draw_string_outline(_glyph_font, gp, String(l.glyph), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		_canvas.draw_string(_glyph_font, gp, String(l.glyph), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, l.color)
	# Namen: große Stellen zuerst; je Name unter, über, rechts und links vom Zeichen probieren – überdeckt er einen
	# schon gesetzten Namen oder ragt aus der Karte, die nächste Lage, sonst entfällt er (das Zeichen bleibt)
	var used: Array[Rect2] = []
	var pp0: Vector2 = to_px.call((_world.player as Node3D).global_position)
	used.append(Rect2(pp0 - Vector2(48, 30), Vector2(96, 44)))      # „Ihr seid hier“ und der Pfeil
	var order := _labels.duplicate()
	order.sort_custom(func(a, b): return bool(a.big) and not bool(b.big))
	for l in order:
		if String(l.text) == "":
			continue
		var q2: Vector2 = to_px.call(l.pos)
		if not box.has_point(q2):
			continue
		var fs2 := 14 if l.big else 12
		var ts2 := _font.get_string_size(String(l.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var cands := [Vector2(q2.x - ts2.x * 0.5, q2.y + 12.0), Vector2(q2.x - ts2.x * 0.5, q2.y - ts2.y - 10.0),
			Vector2(q2.x + 12.0, q2.y - ts2.y * 0.5), Vector2(q2.x - ts2.x - 12.0, q2.y - ts2.y * 0.5)]
		for cand in cands:
			var rr := Rect2(cand, ts2).grow(2.0)
			if not box.encloses(rr):
				continue
			var clash := false
			for u in used:
				if u.intersects(rr):
					clash = true
					break
			if clash:
				continue
			used.append(rr)
			var lp := Vector2(cand.x, cand.y + ts2.y * 0.78)
			_canvas.draw_string_outline(_font, lp, String(l.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 5, Color(0, 0, 0, 0.9))
			_canvas.draw_string(_font, lp, String(l.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Palette.PARCHMENT)
			break
	# Spieler
	var pl: Node3D = _world.player
	var pp: Vector2 = to_px.call(pl.global_position)
	var h := -float(_world.player.cam_yaw)
	var f := Vector2(sin(h), -cos(h))
	var sd := Vector2(-f.y, f.x)
	var pts := PackedVector2Array([pp + f * 14.0, pp - f * 9.0 + sd * 9.0, pp - f * 4.0, pp - f * 9.0 - sd * 9.0])
	_canvas.draw_colored_polygon(pts, Palette.GOLD_BRIGHT)
	_canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.9), 2.0)
	var me := "Ihr seid hier"
	var ms := _font.get_string_size(me, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var mp := Vector2(clampf(pp.x - ms.x * 0.5, box.position.x + 2.0, box.end.x - ms.x - 2.0), pp.y - 18.0)
	_canvas.draw_string_outline(_font, mp, me, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color(0, 0, 0, 0.9))
	_canvas.draw_string(_font, mp, me, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.GOLD_BRIGHT)
	# Maßstab: 20 m
	var px20 := 20.0 / _rect.size.x * side
	var y0 := box.end.y - 16.0
	_canvas.draw_line(Vector2(box.position.x + 16.0, y0), Vector2(box.position.x + 16.0 + px20, y0), Palette.PARCHMENT, 3.0)
	_canvas.draw_string_outline(_font, Vector2(box.position.x + 16.0, y0 - 6.0), "20 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
	_canvas.draw_string(_font, Vector2(box.position.x + 16.0, y0 - 6.0), "20 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.PARCHMENT)

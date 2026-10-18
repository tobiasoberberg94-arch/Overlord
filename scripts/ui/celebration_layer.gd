class_name CelebrationLayer
extends Control
## Feier-Einblendungen für Rangaufstiege, Funde, Errungenschaften und Bauwerke.
## Liegt über allen Fenstern, blockiert keine Eingaben und arbeitet eine
## Warteschlange ab. Große Momente (legendäre Funde, Rang V+, Platin-Errungenschaften)
## bekommen Lichtstrahlen, Partikelregen und eine eigene Fanfare.

var _queue: Array = []
var _showing := false
var _rays := 0.0          ## 0…1 Deckkraft der Lichtstrahlen
var _ray_color := Palette.GOLD
var _t := 0.0
var _anchor := Vector2.ZERO
var _card: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	Progress.celebrate.connect(push)


func push(data: Dictionary) -> void:
	_queue.append(data)
	if not _showing:
		_next()


func _process(delta: float) -> void:
	_t += delta
	# Öffnet sich ein Fenster, weicht die Karte nach oben aus
	if is_instance_valid(_card) and _card.modulate.a > 0.9:
		var over := not get_tree().get_nodes_in_group("ui_overlay").is_empty()
		_card.position.y = move_toward(_card.position.y, 4.0 if over else 110.0, delta * 400.0)
		_card.scale = _card.scale.move_toward(Vector2.ONE * (0.82 if over else 1.0), delta * 1.5)
	if _rays > 0.01:
		queue_redraw()


func _draw() -> void:
	if _rays <= 0.01:
		return
	# Rotierende Lichtstrahlen hinter der Karte
	var n := 14
	var r := 520.0
	for i in n:
		var a := _t * 0.35 + TAU * i / n
		var w := 0.09
		var pts := PackedVector2Array([_anchor,
			_anchor + Vector2(cos(a - w), sin(a - w)) * r,
			_anchor + Vector2(cos(a + w), sin(a + w)) * r])
		draw_colored_polygon(pts, Color(_ray_color, 0.10 * _rays))
	for i in 3:
		draw_circle(_anchor, 90.0 + i * 50.0, Color(_ray_color, 0.06 * _rays))


func _is_big(d: Dictionary) -> bool:
	match d.get("kind", ""):
		"levelup":
			return true
		"loot":
			return d.get("rarity", "") in ["legendary", "world"]
		"achievement":
			return d.get("color", Color.WHITE) in [Palette.GOLD_BRIGHT, Color("b8f0ff")]
	return false


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var d: Dictionary = _queue.pop_front()
	var big := _is_big(d)
	var col: Color = d.get("color", Palette.GOLD_BRIGHT)
	match d.kind:
		"levelup": Audio.sfx("levelup", 0.9)
		"loot": Audio.sfx("loot_legendary" if big else "loot", 0.85)
		"achievement": Audio.sfx("achievement", 0.85)
		"build": Audio.sfx("build_done", 0.85)
		_: Audio.sfx("love", 0.7)

	var card := NzPanel.new(Vector4(20, 16, 26, 16), Color(0.03, 0.015, 0.05, 0.96), col.lerp(Palette.GOLD, 0.35))
	card.glow = 1.0 if big else 0.6
	card.custom_minimum_size = Vector2(560 if big else 480, 0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	card.add_child(hb)
	hb.add_child(_visual(d, big))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vb)
	var t := Label.new()
	t.text = "✦  %s  ✦" % d.get("title", "")
	t.theme_type_variation = "SubHeaderLabel"
	t.add_theme_color_override("font_color", col)
	t.add_theme_font_size_override("font_size", 16)
	vb.add_child(t)
	var main := Label.new()
	main.text = d.get("text", "")
	main.theme_type_variation = "TitleLabel"
	main.add_theme_font_size_override("font_size", 30 if big else 24)
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(main)
	if d.get("sub", "") != "":
		var s := Label.new()
		s.text = d.sub
		s.add_theme_color_override("font_color", Palette.PARCHMENT.darkened(0.15))
		s.add_theme_font_override("font", NazarickTheme.italic_font(600))
		s.add_theme_font_size_override("font_size", 18)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(s)
	add_child(card)
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	# Bei offenem Fenster ganz oben und etwas kleiner, damit Titel und Knöpfe frei bleiben
	var over := not get_tree().get_nodes_in_group("ui_overlay").is_empty()
	card.position = Vector2((size.x - card.size.x) / 2.0, 4.0 if over else 110.0)
	card.pivot_offset = Vector2(card.size.x / 2.0, 0.0 if over else card.size.y / 2.0)
	_anchor = card.position + card.size / 2.0
	_card = card
	_ray_color = col
	_burst(_anchor, col, big)

	card.modulate.a = 0.0
	card.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "scale", Vector2.ONE * (0.82 if over else 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if big:
		tw.tween_property(self, "_rays", 1.0, 0.4)
	await tw.finished
	var hold := (3.0 if big else 2.2) * (0.5 if _queue.size() >= 2 else 1.0)
	await get_tree().create_timer(hold).timeout
	if not is_instance_valid(card):
		return
	var out := create_tween().set_parallel(true)
	out.tween_property(card, "modulate:a", 0.0, 0.35)
	out.tween_property(card, "position:y", card.position.y - 30.0, 0.35)
	out.tween_property(self, "_rays", 0.0, 0.35)
	await out.finished
	card.queue_free()
	queue_redraw()
	_next()


func _visual(d: Dictionary, big: bool) -> Control:
	var sz := 110.0 if big else 84.0
	match d.kind:
		"levelup":
			var p := Portrait.new()
			p.char_id = d.get("char", "")
			p.custom_minimum_size = Vector2(sz * 0.8, sz)
			return p
		"loot":
			return ItemIcon.new(d.get("item", ""), sz)
	var l := Label.new()
	l.text = d.get("icon", "⚒" if d.kind == "build" else "★")
	l.custom_minimum_size = Vector2(sz, sz)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(sz * 0.6))
	l.add_theme_color_override("font_color", d.get("color", Palette.GOLD_BRIGHT))
	l.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.NIGHT, 0.9), d.get("color", Palette.GOLD), 2, int(sz / 2), Color(d.get("color", Palette.GOLD), 0.5), 14))
	return l


func _burst(at: Vector2, col: Color, big: bool) -> void:
	if not Settings.particles:
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = 90 if big else 40
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.6 if big else 1.1
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 420.0 if big else 280.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, col.lightened(0.4))
	g.set_color(1, Color(col, 0.0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)

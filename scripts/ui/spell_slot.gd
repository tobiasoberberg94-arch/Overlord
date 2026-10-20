class_name SpellSlot
extends Control
## Runder Zauber-Slot: Goldring, Glyphe in der Zauberfarbe, radialer Cooldown mit Restzeit,
## Tasten-Plakette, pulsierendes Leuchten bei Bereitschaft und Kurzblitz, wenn er wieder bereit ist.

var spell_id := ""
var icon := "?"
var key := ""
var color := Color.WHITE
var cooldown_max := 1.0
var cooldown := 0.0
var affordable := true
var _was_ready := true
var _flash := 0.0
var _t := 0.0
var _font: Font
var _glyph_font: Font
var _r := 27.0                 ## Radius (Superrang-Slot größer)
var _super := false
var rank := 1                  ## Rang im Zauberbuch (I–III), als Rauten über dem Slot


func _init(id: String, d: Dictionary, key_label: String, big: bool = false) -> void:
	_super = big
	_r = 34.0 if big else 27.0
	spell_id = id
	rank = int(d.get("rank", 1))
	if id == "":
		# unbelegte Taste
		icon = "+"
		key = key_label
		color = Color(0.45, 0.42, 0.55)
		custom_minimum_size = Vector2(64, 76)
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = "Taste %s ist frei – im Zauberbuch [B] einen Zauber darauf legen." % key_label
		_font = NazarickTheme.display_font(700)
		_glyph_font = NazarickTheme.body_font(700)
		affordable = false
		return
	icon = d.get("icon", "?")
	key = key_label
	color = Color(d.get("color", "#ffffff"))
	cooldown_max = maxf(0.1, float(d.get("cooldown", 1.0)))
	custom_minimum_size = Vector2(80, 92) if big else Vector2(64, 76)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "%s [%s]%s\n%s\nKosten: %d %s · Abklingzeit %.0f s" % [d.get("name", id), key_label, ("  · Rang " + ["I", "II", "III"][clampi(rank, 1, 3) - 1]) if rank > 1 else "", d.get("desc", ""), int(d.get("cost", 0)),
		"Mana" if d.get("cost_type", "mana") == "mana" else "Ausdauer", float(d.get("cooldown", 0))]
	_font = NazarickTheme.display_font(700)
	_glyph_font = NazarickTheme.body_font(700)


func update(cd: float, can_pay: bool) -> void:
	cooldown = cd
	affordable = can_pay
	var ready := cd <= 0.0 and can_pay
	if ready and not _was_ready:
		_flash = 1.0
	_was_ready = ready


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, _r + 5.0)
	var r := _r
	if spell_id == "":
		# leere Taste: gedämpfter Ring mit Plus
		draw_circle(c, r, Color(0.02, 0.01, 0.035, 0.55))
		draw_arc(c, r, 0, TAU, 48, Color(Palette.GOLD_DARK, 0.5), 2.0, true)
		draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(0.6, 0.55, 0.7, 0.6), 2.0)
		draw_line(c + Vector2(0, -7), c + Vector2(0, 7), Color(0.6, 0.55, 0.7, 0.6), 2.0)
		var kp0 := Rect2(c + Vector2(-11, r - 4), Vector2(22, 17))
		draw_style_box(NazarickTheme.box(Color(0.03, 0.02, 0.05, 0.8), Color(Palette.GOLD, 0.5), 1, 4, Color.TRANSPARENT, 0, 0), kp0)
		var ks0 := _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(_font, kp0.position + Vector2((kp0.size.x - ks0.x) * 0.5, 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Palette.GOLD_BRIGHT, 0.5))
		return
	var ready := cooldown <= 0.0 and affordable
	# Leuchten
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	if ready:
		for i in 4:
			draw_circle(c, r + 3.0 + i * 2.5, Color(color, (0.07 + 0.04 * pulse) * (1.0 - i * 0.22)))
	if _flash > 0.0:
		draw_circle(c, r + 6.0 + (1.0 - _flash) * 10.0, Color(color.lightened(0.5), 0.45 * _flash))
	if _super and ready:
		for i in 12:
			var a := TAU * i / 12.0 + _t * 0.4
			draw_line(c + Vector2(cos(a), sin(a)) * (r + 4.0), c + Vector2(cos(a), sin(a)) * (r + 9.0 + 3.0 * pulse), Color(Palette.GOLD_BRIGHT, 0.55), 2.0, true)
	# Scheibe mit radialem Verlauf
	draw_circle(c, r, Color(0.02, 0.01, 0.035, 0.92))
	for i in 5:
		draw_circle(c + Vector2(0, -r * 0.18), r * (0.85 - i * 0.15), Color(color.darkened(0.55), 0.10))
	# Glyphe
	var fs := 34 if _super else 28
	var gcol := color.lightened(0.15) if ready else (Color(0.45, 0.55, 0.9) if not affordable else Color(0.55, 0.52, 0.6))
	var gs := _glyph_font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var gp := c + Vector2(-gs.x * 0.5, fs * 0.36)
	draw_string_outline(_glyph_font, gp, icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8))
	draw_string(_glyph_font, gp, icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gcol)
	# Cooldown-Tortenstück
	if cooldown > 0.0:
		var frac := clampf(cooldown / cooldown_max, 0.0, 1.0)
		var pts := PackedVector2Array([c])
		var steps := maxi(3, int(48 * frac))
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * (1.0 - frac) + TAU * frac * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
		var a0 := -PI * 0.5 + TAU * (1.0 - frac)
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * (r - 1.0), Color(color, 0.8), 1.5)
		var txt := ("%.1f" % cooldown) if cooldown < 3.0 else str(int(ceilf(cooldown)))
		var ts := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var tp := c + Vector2(-ts.x * 0.5, 7)
		draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
		draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.PARCHMENT)
	# Ringe
	draw_arc(c, r, 0, TAU, 64, Palette.GOLD_DARK, 3.0, true)
	draw_arc(c, r - 0.5, PI * 1.05, PI * 1.95, 32, Color(Palette.GOLD_BRIGHT, 0.85), 1.5, true)
	if ready:
		draw_arc(c, r + 2.5, 0, TAU, 64, Color(color, 0.55 + 0.3 * pulse), 1.5, true)
	elif not affordable:
		draw_arc(c, r + 2.5, 0, TAU, 64, Color(0.35, 0.5, 1.0, 0.6), 1.5, true)
	# Rang-Rauten (Zauberbuch)
	if rank > 1:
		for i in rank:
			var dc := c + Vector2((i - (rank - 1) * 0.5) * 9.0, -r - 1.0)
			var dia := PackedVector2Array([dc + Vector2(0, -4), dc + Vector2(3.5, 0), dc + Vector2(0, 4), dc + Vector2(-3.5, 0)])
			draw_colored_polygon(dia, Palette.GOLD_BRIGHT if rank >= 3 else Palette.GOLD)
			draw_polyline(dia + PackedVector2Array([dia[0]]), Color(0, 0, 0, 0.7), 1.0)
	# Tasten-Plakette
	var kp := Rect2(c + Vector2(-11, r - 4), Vector2(22, 17))
	draw_style_box(NazarickTheme.box(Color(0.03, 0.02, 0.05, 0.95), Palette.GOLD, 1, 4, Color.TRANSPARENT, 0, 0), kp)
	var ks := _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(_font, kp.position + Vector2((kp.size.x - ks.x) * 0.5, 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.GOLD_BRIGHT)

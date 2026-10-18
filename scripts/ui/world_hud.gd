class_name WorldHud
extends Control
## HUD der 3D-Welt im Stil „Obsidian & Gold“ (siehe docs/KONZEPT_UI_UND_GEGNER.md):
##   oben Mitte  Kompassband mit Gate/Figuren/Gegnern, darunter Zielrahmen beim Lock-on
##   oben links  Ort + Datum (klein) mit Tagesfortschritt, darunter Meldungen, die verblassen
##   oben rechts Ressourcen + Depeschen-Hinweis, darunter Auftrags-Tracker (max. 3 Zeilen)
##   Tab         Wochenziele & Herzenskrieg
##   unten links Medaillon + Leben/Mana/Ausdauer, unten Mitte Zauberleiste
##   F1 / H      Steuerungshilfe (beim ersten Start sichtbar)
## Während ein Fenster offen ist, blendet das HUD aus.

var world: Node            ## world_3d.gd
var compass := HudCompass.new()
var loc_label := Label.new()
var date_label := Label.new()
var day_line := HudBar.new(Palette.GOLD, 3.0, 230.0)
var feed := VBoxContainer.new()
var res_row := HBoxContainer.new()
var res_labels: Dictionary = {}
var dispatch_badge := NzPanel.new(Vector4(12, 4, 12, 4), Color(0.16, 0.0, 0.03, 0.9), Palette.CRIMSON, false, 6.0)
var dispatch_label := Label.new()
var tracker := VBoxContainer.new()
var tracker_text := RichTextLabel.new()
var goals_panel := NzPanel.new(Vector4(16, 12, 16, 12))
var goals_text := RichTextLabel.new()
var rivalry := RivalryMeter.new()
var help_panel := NzPanel.new(Vector4(16, 12, 16, 12), Color(0.035, 0.02, 0.06, 0.8))
var help_text := RichTextLabel.new()
var prompt := NzPanel.new(Vector4(10, 6, 18, 6), Color(0.035, 0.02, 0.06, 0.9))
var prompt_key := Label.new()
var prompt_text := Label.new()
var target := VBoxContainer.new()
var target_name := Label.new()
var target_bar := HudBar.new(Palette.CRIMSON, 12.0, 400.0)
var target_info := Label.new()
var medallion := TextureRect.new()
var style_label := Label.new()
var state_label := Label.new()
var bars: Dictionary = {}
var spell_row := HBoxContainer.new()
var slots: Array[SpellSlot] = []
var toast_box := VBoxContainer.new()
var _portrait_id := ""
var _fade := 1.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(w: Node) -> void:
	world = w
	_build_top()
	_build_right()
	_build_bottom()
	_build_misc()
	Game.log_added.connect(_on_log)
	Quests.changed.connect(refresh)


# ------------------------------------------------------------------ Aufbau

func _outlined(l: Label, size_px: int, col: Color, font: Font = null, outline: int = 5) -> Label:
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rich(r: RichTextLabel, fs: int) -> RichTextLabel:
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_constant_override("outline_size", 5)
	r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return r


func _build_top() -> void:
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.offset_left = -310
	compass.offset_right = 310
	compass.offset_top = 8
	compass.offset_bottom = 52
	add_child(compass)
	# Zielrahmen
	target.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	target.offset_left = -200
	target.offset_right = 200
	target.offset_top = 80
	target.add_theme_constant_override("separation", 2)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outlined(target_name, 19, Palette.PARCHMENT, NazarickTheme.display_font(700), 6)
	target_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outlined(target_info, 14, Palette.MUTED, NazarickTheme.italic_font(600))
	target_bar.ticks = 50.0
	target.add_child(target_name)
	target.add_child(target_bar)
	target.add_child(target_info)
	target.visible = false
	add_child(target)
	# Ort und Datum
	var lv := VBoxContainer.new()
	lv.position = Vector2(22, 14)
	lv.add_theme_constant_override("separation", 0)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(loc_label, 17, Palette.GOLD_BRIGHT, NazarickTheme.display_font(700), 6)
	_outlined(date_label, 15, Palette.PARCHMENT.darkened(0.15), NazarickTheme.italic_font(600))
	day_line.show_text = false
	day_line.tooltip_text = "Fortschritt des aktuellen Tages"
	lv.add_child(loc_label)
	lv.add_child(date_label)
	var sp := Control.new()
	sp.custom_minimum_size.y = 5
	lv.add_child(sp)
	lv.add_child(day_line)
	add_child(lv)
	# Meldungen
	feed.position = Vector2(22, 96)
	feed.custom_minimum_size.x = 560
	feed.add_theme_constant_override("separation", 2)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed)


func _build_right() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.offset_left = -420
	col.offset_right = -20
	col.offset_top = 12
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	res_row.alignment = BoxContainer.ALIGNMENT_END
	res_row.add_theme_constant_override("separation", 14)
	res_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in Game.RESOURCE_KEYS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		hb.mouse_filter = Control.MOUSE_FILTER_PASS
		hb.tooltip_text = str(Game.RESOURCE_LABELS.get(k, k))
		var ic := _outlined(Label.new(), 17, Palette.RESOURCE_COLORS[k].lightened(0.1), NazarickTheme.body_font(700))
		ic.text = Palette.RESOURCE_ICONS[k]
		hb.add_child(ic)
		var l := _outlined(Label.new(), 16, Palette.RESOURCE_COLORS[k].lerp(Palette.PARCHMENT, 0.35), NazarickTheme.display_font(700))
		hb.add_child(l)
		res_labels[k] = l
		res_row.add_child(hb)
	col.add_child(res_row)
	dispatch_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	_outlined(dispatch_label, 15, Color("ffd0d6"), NazarickTheme.display_font(700))
	dispatch_badge.add_child(dispatch_label)
	dispatch_badge.visible = false
	col.add_child(dispatch_badge)
	# Tracker
	tracker.add_theme_constant_override("separation", 2)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := _outlined(Label.new(), 14, Palette.GOLD, NazarickTheme.display_font(700))
	th.text = "⚜  ZIELE"
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tracker.add_child(th)
	_rich(tracker_text, 16)
	tracker.add_child(tracker_text)
	var hint := _outlined(Label.new(), 13, Palette.MUTED, NazarickTheme.italic_font(600))
	hint.text = "[J] Questbuch · [Tab] Wochenziele"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tracker.add_child(hint)
	col.add_child(tracker)
	# Ausklappbares Ziele-Panel
	goals_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	goals_panel.offset_left = -440
	goals_panel.offset_right = -20
	goals_panel.offset_top = -150
	goals_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 8)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich(goals_text, 15)
	gv.add_child(goals_text)
	gv.add_child(HSeparator.new())
	rivalry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(rivalry)
	goals_panel.add_child(gv)
	goals_panel.visible = false
	add_child(goals_panel)


func _build_bottom() -> void:
	# Spieler-Rahmen unten links
	var frame := HBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	frame.offset_left = 18
	frame.offset_top = -128
	frame.offset_bottom = -18
	frame.add_theme_constant_override("separation", 10)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var mm := ShaderMaterial.new()
	mm.shader = preload("res://assets/shaders/ui_medallion.gdshader")
	medallion.material = mm
	medallion.custom_minimum_size = Vector2(96, 96)
	medallion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medallion.stretch_mode = TextureRect.STRETCH_SCALE
	medallion.size_flags_vertical = Control.SIZE_SHRINK_END
	medallion.texture = _blank_tex()
	frame.add_child(medallion)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 5)
	bv.alignment = BoxContainer.ALIGNMENT_END
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bv)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(style_label, 18, Palette.GOLD_BRIGHT, NazarickTheme.display_font(700), 6)
	_outlined(state_label, 15, Palette.MUTED, NazarickTheme.italic_font(600))
	nh.add_child(style_label)
	nh.add_child(state_label)
	bv.add_child(nh)
	for spec in [["hp", Color(0.78, 0.08, 0.16), 18.0, 330.0], ["mana", Color(0.28, 0.45, 1.0), 12.0, 290.0], ["stamina", Color(0.9, 0.72, 0.25), 8.0, 250.0]]:
		var b := HudBar.new(spec[1], spec[2], spec[3])
		b.show_text = spec[0] != "stamina"
		if spec[0] == "hp":
			b.ticks = 100.0
		bars[spec[0]] = b
		bv.add_child(b)
	# Zauberleiste unten Mitte
	spell_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	spell_row.offset_top = -92
	spell_row.offset_bottom = -12
	spell_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	spell_row.add_theme_constant_override("separation", 6)
	spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spell_row)


func _build_misc() -> void:
	# Interaktionshinweis
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -170
	prompt.offset_bottom = -128
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(prompt_key, 17, Palette.GOLD_BRIGHT, NazarickTheme.display_font(800), 0)
	prompt_key.text = "E"
	prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_key.custom_minimum_size = Vector2(30, 30)
	prompt_key.add_theme_stylebox_override("normal", NazarickTheme.box(Color(0.1, 0.06, 0.02), Palette.GOLD, 1, 5, Color(Palette.GOLD, 0.35), 5, 0))
	_outlined(prompt_text, 19, Palette.PARCHMENT, NazarickTheme.body_font(700))
	ph.add_child(prompt_key)
	ph.add_child(prompt_text)
	prompt.add_child(ph)
	prompt.visible = false
	add_child(prompt)
	# Steuerungshilfe
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	help_panel.offset_left = -380
	help_panel.offset_right = -20
	help_panel.offset_bottom = -20
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_rich(help_text, 15)
	help_text.custom_minimum_size.x = 340
	help_text.text = "[color=#d4af37][b]STEUERUNG[/b][/color]  [color=#8f86a3][i]F1 ein/aus[/i][/color]\n" + \
		"[color=#f5d77a]WASD[/color] gehen · [color=#f5d77a]Shift[/color] rennen · Maus Kamera\n" + \
		"[color=#ff9a8a]LMB[/color] leicht · [color=#ff9a8a]RMB[/color] schwer · [color=#f5d77a]Leertaste[/color] Rolle\n" + \
		"[color=#f5d77a]F[/color] Block/Parade · [color=#f5d77a]Q[/color] Ziel · [color=#f5d77a]1–4, R[/color] Zauber · [color=#f5d77a]X[/color] Momon\n" + \
		"[color=#f5d77a]E[/color] benutzen · [color=#f5d77a]G[/color] Gate · [color=#f5d77a]T[/color] Zeit · [color=#f5d77a]Enter[/color] Depesche\n" + \
		"[color=#f5d77a]J[/color] Questbuch · [color=#f5d77a]K[/color] Entsendungen · [color=#f5d77a]M[/color] Karte · [color=#f5d77a]P[/color] Diplomatie · [color=#f5d77a]C[/color] Chronik\n" + \
		"[color=#f5d77a]V[/color] Verwaltung · [color=#f5d77a]N[/color] Nazarick · [color=#f5d77a]U[/color] Wächter · [color=#f5d77a]Esc[/color] Menü"
	help_panel.add_child(help_text)
	help_panel.visible = Settings.show_help
	add_child(help_panel)
	# Toasts
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.offset_top = 118
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _blank_tex() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ Inhalte

func set_location(name_text: String) -> void:
	loc_label.text = name_text.to_upper()


func refresh() -> void:
	var s := Game.state
	date_label.text = "Tag %d · %s · Kapitel %s" % [s.day, Game.format_date(s.day), Content.chapter(s.chapter).numeral]
	for k in res_labels:
		(res_labels[k] as Label).text = str(int(s.resources.get(k, 0)))
	var pend := Game.pending().size()
	dispatch_badge.visible = pend > 0
	dispatch_label.text = "✉  %d Depesche%s  [Enter]" % [pend, "n" if pend != 1 else ""]
	# Tracker: Kapitelziel, Bedrohungen, ein offenes Wochenziel
	var lines := PackedStringArray()
	var tq: Dictionary = Quests.by_id.get(Quests.tracked, {})
	if not tq.is_empty() and Quests.is_active(tq.id):
		lines.append("[color=#f5d77a][b]%s[/b][/color]  ◉" % tq.title)
		lines.append("[color=#ebe2cc]%s[/color]" % Quests.step_text(tq))
	for o in Game.objectives():
		if lines.size() >= 3:
			break
		if not o[1]:
			lines.append("[color=#c79bff]%s[/color]  ⚜" % o[0])
			break
	for t in s.get("threats", []):
		if lines.size() >= 3:
			break
		lines.append("[color=#ff6a78]%s – noch %d T.[/color]  ⚠" % [Game.mission(t.mission_id).get("title", "Bedrohung"), World.threat_days_left(t)])
	var p := Progress.ps()
	for g in p.goals:
		if lines.size() >= 3:
			break
		if not Progress.goal_done(g):
			lines.append("%s [color=#8f86a3](%d/%d)[/color]  ◇" % [g.text, mini(Progress.goal_value(g), int(g.target)), int(g.target)])
			break
	tracker_text.text = "[right]%s[/right]" % "\n".join(lines)
	# Ausgeklapptes Panel
	var gl := PackedStringArray()
	gl.append("[color=#d4af37][b]❤ WOCHENZIELE[/b][/color]  [color=#8f86a3]noch %d Tage[/color]" % Progress.week_days_left())
	for g in p.goals:
		var done := Progress.goal_done(g)
		gl.append("[color=%s]%s %s (%d/%d)[/color]" % ["#6fdc8c" if done else "#ebe2cc", "✔" if done else "◇", g.text, mini(Progress.goal_value(g), int(g.target)), int(g.target)])
	var objs := Game.objectives()
	if not objs.is_empty():
		gl.append("")
		gl.append("[color=#d4af37][b]⚜ KAPITEL[/b][/color]")
		for o in objs:
			gl.append("[color=%s]%s %s[/color]" % ["#6fdc8c" if o[1] else "#c79bff", "✔" if o[1] else "◇", o[0]])
	goals_text.text = "\n".join(gl)
	rivalry.refresh()


func _on_log(e: Dictionary) -> void:
	var l := RichTextLabel.new()
	_rich(l, 15)
	l.custom_minimum_size.x = 560
	l.text = "[color=%s]%s[/color]" % [Palette.LOG_COLORS.get(e.get("cat", "info"), "#b7aecb"), e.get("text", "")]
	feed.add_child(l)
	while feed.get_child_count() > 5:
		feed.get_child(0).free()
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.3)
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)


func toast(text: String, color: Color = Palette.GOLD_BRIGHT) -> void:
	var p := NzPanel.new(Vector4(18, 8, 18, 8), Color(0.035, 0.02, 0.06, 0.94), color.lerp(Palette.GOLD, 0.5), true, 6.0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	_outlined(l, 18, color, NazarickTheme.body_font(700), 4)
	p.add_child(l)
	toast_box.add_child(p)
	p.glow = 0.6
	UIFx.pop_in(p, 0.25)
	var tw := p.create_tween()
	tw.tween_property(p, "glow", 0.0, 0.8)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	Settings.set_value("show_help", help_panel.visible)


func toggle_goals() -> void:
	goals_panel.visible = not goals_panel.visible
	if goals_panel.visible:
		UIFx.pop_in(goals_panel, 0.2)


func set_prompt(text: String) -> void:
	prompt.visible = text != ""
	prompt_text.text = text


func rebuild_spells(player: Node) -> void:
	for c in spell_row.get_children():
		c.queue_free()
	slots.clear()
	var keys := ["1", "2", "3", "4", "R"]
	var sp: Array = player.spells()
	for i in sp.size():
		var s := SpellSlot.new(sp[i], Content.combat.spells[sp[i]], keys[i])
		spell_row.add_child(s)
		slots.append(s)


# ------------------------------------------------------------------ pro Bild

func tick(delta: float, blocked: bool) -> void:
	var p: Node = world.player
	# Ausblenden unter Fenstern
	_fade = move_toward(_fade, 0.0 if blocked else 1.0, delta * 6.0)
	modulate.a = _fade
	visible = _fade > 0.01
	toast_box.offset_top = lerpf(12.0, 118.0, _fade)
	# Kompass
	compass.heading = -float(p.cam_yaw)
	compass.origin = p.global_position
	compass.markers = _markers()
	compass.queue_redraw()
	# Werte
	bars.hp.set_values(p.hp, p.max_hp)
	bars.mana.set_values(p.mana, p.max_mana)
	bars.stamina.set_values(maxf(0.0, p.stamina), p.max_stamina)
	bars.mana.visible = p.max_mana > 0.0
	style_label.text = p.display_name.to_upper()
	var st: String = Fighter.STATE_NAMES[p.state]
	if p.shield_time > 0.0:
		st += "  ·  ⛨ Barriere %.0f s" % p.shield_time
	state_label.text = st
	var pid: String = String(p.style_data.get("model", "ainz_momon" if String(p.style) == "momon" else "ainz"))
	if pid != _portrait_id:
		var tex := PortraitStudio.get_texture(pid)
		if tex:
			medallion.texture = tex
			_portrait_id = pid
	for s in slots:
		var sd: Dictionary = Content.combat.spells[s.spell_id]
		var pool: float = p.mana if sd.get("cost_type", "mana") == "mana" else p.stamina
		s.update(float(p.cooldowns.get(s.spell_id, 0.0)), pool >= float(sd.get("cost", 0)))
	# Ziel
	var lk = p.lock
	if lk != null and is_instance_valid(lk) and lk.state != Fighter.S.DEAD:
		target.visible = true
		var elite: bool = lk.get("data") is Dictionary and lk.data.get("elite", false)
		target_name.text = ("◆ " if elite else "") + lk.display_name
		target_name.add_theme_color_override("font_color", Palette.GOLD_BRIGHT if elite else Color(1, 0.72, 0.7))
		target_bar.set_values(lk.hp, lk.max_hp)
		target_info.text = Fighter.STATE_NAMES[lk.state] + ("  ·  Elite" if elite else "")
	else:
		target.visible = false


func _markers() -> Array:
	var out: Array = []
	var a: Dictionary = world.anchors
	if a.has("gate"):
		out.append({"pos": a.gate, "glyph": "◈", "color": Palette.VIOLET_GLOW.lightened(0.2), "label": "Gate", "big": true})
	for act in world.actors:
		if not is_instance_valid(act):
			continue
		var mk := Quests.marker_for(act.id) if act.kind != "object" else ""
		if mk == "!" or mk == "?":
			out.append({"pos": act.global_position, "glyph": mk, "color": Palette.GOLD_BRIGHT if mk == "!" else Color(0.55, 1.0, 0.6), "label": act.label, "big": true})
			continue
		var col: Color = Palette.GOLD_BRIGHT if act.kind == "char" else (Palette.PARCHMENT if act.kind == "npc" else Color("7fd8ff"))
		out.append({"pos": act.global_position, "glyph": "◆" if act.kind == "char" else ("●" if act.kind == "npc" else "▲"), "color": col, "label": act.label})
	# gesuchte Sammelobjekte und Truhen
	var wanted := {}
	for q in Quests.active():
		var st: Dictionary = Quests.step(q)
		if String(st.get("type", "")) == "collect":
			wanted[st.item] = true
	for p in world.quest_world.pickups:
		if not is_instance_valid(p) or p.global_position.distance_to(world.player.global_position) > 60.0:
			continue
		var dpl: float = p.global_position.distance_to(world.player.global_position)
		if p.kind in ["lore", "shrine"] and not bool(p.get_meta("done", false)) and dpl < 55.0:
			out.append({"pos": p.global_position, "glyph": "?", "color": p.color, "label": "Unentdeckt", "big": true})
		elif p.kind == "cache" and dpl < 14.0:
			out.append({"pos": p.global_position, "glyph": "?", "color": Palette.GOLD, "label": "Etwas glitzert"})
		elif p.kind == "chest":
			out.append({"pos": p.global_position, "glyph": "▣", "color": Palette.GOLD, "label": "Truhe"})
		elif not p.entries.is_empty() and wanted.has(p.entries[0][0]):
			out.append({"pos": p.global_position, "glyph": "◆", "color": p.color, "label": p.label})
	for e in world.enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD and e.global_position.distance_to(world.player.global_position) < 45.0:
			out.append({"pos": e.global_position, "glyph": "✕", "color": Palette.CRIMSON, "label": e.display_name})
	return out

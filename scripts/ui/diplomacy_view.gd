class_name DiplomacyView
extends Overlay
## Diplomatie: Fraktionen der Neuen Welt, Beziehung, Furcht, Verträge –
## und Gesandtschaften, die ein Wächter ausführt.

var list := VBoxContainer.new()
var detail := VBoxContainer.new()
var feedback := RichTextLabel.new()
var envoy_opt := OptionButton.new()
var _fid := ""
var _envoy := ""


func _init() -> void:
	super._init(Vector2(1500, 840))
	content.add_child(make_header("Diplomatie der Neuen Welt", "Wer Euch fürchtet, gehorcht. Wer Euch liebt, dient freiwillig. Beides hat seinen Preis."))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.x = 430
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	row.add_child(sc)
	var dsc := ScrollContainer.new()
	dsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	dsc.add_child(detail)
	row.add_child(dsc)
	envoy_opt.item_selected.connect(func(i): _envoy = envoy_opt.get_item_metadata(i); _build_detail())
	var known := Diplomacy.known_factions()
	if not known.is_empty():
		_fid = known[0].id
	_refresh()


func _refresh() -> void:
	_build_list()
	_build_detail()


func _build_list() -> void:
	for c in list.get_children():
		c.queue_free()
	var known := Diplomacy.known_factions()
	if known.is_empty():
		var l := Label.new()
		l.text = "Noch ist Nazarick keiner Macht der Neuen Welt begegnet.\nErkundet die Welt, um Fraktionen kennenzulernen."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(l)
		return
	for f in known:
		var st := Diplomacy.fs(f.id)
		var stance := Diplomacy.stance(f.id)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = f.id == _fid
		b.theme_type_variation = "ButtonCard"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 84
		var treaties := PackedStringArray()
		for t in st.treaties:
			treaties.append(Diplomacy.treaty_label(t))
		b.text = "%s  %s\n%s  ·  Beziehung %+d  ·  Furcht %d\n%s" % [f.symbol, f.name, stance[0], st.relation, st.fear,
			", ".join(treaties) if not treaties.is_empty() else "keine Verträge"]
		b.add_theme_color_override("font_color", Color(stance[1]).lerp(Palette.PARCHMENT, 0.35))
		b.pressed.connect(func(): _fid = f.id; _refresh())
		list.add_child(b)


func _build_detail() -> void:
	for c in detail.get_children():
		if c != feedback:
			c.queue_free()
	if envoy_opt.get_parent():
		envoy_opt.get_parent().remove_child(envoy_opt)
	if _fid == "":
		return
	var f := Diplomacy.faction(_fid)
	var st := Diplomacy.fs(_fid)
	var stance := Diplomacy.stance(_fid)
	var tex: Texture2D = Content.find_image("backgrounds", f.get("image", ""))
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size.y = 120
		tr.clip_contents = true
		detail.add_child(tr)
	var title := Label.new()
	title.text = "%s  %s" % [f.symbol, f.name]
	title.theme_type_variation = "HeaderLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(f.color))
	detail.add_child(title)
	detail.add_child(_rich("[color=#d4af37]Herrscher:[/color] %s     [color=#d4af37]Haltung:[/color] [color=%s][b]%s[/b][/color]     [color=#d4af37]Militärmacht:[/color] %d" % [f.ruler, stance[1], stance[0], int(f.power)]))
	detail.add_child(_rich("[color=#b7aecb]%s[/color]\n[color=#8f86a3][i]%s[/i][/color]" % [f.desc, f.attitude]))
	var rb := StatBar.new("Beziehung", Color(stance[1]), "", 110)
	rb.set_value(float(st.relation + 100), 200.0, "%+d" % st.relation)
	detail.add_child(rb)
	var fb := StatBar.new("Furcht", Palette.CRIMSON, "", 110)
	fb.set_value(float(st.fear))
	detail.add_child(fb)
	var treaties := PackedStringArray()
	for t in st.treaties:
		treaties.append(Diplomacy.treaty_label(t))
	var regions := PackedStringArray()
	for rid in f.regions:
		if World.rs(rid).discovered:
			regions.append("%s (Einfluss %d)" % [World.region(rid).short, World.rs(rid).influence])
	detail.add_child(_rich("[color=#d4af37]Verträge:[/color] %s\n[color=#d4af37]Gebiete:[/color] %s\n[color=#d4af37]Handel:[/color] %d Gold/Tag bei Abkommen · [color=#d4af37]Tribut:[/color] %d Gold" % [
		", ".join(treaties) if not treaties.is_empty() else "keine", ", ".join(regions) if not regions.is_empty() else "–", int(f.trade), int(f.tribute)]))
	detail.add_child(HSeparator.new())

	# Gesandter
	var erow := HBoxContainer.new()
	var el := Label.new()
	el.text = "Gesandter:"
	el.custom_minimum_size.x = 110
	erow.add_child(el)
	envoy_opt.clear()
	envoy_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := 0
	var found := false
	for cid in Game.unlocked_chars():
		if not Game.is_available(cid):
			continue
		var dip := int(Content.char_data(cid).stats.diplomatie)
		envoy_opt.add_item("%s  (Diplomatie %d)" % [Game.char_name(cid).split(" ")[0], dip])
		envoy_opt.set_item_metadata(idx, cid)
		if cid == _envoy:
			envoy_opt.select(idx)
			found = true
		idx += 1
	if not found:
		_envoy = envoy_opt.get_item_metadata(0) if idx > 0 else ""
		if idx > 0:
			envoy_opt.select(0)
	erow.add_child(envoy_opt)
	detail.add_child(erow)
	if _envoy in ["shalltear", "narberal"]:
		detail.add_child(_rich("[color=#ff9a3c]⚠ %s ist keine geborene Diplomatin. Ein Fehlschlag könnte … Narben hinterlassen.[/color]" % Game.char_name(_envoy).split(" ")[0]))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	detail.add_child(grid)
	for a in Diplomacy.data.actions:
		var ok: Array = Diplomacy.can_do(_fid, a.id)
		var b := Button.new()
		var cost := " · %d Gold" % int(a.cost) if int(a.get("cost", 0)) > 0 else ""
		var days := " · %d T." % int(a.days) if not a.get("instant", false) else ""
		b.text = "%s %s%s%s\n%s" % [a.icon, a.name, cost, days, a.desc if ok[0] else "✗ " + ok[1]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 86)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = "ButtonDanger" if a.id == "war" else "ButtonCard"
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = not ok[0] or (_envoy == "" and not a.get("instant", false))
		b.pressed.connect(func():
			var res := Diplomacy.start_action(_fid, a.id, _envoy)
			Audio.sfx("order" if res.ok else "rebuke", 0.7)
			feedback.text = ("[color=#6fdc8c]%s[/color]" if res.ok else "[color=#ff7a7a]%s[/color]") % res.text
			_refresh())
		grid.add_child(b)
	feedback.bbcode_enabled = true
	feedback.fit_content = true
	feedback.scroll_active = false
	if feedback.get_parent():
		feedback.get_parent().remove_child(feedback)
	detail.add_child(feedback)


func _rich(t: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 17)
	r.text = t
	return r

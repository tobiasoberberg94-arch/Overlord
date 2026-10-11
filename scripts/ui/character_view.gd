class_name CharacterView
extends Overlay
## Detailansicht der Untertanen: großes Portrait, Profil, Werte, Gefühle,
## Taten – und persönliche Audienzen (Gespräch, Geschenk, Zurechtweisung).

signal changed

var tabs := VBoxContainer.new()
var portrait := Portrait.new()
var name_label := Label.new()
var title_label := Label.new()
var quote_label := Label.new()
var bio := RichTextLabel.new()
var stats_box := VBoxContainer.new()
var feelings_box := VBoxContainer.new()
var deeds := RichTextLabel.new()
var reaction := RichTextLabel.new()
var audience_info := Label.new()
var buttons: Dictionary = {}
var _cid := ""


func _init(start_cid: String = "albedo") -> void:
	super._init(Vector2(1480, 820))
	content.add_child(make_header("Die Untertanen von Nazarick", "Floor Guardians, Butler und Pleiaden – loyal bis in den Tod, und doch mit eigenem Willen."))
	content.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)

	# Reiter mit Mini-Portraits
	var tscroll := ScrollContainer.new()
	tscroll.custom_minimum_size = Vector2(200, 0)
	tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 6)
	tscroll.add_child(tabs)
	row.add_child(tscroll)
	var group := ButtonGroup.new()
	for cid in Game.unlocked_chars():
		var c := Game.cs(cid)
		var b := PortraitButton.new(cid, Content.char_data(cid).name.split(" ")[0], Game.STATUS_LABELS.get(c.status, ""), Vector2(40, 48))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = cid == start_cid
		b.pressed.connect(_show.bind(cid))
		tabs.add_child(b)

	# Portrait-Spalte
	var pcol := VBoxContainer.new()
	pcol.custom_minimum_size.x = 340
	pcol.add_theme_constant_override("separation", 6)
	row.add_child(pcol)
	portrait.custom_minimum_size = Vector2(340, 470)
	pcol.add_child(portrait)
	name_label.theme_type_variation = "TitleLabel"
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(name_label)
	title_label.theme_type_variation = "MutedLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(title_label)
	quote_label.add_theme_font_override("font", NazarickTheme.italic_font(600))
	quote_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pcol.add_child(quote_label)

	# Info-Spalte
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)
	bio.bbcode_enabled = true
	bio.fit_content = true
	bio.scroll_active = false
	bio.add_theme_font_size_override("normal_font_size", 18)
	info.add_child(bio)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	info.add_child(cols)
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feelings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(stats_box)
	cols.add_child(feelings_box)
	var dl := Label.new()
	dl.text = "TATEN & CHRONIK"
	dl.theme_type_variation = "SubHeaderLabel"
	dl.add_theme_color_override("font_color", Palette.GOLD)
	info.add_child(dl)
	deeds.bbcode_enabled = true
	deeds.custom_minimum_size.y = 90
	deeds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deeds.add_theme_font_size_override("normal_font_size", 16)
	info.add_child(deeds)

	# Audienz-Leiste
	var aud := PanelContainer.new()
	aud.theme_type_variation = "PanelDim"
	info.add_child(aud)
	var avb := VBoxContainer.new()
	aud.add_child(avb)
	var abar := HBoxContainer.new()
	abar.add_theme_constant_override("separation", 10)
	avb.add_child(abar)
	audience_info.theme_type_variation = "MutedLabel"
	audience_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abar.add_child(audience_info)
	for spec in [["talk", "Audienz gewähren", "ButtonPrimary"], ["gift", "Geschenk (−60 Gold)", "ButtonWarning"], ["rebuke", "Zurechtweisen", "ButtonDanger"]]:
		var b := Button.new()
		b.text = spec[1]
		b.theme_type_variation = spec[2]
		b.pressed.connect(_audience.bind(spec[0]))
		abar.add_child(b)
		buttons[spec[0]] = b
	reaction.bbcode_enabled = true
	reaction.fit_content = true
	reaction.scroll_active = false
	reaction.add_theme_font_size_override("normal_font_size", 18)
	avb.add_child(reaction)
	_show(start_cid if Game.cs(start_cid).unlocked else "albedo")


func _show(cid: String) -> void:
	_cid = cid
	var cd := Content.char_data(cid)
	var c := Game.cs(cid)
	var col := Content.char_color(cid)
	portrait.char_id = cid
	var mood := ""
	if c.status == "feldzug":
		mood = "battle"
	elif c.jealousy >= 60:
		mood = "angry"
	elif c.favor < 30:
		mood = "sad"
	elif c.favor >= 75:
		mood = "love"
	portrait.variant = mood
	name_label.text = cd.name
	name_label.add_theme_color_override("font_color", col.lerp(Palette.GOLD_BRIGHT, 0.35))
	title_label.text = "%s\n%s · %s" % [cd.title, cd.get("race", ""), cd.get("floor", "")]
	quote_label.text = "„%s“" % Game.fmt(cd.get("quote", ""))
	var status: String = Game.STATUS_LABELS.get(c.status, c.status)
	bio.text = "[color=#d4af37]Status:[/color] %s\n\n%s" % [status, Game.fmt(cd.get("bio", ""))]
	if cd.has("style"):
		bio.text += "\n\n[color=#c79bff]✧ Eigener Stil bei Freier Hand: »%s«[/color]" % cd.style.name

	for ch in stats_box.get_children():
		ch.queue_free()
	for ch in feelings_box.get_children():
		ch.queue_free()
	# Rang & Erfahrung
	var rp: Array = Progress.rank_progress(cid)
	var rank_l := Label.new()
	rank_l.text = "♜ " + Progress.rank_title(cid)
	rank_l.theme_type_variation = "GoldLabel"
	stats_box.add_child(rank_l)
	var xb := StatBar.new("Erfahrung", Palette.GOLD_BRIGHT, "✦", 108)
	if rp[1] > 0:
		xb.set_value(rp[0], rp[1], "%d / %d" % [rp[0], rp[1]])
	else:
		xb.set_value(1, 1, "Höchstrang")
	stats_box.add_child(xb)
	stats_box.add_child(_section("Fähigkeiten"))
	for k in Game.STAT_LABELS:
		var sb := StatBar.new(Game.STAT_LABELS[k], col, "", 108)
		var bonus := roundi(Progress.stat_bonus(cid, k))
		sb.set_value(minf(100.0, float(cd.stats[k]) + bonus), 100.0, "%d%s" % [int(cd.stats[k]), " +%d" % bonus if bonus > 0 else ""])
		stats_box.add_child(sb)
	# Ausrüstung
	stats_box.add_child(_section("Ausrüstung"))
	var eq_row := HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 8)
	for slot in Progress.SLOTS:
		var uid: String = Progress.ps().equip.get(cid, {}).get(slot, "")
		var iid: String = Progress.inv_entry(uid).get("id", "") if uid != "" else ""
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.tooltip_text = "%s: %s" % [Progress.SLOT_LABELS[slot], Progress.item_def(iid).get("name", "frei")]
		b.theme_type_variation = "ButtonGhost"
		if iid != "":
			var ic := ItemIcon.new(iid, 54)
			ic.position = Vector2(5, 5)
			b.add_child(ic)
		else:
			b.text = {"waffe": "⚔", "ruestung": "⛨", "schmuck": "◎"}[slot]
		b.pressed.connect(func(): _open_treasury())
		eq_row.add_child(b)
	var auto := Button.new()
	auto.text = "Bestes anlegen"
	auto.tooltip_text = "Legt die besten freien Artefakte der Schatzkammer an"
	auto.pressed.connect(func(): Progress.auto_equip(cid); Audio.sfx("order", 0.6); _show(cid))
	eq_row.add_child(auto)
	stats_box.add_child(eq_row)
	feelings_box.add_child(_section("Gefühle"))
	var feelings := [["favor", "Gunst", Palette.GOLD, "♛"], ["mood", "Stimmung", Palette.VIOLET_GLOW, "☾"],
		["fatigue", "Erschöpfung", Palette.MUTED, "◷"]]
	if cd.has("emotion"):
		feelings.insert(1, ["jealousy", "Eifersucht", Palette.CRIMSON, "⚡"])
	for f in feelings:
		var sb := StatBar.new(f[1], f[2], f[3], 100)
		sb.set_value(float(c[f[0]]))
		feelings_box.add_child(sb)
	var loyal := Label.new()
	loyal.text = "Loyalität: ∞  (absolut)"
	loyal.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	feelings_box.add_child(loyal)
	if cd.has("emotion"):
		var hint := Label.new()
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", Color("ff7aa8"))
		if c.jealousy >= 60:
			hint.text = "♥ Sie ist rasend eifersüchtig auf %s." % Game.char_name(cd.rival).split(" ")[0]
		elif c.favor < 35:
			hint.text = "♥ Sie fühlt sich vernachlässigt – und könnte unüberlegt handeln."
		else:
			hint.text = "♥ Ihr Herz gehört allein Euch."
		feelings_box.add_child(hint)

	var dtext := ""
	var dl: Array = c.deeds.duplicate()
	dl.reverse()
	for d in dl:
		dtext += "[color=#8f86a3]•[/color] %s\n" % d
	deeds.text = dtext if dtext != "" else "[color=#8f86a3]Noch keine Taten in der Neuen Welt verzeichnet.[/color]"
	reaction.text = ""
	_update_audience()


func _open_treasury() -> void:
	var parent := get_parent()
	close()
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(parent):
		parent.add_child(NazarickView.new(1))


func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.theme_type_variation = "SubHeaderLabel"
	l.add_theme_color_override("font_color", Palette.GOLD)
	return l


func _update_audience() -> void:
	var left := Game.audiences_left()
	var avail := Game.is_available(_cid)
	audience_info.text = "Audienzen heute: %d / %d%s" % [left, Game.audiences_per_day(), "" if avail else "  ·  nicht im Thronsaal"]
	for k in buttons:
		buttons[k].disabled = left <= 0 or not avail
	if Game.state.resources.gold < 60:
		buttons.gift.disabled = true


func _audience(kind: String) -> void:
	var res := Game.audience(_cid, kind)
	var cid := _cid
	_show(cid)
	reaction.text = res.get("text", "")
	if res.get("ok", false):
		Audio.sfx("rebuke" if kind == "rebuke" else ("love" if Content.char_data(cid).has("emotion") else "order"), 0.7)
		UIFx.typewriter(reaction, 150.0)
		if kind != "rebuke" and Content.char_data(cid).has("emotion"):
			portrait.variant = "love"
			UIFx.flash(portrait, Color(1.5, 1.2, 1.3))
		var chips := effect_chips(res.get("summary", []))
		reaction.get_parent().add_child(chips)
		get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(chips): chips.queue_free())
	changed.emit()

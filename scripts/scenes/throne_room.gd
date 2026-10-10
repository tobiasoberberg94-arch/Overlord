extends Control
## Thronsaal – die zentrale Hub-Szene.
##
## Aufbau:
##   ┌ Kopfleiste: Wappen · Datum · Kapitel · Effizienz · Speichern/Laden ┐
##   │ Links: Ressourcen + Kapitelziele                                   │
##   │ Mitte: Thron mit dem Overlord + Statuskarten der Untertanen        │
##   │ Rechts: Depeschen-Eingang · laufende Aufträge · Herzenskrieg       │
##   └ Fußleiste: Chronik-Ticker · Aktionen · Zeit vergehen lassen        ┘
## Modale Fenster (Overlay-Unterklassen) werden in [member overlay_layer] geöffnet.

const TITLE_SCENE := "res://scenes/title_screen.tscn"

var overlay_layer := Control.new()
var toast_box := VBoxContainer.new()

var date_label := Label.new()
var chapter_label := Label.new()
var lord_label := Label.new()
var efficiency_label := Label.new()
var resource_bars: Dictionary = {}
var efficiency_bar: StatBar
var balance_label := RichTextLabel.new()
var alerts_label := RichTextLabel.new()
var chapter_title := Label.new()
var chapter_sub := Label.new()
var objectives_box := VBoxContainer.new()
var cards_box := HBoxContainer.new()
var cards: Dictionary = {}
var inbox_box := VBoxContainer.new()
var inbox_badge := Label.new()
var missions_box := VBoxContainer.new()
var rivalry := RivalryMeter.new()
var ticker := RichTextLabel.new()
var time_buttons: Array[Button] = []
var tutorial_targets: Dictionary = {}   ## Bereiche, die das Tutorial hervorhebt
var _badge_tween: Tween
var _busy := false


func _ready() -> void:
	if Game.state.is_empty():
		Game.new_game()
	add_child(NazarickBackground.new("throne_room", true, 0.62))
	_build_layout()
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.position.y = 84
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	Game.state_changed.connect(refresh)
	Game.log_added.connect(_on_log_added)
	Game.dispatches_arrived.connect(func(_n): Audio.sfx("dispatch", 0.8))
	Audio.play_music("throne")
	refresh()
	UIFx.fade_in(self, 0.8)
	await get_tree().create_timer(0.6).timeout
	_open_next_dispatch()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or overlay_layer.get_child_count() > 0:
		return
	match key.keycode:
		KEY_A: _open_missions()
		KEY_K: _open_map()
		KEY_P: _open_overlay(DiplomacyView.new())
		KEY_V: _open_overlay(AdministrationView.new())
		KEY_U: _open_characters("albedo")
		KEY_C: _open_overlay(ChronicleView.new())
		KEY_D: _open_next_dispatch()
		KEY_1: _advance(1)
		KEY_2: _advance(7)
		KEY_3: _advance(30)
		KEY_F5: _open_overlay(SaveLoadDialog.new(true))


# =====================================================================
#  Layout
# =====================================================================

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	root.add_child(mid)
	mid.add_child(_build_left())
	mid.add_child(_build_center())
	mid.add_child(_build_right())
	root.add_child(_build_bottom_bar())


func _panel(variation: String = "PanelGlass") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "HeaderLabel"
	l.add_theme_font_size_override("font_size", 17)
	return l


func _build_top_bar() -> Control:
	var p := _panel()
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.ABYSS, 0.9), Palette.GOLD_DARK, 1, 12, Color(Palette.VIOLET, 0.4), 12, 10))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	p.add_child(hb)
	var crest := Label.new()
	crest.text = "⚜ NAZARICK"
	crest.theme_type_variation = "TitleLabel"
	crest.add_theme_font_size_override("font_size", 26)
	hb.add_child(crest)
	hb.add_child(VSeparator.new())
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", -2)
	date_label.theme_type_variation = "GoldLabel"
	chapter_label.theme_type_variation = "MutedLabel"
	info.add_child(date_label)
	info.add_child(chapter_label)
	hb.add_child(info)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	var lord := VBoxContainer.new()
	lord.add_theme_constant_override("separation", -2)
	lord_label.theme_type_variation = "GoldLabel"
	lord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	efficiency_label.theme_type_variation = "MutedLabel"
	efficiency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lord.add_child(lord_label)
	lord.add_child(efficiency_label)
	hb.add_child(lord)
	hb.add_child(VSeparator.new())
	for spec in [["Chronik", func(): _open_overlay(ChronicleView.new())], ["Speichern", func(): _open_overlay(SaveLoadDialog.new(true))],
			["Laden", _open_load], ["⚙", _open_settings], ["Titel", _to_title]]:
		var b := Button.new()
		b.text = spec[0]
		b.theme_type_variation = "ButtonGhost"
		b.pressed.connect(spec[1])
		if spec[0] == "⚙":
			b.tooltip_text = "Einstellungen & Einführung"
		hb.add_child(b)
	tutorial_targets["topbar"] = p
	return p


func _build_left() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 310
	col.add_theme_constant_override("separation", 12)
	# Ressourcen
	var rp := _panel()
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 7)
	rp.add_child(rv)
	rv.add_child(_header("Macht von Nazarick"))
	for k in Game.RESOURCE_KEYS:
		var sb := StatBar.new(Game.RESOURCE_LABELS[k], Palette.RESOURCE_COLORS[k], Palette.RESOURCE_ICONS[k], 118)
		sb.tooltip_text = _resource_tooltip(k)
		sb.set_icon_texture(Palette.icon(Palette.RESOURCE_ICON_FILES[k]))
		resource_bars[k] = sb
		rv.add_child(sb)
	rv.add_child(HSeparator.new())
	efficiency_bar = StatBar.new("Effizienz", Palette.SUCCESS, "⚙", 118)
	efficiency_bar.tooltip_text = "Effizienz der Guardians – Mittel aus Stimmung, Gunst und Erschöpfung."
	rv.add_child(efficiency_bar)
	balance_label.bbcode_enabled = true
	balance_label.fit_content = true
	balance_label.scroll_active = false
	balance_label.add_theme_font_size_override("normal_font_size", 16)
	balance_label.tooltip_text = "Tägliche Einkünfte aus Regionen und Erlassen abzüglich Unterhalt – Details unter Verwaltung [V]."
	rv.add_child(balance_label)
	col.add_child(rp)
	tutorial_targets["resources"] = rp
	# Kapitel
	var cp := _panel()
	cp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cp.add_child(cv)
	cv.add_child(_header("Chronik der Herrschaft"))
	chapter_title.theme_type_variation = "GoldLabel"
	chapter_title.add_theme_font_size_override("font_size", 19)
	chapter_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_sub.add_theme_font_override("font", NazarickTheme.italic_font(600))
	chapter_sub.add_theme_color_override("font_color", Palette.MUTED)
	chapter_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(chapter_title)
	cv.add_child(chapter_sub)
	cv.add_child(HSeparator.new())
	objectives_box.add_theme_constant_override("separation", 6)
	cv.add_child(objectives_box)
	col.add_child(cp)
	tutorial_targets["chapter"] = cp
	return col


func _resource_tooltip(k: String) -> String:
	return {
		"power": "Macht – Einfluss und militärische Stärke Nazaricks in der Neuen Welt.",
		"info": "Wissen – was Nazarick über die Neue Welt, ihre Mächte und Geheimnisse weiß.",
		"reputation": "Ruf – Ansehen von Ainz Ooal Gown (und Momon) unter den Völkern.",
		"morale": "Stimmung – die innere Verfassung Nazaricks.",
		"gold": "Gold der Schatzkammer (in Millionen YGGDRASIL-Gold).",
		"attention": "Aufmerksamkeit – wie sehr die Mächte der Welt auf Nazarick aufmerksam werden. Gefährlich, wenn hoch!",
	}.get(k, "")


func _build_center() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	var throne_wrap := Control.new()
	throne_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	throne_wrap.custom_minimum_size.y = 240
	var throne := ThroneVisual.new()
	throne.set_anchors_preset(Control.PRESET_FULL_RECT)
	throne_wrap.add_child(throne)
	var hall := Label.new()
	hall.text = "THRONSAAL"
	hall.theme_type_variation = "SubHeaderLabel"
	hall.add_theme_color_override("font_color", Color(Palette.GOLD, 0.7))
	hall.position = Vector2(14, 8)
	throne_wrap.add_child(hall)
	col.add_child(throne_wrap)
	tutorial_targets["throne"] = throne_wrap

	var gp := _panel()
	var gv := VBoxContainer.new()
	gp.add_child(gv)
	var gh := HBoxContainer.new()
	gh.add_child(_header("Die Wächter von Nazarick"))
	var hint := Label.new()
	hint.text = "Karte anklicken für Details & Audienz"
	hint.theme_type_variation = "MutedLabel"
	hint.add_theme_font_size_override("font_size", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gh.add_child(hint)
	gv.add_child(gh)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_box.add_theme_constant_override("separation", 10)
	var cm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		cm.add_theme_constant_override("margin_" + side, 8)
	cm.add_child(cards_box)
	scroll.add_child(cm)
	gv.add_child(scroll)
	var i := 0
	for cid in Content.character_order:
		var card := GuardianCard.new(cid)
		card.selected.connect(_open_characters)
		cards[cid] = card
		cards_box.add_child(card)
		UIFx.pop_in(card, 0.35, 0.3 + i * 0.07)
		i += 1
	col.add_child(gp)
	tutorial_targets["guardians"] = gp
	return col


func _build_right() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 350
	col.add_theme_constant_override("separation", 12)
	# Depeschen
	var ip := _panel()
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	ip.add_child(iv)
	var ih := HBoxContainer.new()
	ih.add_child(_header("Depeschen"))
	inbox_badge.add_theme_color_override("font_color", Palette.CRIMSON)
	inbox_badge.theme_type_variation = "GoldLabel"
	inbox_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inbox_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ih.add_child(inbox_badge)
	iv.add_child(ih)
	inbox_box.add_theme_constant_override("separation", 5)
	iv.add_child(inbox_box)
	alerts_label.bbcode_enabled = true
	alerts_label.fit_content = true
	alerts_label.scroll_active = false
	alerts_label.add_theme_font_size_override("normal_font_size", 15)
	iv.add_child(alerts_label)
	col.add_child(ip)
	tutorial_targets["dispatches"] = ip
	# Laufende Aufträge
	var mp := _panel()
	mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 6)
	mp.add_child(mv)
	mv.add_child(_header("Laufende Aufträge"))
	var ms := ScrollContainer.new()
	ms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ms.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	missions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	missions_box.add_theme_constant_override("separation", 8)
	ms.add_child(missions_box)
	mv.add_child(ms)
	col.add_child(mp)
	tutorial_targets["running"] = mp
	# Herzenskrieg
	var rp := _panel()
	rp.add_theme_stylebox_override("panel", NazarickTheme.box(Color(0.1, 0.02, 0.06, 0.9), Color(Palette.CRIMSON, 0.5), 1, 12, Color(Palette.BLOOD, 0.5), 14, 12))
	rp.add_child(rivalry)
	col.add_child(rp)
	tutorial_targets["rivalry"] = rp
	return col


func _build_bottom_bar() -> Control:
	var p := _panel()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	ticker.bbcode_enabled = true
	ticker.fit_content = true
	ticker.scroll_active = false
	ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker.add_theme_font_size_override("normal_font_size", 16)
	ticker.custom_minimum_size.y = 66
	hb.add_child(ticker)
	hb.add_child(VSeparator.new())
	ticker.custom_minimum_size.x = 180
	for spec in [["Aufträge", "ButtonPrimary", _open_missions, "icon_mission", "Auftragstafel [A]"],
			["Weltkarte", "ButtonPrimary", _open_map, "icon_magic", "Weltkarte, Regionen & Legionen [K]"],
			["Diplomatie", "Button", func(): _open_overlay(DiplomacyView.new()), "icon_emblem", "Fraktionen & Gesandtschaften [P]"],
			["Verwaltung", "Button", func(): _open_overlay(AdministrationView.new()), "icon_gold", "Finanzen & Erlasse [V]"],
			["Untertanen", "Button", func(): _open_characters("albedo"), "icon_nazarick", "Wächter & Audienzen [U]"]]:
		var b := Button.new()
		b.text = spec[0]
		b.tooltip_text = spec[4]
		_set_button_icon(b, spec[3])
		b.theme_type_variation = spec[1]
		b.custom_minimum_size = Vector2(0, 54)
		b.pressed.connect(spec[2])
		UIFx.add_hover_scale(b, 1.04)
		hb.add_child(b)
		if spec[3] == "icon_mission":
			tutorial_targets["orders"] = b
		elif spec[3] == "icon_magic":
			tutorial_targets["map"] = b
		elif spec[3] == "icon_gold":
			tutorial_targets["admin"] = b
		elif spec[3] == "icon_emblem":
			tutorial_targets["diplomacy"] = b
	hb.add_child(VSeparator.new())
	for spec in [["1 Tag", 1], ["1 Woche", 7], ["1 Monat", 30]]:
		var b := Button.new()
		b.text = spec[0]
		_set_button_icon(b, "icon_time")
		b.theme_type_variation = "ButtonWarning"
		b.custom_minimum_size = Vector2(0, 54)
		b.tooltip_text = "Zeit vergehen lassen (hält an, sobald Depeschen eintreffen)"
		b.pressed.connect(_advance.bind(spec[1]))
		UIFx.add_hover_scale(b, 1.04)
		time_buttons.append(b)
		hb.add_child(b)
	return p


func _set_button_icon(b: Button, icon_name: String) -> void:
	var tex := Palette.icon(icon_name)
	if tex:
		b.icon = tex
		b.add_theme_constant_override("icon_max_width", 30)


# =====================================================================
#  Aktualisierung
# =====================================================================

func refresh() -> void:
	var s := Game.state
	date_label.text = "Tag %d  ·  %s" % [s.day, Game.format_date(s.day)]
	var ch := Content.chapter(s.chapter)
	chapter_label.text = "Kapitel %s – %s" % [ch.numeral, ch.title]
	lord_label.text = "♛ " + s.lord_name
	efficiency_label.text = "Effizienz der Guardians %d %%" % Game.efficiency()
	for k in resource_bars:
		var v: int = s.resources.get(k, 0)
		if k == "gold":
			resource_bars[k].set_value(minf(v, 5000), 5000.0, "%d M" % v)
		else:
			resource_bars[k].set_value(v)
	efficiency_bar.set_value(Game.efficiency())
	var net: float = World.daily_income().gold + World.decree_daily_gold() - World.daily_upkeep()
	balance_label.text = "[color=#d4af37]Tagesbilanz:[/color] [color=%s]%+.0f Gold[/color]  [color=#8f86a3]· %d Erlasse · %d Legionen[/color]" % [
		"#6fdc8c" if net >= 0 else "#ff4a5a", net, Game.state.decrees.size(), Game.state.armies.size()]
	var alerts := PackedStringArray()
	for t in Game.state.threats:
		alerts.append("[color=#ff4a5a]⚠ %s – noch %d T.[/color]" % [Game.mission(t.mission_id).get("title", "Bedrohung"), World.threat_days_left(t)])
	for e in Game.state.enemy_armies:
		alerts.append("[color=#ff4a5a]⚔ %s → %s (%d T.)[/color]" % [e.name, World.region(e.target).short, Military.path_days(e.location, e.path)])
	alerts_label.text = "\n".join(alerts)
	alerts_label.visible = not alerts.is_empty()

	chapter_title.text = "Kapitel %s · %s" % [ch.numeral, ch.title]
	chapter_sub.text = ch.get("subtitle", "")
	for c in objectives_box.get_children():
		c.queue_free()
	var objs := Game.objectives()
	if objs.is_empty():
		var l := Label.new()
		l.text = "Freies Spiel: Herrscht, wie es Euch beliebt."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objectives_box.add_child(l)
	for o in objs:
		var l := Label.new()
		l.text = ("✔  " if o[1] else "◇  ") + o[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Palette.SUCCESS if o[1] else Palette.PARCHMENT)
		objectives_box.add_child(l)

	for cid in cards:
		cards[cid].refresh()
	_refresh_inbox()
	_refresh_missions()
	rivalry.refresh()
	_refresh_ticker()


func _refresh_inbox() -> void:
	for c in inbox_box.get_children():
		c.queue_free()
	var pending := Game.pending()
	inbox_badge.text = "● %d" % pending.size() if not pending.is_empty() else ""
	if _badge_tween:
		_badge_tween.kill()
		inbox_badge.modulate.a = 1.0
	if not pending.is_empty():
		_badge_tween = UIFx.pulse(inbox_badge, 0.3, 1.0)
	if pending.is_empty():
		var l := Label.new()
		l.text = "Keine Depeschen. Nazarick wartet auf Eure Befehle."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inbox_box.add_child(l)
	var icons := {"report": "⚔", "event": "⚠", "story": "⚜", "proposal": "✧", "initiative": "❖"}
	for d in pending.slice(0, 5):
		var who: String = Game.char_name(d.char_id) if d.char_id != "" else "Das Große Grab von Nazarick"
		var b := PortraitButton.new(d.char_id if d.char_id != "" else "ainz", "%s %s" % [icons.get(d.kind, "•"), d.title], who, Vector2(32, 40))
		if d.char_id == "":
			b.line1.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
		UIFx.pulse(b.portrait, 0.6, 1.4)
		b.pressed.connect(_open_dispatch.bind(d.uid))
		inbox_box.add_child(b)
	if pending.size() > 5:
		var more := Label.new()
		more.text = "… und %d weitere" % (pending.size() - 5)
		more.theme_type_variation = "MutedLabel"
		inbox_box.add_child(more)
	for b in time_buttons:
		b.disabled = not pending.is_empty()


func _refresh_missions() -> void:
	for c in missions_box.get_children():
		c.queue_free()
	if Game.state.active.is_empty():
		var l := Label.new()
		l.text = "Alle Untertanen weilen im Grab.\nErteilt Aufträge über die Auftragstafel [A]."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		missions_box.add_child(l)
		return
	for am in Game.state.active:
		var m := Game.mission(am.mission_id)
		var col := Content.char_color(am.char_id)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		var p := Portrait.new()
		p.char_id = am.char_id
		p.framed = false
		p.show_symbol = false
		p.custom_minimum_size = Vector2(34, 38)
		top.add_child(p)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", -3)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := Label.new()
		t.text = m.title
		t.add_theme_font_size_override("font_size", 16)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size.x = 200
		var who := Label.new()
		who.text = "%s · %s · noch %d T." % [Game.char_name(am.char_id).split(" ")[0], Content.directives[am.directive].name, maxi(0, am.end_day - Game.state.day)]
		who.add_theme_font_size_override("font_size", 14)
		who.add_theme_color_override("font_color", col.lerp(Palette.MUTED, 0.4))
		info.add_child(t)
		info.add_child(who)
		top.add_child(info)
		box.add_child(top)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.add_theme_stylebox_override("fill", NazarickTheme.box(col, Color.TRANSPARENT, 0, 4, Color(col, 0.5), 4, 0))
		bar.value = Game.mission_progress(am) * 100.0
		box.add_child(bar)
		missions_box.add_child(box)


func _on_log_added(_entry: Dictionary) -> void:
	_refresh_ticker()


func _refresh_ticker() -> void:
	var lines := PackedStringArray()
	var entries: Array = Game.state.log
	for e in entries.slice(maxi(0, entries.size() - 3)):
		lines.append("[color=#7a6f8f]T%d[/color]  [color=%s]%s[/color]" % [e.day, Palette.LOG_COLORS.get(e.cat, "#b7aecb"), e.text])
	ticker.text = "\n".join(lines)


# =====================================================================
#  Aktionen
# =====================================================================

func _open_overlay(o: Control) -> Control:
	overlay_layer.add_child(o)
	return o


func _open_missions(region: String = "") -> void:
	var board := MissionBoard.new(region)
	board.mission_assigned.connect(func(): toast("Befehl erteilt. Eure Untertanen brechen auf."))
	_open_overlay(board)


func _open_map(region: String = "nazarick") -> void:
	var m := WorldMapView.new(region)
	m.open_missions.connect(func(rid): await get_tree().create_timer(0.3).timeout; _open_missions(rid))
	m.closed.connect(func(): await get_tree().create_timer(0.2).timeout; _open_next_dispatch())
	_open_overlay(m)


func _open_characters(cid: String) -> void:
	_open_overlay(CharacterView.new(cid))


func _open_load() -> void:
	var dlg := SaveLoadDialog.new(false)
	dlg.loaded.connect(func(): refresh(); toast("Die Chronik wurde geöffnet."))
	_open_overlay(dlg)


func _to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


func _open_dispatch(uid: String) -> void:
	var d := Game.get_dispatch(uid)
	if d.is_empty() or overlay_layer.get_child_count() > 0:
		return
	var dlg: Overlay = BattleView.new(d) if d.kind == "battle" and Game.state.battles.has(d.get("context", {}).get("battle", "")) else DispatchDialog.new(d)
	dlg.closed.connect(func(): await get_tree().create_timer(0.15).timeout; _open_next_dispatch())
	_open_overlay(dlg)


## Öffnet automatisch die nächste offene Depesche (Berichte reihen sich aneinander).
func _open_next_dispatch() -> void:
	if overlay_layer.get_child_count() > 0:
		return
	var pending := Game.pending()
	if not pending.is_empty():
		if Settings.auto_open:
			_open_dispatch(pending[0].uid)
		return
	Audio.play_music("throne")
	# Beim ersten Spiel: Einführung nach dem Kapitel-Intro
	if not Settings.tutorial_done:
		start_tutorial()


func _open_settings() -> void:
	var dlg := SettingsDialog.new(true)
	dlg.tutorial_requested.connect(func(): await get_tree().create_timer(0.3).timeout; start_tutorial())
	_open_overlay(dlg)


## Startet die geführte Einführung (Spotlight-Tour durch den Thronsaal).
func start_tutorial() -> void:
	if overlay_layer.get_child_count() > 0:
		return
	var t := tutorial_targets
	var steps := [
		{"speaker": "albedo", "variant": "love", "target": null, "title": "Willkommen, mein Gebieter",
			"text": "{lord} … Ihr seid erwacht. Erlaubt Eurer Oberaufseherin, Euch in die Verwaltung des Großen Grabes einzuführen. Es wird nicht lange dauern. [i]Leider.[/i]"},
		{"speaker": "albedo", "target": t.get("resources"), "title": "Die Macht von Nazarick",
			"text": "[b]Macht[/b], [b]Wissen[/b] über die Neue Welt, [b]Ruf[/b], die [b]Stimmung[/b] in Nazarick und das [b]Gold[/b] der Schatzkammer. Achtet auf die [color=#ff8c1a][b]Aufmerksamkeit[/b][/color]: Je lauter wir auftreten, desto eher bemerken uns gefährliche Mächte. Die [b]Effizienz[/b] zeigt, wie gut es Euren Wächtern geht."},
		{"speaker": "albedo", "target": t.get("chapter"), "title": "Die Chronik der Herrschaft",
			"text": "Hier stehen die Ziele des aktuellen Kapitels. Erfüllt sie, und die Geschichte schreitet voran – von der Ankunft bis zur Krönung des Zauberkönigs. Eure Entscheidungen verändern den Weg dorthin."},
		{"speaker": "albedo", "target": t.get("guardians"), "title": "Eure Wächter",
			"text": "Jede Karte zeigt Status, [color=#d4af37]Gunst[/color] und [color=#9b5cff]Stimmung[/color] eines Untertanen. Ein Klick öffnet seine Akte – dort könnt Ihr [b]Audienzen[/b] gewähren, Geschenke machen oder tadeln (zwei Audienzen pro Tag).\n\nIhr werdet bemerken, dass meine Karte die schönste ist. Das ist reiner Zufall."},
		{"speaker": "albedo", "target": t.get("orders"), "title": "Die Auftragstafel  [A]",
			"text": "Hier erteilt Ihr Befehle: Wählt einen [b]Auftrag[/b], einen [b]Vollstrecker[/b] und die [b]Befehlsart[/b]. Hauptaufträge (★) treiben die Geschichte voran, Nebenaufträge (◆) bringen Ressourcen, und Vorschläge (✧) stammen von uns selbst."},
		{"speaker": "demiurge", "target": t.get("orders"), "title": "Über die Kunst des Befehlens",
			"text": "Wenn Ihr erlaubt, {lord}: Wir führen Befehle [i]auf unsere Weise[/i] aus. Bei [b]Freier Hand[/b] handelt jeder nach seinem eigenen Stil – ich etwa nach einem Plan von sieben Ebenen. Manche von uns legen Befehle auch … eigenwillig aus. Die Tafel warnt Euch, wenn jemand dazu neigt. Shalltear und das Wort ›diskret‹ beispielsweise."},
		{"speaker": "albedo", "target": t.get("dispatches"), "title": "Depeschen",
			"text": "Berichte, Ereignisse, Eigeninitiativen und Vorschläge erscheinen hier und öffnen sich automatisch. Ihr antwortet mit [color=#6fdc8c]Lob[/color], [color=#f2b43c]Belohnung[/color], [color=#ff4a5a]Tadel[/color] oder Schweigen – und jede Antwort hat Folgen. Für Gunst, Stimmung … und Eifersucht."},
		{"speaker": "demiurge", "target": t.get("map"), "title": "Die Weltkarte  [K]",
			"text": "Hier liegt die Neue Welt vor Euch, {lord}. Jede [b]Region[/b] muss erst erkundet werden; danach wächst unser [b]Einfluss[/b] durch Aufträge – und mit ihm die täglichen Einkünfte. Achtet auf die [color=#ff4a5a]Unruhe[/color]: Wer zu grausam herrscht, erntet Aufstände.\n\nHier hebt Ihr auch [b]Legionen[/b] aus, ernennt einen Wächter zum Feldherrn und schickt sie auf Feldzüge – zur Verteidigung oder zur Eroberung."},
		{"speaker": "albedo", "target": t.get("diplomacy"), "title": "Diplomatie  [P]",
			"text": "Die Reiche der Menschen, Zwerge und Drachen beobachten uns. Schickt [b]Gesandte[/b] – Geschenke, Handelsabkommen, Nichtangriffspakte … oder eine [b]Machtdemonstration[/b], bis sie sich als [b]Vasallen[/b] unterwerfen. Wer uns hasst, erklärt irgendwann den Krieg. Ich übernehme gerne jede Verhandlung persönlich, {lord}."},
		{"speaker": "albedo", "target": t.get("admin"), "title": "Die Reichsverwaltung  [V]",
			"text": "Ein Reich will verwaltet werden. Hier seht Ihr Einkünfte und [b]Unterhalt[/b] – das Grab, jeder Einsatz und jede Legion kosten Gold. Mit [b]Erlassen[/b] legt Ihr den Kurs Eurer Herrschaft fest. Die Plätze sind begrenzt, und wir Wächter haben … Meinungen dazu."},
		{"speaker": "albedo", "target": t.get("running"), "title": "Laufende Aufträge",
			"text": "Hier seht Ihr, wer gerade unterwegs ist. Mitten im Einsatz melden wir uns mit [b]Lageberichten[/b], wenn etwas Unerwartetes geschieht – dann entscheidet Ihr über Risiko und Vorgehen. Ihr könnt auch zwei Untertanen gemeinsam entsenden; manche ergänzen sich, andere … nicht."},
		{"speaker": "albedo", "target": time_buttons, "title": "Der Lauf der Zeit  [1] [2] [3]",
			"text": "Lasst einen Tag, eine Woche oder einen Monat vergehen. Die Zeit hält von selbst an, sobald eine Depesche eintrifft. Untätige Wächter ergreifen in dieser Zeit gern die [b]Initiative[/b] – besonders, wenn sie sich vernachlässigt fühlen."},
		{"speaker": "shalltear", "variant": "love", "target": t.get("rivalry"), "title": "Der Herzenskrieg!",
			"text": "Endlich darf ich auch etwas sagen, ~arinsu! Das hier ist der [color=#ff2a4f][b]Herzenskrieg[/b][/color]. Lobt Ihr diese gehörnte Kuh, werde ich eifersüchtig – lobt Ihr mich, kocht sie vor Wut. Steigt die Rivalität zu hoch, passieren … interessante Dinge. Lobt einfach immer mich, dann bleibt alles friedlich!"},
		{"speaker": "albedo", "target": t.get("rivalry"), "title": "Eine Richtigstellung",
			"text": "Ignoriert sie, {lord}. Aber es stimmt: Wen Ihr bevorzugt, merken wir. [i]Alle[/i]. Haltet die Waage – oder entscheidet Euch. Für mich, vorzugsweise."},
		{"speaker": "albedo", "target": t.get("topbar"), "title": "Chronik versiegeln",
			"text": "Oben könnt Ihr [b]speichern[/b] und [b]laden[/b]. Unter ⚙ findet Ihr Lautstärke, Vollbild (F11) und diese Einführung, falls Ihr sie erneut hören möchtet. Ich erkläre es Euch jederzeit gern noch einmal. Und noch einmal."},
		{"speaker": "albedo", "variant": "love", "target": t.get("throne"), "title": "Nazarick erwartet Euch",
			"text": "Das war alles. Öffnet die Auftragstafel [b][A][/b] und schickt Eure ersten Wächter aus – die Umgebung muss erkundet und das Grab verborgen werden.\n\nIch werde immer an Eurer Seite sein, {lord}. Immer."},
	]
	var tut := TutorialOverlay.new(steps)
	tut.finished.connect(func(): toast("Die Einführung ist beendet. Ihr findet sie jederzeit unter ⚙."); _open_next_dispatch.call_deferred())
	_open_overlay(tut)


func _advance(days: int) -> void:
	if _busy or overlay_layer.get_child_count() > 0:
		return
	if not Game.pending().is_empty():
		toast("Erst müssen die Depeschen beantwortet werden.", Palette.DANGER)
		_open_next_dispatch()
		return
	_busy = true
	Audio.sfx("gong", 0.6)
	# Übergang „Die Zeit vergeht …“
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.0, 0.04, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var lbl := Label.new()
	lbl.text = "Die Tage vergehen …"
	lbl.theme_type_variation = "TitleLabel"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.modulate.a = 0.0
	veil.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(veil, "color:a", 0.65, 0.3)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	await tw.finished
	var result := Game.advance(days)
	_autosave()
	lbl.text = "%d %s vergangen" % [result.days, "Tag" if result.days == 1 else "Tage"]
	await get_tree().create_timer(0.45).timeout
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(veil, "color:a", 0.0, 0.35)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.35)
	await tw2.finished
	veil.queue_free()
	_busy = false
	if result.get("interrupted", false):
		toast("Die Zeit hält an – eine Depesche erwartet Euch.", Palette.GOLD_BRIGHT)
	_open_next_dispatch()


var _last_autosave := 0


func _autosave() -> void:
	var every := Settings.autosave_days()
	if every > 0 and Game.state.day - _last_autosave >= every:
		_last_autosave = Game.state.day
		SaveSystem.save_game(0)


func toast(text: String, color: Color = Palette.GOLD_BRIGHT) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.ABYSS, 0.95), color, 1, 10, Color(color, 0.4), 12, 10))
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	toast_box.add_child(p)
	UIFx.pop_in(p, 0.25)
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

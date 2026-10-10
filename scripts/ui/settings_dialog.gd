class_name SettingsDialog
extends Overlay
## Optionsmenü mit Reitern: Audio · Grafik · Spiel · Steuerung.
## Jede Änderung wird sofort angewendet und in user://settings.cfg gespeichert.

signal tutorial_requested

var _allow_tutorial := false


func _init(allow_tutorial: bool = false) -> void:
	super._init(Vector2(860, 640))
	_allow_tutorial = allow_tutorial
	content.add_child(make_header("Optionen", "Änderungen werden sofort übernommen"))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	tabs.add_child(_audio_tab())
	tabs.add_child(_video_tab())
	tabs.add_child(_game_tab())
	tabs.add_child(_controls_tab())


func _page(title: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.name = title
	vb.add_theme_constant_override("separation", 14)
	var m := MarginContainer.new()
	return vb


func _row(label: String, control: Control, hint: String = "") -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 240
	l.tooltip_text = hint
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(control)
	return hb


func _slider(prop: String, min_v: float = 0.0, max_v: float = 1.0, step: float = 0.05, pct: bool = true) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = float(Settings.get(prop))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.custom_minimum_size.x = 64
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.text = "%d %%" % roundi(s.value * 100)
	s.drag_ended.connect(func(_c): Settings.set_value(prop, s.value))
	s.value_changed.connect(func(v):
		lbl.text = "%d %%" % roundi(v * 100)
		Settings.set(prop, v)
		if prop != "ui_scale":
			Settings.apply_all()
		if prop == "sfx_volume":
			Audio.sfx("click"))
	hb.add_child(s)
	hb.add_child(lbl)
	return hb


func _check(prop: String, text: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Settings.get(prop))
	c.toggled.connect(func(on): Settings.set_value(prop, on))
	return c


func _choice(prop: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(int(Settings.get(prop)))
	o.item_selected.connect(func(i): Settings.set_value(prop, i))
	return o


func _audio_tab() -> Control:
	var p := _page("Audio")
	p.add_child(_row("Gesamtlautstärke", _slider("master_volume")))
	p.add_child(_row("Musik", _slider("music_volume")))
	p.add_child(_row("Soundeffekte", _slider("sfx_volume")))
	p.add_child(_row("Klickgeräusche der Oberfläche", _check("ui_sounds", "aktiv")))
	return p


func _video_tab() -> Control:
	var p := _page("Grafik")
	p.add_child(_row("Anzeigemodus", _choice("window_mode", Settings.WINDOW_MODES), "F11 wechselt jederzeit zwischen Fenster und Vollbild."))
	var res: Array = Settings.RESOLUTIONS.map(func(r): return "%d × %d" % [r.x, r.y])
	p.add_child(_row("Fenstergröße", _choice("resolution", res), "Gilt im Fenstermodus."))
	p.add_child(_row("Vertikale Synchronisation", _check("vsync", "VSync")))
	p.add_child(_row("Bildrate begrenzen", _choice("max_fps", ["30 FPS", "60 FPS", "120 FPS", "Unbegrenzt"])))
	p.add_child(_row("Partikel & Nebeleffekte", _check("particles", "anzeigen"), "Abschalten spart Leistung auf schwachen Rechnern."))
	p.add_child(_row("Größe der Oberfläche", _slider("ui_scale", 0.8, 1.3, 0.05), "Wird beim Loslassen des Reglers angewendet."))
	return p


func _game_tab() -> Control:
	var p := _page("Spiel")
	p.add_child(_row("Textgeschwindigkeit", _choice("text_speed", Settings.TEXT_SPEEDS)))
	p.add_child(_row("Depeschen automatisch öffnen", _check("auto_open", "aktiv"), "Aus: Depeschen warten im Eingang, bis Ihr sie öffnet."))
	p.add_child(_row("Automatisch speichern", _choice("autosave", ["Aus", "Jede Woche", "Jeden Monat"]), "Speichert in das Siegel »Automatisch«."))
	if _allow_tutorial:
		var t := Button.new()
		t.text = "Einführung erneut zeigen"
		t.theme_type_variation = "ButtonPrimary"
		t.pressed.connect(func():
			tutorial_requested.emit()
			close())
		p.add_child(_row("Einführung", t))
	else:
		var r := Button.new()
		r.text = "Beim nächsten Spiel erneut zeigen"
		r.pressed.connect(func(): Settings.set_value("tutorial_done", false); r.disabled = true)
		p.add_child(_row("Einführung", r))
	return p


func _controls_tab() -> Control:
	var p := _page("Steuerung")
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.add_theme_font_size_override("normal_font_size", 18)
	var keys := [["A", "Auftragstafel"], ["K", "Weltkarte & Legionen"], ["V", "Verwaltung: Finanzen & Erlasse"],
		["U", "Untertanen & Audienzen"], ["C", "Chronik"], ["D", "Nächste Depesche öffnen"],
		["1 / 2 / 3", "Einen Tag / eine Woche / einen Monat vergehen lassen"], ["F5", "Speichern"],
		["F11", "Vollbild umschalten"], ["ESC", "Fenster schließen"], ["Klick in Text", "Schreibeffekt überspringen"]]
	var out := ""
	for k in keys:
		out += "[color=#f5d77a][b]%s[/b][/color]   %s\n" % [k[0], k[1]]
	t.text = out
	p.add_child(t)
	return p

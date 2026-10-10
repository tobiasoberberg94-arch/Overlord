class_name SettingsDialog
extends Overlay
## Einstellungen: Musik- und Effektlautstärke, Vollbild, Tutorial erneut zeigen.

signal tutorial_requested


func _init(allow_tutorial: bool = false) -> void:
	super._init(Vector2(680, 0))
	content.add_child(make_header("Einstellungen", "Lautstärke, Anzeige und Einführung"))
	content.add_child(HSeparator.new())
	content.add_child(_slider("♫  Musik", Settings.music_volume, func(v):
		Settings.music_volume = v
		Settings.save()))
	content.add_child(_slider("♪  Effekte", Settings.sfx_volume, func(v):
		Settings.sfx_volume = v
		Settings.save()
		Audio.sfx("click")))
	var fs := CheckButton.new()
	fs.text = "Vollbild  (F11)"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(Settings.set_fullscreen)
	content.add_child(fs)
	if allow_tutorial:
		var t := Button.new()
		t.text = "Einführung erneut zeigen"
		t.theme_type_variation = "ButtonPrimary"
		t.pressed.connect(func():
			tutorial_requested.emit()
			close())
		content.add_child(t)
	var hint := Label.new()
	hint.text = "Tasten im Thronsaal: A Aufträge · U Untertanen · C Chronik · D Depesche · 1/2/3 Zeit · F5 Speichern · F11 Vollbild"
	hint.theme_type_variation = "MutedLabel"
	hint.add_theme_font_size_override("font_size", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


func _slider(label: String, value: float, cb: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 140
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := Label.new()
	pct.custom_minimum_size.x = 50
	pct.text = "%d %%" % roundi(value * 100)
	s.value_changed.connect(func(v):
		pct.text = "%d %%" % roundi(v * 100)
		cb.call(v))
	hb.add_child(s)
	hb.add_child(pct)
	return hb

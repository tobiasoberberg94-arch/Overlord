class_name TalkDialog
extends Overlay
## Kurzes Gespräch mit einer Figur in der Welt (Portrait + Zitat + optionale Aktionen).

func _init(cid: String, text: String, actions: Array = []) -> void:
	super._init(Vector2(980, 0))
	var cd := Content.char_data(cid)
	content.add_child(make_header(cd.get("name", cid), cd.get("title", "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)
	var p := Portrait.new()
	p.char_id = cid
	p.custom_minimum_size = Vector2(220, 290)
	row.add_child(p)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	row.add_child(vb)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.add_theme_font_size_override("normal_font_size", 22)
	l.add_theme_font_override("normal_font", NazarickTheme.italic_font(600))
	l.text = "»%s«" % Game.fmt(text)
	vb.add_child(l)
	UIFx.typewriter(l, 120.0)
	for a in actions:
		var b := Button.new()
		b.text = a.text
		b.theme_type_variation = "ButtonPrimary"
		var act: Callable = a.action
		b.pressed.connect(func():
			await close()
			act.call())
		vb.add_child(b)
	var ok := Button.new()
	ok.text = "Weitergehen"
	ok.pressed.connect(close)
	vb.add_child(ok)

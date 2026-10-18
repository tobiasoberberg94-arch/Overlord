class_name LoreDialog
extends Overlay
## Lesefenster für Inschriften, Briefe und Steckbriefe aus der Welt (Entdeckungen).

func _init(title: String, text: String) -> void:
	super._init(Vector2(760, 0))
	content.add_child(make_header(title, "Entdeckung"))
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.add_theme_font_override("normal_font", NazarickTheme.italic_font(600))
	l.add_theme_font_size_override("normal_font_size", 22)
	l.text = text
	content.add_child(l)
	UIFx.typewriter(l, 110.0)
	var ok := Button.new()
	ok.text = "Weiter"
	ok.theme_type_variation = "ButtonCard"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(close)
	content.add_child(ok)

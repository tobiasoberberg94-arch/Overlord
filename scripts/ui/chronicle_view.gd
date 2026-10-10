class_name ChronicleView
extends Overlay
## Die vollständige Chronik von Nazarick (Event-Log), nach Tagen gruppiert.

func _init() -> void:
	super._init(Vector2(1000, 760))
	content.add_child(make_header("Chronik des Großen Grabes", "Alles, was geschah – aufgezeichnet von Albedo, korrigiert von Demiurge."))
	content.add_child(HSeparator.new())
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 18)
	content.add_child(text)
	var last_day := -1
	var out := ""
	for e in Game.state.log:
		if e.day != last_day:
			last_day = e.day
			out += "\n[color=#d4af37][b]%s[/b][/color]\n" % Game.format_date(e.day)
		out += "  [color=%s]%s[/color]\n" % [Palette.LOG_COLORS.get(e.cat, "#b7aecb"), e.text]
	text.text = out
	text.scroll_following = true

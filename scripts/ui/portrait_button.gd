class_name PortraitButton
extends Button
## Kachel-Button mit Mini-Portrait und zwei Textzeilen
## (Vollstrecker-Auswahl, Charakter-Reiter, Depeschen-Eingang).

var portrait := Portrait.new()
var line1 := Label.new()
var line2 := Label.new()


func _init(cid: String, text1: String, text2: String = "", portrait_size: Vector2 = Vector2(40, 52)) -> void:
	theme_type_variation = "ButtonCard"
	custom_minimum_size = Vector2(0, portrait_size.y + 12)
	clip_contents = true
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_top = 6
	hb.offset_bottom = -6
	hb.offset_right = -6
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	portrait.char_id = cid
	portrait.framed = false
	portrait.show_symbol = false
	portrait.custom_minimum_size = portrait_size
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	for l in [line1, line2]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(l)
	line1.add_theme_font_size_override("font_size", 18)
	line2.add_theme_font_size_override("font_size", 15)
	set_lines(text1, text2)
	line1.add_theme_color_override("font_color", Content.char_color(cid).lerp(Palette.PARCHMENT, 0.35))
	line2.add_theme_color_override("font_color", Palette.MUTED)


func set_lines(text1: String, text2: String = "", color2: Color = Palette.MUTED) -> void:
	line1.text = text1
	line2.text = text2
	line2.visible = text2 != ""
	line2.add_theme_color_override("font_color", color2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED:
		portrait.dimmed = disabled

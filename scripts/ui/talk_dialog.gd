class_name TalkDialog
extends Overlay
## Gespräch mit einer Figur in der Welt – filmisch: Kinobalken oben/unten, großes Porträt links,
## Namensschild und Zitat im unteren Drittel, Antworten als Karten. Die 3D-Szene bleibt sichtbar.

var _bars: Array[ColorRect] = []
var _portrait := Portrait.new()
var _box: NzPanel


func _init(cid: String, text: String, actions: Array = []) -> void:
	super._init(Vector2.ZERO, "PanelDim")
	_dim.color = Color(0.01, 0.0, 0.02, 0.35)
	# Zentrales Panel durch das Untere-Drittel-Layout ersetzen
	var center := panel.get_parent()
	center.remove_child(panel)
	center.queue_free()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 380
	panel.offset_right = -120
	panel.offset_bottom = -96
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_meta("top", top)
		add_child(bar)
		_bars.append(bar)
	# Porträt ragt links über die Box
	_portrait.char_id = cid
	_portrait.framed = false
	_portrait.show_symbol = false
	_portrait.backdrop = false
	_portrait.focus_y = 0.0
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_portrait.offset_left = 70
	_portrait.offset_right = 360
	_portrait.offset_top = -500
	_portrait.offset_bottom = -96
	add_child(_portrait)
	add_child(panel)
	panel.remove_child(content)
	_box = NzPanel.new(Vector4(30, 22, 30, 22), Color(0.03, 0.015, 0.05, 0.9))
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_box.add_child(content)
	panel.add_child(_box)

	var cd := Content.char_data(cid)
	content.add_theme_constant_override("separation", 8)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 14)
	var nm := Label.new()
	nm.text = cd.get("name", cid).to_upper()
	nm.theme_type_variation = "HeaderLabel"
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", Content.char_color(cid).lerp(Palette.GOLD_BRIGHT, 0.55))
	nh.add_child(nm)
	var tl := Label.new()
	tl.text = cd.get("title", "")
	tl.theme_type_variation = "MutedLabel"
	tl.add_theme_font_override("font", NazarickTheme.italic_font(600))
	tl.size_flags_vertical = Control.SIZE_SHRINK_END
	nh.add_child(tl)
	content.add_child(nh)
	var sep := HSeparator.new()
	content.add_child(sep)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size.x = 600
	l.add_theme_font_size_override("normal_font_size", 23)
	l.add_theme_font_size_override("bold_font_size", 23)
	l.add_theme_font_override("normal_font", NazarickTheme.italic_font(600))
	l.text = "»%s«" % Game.fmt(text)
	content.add_child(l)
	UIFx.typewriter(l, 120.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	for a in actions:
		var b := Button.new()
		b.text = a.text
		b.theme_type_variation = "ButtonPrimary"
		var act: Callable = a.action
		b.pressed.connect(func():
			await close()
			act.call())
		row.add_child(b)
	var ok := Button.new()
	ok.text = "Weitergehen  ▸"
	ok.theme_type_variation = "ButtonCard"
	ok.tooltip_text = "Weiter (E, Enter oder Esc)"
	ok.pressed.connect(close)
	row.add_child(ok)


func _ready() -> void:
	UIFx.fade_in(_dim, 0.3)
	for b in _bars:
		var tw := b.create_tween()
		if b.get_meta("top"):
			tw.tween_property(b, "offset_bottom", 64.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(b, "offset_top", -64.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_portrait.modulate.a = 0.0
	_portrait.position.x -= 40
	var pt := _portrait.create_tween().set_parallel(true)
	pt.tween_property(_portrait, "modulate:a", 1.0, 0.4).set_delay(0.1)
	pt.tween_property(_portrait, "position:x", _portrait.position.x + 40, 0.45).set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	UIFx.fade_in(panel, 0.35, 0.15)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if closable and k and k.pressed and not k.echo and k.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		close()
		return
	super._unhandled_input(event)

class_name CinematicUI
extends Control
## Oberfläche der Filmszenen: Kinobalken, Untertitel mit Porträt und Namensschild (Schreibmaschine),
## Ainz' Gedanken kursiv in Violett, Entscheidungen als Karten in der Bildmitte, Titelkarten.
##   await say(cid, text)            – wartet auf Weiter (E, Leertaste, Klick); erster Druck vervollständigt den Text
##   await choose(prompt, options)   – liefert den Index der gewählten Antwort
## Esc ruft skip_requested aus (die Szene springt dann bis zur nächsten Entscheidung).

signal advanced
signal chosen(index: int)
signal skip_requested

const BAR_H := 0.11

var _top := ColorRect.new()
var _bottom := ColorRect.new()
var _box := NzPanel.new(Vector4(34, 20, 34, 18), Color(0.025, 0.012, 0.04, 0.88))
var _portrait := Portrait.new()
var _name := Label.new()
var _text := RichTextLabel.new()
var _hint := Label.new()
var _skip := Label.new()
var _choice_box := VBoxContainer.new()
var _prompt := RichTextLabel.new()
var _title := Label.new()
var _sub := Label.new()
var _typing: Tween
var _waiting := false
var _choosing := false
var _bars := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [_top, _bottom]:
		b.color = Color(0, 0, 0, 1)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Untertitel
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_box.offset_left = -640
	_box.offset_right = 640
	_box.offset_bottom = -34
	_box.offset_top = -210
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_portrait.custom_minimum_size = Vector2(132, 150)
	_portrait.framed = true
	_portrait.show_symbol = false
	_portrait.focus_y = 0.02
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name.add_theme_font_override("font", NazarickTheme.display_font(800))
	_name.add_theme_font_size_override("font_size", 25)
	_name.add_theme_constant_override("outline_size", 6)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	col.add_child(_name)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(980, 70)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		_text.add_theme_font_size_override(k, 23)
	_text.add_theme_color_override("default_color", Palette.PARCHMENT)
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	col.add_child(_text)
	var hr := HBoxContainer.new()
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hr)
	_skip.text = "Esc  Szene überspringen"
	_skip.add_theme_font_size_override("font_size", 14)
	_skip.add_theme_color_override("font_color", Color(Palette.MUTED, 0.8))
	_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(_skip)
	_hint.text = "▸  E · Leertaste · Klick"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Palette.GOLD)
	hr.add_child(_hint)
	# Entscheidungen
	_choice_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_choice_box.offset_left = -420
	_choice_box.offset_right = 420
	_choice_box.offset_top = -160
	_choice_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.visible = false
	add_child(_choice_box)
	_prompt.bbcode_enabled = true
	_prompt.fit_content = true
	_prompt.scroll_active = false
	_prompt.add_theme_font_size_override("normal_font_size", 24)
	_prompt.add_theme_color_override("default_color", Palette.GOLD_BRIGHT)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Titelkarte
	for l in [_title, _sub]:
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 54)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02, 0.95))
	_title.offset_top = -120
	_sub.add_theme_font_override("font", NazarickTheme.italic_font(600))
	_sub.add_theme_font_size_override("font_size", 24)
	_sub.add_theme_color_override("font_color", Palette.PARCHMENT)
	_sub.add_theme_constant_override("outline_size", 7)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_sub.offset_top = -40


func _ready() -> void:
	_layout_bars()
	resized.connect(_layout_bars)


func _layout_bars() -> void:
	var h := size.y * BAR_H * _bars
	_top.size = Vector2(size.x, h)
	_top.position = Vector2.ZERO
	_bottom.size = Vector2(size.x, h)
	_bottom.position = Vector2(0, size.y - h)


## Kinobalken ein-/ausfahren.
func bars(on: bool, secs: float = 0.6) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_bars = v
		_layout_bars(), _bars, 1.0 if on else 0.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Untertitel. thought = Ainz' Gedanken (kursiv, violett).
func say(cid: String, text: String, thought: bool = false) -> void:
	_box.visible = true
	_box.modulate.a = 1.0
	var who := cid if cid != "" else "ainz"
	_portrait.char_id = who
	_portrait.variant = "momon" if who == "ainz_momon" else ""
	var cd := Content.char_data(who)
	var nm: String = Game.state.get("lord_name", "Ainz Ooal Gown") if who == "ainz" else String(cd.get("name", who))
	if who == "ainz_momon":
		nm = "Momon"
	_name.text = (nm + "  ·  Gedanken") if thought else nm
	var col: Color = Content.char_color(who) if who != "ainz" else Palette.VIOLET_GLOW
	_name.add_theme_color_override("font_color", col.lerp(Palette.GOLD_BRIGHT, 0.45))
	var body := Game.fmt(text)
	_text.text = ("[i][color=#c9a8ff]" + body + "[/color][/i]") if thought else body
	_text.visible_ratio = 0.0
	if _typing and _typing.is_running():
		_typing.kill()
	var f := Settings.text_speed_factor()
	var secs := clampf(_text.get_total_character_count() / 52.0, 0.3, 4.0) / f if f > 0.0 else 0.0
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, secs)
	_hint.modulate.a = 0.35
	_typing.tween_callback(func(): _hint.modulate.a = 1.0)
	_waiting = true
	await advanced
	_waiting = false


func hide_box() -> void:
	_box.visible = false


## Entscheidung: liefert den Index der Antwort.
func choose(prompt: String, options: Array) -> int:
	_box.visible = false
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()
	_prompt.text = "[center]" + Game.fmt(prompt) + "[/center]"
	var pr := _prompt.duplicate()
	_choice_box.add_child(pr)
	var variants := {"primary": "ButtonPrimary", "danger": "ButtonDanger", "success": "ButtonSuccess", "warning": "ButtonWarning"}
	for i in options.size():
		var o: Dictionary = options[i]
		var b := Button.new()
		b.text = Game.fmt(String(o.get("text", "")))
		b.theme_type_variation = variants.get(String(o.get("variant", "default")), "Button")
		b.custom_minimum_size = Vector2(840, 50)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if o.get("disabled", false):
			b.disabled = true
			b.text += "   — " + String(o.get("hint", "nicht möglich"))
			b.tooltip_text = String(o.get("hint", ""))
		b.pressed.connect(func(): chosen.emit(i))
		_choice_box.add_child(b)
		UIFx.pop_in(b, 0.25, 0.1 + i * 0.07)
	_choice_box.visible = true
	_choosing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in _choice_box.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus.call_deferred()
			break
	var idx: int = await chosen
	_choosing = false
	_choice_box.visible = false
	Audio.sfx("order", 0.7)
	return idx


## Titelkarte in der Bildmitte.
func title_card(title: String, sub: String, secs: float = 3.0) -> void:
	_title.text = title.to_upper()
	_sub.text = sub
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, 0.8)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.8).set_delay(0.3)
	tw.chain().tween_interval(secs)
	tw.chain().tween_property(_title, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(_sub, "modulate:a", 0.0, 0.8)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE):
		if not _choosing:
			skip_requested.emit()
			_finish_or_advance(true)
			get_viewport().set_input_as_handled()
		return
	if _choosing or not _waiting:
		return
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		go = true
	if go:
		_finish_or_advance(false)
		get_viewport().set_input_as_handled()


func _finish_or_advance(force: bool) -> void:
	if not _waiting:
		return
	if not force and _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		_hint.modulate.a = 1.0
		return
	advanced.emit()

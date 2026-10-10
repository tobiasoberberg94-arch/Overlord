class_name TutorialOverlay
extends Control
## Geführte Einführung im Thronsaal.
##
## Dunkelt den Bildschirm ab und hebt den gerade erklärten Bereich mit einem
## goldenen Rahmen hervor („Spotlight“). Die Wächter selbst erklären das Spiel –
## jeder in seinem eigenen Ton. Schritte: Array von Dictionaries
##   {"target": Control | Array[Control] | null, "speaker": "albedo", "title": "…", "text": "…"}

signal finished

var steps: Array = []
var _index := 0
var _rect := Rect2()
var _target_rect := Rect2()
var _pulse := 0.0
var _box := PanelContainer.new()
var _portrait := Portrait.new()
var _name := Label.new()
var _title := Label.new()
var _text := RichTextLabel.new()
var _counter := Label.new()
var _back := Button.new()
var _next := Button.new()


func _init(tutorial_steps: Array) -> void:
	steps = tutorial_steps
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_box.custom_minimum_size = Vector2(640, 0)
	_box.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.ABYSS, 0.97), Palette.GOLD, 2, 14, Color(Palette.VIOLET_GLOW, 0.45), 24, 16))
	add_child(_box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_box.add_child(hb)
	_portrait.custom_minimum_size = Vector2(130, 170)
	_portrait.show_symbol = false
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	hb.add_child(vb)
	_name.theme_type_variation = "SubHeaderLabel"
	vb.add_child(_name)
	_title.theme_type_variation = "HeaderLabel"
	_title.add_theme_font_size_override("font_size", 21)
	vb.add_child(_title)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(460, 0)
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_text.add_theme_font_size_override("italics_font_size", 19)
	vb.add_child(_text)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	vb.add_child(bar)
	var skip := Button.new()
	skip.text = "Überspringen"
	skip.theme_type_variation = "ButtonGhost"
	skip.pressed.connect(_finish)
	bar.add_child(skip)
	_counter.theme_type_variation = "MutedLabel"
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_counter)
	_back.text = "Zurück"
	_back.pressed.connect(func(): _show(_index - 1))
	bar.add_child(_back)
	_next.theme_type_variation = "ButtonPrimary"
	_next.pressed.connect(func(): _show(_index + 1))
	bar.add_child(_next)


func _ready() -> void:
	_box.resized.connect(_place_box)
	_rect = Rect2(get_viewport_rect().size / 2.0, Vector2.ZERO)
	_show(0)
	UIFx.fade_in(self, 0.3)


func _process(delta: float) -> void:
	_pulse += delta
	_rect.position = _rect.position.lerp(_target_rect.position, minf(1.0, delta * 9.0))
	_rect.size = _rect.size.lerp(_target_rect.size, minf(1.0, delta * 9.0))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_show(_index + 1)
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_show(_index - 1)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _draw() -> void:
	var vs := size
	var dim := Color(0.01, 0.0, 0.02, 0.72)
	if _rect.size.length() < 2.0:
		draw_rect(Rect2(Vector2.ZERO, vs), dim)
		return
	var r := _rect
	# vier Rechtecke um das „Loch“ herum
	draw_rect(Rect2(0, 0, vs.x, r.position.y), dim)
	draw_rect(Rect2(0, r.end.y, vs.x, vs.y - r.end.y), dim)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, vs.x - r.end.x, r.size.y), dim)
	var glow := 0.5 + 0.5 * sin(_pulse * 3.0)
	for i in 4:
		draw_rect(r.grow(2 + i * 3), Color(Palette.GOLD, (0.5 - i * 0.12) * (0.6 + 0.4 * glow)), false, 2.0)


func _show(i: int) -> void:
	if i >= steps.size():
		_finish()
		return
	_index = clampi(i, 0, steps.size() - 1)
	var st: Dictionary = steps[_index]
	var speaker: String = st.get("speaker", "albedo")
	_portrait.char_id = speaker
	_portrait.variant = st.get("variant", "")
	var col := Content.char_color(speaker)
	_name.text = Content.char_data(speaker).get("name", "").to_upper()
	_name.add_theme_color_override("font_color", col)
	_title.text = st.get("title", "")
	_text.text = Game.fmt(st.get("text", ""))
	UIFx.typewriter(_text, 220.0)
	_counter.text = "%d / %d" % [_index + 1, steps.size()]
	_back.disabled = _index == 0
	_next.text = "Verstanden  ⟶" if _index == steps.size() - 1 else "Weiter  ⟶"
	_target_rect = _rect_of(st.get("target"))
	if _rect.size.length() < 2.0:
		_rect = Rect2(_target_rect.get_center(), Vector2.ZERO)
	_box.size = Vector2.ZERO  # neu auf Mindestgröße schrumpfen → resized → _place_box
	await get_tree().process_frame
	await get_tree().process_frame
	_place_box()
	UIFx.pop_in(_box, 0.22)
	Audio.sfx("page", 0.5)


func _rect_of(target: Variant) -> Rect2:
	var list: Array = []
	if target is Control:
		list = [target]
	elif target is Array:
		list = target
	var out := Rect2()
	var first := true
	for c in list:
		if c is Control and is_instance_valid(c) and c.is_visible_in_tree():
			var gr: Rect2 = c.get_global_rect()
			out = gr if first else out.merge(gr)
			first = false
	return out.grow(6) if not first else Rect2()


## Sprechblase neben dem hervorgehobenen Bereich platzieren (nie darüber).
func _place_box() -> void:
	var vs := size
	var bs := _box.size.max(_box.get_combined_minimum_size())
	var t := _target_rect
	var pos: Vector2
	if t.size.length() < 2.0:
		pos = (vs - bs) / 2.0
	elif t.end.y + bs.y + 20 < vs.y:
		pos = Vector2(t.get_center().x - bs.x / 2.0, t.end.y + 16)
	elif t.position.y - bs.y - 20 > 0:
		pos = Vector2(t.get_center().x - bs.x / 2.0, t.position.y - bs.y - 16)
	elif t.end.x + bs.x + 20 < vs.x:
		pos = Vector2(t.end.x + 16, t.get_center().y - bs.y / 2.0)
	else:
		pos = Vector2(t.position.x - bs.x - 16, t.get_center().y - bs.y / 2.0)
	pos.x = clampf(pos.x, 12, vs.x - bs.x - 12)
	pos.y = clampf(pos.y, 12, vs.y - bs.y - 12)
	_box.position = pos


func _finish() -> void:
	if is_queued_for_deletion():
		return
	Settings.tutorial_done = true
	Settings.save()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	finished.emit()
	queue_free()

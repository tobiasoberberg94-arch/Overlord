class_name Overlay
extends Control
## Basisklasse für modale Fenster (Berichte, Auftragstafel, Charakteransicht …).
## Dunkelt den Hintergrund ab, zeigt ein zentrales Panel mit Einblend-Animation
## und schließt per ESC (sofern [member closable]).

signal closed

var panel := PanelContainer.new()
var content := VBoxContainer.new()
var closable := true
var frame_texture: Texture2D:
	set(v):
		frame_texture = v
		_frame_box = null
var _frame_box: StyleBoxTexture
var _dim := ColorRect.new()


func _init(panel_size: Vector2 = Vector2(1100, 720), variation: String = "PanelOrnate") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("ui_overlay")
	_dim.color = Color(0.01, 0.0, 0.02, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel.theme_type_variation = variation
	panel.custom_minimum_size = panel_size
	center.add_child(panel)
	# Ornamentaler Goldrahmen + dunkles Muster aus assets/ui (falls vorhanden)
	frame_texture = Palette.frame("frame_gold")
	var pattern: Texture2D = Content.find_image("ui/frames", "pattern_dark")
	if frame_texture and pattern and variation == "PanelOrnate":
		var sb := StyleBoxTexture.new()
		sb.texture = pattern
		sb.modulate_color = Color(0.75, 0.7, 0.8)
		sb.content_margin_left = 98
		sb.content_margin_right = 98
		sb.content_margin_top = 84
		sb.content_margin_bottom = 88
		panel.add_theme_stylebox_override("panel", sb)
		panel.draw.connect(_draw_frame)
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)


## Rahmen wird über den Hintergrund des Panels gezeichnet (unter dem Inhalt).
## 9-Slice: Ecken in Originalgröße, Kanten gekachelt – unabhängig von der Panelgröße.
func _draw_frame() -> void:
	if frame_texture == null:
		return
	if _frame_box == null:
		_frame_box = StyleBoxTexture.new()
		_frame_box.texture = frame_texture
		var ts := frame_texture.get_size()
		_frame_box.texture_margin_left = ts.x * 0.16
		_frame_box.texture_margin_right = ts.x * 0.16
		_frame_box.texture_margin_top = ts.y * 0.2
		_frame_box.texture_margin_bottom = ts.y * 0.2
		_frame_box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		_frame_box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		_frame_box.draw_center = false
	panel.draw_rect(Rect2(Vector2(14, 14), panel.size - Vector2(28, 28)), Color(0.02, 0.0, 0.04, 0.5))
	panel.draw_style_box(_frame_box, Rect2(Vector2(-22, -22), panel.size + Vector2(44, 44)))


func _ready() -> void:
	UIFx.fade_in(_dim, 0.25)
	Pad.changed.connect(func(on: bool): if on: _focus_first())
	await get_tree().process_frame
	UIFx.pop_in(panel, 0.3)
	_focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if closable and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Controller: den ersten Knopf fokussieren (Steuerkreuz/Stick wandern dann, A drückt, B schließt), Listen folgen dem Fokus.
func _focus_first() -> void:
	if not is_inside_tree() or _closing:
		return
	for sc in find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).follow_focus = true
	if not Pad.active:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and is_ancestor_of(owner):
		return
	var b := _first_button(self)
	if b:
		b.grab_focus()


func _first_button(n: Node) -> BaseButton:
	for c in n.get_children():
		if c is BaseButton:
			var b := c as BaseButton
			if b.visible and not b.disabled and b.focus_mode != Control.FOCUS_NONE and b.text != "✕":
				return b
		if c is Control and not (c as Control).visible:
			continue
		var deeper := _first_button(c)
		if deeper:
			return deeper
	return null


var _closing := false


func close() -> void:
	# Doppeltes Schließen (z. B. ESC während einer automatischen Schließung) ignorieren
	if _closing or is_queued_for_deletion():
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(panel, "scale", Vector2(0.96, 0.96), 0.18)
	await tw.finished
	closed.emit()
	queue_free()


## Kopfzeile mit Titel, optionalem Untertitel und Schließen-Knopf.
func make_header(title: String, subtitle: String = "") -> HBoxContainer:
	var hb := HBoxContainer.new()
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "HeaderLabel"
	t.add_theme_font_size_override("font_size", 26)
	vb.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.theme_type_variation = "SubHeaderLabel"
		vb.add_child(s)
	hb.add_child(vb)
	if closable:
		var x := Button.new()
		x.text = "✕"
		x.theme_type_variation = "ButtonGhost"
		x.tooltip_text = "Schließen (ESC)"
		x.pressed.connect(close)
		hb.add_child(x)
	return hb


## Kleine farbige „Chips“ für Effekt-Zusammenfassungen ([Label, Delta]-Paare).
static func effect_chips(summary: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for pair in summary:
		var delta: int = int(pair[1])
		var label: String = pair[0]
		var good := delta > 0
		# Mehr Aufmerksamkeit oder Erschöpfung ist schlecht
		for bad in ["Aufmerksamkeit", "Erschöpfung"]:
			if bad in label:
				good = not good
		var chip := PanelContainer.new()
		var col := Palette.SUCCESS if good else Palette.DANGER
		chip.add_theme_stylebox_override("panel", NazarickTheme.box(Color(col, 0.12), Color(col, 0.6), 1, 12, Color.TRANSPARENT, 0, 4))
		var l := Label.new()
		l.text = "%s %s%d" % [label, "+" if delta > 0 else "", delta]
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", col.lightened(0.3))
		chip.add_child(l)
		flow.add_child(chip)
	return flow

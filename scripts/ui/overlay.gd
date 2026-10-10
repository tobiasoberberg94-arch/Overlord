class_name Overlay
extends Control
## Basisklasse für modale Fenster (Berichte, Auftragstafel, Charakteransicht …).
## Dunkelt den Hintergrund ab, zeigt ein zentrales Panel mit Einblend-Animation
## und schließt per ESC (sofern [member closable]).

signal closed

var panel := PanelContainer.new()
var content := VBoxContainer.new()
var closable := true
var _dim := ColorRect.new()


func _init(panel_size: Vector2 = Vector2(1100, 720), variation: String = "PanelOrnate") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color = Color(0.01, 0.0, 0.02, 0.78)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel.theme_type_variation = variation
	panel.custom_minimum_size = panel_size
	center.add_child(panel)
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)


func _ready() -> void:
	UIFx.fade_in(_dim, 0.25)
	await get_tree().process_frame
	UIFx.pop_in(panel, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if closable and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
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
		# Mehr Aufmerksamkeit, Eifersucht, Rivalität oder Erschöpfung sind schlecht
		for bad in ["Aufmerksamkeit", "Eifersucht", "Rivalität", "Erschöpfung"]:
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

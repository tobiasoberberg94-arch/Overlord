class_name ChoiceMenu
extends Overlay
## Kleines Auswahlfenster (Kriegsrat, Thron, Gate, Pausenmenü …).
## entries: [{text, sub?, action: Callable, disabled?: bool, tip?: String, icon?: String}]

var _list := VBoxContainer.new()


func _init(title: String, subtitle: String, entries: Array, width: float = 760.0, portrait_id: String = "") -> void:
	super._init(Vector2(width, 0))
	content.add_child(make_header(title, subtitle))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	if portrait_id != "":
		var p := Portrait.new()
		p.char_id = portrait_id
		p.custom_minimum_size = Vector2(170, 230)
		row.add_child(p)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = mini(entries.size(), 7) * 76
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)
	row.add_child(sc)
	for e in entries:
		var b := Button.new()
		b.text = e.text + ("\n" + e.sub if e.get("sub", "") != "" else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 54
		b.disabled = e.get("disabled", false)
		b.tooltip_text = e.get("tip", "")
		b.theme_type_variation = e.get("style", "Button")
		var act: Callable = e.action
		b.pressed.connect(func():
			await close()
			act.call())
		_list.add_child(b)


func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	if _list.get_child_count() > 0 and is_instance_valid(_list.get_child(0)):
		(_list.get_child(0) as Button).grab_focus()

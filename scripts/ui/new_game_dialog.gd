class_name NewGameDialog
extends Overlay
## Neues Spiel: Schwierigkeitsgrad wählen.

signal start(difficulty: String)

var _choice := "normal"
var _group := ButtonGroup.new()
var _desc := RichTextLabel.new()


func _init() -> void:
	super._init(Vector2(980, 0))
	content.add_child(make_header("Eine neue Herrschaft", "Wie gnädig ist die Neue Welt zu ihrem neuen Herrscher?"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for d in Content.systems.difficulties:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group
		b.theme_type_variation = "ButtonCard"
		b.custom_minimum_size = Vector2(440, 96)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s\n%s" % [d.name.to_upper(), d.desc]
		b.button_pressed = d.id == _choice
		b.pressed.connect(func(): _choice = d.id; _update())
		grid.add_child(b)
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.scroll_active = false
	_desc.add_theme_font_size_override("normal_font_size", 17)
	content.add_child(_desc)
	var go := Button.new()
	go.text = "⚜  Das Große Grab erwacht  ⚜"
	go.theme_type_variation = "ButtonPrimary"
	go.custom_minimum_size.y = 56
	go.pressed.connect(func(): start.emit(_choice); close())
	content.add_child(go)
	_update()


func _update() -> void:
	var d := Content.difficulty(_choice)
	_desc.text = "[color=#d4af37]Startgold:[/color] %d   ·   [color=#d4af37]Einkünfte:[/color] %d %%   ·   [color=#d4af37]Unterhalt:[/color] %d %%   ·   [color=#d4af37]Bedrohungen:[/color] %d %%   ·   [color=#d4af37]Feindstärke:[/color] %d %%" % [
		int(d.gold), roundi(float(d.income) * 100), roundi(float(d.upkeep) * 100), roundi(float(d.threat) * 100), roundi(float(d.enemy) * 100)]

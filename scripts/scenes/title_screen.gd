extends Control
## Titelbildschirm: „AINZ OOAL GOWN“ in Gold, animierter Hintergrund, Hauptmenü.

const THRONE_SCENE := "res://scenes/throne_room.tscn"

var _title := Label.new()
var _menu := VBoxContainer.new()


func _ready() -> void:
	add_child(NazarickBackground.new("title" if Content.find_image("backgrounds", "title") else "nazarick_exterior", false, 0.3))
	Audio.play_music("title")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var crest := Portrait.new()
	crest.char_id = "ainz"
	crest.show_symbol = false
	crest.custom_minimum_size = Vector2(170, 200)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(crest)

	var pre := Label.new()
	pre.text = "DAS GROSSE GRAB VON NAZARICK"
	pre.theme_type_variation = "SubHeaderLabel"
	pre.add_theme_font_size_override("font_size", 18)
	pre.add_theme_color_override("font_color", Palette.MUTED)
	pre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pre)

	_title.text = "AINZ OOAL GOWN"
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	var sub := Label.new()
	sub.text = "— Herrscher von Nazarick —"
	sub.add_theme_font_override("font", NazarickTheme.italic_font(600))
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Palette.GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	vb.add_child(spacer)

	_menu.add_theme_constant_override("separation", 10)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_menu)
	if SaveSystem.has_any_save():
		_add_button("Fortsetzen", "ButtonPrimary", _on_continue)
	_add_button("Neues Spiel", "ButtonPrimary" if not SaveSystem.has_any_save() else "Button", _on_new)
	_add_button("Chronik laden", "Button", _on_load)
	_add_button("Optionen", "Button", func(): add_child(SettingsDialog.new(false)))
	_add_button("Nazarick verlassen", "ButtonGhost", func(): get_tree().quit())

	var foot := Label.new()
	foot.text = "Fan-Projekt · inspiriert von „Overlord“ (Kugane Maruyama) · Platzhalter-Grafiken können durch eigene Artworks ersetzt werden"
	foot.theme_type_variation = "MutedLabel"
	foot.add_theme_font_size_override("font_size", 14)
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position.y -= 34
	foot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(foot)

	# Einblendungen
	UIFx.fade_in(crest, 1.2)
	UIFx.fade_in(pre, 1.0, 0.3)
	UIFx.fade_in(_title, 1.4, 0.5)
	UIFx.fade_in(sub, 1.0, 1.0)
	var i := 0
	for b in _menu.get_children():
		UIFx.fade_in(b, 0.5, 1.4 + i * 0.12)
		i += 1
	# Goldenes Glühen des Titels
	_title.add_theme_color_override("font_outline_color", Color("2a0a3a"))
	var tw := create_tween().set_loops()
	tw.tween_property(_title, "theme_override_colors/font_outline_color", Color("5b0010"), 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title, "theme_override_colors/font_outline_color", Color("2a0a3a"), 1.8).set_trans(Tween.TRANS_SINE)


func _add_button(text: String, variation: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	_menu.add_child(b)
	UIFx.add_hover_scale(b, 1.05)


func _on_new() -> void:
	var dlg := NewGameDialog.new()
	dlg.start.connect(func(diff): Game.new_game(diff); _go())
	add_child(dlg)


func _on_continue() -> void:
	# Neuester Spielstand
	var best := -1
	var best_time := ""
	for i in range(0, SaveSystem.SLOTS + 1):
		var m := SaveSystem.slot_meta(i)
		if not m.is_empty() and str(m.get("saved_at", "")) > best_time:
			best_time = str(m.saved_at)
			best = i
	if best > 0 and SaveSystem.load_game(best):
		_go()


func _on_load() -> void:
	var dlg := SaveLoadDialog.new(false)
	dlg.loaded.connect(_go)
	add_child(dlg)


func _go() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	await tw.finished
	get_tree().change_scene_to_file(THRONE_SCENE)

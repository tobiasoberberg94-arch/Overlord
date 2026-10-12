extends Node3D
## Titelbildschirm in 3D: Kamerafahrt über den roten Teppich des Thronsaals,
## Ainz vor dem Thron, die Wächter säumen die Halle. Hauptmenü links.

const WORLD_SCENE := "res://scenes/world_3d.tscn"

var ui := CanvasLayer.new()
var ui_root := Control.new()
var _menu := VBoxContainer.new()
var _title := Label.new()
var _cam := Camera3D.new()
var _t := 0.0
var _rigs: Array[CharacterRig] = []


func _ready() -> void:
	Audio.play_music("title")
	_build_scene()
	_build_ui()


func _build_scene() -> void:
	var loc: Dictionary = Content.location_by_id["throne"]
	LocationBuilder.environment(self, loc, LocationBuilder.preset("throne"))
	var a := LocationBuilder.build(loc, self)
	# Ainz vor dem Thron
	var ainz := CharacterRig.create("ainz", func(r): ProcModel.ainz(r))
	ainz.position = a.throne + Vector3(0, 0, 0.6)
	add_child(ainz)
	_rigs.append(ainz)
	# Wächter beidseits des Teppichs, zum Thron gewandt
	var ids := ["albedo", "demiurge", "shalltear", "cocytus", "aura", "mare", "sebas", "pandora", "narberal"]
	for i in ids.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var r := CharacterRig.create(ids[i], func(rr): ProcModel.figure(rr, ids[i]))
		r.position = Vector3(2.8 * side, 0, -16.0 + (i / 2) * 3.4)
		r.rotation.y = PI + side * 0.35
		add_child(r)
		_rigs.append(r)
	B3.light(self, a.throne + Vector3(0, 4, 4), Color(0.9, 0.6, 1.0), 3.0, 14.0)
	_cam.fov = 55.0
	_cam.far = 300.0
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta
	# Langsame, endlose Fahrt den Teppich entlang mit leichtem Schwenk
	var k := fmod(_t * 0.035, 1.0)
	var z := lerpf(4.0, -13.0, ease(k, -1.6))
	_cam.position = Vector3(1.2 + sin(_t * 0.15) * 1.2, 2.4 + sin(_t * 0.2) * 0.3, z)
	_cam.look_at(Vector3(0, 2.2, -24.0))
	for r in _rigs:
		r.pose(Fighter.S.IDLE, "", 0.0, 0.0)


func _build_ui() -> void:
	add_child(ui)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.theme = load("res://assets/ui/nazarick_theme.tres")
	ui.add_child(ui_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 620
	shade.color = Color(0.01, 0.0, 0.02, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(shade)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	vb.offset_left = 80
	vb.offset_right = 600
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	ui_root.add_child(vb)
	var pre := Label.new()
	pre.text = "DAS GROSSE GRAB VON NAZARICK"
	pre.theme_type_variation = "SubHeaderLabel"
	pre.add_theme_font_size_override("font_size", 18)
	vb.add_child(pre)
	_title.text = "AINZ OOAL GOWN"
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_constant_override("outline_size", 6)
	vb.add_child(_title)
	var sub := Label.new()
	sub.text = "— Herrscher von Nazarick —"
	sub.add_theme_font_override("font", NazarickTheme.italic_font(600))
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Palette.GOLD)
	vb.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size.y = 26
	vb.add_child(sp)
	_menu.add_theme_constant_override("separation", 10)
	vb.add_child(_menu)
	if SaveSystem.has_any_save():
		_add_button("Fortsetzen", "ButtonPrimary", _on_continue)
	_add_button("Neues Spiel", "ButtonPrimary" if not SaveSystem.has_any_save() else "Button", _on_new)
	_add_button("Chronik laden", "Button", _on_load)
	_add_button("Optionen", "Button", func(): ui_root.add_child(SettingsDialog.new(false)))
	_add_button("Nazarick verlassen", "ButtonGhost", func(): get_tree().quit())
	var foot := Label.new()
	foot.text = "Fan-Projekt · inspiriert von „Overlord“ (Kugane Maruyama)"
	foot.theme_type_variation = "MutedLabel"
	foot.add_theme_font_size_override("font_size", 14)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 80
	foot.offset_top = -50
	ui_root.add_child(foot)
	UIFx.fade_in(vb, 1.4, 0.3)
	_title.add_theme_color_override("font_outline_color", Color("2a0a3a"))
	var tw := create_tween().set_loops()
	tw.tween_property(_title, "theme_override_colors/font_outline_color", Color("5b0010"), 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title, "theme_override_colors/font_outline_color", Color("2a0a3a"), 1.8).set_trans(Tween.TRANS_SINE)


func _add_button(text: String, variation: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(360, 52)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	_menu.add_child(b)
	UIFx.add_hover_scale(b, 1.04)


func _on_new() -> void:
	var dlg := NewGameDialog.new()
	dlg.start.connect(func(diff): Game.new_game(diff); _go())
	ui_root.add_child(dlg)


func _on_continue() -> void:
	var best := -1
	var best_time := ""
	for i in range(0, SaveSystem.SLOTS + 1):
		var m := SaveSystem.slot_meta(i)
		if not m.is_empty() and str(m.get("saved_at", "")) > best_time:
			best_time = str(m.saved_at)
			best = i
	if best >= 0 and SaveSystem.load_game(best):
		_go()


func _on_load() -> void:
	var dlg := SaveLoadDialog.new(false)
	dlg.loaded.connect(_go)
	ui_root.add_child(dlg)


func _go() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	await tw.finished
	get_tree().change_scene_to_file(WORLD_SCENE)

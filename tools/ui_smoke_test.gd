extends Node
## UI-Rauchtest: lädt Titel und Thronsaal, öffnet alle Fenster, beantwortet
## Depeschen, lässt Zeit vergehen und speichert Screenshots (falls ein
## Renderer verfügbar ist). Aufruf:
##   godot --path . res://tools/ui_smoke_test.tscn         (mit Fenster → Screenshots)
##   godot --headless --path . res://tools/ui_smoke_test.tscn

var shots_dir := "res://tools/screenshots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	var title: Node = load("res://scenes/title_screen.tscn").instantiate()
	get_tree().root.add_child.call_deferred(title)
	await _wait(2.6)
	_shot("01_title")
	title.queue_free()
	Game.rng.seed = 7
	Game.new_game()
	var throne: Node = load("res://scenes/throne_room.tscn").instantiate()
	get_tree().root.add_child(throne)
	await _wait(1.6)
	_shot("02_chapter_intro")
	# Kapitel-Intro beantworten → Tutorial startet automatisch
	await _answer_open_dialog(throne)
	await _wait(1.0)
	var tut = throne.overlay_layer.get_child(0) if throne.overlay_layer.get_child_count() > 0 else null
	assert(tut is TutorialOverlay, "Tutorial sollte nach dem Intro starten")
	await _wait(1.2)
	_shot("02b_tutorial_start")
	for step in [1, 3, 5, 9]:
		tut._show(step)
		await _wait(1.6)
		_shot("02c_tutorial_%02d" % step)
	tut._finish()
	await _wait(0.8)
	assert(Settings.tutorial_done)
	for i in 2:
		await _answer_open_dialog(throne)
	await _wait(0.8)
	_shot("03_throne_room")
	# Auftragstafel
	throne._open_missions()
	await _wait(0.9)
	_shot("04_mission_board")
	var board: MissionBoard = throne.overlay_layer.get_child(0)
	board._on_confirm()
	board._select_mission(board._mission_id) if board._mission_id != "" else null
	board._on_confirm()
	await _wait(0.3)
	board.close()
	await _wait(0.5)
	# Charakteransicht + Audienz
	throne._open_characters("albedo")
	await _wait(0.9)
	var cv: CharacterView = throne.overlay_layer.get_child(0)
	cv._audience("talk")
	await _wait(1.2)
	_shot("05_character_albedo")
	cv._show("shalltear")
	await _wait(0.5)
	_shot("06_character_shalltear")
	cv.close()
	await _wait(0.5)
	# Zeit vergehen lassen, bis ein Bericht eintrifft
	var shot_event := false
	for i in 14:
		if throne.overlay_layer.get_child_count() > 0:
			var dlg = throne.overlay_layer.get_child(0)
			if dlg is DispatchDialog and dlg.dispatch.kind == "report":
				await _wait(3.5)
				_shot("07_report")
				dlg._choose("praise")
				await _wait(2.0)
				_shot("08_report_reaction")
				break
			if dlg is DispatchDialog and not shot_event:
				shot_event = true
				await _wait(3.0)
				_shot("07_event")
			await _answer_open_dialog(throne)
			continue
		throne._advance(7)
		await _wait(1.8)
	for i in 12:
		await _answer_open_dialog(throne)
	await _wait(0.5)
	_shot("09_throne_later")
	throne._open_settings()
	await _wait(0.8)
	_shot("11_settings")
	throne.overlay_layer.get_child(0).close()
	await _wait(0.5)
	# Wiederholbare Aufträge dürfen nach Abschluss nicht sofort wieder erscheinen
	var m := Game.mission("s_training")
	Game.state.completed["s_training"] = 1
	Game.state.completed_day["s_training"] = Game.state.day
	assert(not Game.mission_available(m), "Wiederholbarer Auftrag sollte in der Abklingzeit sein")
	Game.state.completed_day["s_training"] = Game.state.day - Game.REPEAT_COOLDOWN
	assert(Game.mission_available(m) and Game.mission_badge(m) == "repeat")
	throne._open_overlay(ChronicleView.new())
	await _wait(0.8)
	_shot("10_chronicle")
	print("UI-RAUCHTEST OK – Tag ", Game.state.day, ", Kapitel ", Game.state.chapter)
	get_tree().quit()


func _answer_open_dialog(throne: Node) -> void:
	if throne.overlay_layer.get_child_count() == 0:
		return
	var dlg = throne.overlay_layer.get_child(0)
	if dlg is TutorialOverlay:
		dlg._finish()
	elif dlg is DispatchDialog:
		dlg._choose(dlg.dispatch.options[0].key)
		await _wait(0.3)
		if is_instance_valid(dlg):
			dlg.close()
	else:
		dlg.close()
	await _wait(0.7)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(shots_dir + name + ".png"))
	print("Screenshot: ", name)

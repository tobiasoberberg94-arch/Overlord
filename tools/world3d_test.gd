extends Node
## 3D-Rauchtest: besucht jeden begehbaren Ort, läuft ein Stück, spricht Figuren an,
## öffnet die Menüs und speichert Screenshots (mit Fenster). Aufruf:
##   godot --path . res://tools/world3d_test.tscn

var shots_dir := "res://tools/screenshots3d/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	Settings.tutorial_done = true
	Game.rng.seed = 11
	Game.new_game()
	# Fortgeschrittener Spielstand: alle Regionen entdeckt, einige Wächter im Einsatz
	Game.state.chapter = 10
	for r in Content.regions:
		World.apply_region_effects({r.id: {"discover": true, "influence": 30}})
	for cid in ["shalltear", "cocytus", "aura", "mare", "sebas", "narberal", "pandora"]:
		Game.apply_effects({"unlock_chars": [cid]})
	Game.state.dispatches.clear()
	var w: Node = load("res://scenes/world_3d.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await _wait(2.5)
	for c in w.overlay_layer.get_children():
		c.queue_free()
	var only := OS.get_environment("LOC")
	for l in Content.locations:
		if only != "" and l.id != only:
			continue
		await w.load_location(l.id)
		await _wait(0.6)
		# ein paar Schritte vorwärts
		w.player.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		await _wait(0.8)
		Input.action_release("move_forward")
		await _wait(0.5)
		_shot("loc_%s" % l.id)
		print("Ort OK: ", l.id, " – Figuren: ", w.actors.size(), " Position ", w.player.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
	if only == "":
		await w.load_location("throne")
		await _wait(0.5)
		# zu Albedo laufen (Teleport in die Nähe) und ansprechen
		for a in w.actors:
			if a.id == "albedo":
				w.player.global_position = a.global_position + Vector3(0, 0.2, 2.0)
				w.player.cam_yaw = 0.0
		await _wait(0.6)
		_shot("throne_near_albedo")
		assert(w._focus != null, "Eine Figur sollte im Fokus sein")
		w._interact(w._focus)
		await _wait(1.2)
		_shot("throne_audience")
		w.overlay_layer.get_child(0).close()
		await _wait(0.5)
		w._war_table()
		await _wait(0.8)
		_shot("menu_war_table")
		w.overlay_layer.get_child(0).close()
		await _wait(0.5)
		w._gate_menu()
		await _wait(0.8)
		_shot("menu_gate")
		w.overlay_layer.get_child(0).close()
		await _wait(0.5)
		w._advance(3)
		await _wait(2.5)
		_shot("after_time")
		SaveSystem.save_game(3)
		assert(SaveSystem.load_game(3))
		assert(Game.state.world3d.loc == "throne")
	print("3D-RAUCHTEST OK")
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(shots_dir + n + ".png"))

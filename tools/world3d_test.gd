extends Node
## 3D-Rauchtest: besucht jeden begehbaren Ort, läuft ein Stück, spricht Figuren an,
## öffnet die Menüs und speichert Screenshots (mit Fenster). Aufruf:
##   godot --path . res://tools/world3d_test.tscn

var shots_dir := "res://tools/screenshots3d/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	Settings.tutorial_done = true
	if OS.get_environment("RSCALE") != "":
		Settings.render_scale = int(OS.get_environment("RSCALE"))
		Settings.antialias = 2
		Settings.apply_all()
	var only_env := OS.get_environment("LOC")
	if only_env == "gallery":
		await _gallery()
		get_tree().quit()
		return
	if only_env == "" or only_env == "title" or only_env == "ui":
		var title: Node = load("res://scenes/title_screen.tscn").instantiate()
		get_tree().root.add_child.call_deferred(title)
		await _wait(3.0)
		_shot("title_3d")
		title.queue_free()
		await _wait(0.3)
		if only_env == "title":
			get_tree().quit()
			return
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
	if only == "guardian":
		await _guardian_test(w)
		get_tree().quit()
		return
	if only == "quest":
		await _quest_test(w)
		get_tree().quit()
		return
	if only == "compare":
		await _compare(w)
		get_tree().quit()
		return
	for l in Content.locations:
		if only != "" and l.id != only and not (only == "ui" and l.id == "throne"):
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
		if OS.get_environment("DISC") != "":
			await _wait(1.0)
			var ds: Array = w.quest_world.pickups.filter(func(p): return p.kind in ["lore", "shrine", "cache"])
			print("ENTDECKUNGEN %s: %d (%s)" % [l.id, ds.size(), ", ".join(ds.map(func(p): return p.kind + ":" + p.label))])
			for p in ds:
				if p.kind == "lore":
					w.player.global_position = p.global_position + Vector3(0, 0.3, 2.2)
					await _wait(1.0)
					_shot("disc_" + l.id)
					w.quest_world.collect(p)
					await _wait(1.5)
					_shot("disc_read_" + l.id)
					w.overlay_layer.get_child(0).close()
					break
		if OS.get_environment("SHOTCAM") != "":
			var v: PackedFloat64Array = PackedFloat64Array(Array(OS.get_environment("SHOTCAM").split(",")).map(func(x): return float(x)))
			var cam := Camera3D.new()
			cam.far = 3000.0
			cam.fov = 70.0
			w.add_child(cam)
			cam.look_at_from_position(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]))
			cam.current = true
			for c in w.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = false
			await _wait(2.5)
			_shot("cam_%s" % l.id)
			for c in w.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = true
			cam.queue_free()
			w.player.camera.current = true
		print("Ort OK: ", l.id, " – Figuren: ", w.actors.size(), " Position ", w.player.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " FPS ", Engine.get_frames_per_second(),
			" | Objekte ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			" Dreiecke ", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			" DrawCalls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" VRAM ", int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576), " MB")
		if OS.get_environment("PERF") != "":
			_perf_detail(w)
		if OS.get_environment("CPU") != "":
			await _cpu_profile(w)
	if only == "" or only == "combat" or only == "ui":
		# Kampf auf der Katze-Ebene
		await w.load_location("katze")
		await _wait(0.5)
		assert(w.enemies.size() >= 5, "Gegner sollten erscheinen")
		var e: Enemy3D = w.enemies[0]
		w.player.global_position = e.global_position + Vector3(0, 0.2, 6)
		w.player.face(0.0)
		await _wait(1.5)
		w.player.toggle_lock()
		w.player.cast("fireball")
		await _wait(0.5)
		_shot("combat_fireball")
		w.player.request("light")
		await _wait(0.25)
		_shot("combat_attack")
		await _wait(1.5)
		_shot("combat_enemies")
		w.player.set_style("momon")
		await _wait(0.4)
		w.player.request("heavy")
		await _wait(0.45)
		_shot("combat_momon")
		await _wait(1.5)
		w.player.set_style("ainz")
		print("Kampf OK – Gegner übrig: ", w.enemies.size(), " Leben Ainz: ", int(w.player.hp))
	if only == "" or only == "ui":
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
		await _wait(2.5)
		_shot("throne_audience_3d_portrait")
		w.overlay_layer.get_child(0).close()
		await _wait(0.5)
		w._open_map()
		await _wait(2.0)
		_shot("map_table_3d")
		w.overlay_layer.get_child(0).close()
		await _wait(0.5)
		if only == "ui":
			for v in [["view_missions", MissionBoard.new("")], ["view_admin", AdministrationView.new()], ["view_nazarick", NazarickView.new()],
					["view_diplomacy", DiplomacyView.new()], ["view_chronicle", ChronicleView.new()], ["view_settings", SettingsDialog.new(true)]]:
				w._open(v[1])
				if v[0] == "view_settings":
					var tabs: TabContainer = v[1].find_children("*", "TabContainer", true, false)[0]
					tabs.current_tab = tabs.get_tab_count() - 1
				await _wait(1.6)
				_shot(v[0])
				if is_instance_valid(v[1]):
					v[1].close()
				await _wait(0.5)
		w._open(TalkDialog.new("shalltear", "Mein Gebieter! Wenn Ihr mich lobt statt dieser gehörnten Kuh, schwöre ich Euch ewige Treue – ~arinsu!"))
		await _wait(2.5)
		_shot("talk_dialog")
		w.overlay_layer.get_child(0).close()
		await _wait(0.5)
		# Schlacht persönlich anführen
		var army := Military.create_army()
		for u in ["death_knight", "skeleton"]:
			Military.recruit(army.uid, u)
		army.location = "katze"
		Game.state.dispatches.clear()
		Military._create_battle(army, {"name": "Adelsheer des Königreichs", "strength": 160, "uid": ""}, "defense")
		var buid: String = Game.state.battles.keys()[0]
		w._open_next_dispatch(true)
		await _wait(1.0)
		_shot("battle_dispatch")
		var dd = null
		for c in w.overlay_layer.get_children():
			if c is DispatchDialog:
				dd = c
			else:
				print("Weiteres Fenster offen: ", c.get_class(), " ", c.get_script().resource_path)
		assert(dd != null, "Schlacht-Depesche sollte offen sein")
		dd._choose("lead")
		await _wait(0.4)
		if is_instance_valid(dd):
			dd.close()
		await _wait(2.5)
		assert(w._battle.get("uid", "") == buid, "Persönliche Schlacht sollte laufen")
		_shot("battle_personal")
		for e in w._battle.enemies:
			if is_instance_valid(e):
				e.take_hit({"amount": 9999.0, "type": "physical"}, w.player)
		await _wait(1.0)
		assert(not Game.state.battles.has(buid), "Schlacht sollte entschieden sein")
		print("Persönliche Schlacht OK: ", Military.last_result.get("won", false))
		await w.load_location("throne")
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


## Questablauf: annehmen (NPC), sammeln, töten + Beute, abgeben, Questbuch.
func _quest_test(w: Node) -> void:
	Game.state.chapter = 2
	await w.load_location("carne")
	await _wait(1.5)
	var nf: Actor3D = null
	for a in w.actors:
		if a.id == "nfirea":
			nf = a
	assert(nf != null, "Nfirea sollte in Carne stehen")
	print("QUEST Marker Nfirea: '%s'" % Quests.marker_for("nfirea"))
	w.player.global_position = nf.global_position + Vector3(0, 0.2, 2.2)
	w.player.cam_yaw = 0.0
	await _wait(1.0)
	_shot("quest_giver")
	w._interact(nf)
	await _wait(1.5)
	_shot("quest_offer")
	var dlg = w.overlay_layer.get_child(0)
	for b in dlg.find_children("*", "Button", true, false):
		if (b as Button).text.contains("annehmen"):
			(b as Button).pressed.emit()
	await _wait(1.0)
	assert(Quests.is_active("q_carne_herbs"), "Quest sollte laufen")
	# Wald von Tob: Mondkraut sammeln
	await w.load_location("tob_wald")
	await _wait(2.0)
	var herbs: Array = w.quest_world.pickups.filter(func(p): return p.entries[0][0] == "moonleaf")
	print("QUEST Sammelstellen in Tob: %d (Mondkraut %d)" % [w.quest_world.pickups.size(), herbs.size()])
	if not herbs.is_empty():
		w.player.global_position = herbs[0].global_position + Vector3(0, 0.3, 1.2)
		await _wait(1.0)
		_shot("quest_pickup")
	for p in herbs.slice(0, 8):
		w.quest_world.collect(p)
	await _wait(0.5)
	print("QUEST Mondkraut im Beutel: %d · Schritt: %s" % [Quests.count("moonleaf"), Quests.step_text(Quests.by_id.q_carne_herbs)])
	# Wölfe: Beute
	for e in w.enemies.duplicate():
		e.take_hit({"amount": 9999.0, "type": "physical"}, w.player)
	await _wait(1.0)
	var bags: Array = w.quest_world.pickups.filter(func(p): return p.kind == "bag")
	print("QUEST Beutebeutel nach Wolfskampf: %d" % bags.size())
	for b in bags:
		w.quest_world.collect(b)
	print("QUEST Beutel: ", Quests.bag())
	await w.load_location("carne")
	await _wait(1.5)
	for a in w.actors:
		if a.id == "nfirea":
			nf = a
	print("QUEST Marker Nfirea vor Abgabe: '%s'" % Quests.marker_for("nfirea"))
	w._interact(nf)
	await _wait(1.0)
	dlg = w.overlay_layer.get_child(0)
	for b in dlg.find_children("*", "Button", true, false):
		if (b as Button).text.contains("Übergeben"):
			(b as Button).pressed.emit()
	await _wait(1.5)
	_shot("quest_done")
	print("QUEST Zustand: %s · Gold %d" % [Quests.state_of("q_carne_herbs"), int(Game.state.resources.gold)])
	for c in w.overlay_layer.get_children():
		c.queue_free()
	await _wait(0.3)
	w._open(QuestJournal.new())
	await _wait(1.2)
	_shot("quest_journal")
	print("QUEST-TEST " + ("OK" if Quests.state_of("q_carne_herbs") == "done" else "FEHLGESCHLAGEN"))


## Wächter-Einsatz: Cocytus gegen die Echsenmenschen.
func _guardian_test(w: Node) -> void:
	Game.state.chapter = 3
	Quests.accept(OS.get_environment("GQ") if OS.get_environment("GQ") != "" else "g_cocytus_lizards")
	var q: Dictionary = Quests.by_id[Quests.tracked]
	var loc_id: String = q.steps[0].loc
	await w.load_location(loc_id)
	await _wait(2.5)
	print("WÄCHTER Stil: %s · Gegner: %d" % [w.player.style, w.enemies.size()])
	var e0: Enemy3D = null
	for e in w.enemies:
		if e.type_id == q.steps[0].enemy:
			e0 = e
	if e0:
		w.player.global_position = e0.global_position + Vector3(0, 0.2, 5)
		w.player.face(0.0)
		await _wait(1.0)
		w.player.toggle_lock()
		w.player.cast(w.player.spells()[0])
		await _wait(0.5)
		_shot("guardian_play")
	for round in 3:
		for e in w.enemies.duplicate():
			if is_instance_valid(e) and e.type_id == Quests.step(q).get("enemy", ""):
				e.take_hit({"amount": 9999.0, "type": "physical"}, w.player)
		await _wait(2.5)
		print("WÄCHTER Schritt: %s · Stil %s · Gegner %d" % [Quests.step_text(q), w.player.style, w.enemies.size()])
	for e in w.enemies:
		if is_instance_valid(e) and e.data.get("elite", false):
			w.player.global_position = e.global_position + Vector3(0, 0.2, 5)
			await _wait(1.0)
			_shot("guardian_boss")
			break
	await _wait(3.0)
	print("WÄCHTER Ende: Stil %s · Schritt '%s'" % [w.player.style, Quests.step_text(q)])


## Renderer-Vergleich: feste Ansichten ohne Oberfläche, Dateiname mit Renderer
## (compat_… / forward_plus_…). Aufruf: LOC=compare godot --path . res://tools/world3d_test.tscn
func _compare(w: Node) -> void:
	var tag := String(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	for c in w.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await w.load_location("tombs")
	await _wait(4.0)
	_shot("cmp_%s_tombs" % tag)
	w.player.cam_yaw += PI * 0.75
	await _wait(1.0)
	_shot("cmp_%s_tombs_b" % tag)
	await w.load_location("throne")
	await _wait(4.0)
	_shot("cmp_%s_throne" % tag)
	for a in w.actors:
		if a.id == "albedo":
			w.player.global_position = a.global_position + Vector3(1.4, 0.2, 3.0)
			w.player.cam_yaw = 0.0
	await _wait(1.5)
	_shot("cmp_%s_albedo" % tag)
	await _wait(2.0)
	print("Vergleich OK: ", tag, " – FPS im Thronsaal: ", Engine.get_frames_per_second())


## CPU-Zeiten je Bild: Skripte (process), Physik, Rendering-Vorbereitung; dazu teuerste Knotentypen.
func _cpu_profile(w: Node) -> void:
	await _wait(4.0)
	var acc := {"process": 0.0, "physics": 0.0, "nav": 0.0}
	for i in 60:
		await get_tree().process_frame
		acc.process += Performance.get_monitor(Performance.TIME_PROCESS)
		acc.physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("CPU ms/Bild: Skripte %.1f · Physik %.1f · Bild gesamt %.1f · Objekte %d · Knoten %d · Physikkörper %d" % [acc.process / 60.0 * 1000.0,
		acc.physics / 60.0 * 1000.0, 1000.0 / maxf(1.0, Engine.get_frames_per_second()), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	var hist := {}
	for n in w.find_children("*", "", true, false):
		var c := n.get_class()
		hist[c] = int(hist.get(c, 0)) + 1
	var ha := []
	for k in hist:
		ha.append([hist[k], k])
	ha.sort_custom(func(a, b): return a[0] > b[0])
	print("CPU Knotentypen: ", ha.slice(0, 10))
	# Zeit der _process-Schleifen einzelner Systeme abschätzen: kurz abschalten und vergleichen
	var hud_nodes: Array = [w.hud]
	var groups := [["GrassField", "Grasfeld"], ["FoliageLod", "Laub-LOD"], ["Actor3D", "Figuren"], ["Townsfolk", "Bewohner"], ["HUD", "HUD"],
		["Pickup", "Sammelobjekte"], ["Enemy", "Gegner"], ["World", "Welt-Schleife"]]
	for grp in groups:
		var nodes: Array = w.level.find_children("*", grp[0], true, false) if grp[0] != "Actor3D" else w.actors.duplicate()
		if grp[0] == "GrassField":
			nodes = w.level.find_children("Grasfeld", "", true, false)
		if grp[0] == "FoliageLod":
			nodes = w.level.find_children("*", "", true, false).filter(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("foliage_lod.gd"))
		if grp[0] == "Townsfolk":
			nodes = w.level.find_children("Townsfolk", "", true, false)
		if grp[0] == "HUD":
			nodes = w.hud.find_children("*", "Control", true, false) + [w.hud]
		if grp[0] == "Pickup":
			nodes = w.quest_world.pickups.duplicate()
		if grp[0] == "Enemy":
			nodes = w.enemies.duplicate()
		if grp[0] == "World":
			nodes = [w]
		if nodes.is_empty():
			continue
		var base := 0.0
		for i in 40:
			await get_tree().process_frame
			base += Performance.get_monitor(Performance.TIME_PROCESS)
		for n in nodes:
			n.process_mode = Node.PROCESS_MODE_DISABLED
		var t := 0.0
		for i in 40:
			await get_tree().process_frame
			t += Performance.get_monitor(Performance.TIME_PROCESS)
		for n in nodes:
			n.process_mode = Node.PROCESS_MODE_INHERIT
		print("CPU   %-14s (%4d): mit %.1f ms → ohne %.1f ms" % [grp[1], nodes.size(), base / 40.0 * 1000.0, t / 40.0 * 1000.0])


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(shots_dir + n + ".png"))


## Alle Figuren nebeneinander + ihre Portraits aus dem Portrait-Studio.
func _gallery() -> void:
	var ids := ["ainz", "ainz_momon", "albedo", "shalltear", "demiurge", "cocytus", "aura", "mare", "sebas", "narberal", "pandora",
		"solution", "yuri", "lupusregina", "entoma", "cz", "victim", "neuronist", "gazef", "jircniv", "neia", "hamsuke", "nigun", "clementine", "platinum_dragon"]
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await _wait(0.2)
	LocationBuilder.environment(root, {}, LocationBuilder.preset("royal"))
	B3.ground(root, 30, B3.mat(Color(0.2, 0.18, 0.22)))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.6, 13), Vector3(0, 1.1, 0))
	cam.current = true
	cam.fov = 60
	for i in ids.size():
		var r := CharacterRig.create(ids[i], func(rr): ProcModel.figure(rr, ids[i]))
		r.position = Vector3((i % 13 - 6) * 1.55, 0, -(i / 13) * 3.2)
		root.add_child(r)
		r.pose(Fighter.S.IDLE, "", 0.0, 0.0)
	B3.light(root, Vector3(0, 6, 6), Color(1, 0.95, 0.9), 3.0, 30.0)
	await _wait(1.0)
	_shot("gallery_figures")
	root.queue_free()
	var grid := GridContainer.new()
	grid.columns = 9
	get_tree().root.add_child.call_deferred(grid)
	await _wait(0.1)
	for id in ids:
		var p := Portrait.new()
		p.char_id = id
		p.custom_minimum_size = Vector2(170, 210)
		grid.add_child(p)
	await _wait(6.0)
	_shot("gallery_portraits")


## Grobe Aufschlüsselung der sichtbaren Dreiecke je Mesh (Sichtweite berücksichtigt, ohne Frustum/Schatten).
func _perf_detail(w: Node) -> void:
	var cam := get_viewport().get_camera_3d()
	var per := {}
	for n in w.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var count := 1
		if g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			mesh = mm.mesh
			count = mm.instance_count
		elif g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		if mesh == null:
			continue
		var aabb := g.global_transform * g.get_aabb()
		var d := cam.global_position.distance_to(aabb.get_center())
		var r := aabb.size.length() * 0.5
		if g.visibility_range_end > 0.0 and d - r > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		if d + r < g.visibility_range_begin - g.visibility_range_begin_margin:
			continue
		var tris := 0
		for i in mesh.get_surface_count():
			tris += int(RenderingServer.mesh_get_surface(mesh.get_rid(), i).get("index_count", 0)) / 3
		var key := String(g.name).get_slice("_lod", 0).rstrip("0123456789_-")
		if g.name.contains("_lod"):
			key += " lod" + String(g.name).get_slice("_lod", 1).substr(0, 1)
		per[key] = per.get(key, 0) + tris * count
	var keys := per.keys()
	keys.sort_custom(func(a, b): return per[a] > per[b])
	for k in keys.slice(0, 25):
		print("PERF %-45s %d" % [k, per[k]])

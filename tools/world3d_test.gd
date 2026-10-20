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
	if only == "fx":
		await _fx_test(w)
		get_tree().quit()
		return
	if only == "battle":
		await _battle_test(w)
		get_tree().quit()
		return
	if only == "story":
		await _story_test(w)
		get_tree().quit()
		return
	if only == "grimoire":
		await _grimoire_test(w)
		get_tree().quit()
		return
	if only == "anchors":
		# Ankerpunkte und Draufsicht je Ort (für das Einrichten von Szenen-Bühnen)
		for lid in OS.get_environment("ANCHORLOCS").split(",", false):
			await w.load_location(lid)
			await _wait(1.2)
			var a: Dictionary = w.anchors
			var keys := PackedStringArray()
			for k in a:
				var v: Variant = a[k]
				keys.append("%s=%s" % [k, (v as Vector3).snapped(Vector3(0.1, 0.1, 0.1)) if v is Vector3 else (str((v as Array).size()) + " Plätze" if v is Array else str(v))])
			print("ANKER %s: %s" % [lid, ", ".join(keys)])
			var cam := Camera3D.new()
			cam.far = 3000.0
			cam.fov = 60.0
			w.add_child(cam)
			var sp: Vector3 = a.spawn
			var yaw: float = a.get("yaw", 0.0)
			var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
			cam.look_at_from_position(sp - fwd * 4.0 + Vector3.UP * 34.0, sp + fwd * 14.0)
			cam.current = true
			for c in w.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = false
			await _wait(1.5)
			_shot("anchor_%s" % lid)
			cam.queue_free()
			w.player.camera.current = true
			for c in w.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = true
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
		var cams: PackedStringArray = OS.get_environment("SHOTCAM").split(";", false)
		for ci in cams.size():
			var rel := cams[ci].begins_with("@")    # @… = relativ zum Startpunkt des Ortes
			var v: PackedFloat64Array = PackedFloat64Array(Array(cams[ci].trim_prefix("@").split(",")).map(func(x): return float(x)))
			if rel:
				var sp: Vector3 = w.anchors.spawn
				v[0] += sp.x
				v[2] += sp.z
				v[3] += sp.x
				v[5] += sp.z
			var cam := Camera3D.new()
			cam.far = 3000.0
			cam.fov = 70.0
			w.add_child(cam)
			# negative Höhe = Meter über dem Boden an dieser Stelle
			var cp := Vector3(v[0], v[1], v[2])
			var tp := Vector3(v[3], v[4], v[5])
			var space: PhysicsDirectSpaceState3D = w.player.get_world_3d().direct_space_state
			for q in [0, 1]:
				var pt: Vector3 = cp if q == 0 else tp
				if pt.y < 0.0:
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(pt.x, 400.0, pt.z), Vector3(pt.x, -200.0, pt.z)))
					var gy: float = hit.position.y if not hit.is_empty() else 0.0
					if q == 0:
						cp.y = gy - pt.y
					else:
						tp.y = gy - pt.y
			cam.look_at_from_position(cp, tp)
			cam.current = true
			for c in w.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = false
			await _wait(2.5)
			_shot("cam_%s%s" % [l.id, "" if ci == 0 else "_%d" % ci])
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
		# offene Fenster (z. B. Quest-Gespräche) schließen
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(0.4)
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
		# zweimal: Todesritter überstehen den ersten tödlichen Treffer
		for k in 2:
			for e in w._battle.enemies:
				if is_instance_valid(e) and e.state != Fighter.S.DEAD:
					e.take_hit({"amount": 9999.0, "type": "physical"}, w.player)
			await _wait(0.4)
		await _wait(0.6)
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
	var herbs: Array = w.quest_world.pickups.filter(func(p): return not p.entries.is_empty() and p.entries[0][0] == "moonleaf")
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


## Effekt-Schau: stellt Kampfmomente nach und fotografiert sie (LOC=fx, optional FXLOC=<ort>).
##   godot --path . res://tools/world3d_test.tscn   mit LOC=fx
func _fx_test(w: Node) -> void:
	var where := OS.get_environment("FXLOC")
	await w.load_location(where if where != "" else "nazarick_land")
	await _wait(1.0)
	for e in w.enemies.duplicate():
		e.queue_free()
	w.enemies.clear()
	var p: Player3D = w.player
	p.max_hp = 99999.0
	p.hp = p.max_hp
	p.max_mana = 9999.0
	var base: Vector3 = p.global_position
	var fwd := -p.global_basis.z
	fwd = (Basis(Vector3.UP, p.cam_yaw) * Vector3(0, 0, -1)).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	p.cam_distance = 5.0
	p.cam_pitch = -0.22
	var frame := func(yaw_off: float):
		p.cam_yaw = atan2(-fwd.x, -fwd.z) + yaw_off
	var spawn := func(id: String, at: Vector3, ai: bool = false) -> Enemy3D:
		var e: Enemy3D = w.spawn_enemy(id, at)
		if not ai:
			e.target = null
		e.face_towards(p.global_position)
		return e
	var reset := func():
		for e in w.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		w.enemies.clear()
		p.revive()
		p.set_state(Fighter.S.IDLE)
		p.cooldowns.clear()
		p.global_position = base
		p.face(atan2(-fwd.x, -fwd.z))
		p.lock = null
	# 1) Stabhieb auf Skelett
	var e1: Enemy3D = spawn.call("skeleton", base + fwd * 1.7)
	frame.call(0.6)
	await _wait(0.8)
	p.request("light")
	await _wait(float(p.attack.windup) + 0.05)
	_shot("fx_01_staff_hit")
	await _wait(1.0)
	reset.call()
	# 2) Momon: schwerer Hieb auf einen Ritter (Funken)
	p.set_style("momon")
	spawn.call("soldier", base + fwd * 2.0)
	frame.call(-0.6)
	await _wait(0.8)
	p.request("heavy")
	await _wait(float(p.attack.windup) + 0.06)
	_shot("fx_02_momon_heavy")
	await _wait(1.2)
	p.set_style("ainz")
	reset.call()
	# 3) Feuerkugel auf Todesritter
	var dk: Enemy3D = spawn.call("death_knight", base + fwd * 9.0)
	frame.call(0.35)
	await _wait(0.8)
	p.toggle_lock()
	p.cast("fireball")
	await _wait(0.33)
	_shot("fx_03_fireball_flight")
	await _wait(0.32)
	_shot("fx_04_fireball_impact")
	await _wait(1.2)
	reset.call()
	# 4) Kettendrachenblitz auf drei Skelette
	for i in 3:
		spawn.call("skeleton", base + fwd * (6.0 + i * 1.5) + side * (i - 1) * 2.2)
	frame.call(0.25)
	await _wait(0.8)
	p.toggle_lock()
	p.cast("chain_lightning")
	await _wait(0.5)
	_shot("fx_05_chain_lightning")
	await _wait(1.5)
	reset.call()
	# 5) Druckwelle
	for i in 3:
		spawn.call("soldier", base + fwd * 3.0 + side * (i - 1) * 1.6)
	frame.call(0.5)
	await _wait(0.8)
	p.cast("shockwave")
	await _wait(0.42)
	_shot("fx_06_shockwave")
	await _wait(1.5)
	reset.call()
	# 6) Barriere + Lähmung
	var dk2: Enemy3D = spawn.call("death_knight", base + fwd * 5.0)
	frame.call(0.7)
	await _wait(0.6)
	p.cast("shield")
	await _wait(0.6)
	p.toggle_lock()
	p.cast("hold")
	await _wait(0.9)
	_shot("fx_07_barrier_bind")
	await _wait(0.5)
	# 7) Herzgriff (Herz vor der Hand, dann Zugriff)
	p.cooldowns.clear()
	p.mana = p.max_mana
	p.cast("grasp_heart")
	await _wait(0.85)
	_shot("fx_08_heart_cast")
	await _wait(0.35)
	_shot("fx_09_heart_crush")
	await _wait(1.5)
	reset.call()
	# 8) Gegner holt aus: rote Warnung (Todesurteil) und Leichnam-Feuerball am Boden
	var dk3: Enemy3D = spawn.call("death_knight", base + fwd * 2.6)
	var lich: Enemy3D = spawn.call("elder_lich", base + fwd * 9.0 + side * 3.0)
	frame.call(-0.5)
	await _wait(0.8)
	dk3.target = p
	dk3.notice(p)
	dk3._alert_t = 0.0
	dk3._begin_attack(dk3._attack_by_id("overhead"))
	lich.target = p
	lich.notice(p)
	lich._alert_t = 0.0
	lich._begin_attack(lich._attack_by_id("fireball"))
	await _wait(0.9)
	_shot("fx_10_enemy_telegraphs")
	await _wait(0.75)
	_shot("fx_11_lich_fireball")
	await _wait(1.5)
	reset.call()
	# 9) Momon: Sprungangriff
	p.set_style("momon")
	for i in 3:
		spawn.call("skeleton", base + fwd * 6.0 + side * (i - 1) * 1.4)
	frame.call(0.6)
	await _wait(0.8)
	p.toggle_lock()
	p.cast("leap")
	await _wait(0.62)
	_shot("fx_12_leap_air")
	await _wait(0.33)
	_shot("fx_13_leap_land")
	await _wait(1.2)
	p.set_style("ainz")
	reset.call()
	# 10) Superrang: Fallen Down (Aufbau und Einschlag)
	for i in 4:
		spawn.call("soldier", base + fwd * 14.0 + side * (i - 1.5) * 2.0)
	p.cam_distance = 9.0
	p.cam_pitch = -0.3
	frame.call(0.45)
	await _wait(0.8)
	p.toggle_lock()
	p.cast("fallen_down")
	await _wait(3.0)
	_shot("fx_14_super_charge")
	await _wait(1.12)
	_shot("fx_15_super_blast")
	await _wait(0.6)
	_shot("fx_16_super_after")
	await _wait(1.5)
	reset.call()
	# 11) Bogenschützen schießen
	p.cam_distance = 6.0
	p.cam_pitch = -0.2
	for i in 2:
		var a: Enemy3D = spawn.call("skeleton_archer", base + fwd * 11.0 + side * (i * 2 - 1) * 2.5, true)
		a.notice(p)
		a._alert_t = 0.0
		a._cooldown = 0.0
	frame.call(0.3)
	await _wait(1.25)
	_shot("fx_17_archers")
	await _wait(1.0)
	reset.call()


## Gefechtsprobe: Ainz kämpft automatisch gegen die Begegnungen eines Ortes (BATTLELOC, Standard katze).
## Misst Bildrate, gleichzeitige Angreifer, Fernkampf-Treffer und fotografiert alle 1,5 s.
func _battle_test(w: Node) -> void:
	var where := OS.get_environment("BATTLELOC")
	await w.load_location(where if where != "" else "katze")
	await _wait(1.0)
	var p: Player3D = w.player
	p.max_hp = 99999.0
	p.hp = p.max_hp
	p.max_mana = 9999.0
	if OS.get_environment("NOFX") != "":
		CombatFX.enabled = false
	if OS.get_environment("NOAI") != "":
		for e in w.enemies:
			e.target = null
	print("Ruhe vor dem Kampf: FPS %d" % Engine.get_frames_per_second())
	await _wait(2.0)
	print("Ruhe vor dem Kampf: FPS %d · Zeichenaufrufe %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	# alle Gegner in die Nähe holen (wie eine anrückende Gruppe)
	var c: Vector3 = p.global_position + (Basis(Vector3.UP, p.cam_yaw) * Vector3(0, 0, -1)) * 10.0
	var i := 0
	for e in w.enemies:
		var a := TAU * i / maxf(1.0, w.enemies.size())
		var at := c + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 7.0)
		var g := CombatFX._ground_below(w.level, at + Vector3.UP * 5.0)
		e.global_position = (g if g != Vector3.INF else at) + Vector3.UP * 0.2
		e.home = e.global_position
		i += 1
	print("GEFECHT: %d Gegner" % w.enemies.size())
	var fps_min := 999.0
	var fps_sum := 0.0
	var frames := 0
	var most := 0
	var shots := 0
	var t := 0.0
	var next_shot := 1.5
	var next_act := 0.0
	var hp0 := p.hp
	while t < 14.0:
		await get_tree().process_frame
		var dt := get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		t += dt
		if t > 1.0:
			fps_min = minf(fps_min, Engine.get_frames_per_second())
			fps_sum += Engine.get_frames_per_second()
			frames += 1
			var ft := get_process_delta_time() / maxf(Engine.time_scale, 0.05)
			if ft > 0.05 and OS.get_environment("SPIKES") != "":
				print("SPITZE %.0f ms bei t=%.2f · Prozess %.1f ms · Physik %.1f ms · Partikel %d · Marken %d · Decals %d · Lichter %d · Texte %d · Zeitmaß %.2f" % [ft * 1000.0, t,
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					w.level.find_children("*", "GPUParticles3D", true, false).size(), w.level.find_children("*", "GroundMark", true, false).size(),
					w.level.find_children("*", "Decal", true, false).size(), w.level.find_children("*", "OmniLight3D", true, false).size(),
					w.level.find_children("*", "Label3D", true, false).size(), Engine.time_scale])
		var n := 0
		for e in w.enemies:
			if is_instance_valid(e) and e.state == Fighter.S.ATTACK and e.phase != "recovery":
				n += 1
		most = maxi(most, n)
		next_act -= dt
		if next_act <= 0.0:
			next_act = 0.55
			if p.lock == null or not is_instance_valid(p.lock):
				p.toggle_lock()
			var k := int(t * 10.0) % 9
			if k == 0:
				p.cast("fireball")
			elif k == 3:
				p.cast("chain_lightning")
			elif k == 6:
				p.cast("shockwave")
			else:
				p.request("light")
		if int(t) != int(t - dt) and OS.get_environment("SPIKES") != "":
			print("SEKUNDE %d · FPS %d · Partikel %d · Lichter %d · Zeichenaufrufe %d · Objekte %d" % [int(t), Engine.get_frames_per_second(),
				w.level.find_children("*", "GPUParticles3D", true, false).size(), w.level.find_children("*", "OmniLight3D", true, false).size(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		if t >= next_shot and shots < 8 and OS.get_environment("NOSHOT") == "":
			next_shot += 1.5
			_shot("battle_%d" % shots)
			shots += 1
	var alive := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD:
			alive += 1
	print("GEFECHT: FPS min %.0f, Mittel %.0f · gleichzeitige Angreifer max %d · Schaden an Ainz %.0f · Gegner übrig %d" % [fps_min, fps_sum / maxf(1, frames), most, hp0 - p.hp, alive])


## Story-Einsatz automatisch durchspielen: STORY=sm_… (STORYCHOICE=Index der Antwort, STORYSHOTS=jede n-te Zeile).
## Ainz ist unverwundbar, die Gegner verlieren laufend Leben (als kämpfte er), Wegpunkte werden angesprungen.
func _story_test(w: Node) -> void:
	var mid := OS.get_environment("STORY")
	var pick := int(OS.get_environment("STORYCHOICE")) if OS.get_environment("STORYCHOICE") != "" else 0
	var every := int(OS.get_environment("STORYSHOTS")) if OS.get_environment("STORYSHOTS") != "" else 4
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1720, 720)
	var defs := StoryMission.load_all()
	assert(defs.has(mid), "Unbekannter Einsatz " + mid)
	var d: Dictionary = defs[mid]
	Game.state.resources["gold"] = 9000
	Game.state.resources["power"] = 90
	Game.queue_event(String(d.event))
	await _wait(0.5)
	for c in w.overlay_layer.get_children():
		c.queue_free()
	var disp: Dictionary = Game.pending().back()
	var uid := String(disp.uid)
	if OS.get_environment("STORYREPLAY") != "":
		# Erinnerung: als „erlebt“ markieren, Questbuch öffnen, Reiter Kapitel-Momente zeigen, Erinnerung starten
		Game.set_flag("story_" + mid)
		var qj := QuestJournal.new()
		qj.replay_requested.connect(func(id: String): w.replay_story(id))
		w._open(qj)
		await _wait(0.6)
		var tabs: TabContainer = qj.find_children("*", "TabContainer", true, false)[0]
		tabs.current_tab = tabs.get_tab_count() - 1
		await _wait(0.8)
		_shot("story_%s_questbuch" % mid)
		var gold0 := int(Game.state.resources.get("gold", 0))
		qj.replay_requested.emit(mid)
		qj.close()
		uid = ""
		await _wait(0.5)
		print("STORY Erinnerung gestartet, Gold vorher ", gold0)
	elif OS.get_environment("STORYDISPATCH") != "":
		# wie im Spiel: Depesche öffnen, „selbst erleben“ wählen
		w._open_next_dispatch(true)
		await _wait(1.2)
		var dlg: DispatchDialog = null
		for c in w.overlay_layer.get_children():
			if c is DispatchDialog:
				dlg = c
		assert(dlg != null, "Depesche sollte offen sein")
		_shot("story_%s_depesche" % mid)
		var key := ""
		for o in dlg.dispatch.options:
			if o.has("play"):
				key = String(o.key)
		print("STORY Depesche: ", " | ".join(dlg.dispatch.options.map(func(o): return String(o.label))))
		assert(key != "", "Option ‚selbst erleben‘ fehlt")
		dlg._choose(key)
	else:
		w._start_story(mid, uid)
	await _wait(0.5)
	var p: Player3D = w.player
	var t := 0.0
	var lines := 0
	var shots := 0
	var hit_t := 0.0
	var fight_shot := 0.0
	var started := false
	var errors := 0
	var stuck := 0.0
	while t < float(OS.get_environment("STORYTIME") if OS.get_environment("STORYTIME") != "" else "900"):
		await _wait(0.2)
		t += 0.2
		p.hp = p.max_hp
		p.mana = p.max_mana
		var ui: CinematicUI = w._cine_ui
		if w.story != null:
			started = true
		if ui and is_instance_valid(ui) and ui.visible and w.cinematic:
			stuck = stuck + 0.2 if not (ui._choosing or ui._waiting) else 0.0
			if stuck > 40.0:
				print("STORY %s: FEHLER – Szene hängt (Skriptfehler?)" % mid)
				return
			if ui._choosing:
				await _wait(1.2)
				_shot("story_%s_%02d_wahl" % [mid, shots])
				shots += 1
				var n := 0
				for c in ui._choice_box.get_children():
					if c is Button:
						n += 1
				var idx := clampi(pick, 0, n - 1)
				# gesperrte Antworten überspringen
				var bi := 0
				for c in ui._choice_box.get_children():
					if c is Button:
						if bi == idx and (c as Button).disabled:
							idx = (idx + 1) % n
						bi += 1
				print("STORY Wahl: ", idx, " von ", n)
				ui.chosen.emit(idx)
			elif ui._waiting:
				await _wait(0.9)
				if lines % every == 0:
					_shot("story_%s_%02d" % [mid, shots])
					shots += 1
				lines += 1
				if OS.get_environment("STORYDEBUG") != "":
					var parts := PackedStringArray()
					for ac in w.actors:
						if is_instance_valid(ac) and ac.scripted and ac.rig:
							parts.append("%s:%s k%.2f/%.2f model%s by%.2f" % [ac.id, ac.scripted_pose, ac.rig.kneel, ac.rig._kneel_cur, ac.rig.has_model, (ac.rig.parts.body.position.y if ac.rig.parts.has("body") else -1.0)])
					print("STORYDBG ", lines, " ", " | ".join(parts))
				ui.advanced.emit()
			continue
		if w.story != null and not w.cinematic:
			var m: StoryMission = w.story
			if m.marker != Vector3.INF:
				p.global_position = m.marker + Vector3(0.5, 0.3, 0.5)
				continue
			hit_t += 0.2
			fight_shot += 0.2
			if fight_shot >= 3.0:
				fight_shot = 0.0
				_shot("story_%s_%02d_kampf" % [mid, shots])
				shots += 1
			if hit_t >= 0.4:
				hit_t = 0.0
				var best: Enemy3D = null
				var bd := INF
				for e in w.enemies:
					if is_instance_valid(e) and e.state != Fighter.S.DEAD and not e.yielded:
						var dd := p.global_position.distance_to(e.global_position)
						if dd < bd:
							bd = dd
							best = e
				if best:
					best.take_hit({"amount": best.max_hp * 0.07 + 12.0, "type": "physical", "stagger": 8}, p)
		elif started and w.story == null:
			break
	await _wait(2.5)
	_shot("story_%s_%02d_ende" % [mid, shots])
	var answered := Game.get_dispatch(uid).is_empty() if uid != "" else true
	var flag := Game.has_flag("story_" + mid)
	if not answered or not flag:
		errors += 1
	print("STORY %s: %s – Zeilen %d, Zeit %.0f s, beantwortet %s, Flag %s, Ergebnis %s" % [mid, "OK" if errors == 0 else "FEHLER", lines, t, answered, flag, (Game.state.flags as Array).filter(func(k): return String(k).begins_with("story_") or k in ["loyalty_sworn", "carne_saved", "nigun_resolved", "nigun_captured", "erantel_saved", "nfirea_taken", "shalltear_defeated", "ending_peace", "ending_power", "ending_conquest"])])


## Zauberbuch und Fortschritt sichtbar prüfen: Fenster (alle Reiter), neue Zauber im Kampf, Seelen-Lichter, Beute.
func _grimoire_test(w: Node) -> void:
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1720, 720)
	Game.state.chapter = 6
	Progress.add_souls(2400)
	for id in ["negative_burst", "black_hole", "reality_slash", "create_death_knight"]:
		Progress.unlock_spell(id)
	Progress.upgrade_spell("fireball")
	Progress.upgrade_spell("fireball")
	Progress.upgrade_spell("chain_lightning")
	for r in ["ring_primal_flame", "ring_focus", "ring_blood", "ring_storm", "ring_archmage"]:
		Progress.grant_ring(r, "Test")
	var base: Array = w.player.style_data.spells
	Progress.set_loadout("ainz", base, 2, "negative_burst")
	Progress.set_loadout("ainz", base, 3, "black_hole")
	Progress.set_loadout("ainz", base, 4, "reality_slash")
	await w.load_location("katze")
	await _wait(1.5)
	for c in w.overlay_layer.get_children():
		c.queue_free()
	var gr := Grimoire.new()
	w._open(gr)
	await _wait(1.0)
	_shot("grim_ainz")
	gr._sel["ainz"] = "black_hole"
	gr._build_style("ainz")
	await _wait(0.5)
	_shot("grim_ainz_detail")
	gr._tabs.current_tab = 1
	await _wait(0.5)
	_shot("grim_momon")
	gr._tabs.current_tab = 2
	await _wait(0.5)
	_shot("grim_ringe")
	gr.close()
	await _wait(0.8)
	# Kampf mit den neuen Zaubern
	var p: Player3D = w.player
	p.max_hp = 99999.0
	p.hp = p.max_hp
	var foes: Array = []
	for e in w.enemies:
		if is_instance_valid(e):
			foes.append(e)
	foes.sort_custom(func(x, y): return x.global_position.distance_to(p.global_position) < y.global_position.distance_to(p.global_position))
	if foes.is_empty():
		print("GRIMOIRE: keine Gegner")
		return
	var f0: Enemy3D = foes[0]
	p.global_position = f0.global_position + Vector3(0, 0.3, 7)
	p.face(0.0)
	await _wait(0.6)
	_shot("grim_hud")
	p.toggle_lock()
	for id in ["fireball", "negative_burst", "black_hole", "reality_slash", "create_death_knight"]:
		p.mana = p.max_mana
		p.set_state(Fighter.S.IDLE)
		p.cooldowns.clear()
		var ok := p.cast(id)
		print("GRIMOIRE cast %s: %s" % [id, ok])
		await _wait(0.75 if id != "black_hole" else 1.4)
		_shot("grim_cast_" + id)
		await _wait(0.9)
	# Beute und Seelen: einen Elite-Gegner fallen lassen (Beute sicher)
	var elite: Enemy3D = null
	for e in w.enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD and e.data.get("elite", false):
			elite = e
	if elite:
		LootDrop.drop(w.level, elite.global_position + Vector3(2, 0, 0), "ring", "ring_reaper", "epic", "Test")
		LootDrop.drop(w.level, elite.global_position + Vector3(-2, 0, 0), "item", Progress.roll_item("legendary"), "legendary", "Test")
		elite.take_hit({"amount": 99999.0, "type": "negative"}, p)
		await _wait(0.5)
		_shot("grim_souls")
		await _wait(1.0)
		p.camera.global_position = elite.global_position + Vector3(0, 4, 9)
		_shot("grim_loot")
	await _wait(2.0)
	print("GRIMOIRE: Seelen %d, Ringe %d" % [Progress.souls(), Progress.rings().size()])


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

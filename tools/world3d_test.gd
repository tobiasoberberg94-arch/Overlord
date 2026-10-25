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
	w.arrival_pans = false
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
	if only == "bench":
		await _bench(w)
		get_tree().quit()
		return
	if only == "stageprobe":
		await _stage_probe(w)
		get_tree().quit()
		return
	if only == "propsizes":
		for n in ["WoodenChair_01", "WoodenTable_01", "WoodenTable_02", "WoodenTable_03", "round_wooden_table_01", "GothicCabinet_01", "Lantern_01",
				"wooden_lantern_01", "wooden_candlestick", "brass_candleholders", "book_encyclopedia_set_01", "chess_set", "wine_barrel_01",
				"barrel_03", "wooden_barrels_01", "wooden_crate_01", "wooden_crate_02", "wicker_basket_02", "jug_01", "metal_jug", "brass_goblets",
				"wine_bottles_01", "ceramic_vase_01", "CheeseBox_01", "carved_wooden_plate", "wooden_bowl_02", "food_apple_01", "kite_shield",
				"antique_estoc", "large_castle_door", "wooden_ladder", "treasure_chest", "gothic_statue", "stone_fire_pit", "painted_wooden_bench",
				"folding_wooden_stool", "wooden_stool_01", "wooden_stool_02", "wooden_bucket_01", "rusted_spade_01", "wooden_broom", "hatchet", "wooden_axe", "modular_wooden_pier"]:
			var w2 := PhProps.whole(n)
			print("PROP %-26s %s" % [n, (w2.size as Vector3).snapped(Vector3(0.01, 0.01, 0.01)) if not w2.is_empty() else "fehlt"])
		get_tree().quit()
		return
	if only == "polish":
		# Feinschliff: Schritte und Gras-Ausweichen, dynamische Musik, Ankunftskamera, Fotomodus
		w._time_running = false
		await w.load_location("tob_wald")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var s0 := Player3D.step_count
		Input.action_press("move_forward")
		await _wait(3.0)
		Input.action_release("move_forward")
		print("POLISH Schritte: %d (Untergrund %s)" % [Player3D.step_count - s0, w.player._surface])
		var e: Enemy3D = w.spawn_enemy("wolf", w.player.global_position + Vector3(6, 0, 0))
		await _wait(1.5)
		print("POLISH Musik bei Gegner: %s (Zustand %s)" % [Audio._current, w._music_state])
		if is_instance_valid(e):
			e.queue_free()
			w.enemies.clear()
		await _wait(7.5)
		print("POLISH Musik danach: %s (Zustand %s)" % [Audio._current, w._music_state])
		w.photo.toggle()
		await _wait(0.5)
		w.photo.set_filter(1)
		await _wait(0.4)
		_shot("polish_photo_sepia")
		print("POLISH Fotomodus: aktiv %s · Kamera %s · HUD aus %s" % [w.photo.active, w.photo._cam != null, w.cinematic])
		w.photo.toggle()
		await _wait(0.3)
		w.arrival_pans = true
		w.load_location("carne")
		await _wait(2.5)
		print("POLISH Ankunft: Schwenk läuft %s" % w._panning)
		_shot("polish_arrival")
		await _wait(4.0)
		print("POLISH Ankunft danach: Schwenk %s · Spielerkamera %s · Partikel %d" % [w._panning, w.player.camera.current, w._ambient.size()])
		w.arrival_pans = false
		await w.load_location("glacier")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		s0 = Player3D.step_count
		Input.action_press("move_forward")
		await _wait(2.5)
		Input.action_release("move_forward")
		print("POLISH Schnee: %d Schritte · Spuren %d · Untergrund %s" % [Player3D.step_count - s0, w.player._prints.size(), w.player._surface])
		_shot("polish_snow")
		print("POLISHDONE")
		get_tree().quit()
		return
	if only == "dungeon":
		# Verliese: Schlüssel auf dem Friedhof, verschlossenes Kanalgitter, Kanalisation, Siegel, Gruft mit General
		w._time_running = false
		if not Game.state.has("flags"):
			Game.state["flags"] = []
		for f in ["unlocked_erantel_kanal", "unlocked_katze_gruft", "gruft_general"]:
			Game.state.flags.erase(f)
		Quests.bag().erase("key_kanal")
		Quests.bag().erase("key_gruft")
		var picked: Dictionary = Game.state.get("picked", {})
		for k in ["d:erantel_friedhof:key_kanal", "d:erantel_kanal:key_gruft"]:
			picked.erase(k)
		await w.load_location("erantel_friedhof")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var keyp: Pickup = null
		for p in w.quest_world.pickups:
			if p.kind == "key":
				keyp = p
		print("DUNGEON Friedhof: Schlüssel %s" % ("bei " + str(keyp.global_position) if keyp else "FEHLT"))
		if keyp:
			w.quest_world.collect(keyp)
			await _wait(0.4)
			for c in w.overlay_layer.get_children():
				c.queue_free()
		print("DUNGEON Beutel: key_kanal %d" % Quests.count("key_kanal"))
		await w.load_location("e_rantel")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var door: Actor3D = null
		for a in w.actors:
			if a.id == "door:kanal":
				door = a
		print("DUNGEON Kanalgitter: %s" % ("bei " + str(door.global_position) + " · " + door.prompt if door else "FEHLT"))
		w.player.global_position = door.global_position + Vector3(-4, 0.5, 0)
		w.player.cam_yaw = -PI * 0.5
		w.player.cam_pitch = -0.35
		await _wait(0.5)
		_shot("dungeon_gitter")
		Quests.bag().erase("key_kanal")
		w._enter_door(door.get_meta("door"))
		await _wait(1.0)
		print("DUNGEON ohne Schlüssel: Ort %s" % w.loc.id)
		Quests.add_item("key_kanal")
		await w._enter_door(door.get_meta("door"))
		await _wait(1.5)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		print("DUNGEON mit Schlüssel: Ort %s · Gegner %d · Entdeckungen %d · Flagge %s" % [w.loc.id, w.enemies.size(), w.quest_world.pickups.size(), Game.has_flag("unlocked_erantel_kanal")])
		_shot("dungeon_kanal")
		var s0: Vector3 = w.player.global_position
		Input.action_press("move_forward")
		await _wait(2.0)
		Input.action_release("move_forward")
		print("DUNGEON Gang begehbar: %.1f m" % s0.distance_to(w.player.global_position))
		keyp = null
		for p in w.quest_world.pickups:
			if p.kind == "key":
				keyp = p
		w.player.global_position = Vector3(0, 0.2, -11.5)
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = -0.15
		await _wait(0.6)
		_shot("dungeon_kanal_altar")
		if keyp:
			w.quest_world.collect(keyp)
			await _wait(0.4)
			for c in w.overlay_layer.get_children():
				c.queue_free()
		print("DUNGEON Siegel: key_gruft %d" % Quests.count("key_gruft"))
		await w.load_location("katze")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		door = null
		for a in w.actors:
			if a.id == "door:gruft":
				door = a
		print("DUNGEON Gruftportal: %s" % ("bei " + str(door.global_position) + " · " + door.prompt if door else "FEHLT"))
		w.player.global_position = door.global_position + Vector3(-6, 0.5, 0)
		w.player.cam_yaw = -PI * 0.5
		w.player.cam_pitch = -0.1
		await _wait(0.5)
		_shot("dungeon_gruft_portal")
		await w._enter_door(door.get_meta("door"))
		await _wait(1.5)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		var boss: Enemy3D = null
		for e in w.enemies:
			if e.type_id == "fallen_general":
				boss = e
		print("DUNGEON Gruft: Ort %s · Gegner %d · General %s" % [w.loc.id, w.enemies.size(), boss != null])
		_shot("dungeon_gruft")
		if boss:
			w.player.global_position = Vector3(0, 0.2, -4.0)
			w.player.cam_yaw = 0.0
			await _wait(0.6)
			_shot("dungeon_gruft_general")
			boss.die()
			await _wait(2.5)
		var chests := 0
		for p in w.quest_world.pickups:
			if p.kind == "chest":
				chests += 1
		print("DUNGEON General besiegt: Flagge %s · Truhen %d · Gegner %d" % [Game.has_flag("gruft_general"), chests, w.enemies.size()])
		print("DUNGEONDONE")
		get_tree().quit()
		return
	if only == "hamsuke":
		# Hamsuke-Modell im Tob-Wald: Figur suchen, davorstellen, Bilder über einige Sekunden (Leerlauf, Umherlaufen, Kopfblick)
		w._time_running = false
		var ham: Actor3D = null
		for lid in ["jungle", "tob_wald"]:
			await w.load_location(lid)
			for c in w.overlay_layer.get_children():
				c.queue_free()
			await _wait(1.0)
			for a in w.actors:
				if a.id == "hamsuke":
					ham = a
			if ham:
				break
		if ham == null:
			print("HAMSUKE FEHLT (Dschungel und Tob-Wald)")
			get_tree().quit()
			return
		print("HAMSUKE Modell: %s · Animationen: %s · aktuell: %s" % [ham.rig.has_model, str(ham.rig.anim_map.keys()) if ham.rig.anim else "-", ham.rig._current])
		var fwd: Vector3 = ham.global_basis.z
		for k in 3:
			w.player.global_position = ham.global_position + fwd * 4.5 + Vector3(0, 0.3, 0)
			w.player.cam_yaw = atan2(-(ham.global_position.x - w.player.global_position.x), -(ham.global_position.z - w.player.global_position.z))
			w.player.cam_pitch = -0.25
			await _wait(1.6)
			print("HAMSUKE Bild %d: Animation %s · Abstand %.1f m" % [k, ham.rig._current, ham.global_position.distance_to(w.player.global_position)])
			_shot("hamsuke_%d" % k)
			fwd = ham.global_basis.z
		print("HAMSUKEDONE")
		get_tree().quit()
		return
	if only == "props":
		# Requisiten an Figuren: Jaldabaoths Maske am Demiurge-Modell, Frost Pain in Zaryusus Hand
		print("PROPS Modelle: Maske %s · Frost Pain %s" % [ModelLib.has("props", "jaldabaoth_mask"), ModelLib.has("props", "frost_pain")])
		w.queue_free()
		await _wait(0.5)
		var root := Node3D.new()
		get_tree().root.add_child.call_deferred(root)
		await _wait(0.2)
		LocationBuilder.environment(root, {}, LocationBuilder.preset("royal"))
		B3.ground(root, 30, B3.mat(Color(0.2, 0.18, 0.22)))
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.current = true
		cam.fov = 45
		var jal := CharacterRig.create(ProcModel.model_of("jaldabaoth"), func(rr): ProcModel.figure(rr, "jaldabaoth"))
		root.add_child(jal)
		ProcModel.accessories(jal, "jaldabaoth")
		jal.pose(Fighter.S.IDLE, "", 0.0, 0.0)
		var zar := CharacterRig.create(ProcModel.model_of("zaryusu"), func(rr): ProcModel.figure(rr, "zaryusu"))
		zar.position = Vector3(3.0, 0, 0)
		root.add_child(zar)
		zar.pose(Fighter.S.IDLE, "", 0.0, 0.0)
		B3.light(root, Vector3(0, 4, 4), Color(1, 0.95, 0.9), 2.5, 20.0)
		await _wait(1.0)
		var masks := jal.find_children("mask", "", true, false)
		print("PROPS Maske am Rig: %d · Knoten darunter: %d" % [masks.size(), masks[0].get_child_count() if masks.size() > 0 else 0])
		cam.look_at_from_position(Vector3(0.6, 1.75, 1.4), Vector3(0, 1.6, 0))
		await _wait(0.4)
		_shot("props_mask")
		cam.look_at_from_position(Vector3(4.6, 1.5, 2.6), Vector3(3.0, 1.0, 0))
		await _wait(0.4)
		_shot("props_frost_pain")
		cam.look_at_from_position(Vector3(1.5, 1.6, 5.5), Vector3(1.5, 1.0, 0))
		await _wait(0.4)
		_shot("props_both")
		print("PROPSDONE")
		get_tree().quit()
		return
	if only == "wolf":
		# Wolf-Modell als echter Gegner im Tob-Wald: Bemerken, Anlauf, Angriff, Tod
		w._time_running = false
		await w.load_location("tob_wald")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var p0: Vector3 = w.player.global_position
		var e: Enemy3D = w.spawn_enemy("wolf", p0 + Vector3(0, 0.2, -9.0))
		await _wait(0.3)
		print("WOLF Modell: %s · Animationen: %s" % [e.rig.has_model, str(e.rig.anim_map.keys()) if e.rig.anim else "-"])
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = -0.2
		for k in 4:
			await _wait(0.9)
			if is_instance_valid(e):
				print("WOLF Bild %d: Zustand %d · Animation %s · Abstand %.1f m" % [k, e.state, e.rig._current, e.global_position.distance_to(w.player.global_position)])
			_shot("wolf_%d" % k)
		if is_instance_valid(e) and e.state != Fighter.S.DEAD:
			e.die()
			await _wait(1.6)
			_shot("wolf_death")
			print("WOLF tot: Animation %s" % e.rig._current)
		print("WOLFDONE")
		get_tree().quit()
		return
	if only == "dragon":
		# Skelettdrache als Gegner auf dem Friedhof: Modell, Anlauf, Angriffe, Tod
		w._time_running = false
		await w.load_location("erantel_friedhof")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var p0: Vector3 = w.player.global_position
		var e: Enemy3D = w.spawn_enemy("skeletal_dragon", p0 + Vector3(0, 0.2, -14.0))
		await _wait(0.3)
		print("DRAGON Modell: %s · Animationen: %s" % [e.rig.has_model, str(e.rig.anim_map.keys()) if e.rig.anim else "-"])
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = -0.1
		for k in 5:
			await _wait(1.0)
			if is_instance_valid(e):
				print("DRAGON Bild %d: Zustand %d · Animation %s · Abstand %.1f m" % [k, e.state, e.rig._current, e.global_position.distance_to(w.player.global_position)])
			_shot("dragon_%d" % k)
		if is_instance_valid(e) and e.state != Fighter.S.DEAD:
			e.die()
			await _wait(1.8)
			_shot("dragon_death")
			print("DRAGON tot: Animation %s" % e.rig._current)
		print("DRAGONDONE")
		get_tree().quit()
		return
	if only == "darkyoung":
		# Dunkles Junges mit echtem Modell: aufsteigen, stapfen, brüllen
		w._time_running = false
		await w.load_location("katze")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var p0: Vector3 = w.player.global_position
		var d := DarkYoung.spawn(w.level, p0 + Vector3(0, 0, -28.0), 0.0, 1.0)
		print("DARKYOUNG Modell: %s · Animation: %s" % [d._model != null, d._anim.current_animation if d._anim else "-"])
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = 0.12
		d.rise(2.0)
		await _wait(3.2)
		_shot("darkyoung_0")
		d.walk_to(p0 + Vector3(0, 0, -12.0), 6.0)
		await _wait(2.5)
		print("DARKYOUNG geht: Animation %s · läuft %s" % [d._anim.current_animation if d._anim else "-", d.walking])
		_shot("darkyoung_1")
		await _wait(4.0)
		d.roar()
		await _wait(0.5)
		print("DARKYOUNG brüllt: Animation %s" % (d._anim.current_animation if d._anim else "-"))
		_shot("darkyoung_2")
		await _wait(1.5)
		print("DARKYOUNG danach: Animation %s" % (d._anim.current_animation if d._anim else "-"))
		print("DARKYOUNGDONE")
		get_tree().quit()
		return
	if only == "testmenu":
		# Testmodus: Freischalten, Testmenü, Gegner beschwören, Testreise, Tageszeit und Wetter
		w._time_running = false
		await _wait(0.5)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		var before := [int(Game.state.chapter), Game.unlocked_chars().size()]
		Game.unlock_everything()
		var disc := 0
		for rid in Game.state.regions:
			if Game.state.regions[rid].discovered:
				disc += 1
		var stories := 0
		for f in Game.state.flags:
			if String(f).begins_with("story_"):
				stories += 1
		print("TESTMENU Freischalten: Kapitel %d → %d · Wächter %d → %d · Gegenden erkundet %d/%d · Kapitel-Momente %d · Gold %d" % [before[0], int(Game.state.chapter), before[1], Game.unlocked_chars().size(), disc, Game.state.regions.size(), stories, int(Game.state.resources.gold)])
		w._test_menu()
		await _wait(0.4)
		print("TESTMENU Menü offen: %d Fenster" % w.overlay_layer.get_child_count())
		_shot("testmenu_menu")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(0.3)
		var sp: Array = w.test_spawn("skeleton", 3)
		await _wait(0.5)
		print("TESTMENU Gegner: %d beschworen · gesamt %d" % [sp.size(), w.enemies.size()])
		w._gate_menu()
		await _wait(0.3)
		var gate: Node = w.overlay_layer.get_child(0) if w.overlay_layer.get_child_count() > 0 else null
		var disabled := 0
		var total := 0
		if gate:
			for b in gate.find_children("*", "Button", true, false):
				total += 1
				if (b as Button).disabled:
					disabled += 1
		print("TESTMENU Gate: %d Knöpfe, %d gesperrt" % [total, disabled])
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(0.3)
		await w._test_travel("erantel_kanal")
		await _wait(1.0)
		print("TESTMENU Testreise: Ort %s" % w.loc.id)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await w._test_travel("tob_wald")
		await _wait(1.0)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		w.day_cycle.force = 0.95
		w.day_cycle.update(0.95)
		w.weather.force = "snow"
		w.weather.refresh(int(Game.state.day), true)
		await _wait(0.6)
		print("TESTMENU Tob-Wald: Nacht %s · Wetter %s" % [w.day_cycle.night, w.weather.kind])
		_shot("testmenu_night_snow")
		print("TESTMENUDONE")
		get_tree().quit()
		return
	if only == "kodex":
		# Erinnerungsstücke, Kodex und Runenrätsel: Stück im Wald von Tob finden und aufheben, Kodex öffnen, Runen in Feo Jera
		var MEM := preload("res://scripts/world3d/mementos.gd")
		w._time_running = false
		await w.load_location("tob_wald")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.5)
		var ms: Array = []
		for pk in w.quest_world.pickups:
			if is_instance_valid(pk) and pk.kind == "memento":
				ms.append(pk)
		print("KODEX Tob-Wald: %d Erinnerungsstücke platziert (erwartet %d)" % [ms.size(), MEM.by_loc("tob_wald").size()])
		if not ms.is_empty():
			var pk: Pickup = ms[0]
			w.player.global_position = pk.global_position + Vector3(1.2, 0.1, 0)
			await _wait(0.8)
			_shot("kodex_memento")
			w.quest_world.collect(pk)
			await _wait(0.8)
			print("KODEX aufgehoben: %d gefunden · Stat %d" % [MEM.found().size(), Progress.stat("mementos")])
			for c in w.overlay_layer.get_children():
				c.queue_free()
			await _wait(0.5)
		w._open_journal()
		await _wait(1.0)
		var qj: Node = w.overlay_layer.get_child(w.overlay_layer.get_child_count() - 1) if w.overlay_layer.get_child_count() > 0 else null
		var tabs: TabContainer = null
		if qj:
			for t in qj.find_children("*", "TabContainer", true, false):
				tabs = t
		if tabs:
			for i in tabs.get_tab_count():
				if tabs.get_tab_title(i) == "Kodex":
					tabs.current_tab = i
		await _wait(0.8)
		print("KODEX Questbuch: Tab Kodex %s · Fortschritt Tob-Wald %s" % [tabs != null, str(MEM.location_progress("tob_wald"))])
		_shot("kodex_page")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await w.load_location("azerlisia_schmiedehalle")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var runes := {}
		for a in w.actors:
			if is_instance_valid(a) and String(a.id).begins_with("rune:"):
				runes[String(a.id).trim_prefix("rune:")] = a
		print("KODEX Runen: %d Pfeiler" % runes.size())
		if runes.size() == 4:
			w.quest_world.rune_touch(runes["wasser"])
			w.quest_world.rune_touch(runes["feuer"])
			print("KODEX falsche Reihenfolge: Schritt %d" % w.quest_world._rune_step)
			w.quest_world._rune_step = 0
			for rid in ["feuer", "erde", "luft", "wasser"]:
				w.quest_world.rune_touch(runes[rid])
				await _wait(0.3)
			print("KODEX gelöst: %s · Gegenstände %d · Rätsel-Stat %d" % [Game.has_flag("runen_geloest"), Progress.inventory().size(), Progress.stat("puzzles")])
			_shot("kodex_runes")
		print("KODEXDONE")
		get_tree().quit()
		return
	if only == "barks":
		# Bemerkungen: Markt von E-Rantel als Momon (Jubel) und als Ainz (Schrecken, Flucht), dann Thronsaal (Dienerschaft, Albedo)
		w._time_running = false
		await w.load_location("e_rantel")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		w.player.set_style("momon", true)
		w.player.global_position = Vector3(6, 0.2, 16)
		await _wait(5.0)
		print("BARKS Momon: %d Bemerkungen, %d Fluchten" % [Townsfolk.bark_count, Townsfolk.flee_count])
		_shot("barks_momon")
		var b0 := Townsfolk.bark_count
		w.player.set_style("ainz", true)
		w.player.global_position = Vector3(-6, 0.2, 22)
		await _wait(5.0)
		print("BARKS Ainz: %d neue Bemerkungen, %d Fluchten" % [Townsfolk.bark_count - b0, Townsfolk.flee_count])
		_shot("barks_ainz")
		await w.load_location("throne")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		b0 = Townsfolk.bark_count
		w.player.global_position = Vector3(-5.5, 0.2, 6.5)
		await _wait(4.0)
		_shot("barks_maid")
		for a in w.actors:
			if is_instance_valid(a) and String(a.id) == "albedo":
				w.player.global_position = a.global_position + Vector3(1.6, 0.1, 0.0)
		await _wait(4.0)
		var alb: Actor3D = null
		for a in w.actors:
			if is_instance_valid(a) and String(a.id) == "albedo":
				alb = a
		print("BARKS Debug: Fenster %d · busy %s · cinematic %s · Albedo %s · Abstand %.1f · Zeile '%s'" % [w.overlay_layer.get_child_count(), w._busy, w.cinematic, alb != null, w.player.global_position.distance_to(alb.global_position) if alb else -1.0, w.BARKS.for_char("albedo")])
		print("BARKS Nazarick: %d Bemerkungen der Dienerschaft · Figuren: %d" % [Townsfolk.bark_count - b0, Actor3D.bark_count])
		_shot("barks_throne")
		print("BARKSDONE")
		get_tree().quit()
		return
	if only == "trade":
		# Handel: in der Apotheke mit Lizzie sprechen, „Handeln“ drücken, Heiltrank kaufen, Mondkraut verkaufen
		var TD := preload("res://scripts/ui/trade_dialog.gd")
		await w.load_location("erantel_apotheke")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		Game.apply_effects({"res": {"gold": 100}})
		Quests.add_item("moonleaf", 5)
		w.player.hp = w.player.max_hp * 0.4
		var liz: Actor3D = null
		for a in w.actors:
			if is_instance_valid(a) and String(a.id) == "lizzie":
				liz = a
		if liz == null:
			print("TRADE: Lizzie fehlt")
			get_tree().quit()
			return
		var g0 := TD.gold()
		w.quest_world.talk(liz)
		await _wait(0.8)
		var dlg: Node = w.overlay_layer.get_child(w.overlay_layer.get_child_count() - 1) if w.overlay_layer.get_child_count() > 0 else null
		var handel: Button = null
		if dlg:
			for b in dlg.find_children("*", "Button", true, false):
				if String((b as Button).text).contains("Handeln"):
					handel = b
		print("TRADE Gespräch: %s · Knopf Handeln: %s" % [dlg != null, handel != null])
		if handel:
			handel.pressed.emit()
			await _wait(1.0)
		var trade: Node = null
		for c in w.overlay_layer.get_children():
			if c.get_script() == preload("res://scripts/ui/trade_dialog.gd"):
				trade = c
		if trade == null:
			print("TRADE: Handelsfenster fehlt")
			_shot("trade_fail")
			get_tree().quit()
			return
		var buttons := trade.find_children("*", "Button", true, false)
		print("TRADE Fenster: %d Knöpfe · Gold %d · Leben %.0f/%.0f" % [buttons.size(), TD.gold(), w.player.hp, w.player.max_hp])
		_shot("trade_dialog")
		for b in buttons:
			if String((b as Button).text).begins_with("Heiltrank"):
				(b as Button).pressed.emit()
				break
		await _wait(0.5)
		print("TRADE Heiltrank: Gold %d (vorher %d) · Leben %.0f/%.0f" % [TD.gold(), g0 + 100, w.player.hp, w.player.max_hp])
		for b in trade.find_children("*", "Button", true, false):
			if String((b as Button).text).contains("Mondkraut"):
				(b as Button).pressed.emit()
				break
		await _wait(0.5)
		print("TRADE Mondkraut verkauft: Gold %d · Beutel %d" % [TD.gold(), Quests.count("moonleaf")])
		for b in trade.find_children("*", "Button", true, false):
			if String((b as Button).text).begins_with("Silberring"):
				(b as Button).pressed.emit()
				break
		await _wait(0.5)
		print("TRADE Kauf Silberring: Gold %d · Gegenstände %d" % [TD.gold(), Progress.inventory().size()])
		_shot("trade_after")
		print("TRADEDONE")
		get_tree().quit()
		return
	if only == "pad":
		# Controller-Simulation ohne Gerät: linker Stick bewegt, rechter Stick dreht, Start öffnet das Menü mit Fokus,
		# Steuerkreuz wandert, B schließt, Back öffnet die Karte, A benutzt eine Tür.
		await w.load_location("e_rantel")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var p0: Vector3 = w.player.global_position
		_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
		await _wait(1.5)
		_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
		await _wait(0.3)
		print("PAD Bewegung: %.1f m · Controller aktiv: %s" % [w.player.global_position.distance_to(p0), Pad.active])
		var yaw0: float = w.player.cam_yaw
		_pad_axis(JOY_AXIS_RIGHT_X, 1.0)
		await _wait(0.6)
		_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
		print("PAD Kamera: Drehung %.2f rad" % absf(wrapf(w.player.cam_yaw - yaw0, -PI, PI)))
		print("PAD HUD: Aufforderung '%s' · Hilfe Controller: %s" % [w.hud.prompt_key.text, w.hud.help_text.text.contains("Linker Stick")])
		await _pad_button(JOY_BUTTON_START)
		await _wait(0.7)
		var foc := get_viewport().gui_get_focus_owner()
		print("PAD Start: %d Fenster · Fokus: %s" % [w.overlay_layer.get_child_count(), (foc as Button).text.get_slice("\n", 0) if foc is Button else "keiner"])
		_shot("pad_menu")
		await _pad_button(JOY_BUTTON_DPAD_DOWN)
		await _wait(0.3)
		foc = get_viewport().gui_get_focus_owner()
		print("PAD Steuerkreuz: Fokus: %s" % ((foc as Button).text.get_slice("\n", 0) if foc is Button else "keiner"))
		await _pad_button(JOY_BUTTON_A)
		await _wait(0.8)
		foc = get_viewport().gui_get_focus_owner()
		print("PAD A im Menü: %d Fenster · Fokus: %s" % [w.overlay_layer.get_child_count(), (foc as Button).text.get_slice("\n", 0) if foc is Button else "keiner"])
		_shot("pad_submenu")
		await _pad_button(JOY_BUTTON_B)
		await _wait(0.6)
		print("PAD B: %d Fenster" % w.overlay_layer.get_child_count())
		await _pad_button(JOY_BUTTON_BACK)
		await _wait(1.2)
		print("PAD Back (Karte): %d Fenster" % w.overlay_layer.get_child_count())
		await _pad_button(JOY_BUTTON_B)
		await _wait(0.8)
		var door: Actor3D = null
		for a in w.actors:
			if is_instance_valid(a) and String(a.id) == "door:gilde":
				door = a
		if door:
			w.player.global_position = door.global_position + Vector3(0, 0.1, 1.2)
			await _wait(1.0)
			await _pad_button(JOY_BUTTON_A)
			await _wait(4.0)
			print("PAD A an der Tür: jetzt in %s" % w.loc.id)
		print("PADDONE")
		get_tree().quit()
		return
	if only == "buildings":
		# Gebäude-Knoten nach der Vergrößerung: Drehung, Skalierung, Hülle – Verdacht auf gedrehte Knoten (seitlich gestreckt)
		var blocs := OS.get_environment("BUILDLOCS")
		for lid in (blocs if blocs != "" else "carne,re_capital,drachen").split(","):
			await w.load_location(lid)
			for c in w.overlay_layer.get_children():
				c.queue_free()
			await _wait(0.5)
			var cnt := 0
			var odd := 0
			for h in w.find_children("*", "MeshInstance3D", true, false):
				var mi := h as MeshInstance3D
				if not mi.has_meta("enlarged"):
					continue
				cnt += 1
				var rd := mi.rotation_degrees
				var tilted := absf(rd.x) > 1.0 or absf(rd.z) > 1.0
				var ab := mi.get_aabb()
				if tilted or cnt <= 3 or absf(ab.position.y) > 0.05:
					var col := ""
					for c in mi.get_children():
						if c is StaticBody3D:
							col = " Kollision %s rot (%.0f, %.0f, %.0f)" % [c.name, (c as Node3D).rotation_degrees.x, (c as Node3D).rotation_degrees.y, (c as Node3D).rotation_degrees.z]
					print("BUILDINGS %s %s rot (%.0f, %.0f, %.0f) scale (%.2f, %.2f, %.2f) aabb %.1f x %.1f x %.1f unten %.2f%s%s" % [lid, mi.name, rd.x, rd.y, rd.z, mi.scale.x, mi.scale.y, mi.scale.z, ab.size.x, ab.size.y, ab.size.z, ab.position.y, col, " GEDREHT" if tilted else ""])
				if tilted:
					odd += 1
			print("BUILDINGS %s: %d vergrößert, %d gedreht" % [lid, cnt, odd])
		print("BUILDINGSDONE")
		get_tree().quit()
		return
	if only == "villagers":
		# Dorfbewohner-Modelle: Bewohner aller Stile und benannte Figuren in einer Reihe vor der Kamera, Nahaufnahme, Gang
		await w.load_location("carne")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(0.5)
		w._time_running = false
		var base: Vector3 = w.player.global_position
		var d := Vector3(0, 0, -1)
		var right := Vector3(1, 0, 0)
		var root := Node3D.new()
		w.add_child(root)
		var styles := ["", "", "adventurer", "guard", "priest", "mage", "maid", "noble", "merchant", "smith"]
		var models := 0
		var rigs: Array = []
		for i in styles.size():
			var p: Vector3 = w._on_ground(base + d * 5.0 + right * ((i - (styles.size() - 1) / 2.0) * 0.95))
			var t := Townsfolk.spawn(root, [], [p], 100 + i, 1, styles[i])
			for e in t._people:
				var rig: CharacterRig = e.rig
				rig.rotation.y = 0.0
				rigs.append(rig)
				if rig.has_model:
					models += 1
		print("VILLAGERS Bewohner: %d von %d mit Modell" % [models, rigs.size()])
		if not rigs.is_empty() and (rigs[0] as CharacterRig).anim:
			var have: Array = []
			for cn in ["talk", "argue", "clap", "cheer", "wave", "pray", "sit", "sit_talk", "drink"]:
				if (rigs[0] as CharacterRig).anim.has_animation(cn):
					have.append(cn)
			print("VILLAGERS Clips: %s" % ", ".join(have))
		w.player.global_position = base
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = -0.12
		await _wait(2.5)
		_shot("villagers_styles")
		var playing: Array = []
		for rg in rigs:
			playing.append((rg as CharacterRig)._current)
		print("VILLAGERS läuft: %s" % ", ".join(playing))
		w.player.global_position = base + d * 3.2
		await _wait(0.6)
		_shot("villagers_close")
		root.queue_free()
		root = Node3D.new()
		w.add_child(root)
		var ids := ["enri", "nfirea", "gazef", "sebas", "jircniv", "clementine", "neia", "carne_knight", "priest", "fluder", "ranpossa", "child"]
		var named := 0
		for i in ids.size():
			var cid: String = ids[i]
			var rig := CharacterRig.create(ProcModel.model_of(cid), func(r: CharacterRig) -> void: ProcModel.figure(r, cid))
			root.add_child(rig)
			ProcModel.accessories(rig, cid)
			rig.global_position = w._on_ground(base + d * 5.0 + right * ((i - (ids.size() - 1) / 2.0) * 0.9))
			rig.rotation.y = 0.0
			if rig.has_model:
				named += 1
			print("VILLAGERS Figur %s: Modell %s (%s)" % [cid, rig.has_model, rig.model_id])
		print("VILLAGERS Figuren: %d von %d mit Modell" % [named, ids.size()])
		w.player.global_position = base
		await _wait(1.0)
		_shot("villagers_figures")
		root.queue_free()
		var walkers := Townsfolk.spawn(w, [w._on_ground(base + d * 4.0 + right * 3.0), w._on_ground(base + d * 4.0 - right * 3.0)], [], 7, 2, "")
		for e in walkers._people:
			e.wait = 0.0
		await _wait(2.0)
		var anim := ""
		for e in walkers._people:
			var rig: CharacterRig = e.rig
			anim = rig._current if rig.has_model else "proc"
		print("VILLAGERS Gang: Animation %s" % anim)
		_shot("villagers_walk")
		print("VILLAGERSDONE")
		get_tree().quit()
		return
	if only == "enemies":
		# Menschliche Gegner auf dem Bewohner-Modell: eine Reihe vor der Kamera, Nahaufnahme, dann ein Angriff
		await w.load_location("carne")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(0.5)
		w._time_running = false
		var base: Vector3 = w.player.global_position
		var d := Vector3(0, 0, -1)
		var right := Vector3(1, 0, 0)
		var ids := ["soldier", "mercenary", "bandit_archer", "zurrernorn_cultist", "zurrernorn_priest", "sunlit_caster", "adventurer", "gagaran", "brain", "decem", "eight_fingers", "scripture_archer"]
		var spawned: Array = []
		var models := 0
		for i in ids.size():
			var arr: Array = w.test_spawn(ids[i], 1)
			for e in arr:
				var en := e as Enemy3D
				en.global_position = w._on_ground(base + d * 5.0 + right * ((i - (ids.size() - 1) / 2.0) * 0.95))
				en.rotation.y = 0.0
				en.set_physics_process(false)
				en.set_process(false)
				spawned.append(en)
				if en.rig.has_model:
					models += 1
				print("ENEMIES %s: Modell %s (%s)" % [ids[i], en.rig.has_model, en.rig.model_id])
		print("ENEMIES Gegner: %d von %d mit Modell" % [models, spawned.size()])
		w.player.global_position = base
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = -0.12
		await _wait(1.5)
		_shot("enemies_row")
		w.player.global_position = base + d * 3.2
		await _wait(0.6)
		_shot("enemies_close")
		# Angriff: Soldat wieder aktiv, Spieler in Reichweite
		w.player.global_position = base
		for en in spawned:
			if en.type_id != "soldier":
				en.queue_free()
			else:
				en.set_physics_process(true)
				en.set_process(true)
				en.global_position = w._on_ground(base + d * 2.2)
				en.target = w.player
				en.engaged = true
		w._time_running = true
		var seen: Array = []
		for k in 12:
			await _wait(0.5)
			for en in spawned:
				if is_instance_valid(en) and en.type_id == "soldier" and not seen.has(en.rig._current):
					seen.append(en.rig._current)
			if k == 5:
				_shot("enemies_attack")
		print("ENEMIES Soldat spielte: %s" % ", ".join(seen))
		print("ENEMIESDONE")
		get_tree().quit()
		return
	if only == "seats":
		# Sitzende Gäste in Gilde und Gasthaus: Anzahl, laufende Clips, Bilder von den Tischen
		for lid in ["erantel_gilde", "erantel_gasthaus"]:
			await w.load_location(lid)
			for c in w.overlay_layer.get_children():
				c.queue_free()
			await _wait(2.0)
			var seated := 0
			var clips: Array = []
			var first: Node3D = null
			for t in w.find_children("*Guest*", "Townsfolk", true, false):
				for pp in (t as Townsfolk)._people:
					if pp.get("seated", false):
						seated += 1
						clips.append(String((pp.rig as CharacterRig)._current))
						if first == null:
							first = pp.rig
			print("SEATS %s: %d Gäste · Clips %s" % [lid, seated, ", ".join(clips)])
			if first:
				var look := first.global_position
				w.player.global_position = look + Vector3(2.6, 0, 2.6)
				w.player.cam_yaw = atan2(-(look.x - w.player.global_position.x), -(look.z - w.player.global_position.z))
				w.player.cam_pitch = -0.2
				await _wait(1.0)
				_shot("seats_" + lid)
		print("SEATSDONE")
		get_tree().quit()
		return
	if only == "parts":
		# Alle Partikel eines Ortes: PARTLOC=ort – Lage, Anzahl, Lebensdauer, Tempo, Schwerkraft, Pfad
		w._time_running = false
		await w.load_location(OS.get_environment("PARTLOC"))
		await _wait(1.5)
		for n in w.find_children("*", "GeometryInstance3D", true, false):
			if n is CPUParticles3D:
				var c := n as CPUParticles3D
				print("TEILCHEN CPU %s n=%d leben=%.1f v=%.2f-%.2f g=%s lokal=%s | %s" % [str(c.global_position.snapped(Vector3(0.1, 0.1, 0.1))), c.amount, c.lifetime, c.initial_velocity_min, c.initial_velocity_max, str(c.gravity), c.local_coords, String(w.get_path_to(c)).right(60)])
			elif n is GPUParticles3D:
				var gp := n as GPUParticles3D
				var pm := gp.process_material as ParticleProcessMaterial
				var info := ""
				if pm:
					info = "v=%.2f-%.2f g=%s" % [pm.initial_velocity_min, pm.initial_velocity_max, str(pm.gravity)]
				print("TEILCHEN GPU %s n=%d leben=%.1f %s lokal=%s sichtbar=%s | %s" % [str(gp.global_position.snapped(Vector3(0.1, 0.1, 0.1))), gp.amount, gp.lifetime, info, gp.local_coords, gp.is_visible_in_tree(), String(w.get_path_to(gp)).right(60)])
		print("TEILCHENDONE")
		get_tree().quit()
		return
	if only == "walk":
		# Lauftest: WALK="ort:x,z,winkel,sekunden;…" (Winkel wie RAYS: 0° = -z, 90° = +x) – der Spieler läuft geradeaus;
		# gemeldet werden Endpunkt, tiefster Punkt und Rücksetzer des Sicherheitsnetzes (aus der Welt gefallen)
		for spec in OS.get_environment("WALK").split(";", false):
			var lid := spec.get_slice(":", 0)
			var v := spec.get_slice(":", 1).split(",")
			if w.loc.get("id", "") != lid:
				w._time_running = false
				await w.load_location(lid)
				await _wait(1.0)
			for c in w.overlay_layer.get_children():
				c.queue_free()
			var start: Vector3 = w._on_ground(Vector3(float(v[0]), 2.0, float(v[1])))
			w.player.global_position = start + Vector3(0, 0.3, 0)
			w.player.velocity = Vector3.ZERO
			w.player.cam_yaw = -deg_to_rad(float(v[2]))
			await _wait(0.4)
			var miny: float = w.player.global_position.y
			var secs := float(v[3]) if v.size() > 3 else 6.0
			var resets := 0
			var last: Vector3 = w.player.global_position
			var t := 0.0
			Input.action_press("move_forward")
			while t < secs:
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
				w.player.cam_yaw = -deg_to_rad(float(v[2]))
				var gp: Vector3 = w.player.global_position
				miny = minf(miny, gp.y)
				if gp.distance_to(last) > 5.0:
					resets += 1
				last = gp
			Input.action_release("move_forward")
			var e2: Vector3 = w.player.global_position
			print("WALK %s von (%.1f, %.1f, %.1f) Richtung %s° %.0f s -> (%.1f, %.1f, %.1f) tiefster Punkt %.1f Rücksetzer %d" % [lid, start.x, start.y, start.z, v[2], secs, e2.x, e2.y, e2.z, miny, resets])
		print("WALKDONE")
		get_tree().quit()
		return
	if only == "actors":
		# Figuren eines Ortes: ACTLOC=ort – Kennung, Art, Lage, Blickrichtung und Größe des Modells
		w._time_running = false
		await w.load_location(OS.get_environment("ACTLOC"))
		await _wait(2.0)
		for ac in w.actors:
			var an := ac as Node3D
			var box := AABB()
			var first := true
			var mname := ""
			for mi in an.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				if m.mesh == null or not m.is_visible_in_tree():
					continue
				var gb: AABB = m.global_transform * m.get_aabb()
				box = gb if first else box.merge(gb)
				if first:
					mname = String(m.name)
				first = false
			var fwd := -an.global_transform.basis.z
			var rig_info := ""
			if ac.get("rig") != null:
				var rg := ac.get("rig") as Node3D
				rig_info = " Rig-Blick (%.2f, %.2f) Rig-Drehung %.0f°" % [-rg.global_transform.basis.z.x, -rg.global_transform.basis.z.z, rg.rotation_degrees.y]
			print("FIGUR %-18s %-6s @ (%.1f, %.1f, %.1f) Drehung %.0f° Blick (%.2f, %.2f)%s | Modell %s %.1fx%.1fx%.1f ab y=%.1f" % [String(ac.get("id")), String(ac.get("kind")), an.global_position.x, an.global_position.y, an.global_position.z, an.rotation_degrees.y, fwd.x, fwd.z, rig_info, mname.left(24), box.size.x, box.size.y, box.size.z, box.position.y])
		print("FIGURENDONE")
		get_tree().quit()
		return
	if only == "mats":
		# Materialien eines Ortes: MATLOC=ort [MATFILTER=teilname] – je Material Anzahl Flächen, Gesamtgröße, Textur ja/nein,
		# Shader und ein Beispiel-Mesh mit Lage; zum Aufspüren schlechter Oberflächen (Eis ohne Textur …)
		await w.load_location(OS.get_environment("MATLOC"))
		await _wait(1.0)
		var filt := OS.get_environment("MATFILTER").to_lower()
		var mats := {}
		for mi in w.level.find_children("*", "GeometryInstance3D", true, false):
			var m := mi as GeometryInstance3D
			var msh: Mesh = null
			var cnt := 1
			if m is MeshInstance3D:
				msh = (m as MeshInstance3D).mesh
			elif m is MultiMeshInstance3D and (m as MultiMeshInstance3D).multimesh:
				msh = (m as MultiMeshInstance3D).multimesh.mesh
				cnt = (m as MultiMeshInstance3D).multimesh.instance_count
			if msh == null or not m.is_visible_in_tree():
				continue
			var gb: AABB = m.global_transform * m.get_aabb()
			for si in msh.get_surface_count():
				var mat: Material = m.material_override
				if mat == null and m is MeshInstance3D:
					mat = (m as MeshInstance3D).get_active_material(si)
				if mat == null:
					mat = msh.surface_get_material(si)
				var nm := String(mat.resource_name) if mat else "-"
				if nm == "" and mat:
					nm = mat.get_class()
					if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
						nm += ":" + (mat as ShaderMaterial).shader.resource_path.get_file()
					if m.material_overlay:
						nm += "+Überzug"
					nm += ":" + String(m.name).rstrip("0123456789_").left(16)
				if filt != "" and not (nm.to_lower().contains(filt) or String(m.name).to_lower().contains(filt)):
					continue
				if not mats.has(nm):
					var info := "-"
					if mat is StandardMaterial3D:
						var sm := mat as StandardMaterial3D
						info = "Std tex=%s farbe=%s transp=%d emis=%s" % [sm.albedo_texture != null, sm.albedo_color.to_html(), sm.transparency, sm.emission_enabled]
					elif mat is ShaderMaterial:
						var shm := mat as ShaderMaterial
						var tx: Variant = shm.get_shader_parameter("albedo_tex")
						var ph: Variant = shm.get_shader_parameter("photo_tex")
						info = "Shader %s tex=%s photo=%s farbe=%s" % [shm.shader.resource_path.get_file() if shm.shader else "-", tx != null, ph != null, str(shm.get_shader_parameter("albedo_col"))]
					mats[nm] = {"n": 0, "area": 0.0, "info": info, "ex": "%s @ (%.0f, %.0f, %.0f) %.1fx%.1fx%.1f" % [String(m.name).left(40), gb.get_center().x, gb.position.y, gb.get_center().z, gb.size.x, gb.size.y, gb.size.z]}
				var e: Dictionary = mats[nm]
				e.n = int(e.n) + cnt
				e.area = float(e.area) + gb.size.x * gb.size.z
		var keys := mats.keys()
		keys.sort_custom(func(a, b): return float(mats[a].area) > float(mats[b].area))
		for k in keys.slice(0, 80):
			var e2: Dictionary = mats[k]
			print("MAT %-40s n=%4d Fläche %8.0f | %s | %s" % [String(k).left(40), int(e2.n), float(e2.area), e2.info, e2.ex])
		print("MATSDONE %d" % mats.size())
		get_tree().quit()
		return
	if only == "meshes":
		# Große Meshes eines Ortes (Gebäude, Grüfte) mit Mittelpunkt und Größe – zum Setzen von Türen und Bühnen:
		# MESHLOC=ort MESHAT=x,z MESHR=Radius MESHMIN=Mindestgröße
		var mlid := OS.get_environment("MESHLOC")
		await w.load_location(mlid)
		await _wait(1.0)
		var at := OS.get_environment("MESHAT").split(",")
		var c0 := Vector3(float(at[0]), 0, float(at[1])) if at.size() == 2 else Vector3.ZERO
		var rad := float(OS.get_environment("MESHR")) if OS.get_environment("MESHR") != "" else 60.0
		var mn := float(OS.get_environment("MESHMIN")) if OS.get_environment("MESHMIN") != "" else 3.0
		# MESHNAME="sarg,coffin" – nur Meshes, deren Name eines der Muster enthält
		var pats := OS.get_environment("MESHNAME").to_lower().split(",", false)
		var rows: Array = []
		for mi in w.level.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			if not pats.is_empty():
				var hit := false
				for pt in pats:
					if String(m.name).to_lower().contains(pt):
						hit = true
				if not hit:
					continue
			var gb: AABB = m.global_transform * m.get_aabb()
			var cen := gb.get_center()
			var dist := Vector2(cen.x - c0.x, cen.z - c0.z).length()
			if dist > rad or maxf(gb.size.x, gb.size.z) < mn:
				continue
			rows.append([dist, "MESH %-34s Mitte (%6.1f, %5.1f, %6.1f) Größe %5.1f x %4.1f x %5.1f Drehung %4.0f°" % [String(m.name).left(34), cen.x, gb.position.y, cen.z, gb.size.x, gb.size.y, gb.size.z, rad_to_deg(m.global_rotation.y)]])
		rows.sort_custom(func(a, b): return a[0] < b[0])
		for r in rows.slice(0, 60):
			print(r[1])
		print("MESHESDONE %d" % rows.size())
		get_tree().quit()
		return
	if only == "mausoleum":
		# Khajits Mausoleum: Schlüssel fällt vom Priester in der Kanalisation, Tor auf dem Friedhof, Halle, Altar, Khajit besiegt
		w._time_running = false
		if not Game.state.has("flags"):
			Game.state["flags"] = []
		for f in ["unlocked_erantel_mausoleum", "mausoleum_khajit"]:
			Game.state.flags.erase(f)
		Quests.bag().erase("key_mausoleum")
		var picked: Dictionary = Game.state.get("picked", {})
		picked.erase("k:key_mausoleum")
		await w.load_location("erantel_kanal")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var priest: Enemy3D = null
		for e in w.enemies:
			if e.type_id == "zurrernorn_priest":
				priest = e
		print("MAUSOLEUM Priester in der Kanalisation: %s" % (priest != null))
		if priest:
			w.player.global_position = priest.global_position + Vector3(0, 0.2, 4.0)
			w.player.cam_yaw = 0.0
			priest.die()
			await _wait(2.5)
		var keyp: Pickup = null
		for pk in w.quest_world.pickups:
			if pk.kind == "key" and String(pk.get_meta("item", "")) == "key_mausoleum":
				keyp = pk
		print("MAUSOLEUM Schlüssel fällt: %s" % ("bei " + str(keyp.global_position) if keyp else "FEHLT"))
		_shot("mausoleum_schluessel")
		if keyp:
			w.quest_world.collect(keyp)
			await _wait(0.4)
			for c in w.overlay_layer.get_children():
				c.queue_free()
		print("MAUSOLEUM Beutel: key_mausoleum %d" % Quests.count("key_mausoleum"))
		await w.load_location("erantel_friedhof")
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var door: Actor3D = null
		for a in w.actors:
			if a.id == "door:mausoleum":
				door = a
		print("MAUSOLEUM Tor: %s" % ("bei " + str(door.global_position) + " · " + door.prompt if door else "FEHLT"))
		if door:
			w.player.global_position = door.global_position + Vector3(0, 0.5, 6.0)
			w.player.cam_yaw = 0.0
			w.player.cam_pitch = -0.1
			await _wait(0.6)
			_shot("mausoleum_tor")
			await w._enter_door(door.get_meta("door"))
			await _wait(1.5)
			for c in w.overlay_layer.get_children():
				c.queue_free()
		var kh: Enemy3D = null
		var cl: Enemy3D = null
		for e in w.enemies:
			if e.type_id == "khajit":
				kh = e
			elif e.type_id == "clementine":
				cl = e
		print("MAUSOLEUM Halle: Ort %s · Gegner %d · Khajit %s · Clementine %s · Entdeckungen %d · Flagge %s" % [w.loc.id, w.enemies.size(), kh != null, cl != null, w.quest_world.pickups.size(), Game.has_flag("unlocked_erantel_mausoleum")])
		_shot("mausoleum_halle")
		w.player.global_position = Vector3(0, 0.2, -6.0)
		w.player.cam_yaw = 0.0
		w.player.cam_pitch = -0.1
		await _wait(0.6)
		_shot("mausoleum_altar")
		if kh:
			kh.die()
			await _wait(2.5)
		var chests := 0
		for pk in w.quest_world.pickups:
			if pk.kind == "chest":
				chests += 1
		print("MAUSOLEUM Khajit besiegt: Flagge %s · Truhen %d · Gegner %d" % [Game.has_flag("mausoleum_khajit"), chests, w.enemies.size()])
		print("MAUSOLEUMDONE")
		get_tree().quit()
		return
	if only == "tour":
		# TOURRS=Index: Renderauflösung/Hochskalierung (Settings.RENDER_SCALES; 5 = nativ ohne FSR 2) für Vergleiche
		if OS.get_environment("TOURRS") != "":
			Settings.render_scale = int(OS.get_environment("TOURRS"))
			Settings.apply_viewport(get_tree().root)
		# Rundgang je Ort (TOURLOCS=ort,ort): Ankunft, jede Tür, das Gate, die Funde – Bilder tour_<ort>_*.png und
		# eine Liste der Gegner, Funde und Figuren. Zeit angehalten, Gegner ruhen.
		w._time_running = false
		for lid in OS.get_environment("TOURLOCS").split(",", false):
			var t0 := Time.get_ticks_msec()
			await w.load_location(lid)
			var load_ms := Time.get_ticks_msec() - t0
			for c in w.overlay_layer.get_children():
				c.queue_free()
			await _wait(1.2)
			w.cinematic = true
			var kinds := {}
			for pk in w.quest_world.pickups:
				kinds[pk.kind] = int(kinds.get(pk.kind, 0)) + 1
			var ens := PackedStringArray()
			for e in w.enemies:
				ens.append(e.type_id)
			var acts := PackedStringArray()
			for a in w.actors:
				acts.append(a.id)
			print("TOUR %s: Ladezeit %d ms · Gegner %d %s · Funde %s · Figuren/Objekte %s" % [lid, load_ms, w.enemies.size(), str(ens), str(kinds), ", ".join(acts)])
			# TOURENV="ssil,ssr,glow,volfog,sdfgi,ssao": diese Effekte für den Rundgang abschalten (Ursachen eingrenzen)
			var off := OS.get_environment("TOURENV").split(",", false)
			if not off.is_empty():
				for c in w.level.get_children():
					if c is WorldEnvironment:
						var ev := (c as WorldEnvironment).environment
						if "ssil" in off: ev.ssil_enabled = false
						if "ssr" in off: ev.ssr_enabled = false
						if "glow" in off: ev.glow_enabled = false
						if "volfog" in off: ev.volumetric_fog_enabled = false
						if "sdfgi" in off: ev.sdfgi_enabled = false
						if "ssao" in off: ev.ssao_enabled = false
				print("TOUR %s: abgeschaltet %s" % [lid, str(off)])
			var sp: Vector3 = w.player.global_position
			var y0: float = w.player.cam_yaw
			w.player.cam_pitch = -0.15
			await _wait(0.4)
			_shot("tour_%s_0_ankunft" % lid)
			w.player.cam_yaw = y0 + PI
			await _wait(0.4)
			_shot("tour_%s_0_ankunft_zurueck" % lid)
			var k := 0
			for a in w.actors:
				var look: Vector3 = a.global_position
				var from := look + Vector3(0, 0.5, 6.0)
				if a.has_meta("door"):
					var dd: Dictionary = a.get_meta("door")
					var out := Basis(Vector3.UP, deg_to_rad(float(dd.get("yaw", 180.0)))) * Vector3(0, 0, -1)
					from = look + out * 6.5 + Vector3(0, 0.5, 0)
				elif a.kind != "object":
					continue
				w.player.global_position = from
				w.player.cam_yaw = atan2(-(look.x - from.x), -(look.z - from.z))
				w.player.cam_pitch = -0.12
				await _wait(0.5)
				_shot("tour_%s_%d_%s" % [lid, k + 1, String(a.id).replace(":", "_")])
				k += 1
			var f := 0
			for pk in w.quest_world.pickups:
				if f >= 4:
					break
				var look2: Vector3 = pk.global_position
				var from2 := look2 + Vector3(2.6, 1.0, 2.6)
				w.player.global_position = from2
				w.player.cam_yaw = atan2(-(look2.x - from2.x), -(look2.z - from2.z))
				w.player.cam_pitch = -0.3
				await _wait(0.4)
				_shot("tour_%s_f%d_%s" % [lid, f, pk.kind])
				f += 1
			w.player.global_position = sp
			w.cinematic = false
		print("TOURDONE")
		get_tree().quit()
		return
	if only == "rays":
		# Wandabstände: RAYS="ort:x,z;ort:x,z" – 16 waagerechte Strahlen auf Brusthöhe, Abstand und Körper je Richtung
		for spec in OS.get_environment("RAYS").split(";", false):
			var lid := spec.get_slice(":", 0)
			var xz := spec.get_slice(":", 1).split(",")
			if w.loc.get("id", "") != lid:
				w._time_running = false
				await w.load_location(lid)
				await _wait(0.8)
			var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
			var g: Vector3 = w._on_ground(Vector3(float(xz[0]), float(xz[2]) if xz.size() > 2 else 0.0, float(xz[1])))   # optional dritter Wert: Höhe
			var parts := PackedStringArray()
			for k in 16:
				var a := TAU * k / 16.0
				var dir := Vector3(sin(a), 0.0, -cos(a))
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3.UP * 1.1, g + Vector3.UP * 1.1 + dir * 30.0, 1))
				var dd := g.distance_to(hit.position) if not hit.is_empty() else 30.0
				var nm := String((hit.collider as Node).get_parent().name) if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).get_parent() else "-"
				parts.append("%d°:%.1f(%s)" % [int(rad_to_deg(a)), dd, nm.left(16)])
			print("RAYS %s (%s, %s) Boden %.2f | %s" % [lid, xz[0], xz[1], g.y, " ".join(parts)])
		print("RAYSDONE")
		get_tree().quit()
		return
	if only == "plan":
		# Grundriss unter der Decke: PLAN="ort:x,z,breite,höhe" – senkrechte Draufsicht (orthografisch) aus der angegebenen
		# Höhe, Norden (-z) oben; Raster alle 5 m (dünn) und 10 m (dick, beschriftet), Türen gelb, Gate violett, Ankunft grün.
		for spec in OS.get_environment("PLAN").split(";", false):
			var lid := spec.get_slice(":", 0)
			var v := spec.get_slice(":", 1).split(",")
			var cx := float(v[0])
			var cz := float(v[1])
			var size := float(v[2]) if v.size() > 2 else 60.0
			var ph := float(v[3]) if v.size() > 3 else 9.0
			w._time_running = false
			await w.load_location(lid)
			for c in w.overlay_layer.get_children():
				c.queue_free()
			await _wait(1.0)
			w.cinematic = true
			var root := Node3D.new()
			w.level.add_child(root)
			var gm := B3.mat(Color(1, 1, 1, 0.55), 1.0, 0.0, Color(1, 1, 1), 1.2)
			var gm2 := B3.mat(Color(1, 0.3, 0.3, 0.7), 1.0, 0.0, Color(1, 0.3, 0.3), 1.6)
			var x0 := floorf((cx - size * 0.5) / 5.0) * 5.0
			var z0 := floorf((cz - size * 0.5) / 5.0) * 5.0
			var steps := int(size / 5.0) + 2
			for i in steps:
				var gx := x0 + i * 5.0
				var gz := z0 + i * 5.0
				var thick := int(roundf(gx)) % 10 == 0
				B3.box(root, Vector3(0.12 if thick else 0.05, 0.02, size + 10.0), Vector3(gx, ph - 3.0, cz), gm2 if thick else gm, false)
				thick = int(roundf(gz)) % 10 == 0
				B3.box(root, Vector3(size + 10.0, 0.02, 0.12 if thick else 0.05), Vector3(cx, ph - 3.0, gz), gm2 if thick else gm, false)
				if int(roundf(gx)) % 10 == 0:
					var lb := Label3D.new()
					lb.text = "x%d" % int(gx)
					lb.pixel_size = 0.02
					lb.font_size = 48
					lb.modulate = Color(1, 0.4, 0.4)
					lb.rotation_degrees = Vector3(-90, 0, 0)
					lb.position = Vector3(gx + 0.8, ph - 2.9, cz - size * 0.45)
					root.add_child(lb)
				if int(roundf(gz)) % 10 == 0:
					var lb2 := Label3D.new()
					lb2.text = "z%d" % int(gz)
					lb2.pixel_size = 0.02
					lb2.font_size = 48
					lb2.modulate = Color(1, 0.4, 0.4)
					lb2.rotation_degrees = Vector3(-90, 0, 0)
					lb2.position = Vector3(cx - size * 0.45, ph - 2.9, gz - 0.8)
					root.add_child(lb2)
			var mark := func(pos: Vector3, col: Color) -> void:
				B3.cyl(root, 0.6, 0.6, 0.1, Vector3(pos.x, ph - 2.8, pos.z), B3.mat(col, 1.0, 0.0, col, 3.0), false, 12)
			mark.call(w.anchors.spawn, Color(0.2, 1.0, 0.3))
			if w.anchors.has("gate"):
				mark.call(w.anchors.gate, Color(0.7, 0.3, 1.0))
			for a in w.actors:
				if a.has_meta("door"):
					mark.call(a.global_position, Color(1.0, 0.85, 0.2))
			for pk in w.quest_world.pickups:
				mark.call(pk.global_position, Color(0.3, 0.8, 1.0))
			var cam := Camera3D.new()
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = size
			cam.near = 0.05
			cam.far = ph + 20.0
			w.add_child(cam)
			cam.look_at_from_position(Vector3(cx, ph, cz), Vector3(cx, 0, cz), Vector3(0, 0, -1))
			cam.current = true
			var menv: Environment = null
			for c in w.level.get_children():
				if c is WorldEnvironment:
					menv = (c as WorldEnvironment).environment
			if menv:
				menv.fog_enabled = false
				menv.volumetric_fog_enabled = false
				menv.tonemap_exposure = maxf(menv.tonemap_exposure, 1.0) * 1.3
				menv.ambient_light_energy = maxf(menv.ambient_light_energy, 1.0) * 2.0
			await _wait(0.8)
			_shot("plan_" + lid)
			cam.queue_free()
			root.queue_free()
			w.cinematic = false
		print("PLANDONE")
		get_tree().quit()
		return
	if only == "lookhide":
		# Ursache eines Effekts eingrenzen: LOOK="ort:x,y,z" – Blick aus 2,6 m auf den Punkt, dann der Reihe nach Klassen in
		# 1,5 m Umkreis ausblenden (CPU-Partikel, Flammen-Quads, Lichter) und je ein Bild aufnehmen
		var spec := OS.get_environment("LOOK")
		var lid := spec.get_slice(":", 0)
		var v := spec.get_slice(":", 1).split(",")
		var c0 := Vector3(float(v[0]), float(v[1]), float(v[2]))
		w._time_running = false
		await w.load_location(lid)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		w.cinematic = true
		var fr := OS.get_environment("LOOKFROM").split(",")
		var from := Vector3(float(fr[0]), float(fr[1]), float(fr[2])) if fr.size() == 3 else c0 + Vector3(-2.2, 0.2, -1.4)
		w.player.global_position = from + Vector3(0, -1.6, 0)
		var cam := Camera3D.new()
		cam.fov = 50.0
		w.add_child(cam)
		cam.look_at_from_position(from, c0 + Vector3(0, 0.5, 0))
		cam.current = true
		await _wait(0.8)
		_shot("look_0_alles")
		var groups := [["CPUParticles3D", "look_1_ohne_partikel"], ["MeshInstance3D", "look_2_ohne_flammen"], ["OmniLight3D", "look_3_ohne_licht"]]
		for gpair in groups:
			for n in w.find_children("*", String(gpair[0]), true, false):
				var n3 := n as Node3D
				if n3.global_position.distance_to(c0) > 1.5:
					continue
				if n3 is MeshInstance3D and not ((n3 as MeshInstance3D).mesh is QuadMesh):
					continue
				n3.visible = false
			await _wait(0.6)
			_shot(String(gpair[1]))
		print("LOOKDONE")
		get_tree().quit()
		return
	if only == "near":
		# Was steckt an einer Stelle? NEAR="ort:x,y,z,r" – alle sichtbaren Geometrien und Partikel im Umkreis mit Klasse,
		# Pfad, Größe und Material (Textur ja/nein) – zum Aufspüren von Effekten ohne Textur.
		for spec in OS.get_environment("NEAR").split(";", false):
			var lid := spec.get_slice(":", 0)
			var v := spec.get_slice(":", 1).split(",")
			var c0 := Vector3(float(v[0]), float(v[1]), float(v[2]))
			var rad := float(v[3]) if v.size() > 3 else 2.0
			if w.loc.get("id", "") != lid:
				w._time_running = false
				await w.load_location(lid)
				await _wait(1.0)
			for vi in w.find_children("*", "VisualInstance3D", true, false):
				var vv := vi as VisualInstance3D
				if not vv.is_visible_in_tree() or vv is GeometryInstance3D:
					continue
				var dv := vv.global_position.distance_to(c0)
				if dv <= rad:
					var extra := ""
					if vv is Light3D:
						extra = " Energie %.2f Nebel %.2f Schatten %s" % [(vv as Light3D).light_energy, (vv as Light3D).light_volumetric_fog_energy, (vv as Light3D).shadow_enabled]
					print("NEAR %.1f m %s | %s%s" % [dv, String(w.get_path_to(vv)).right(70), vv.get_class(), extra])
			for gi in w.find_children("*", "GeometryInstance3D", true, false):
				var g := gi as GeometryInstance3D
				if not g.is_visible_in_tree():
					continue
				var d := g.global_position.distance_to(c0)
				if d > rad:
					continue
				var info := g.get_class() + " "
				var mat: Material = g.material_override
				if g is CPUParticles3D:
					var cp := g as CPUParticles3D
					info = "CPU-Partikel %d" % cp.amount
					if cp.mesh:
						mat = cp.mesh.surface_get_material(0) if cp.mesh.get_surface_count() > 0 else null
						if mat == null and cp.mesh is PrimitiveMesh:
							mat = (cp.mesh as PrimitiveMesh).material
				elif g is GPUParticles3D:
					var gp := g as GPUParticles3D
					info = "GPU-Partikel %d" % gp.amount
					if mat == null and gp.draw_pass_1 is PrimitiveMesh:
						mat = (gp.draw_pass_1 as PrimitiveMesh).material
				elif g is MeshInstance3D:
					var mi := g as MeshInstance3D
					var ab := mi.get_aabb()
					info = "Mesh %s %.2fx%.2fx%.2f" % [mi.mesh.get_class() if mi.mesh else "-", ab.size.x, ab.size.y, ab.size.z]
					if mat == null and mi.mesh and mi.mesh.get_surface_count() > 0:
						mat = mi.get_active_material(0)
				var mi2 := "-"
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					mi2 = "Std tex=%s billboard=%d blend=%d" % [sm.albedo_texture != null, sm.billboard_mode, sm.blend_mode]
				elif mat is ShaderMaterial:
					mi2 = "Shader %s" % String((mat as ShaderMaterial).shader.resource_path.get_file() if (mat as ShaderMaterial).shader else "-")
				print("NEAR %.1f m %s | %s | %s" % [d, String(w.get_path_to(g)).right(70), info, mi2])
		print("NEARDONE")
		get_tree().quit()
		return
	if only == "probe":
		# Bodenprobe: PROBE="ort:x,z;ort:x,z" – was liegt unter dem Punkt (Kollisionskörper, Höhe, Neigung)?
		for spec in OS.get_environment("PROBE").split(";", false):
			var lid := spec.get_slice(":", 0)
			var xz := spec.get_slice(":", 1).split(",")
			if w.loc.get("id", "") != lid:
				w._time_running = false
				await w.load_location(lid)
				await _wait(0.8)
			var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
			var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
			var excl: Array[RID] = []
			for k in 4:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 80.0, p - Vector3.UP * 80.0, 1, excl))
				if hit.is_empty():
					break
				var col: Node = hit.collider
				print("PROBE %s (%s, %s) Treffer %d: y=%.2f Neigung %.0f° Körper %s/%s" % [lid, xz[0], xz[1], k, hit.position.y, rad_to_deg(acos((hit.normal as Vector3).y)), col.get_parent().name if col.get_parent() else "-", col.name])
				excl.append(hit.rid)
		print("PROBEDONE")
		get_tree().quit()
		return
	if only == "dresscheck":
		# Ausstattung prüfen (DRESSLOCS=ort,ort; leer = alle): jedes Stück aus data/dressing.json auf Überschneidung
		# mit Gebäuden oder Fels, fehlenden Boden und Hanglage testen – Ergebnis als AUSSTATTUNG-Zeilen.
		var want := OS.get_environment("DRESSLOCS").split(",", false)
		for l in Content.locations:
			if not want.is_empty() and not l.id in want:
				continue
			w._time_running = false
			await w.load_location(l.id)
			await _wait(0.8)
			for c in w.overlay_layer.get_children():
				c.queue_free()
			var holder: Node = w.level.find_child("Ausstattung", true, false)
			if holder == null:
				print("AUSSTATTUNG %s: keine Einträge" % l.id)
				continue
			var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
			var bad := 0
			for n in holder.get_children():
				var nd := n as Node3D
				var pos := nd.global_position
				var e: Dictionary = nd.get_meta("entry", {})
				if String(e.get("kind", "")) in Dressing.SOFT or String(e.get("kind", "")) == "folk" or String(nd.name).begins_with("Townsfolk"):
					continue
				var own: Array[RID] = [w.player.get_rid()]
				for b in nd.find_children("*", "StaticBody3D", true, false):
					own.append((b as StaticBody3D).get_rid())
				var sh := SphereShape3D.new()
				sh.radius = 0.6
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = sh
				q.transform = Transform3D(Basis(), pos + Vector3.UP * 1.0)
				q.collision_mask = 1
				q.exclude = own
				var names: Array = []
				for h in space.intersect_shape(q, 8):
					var col: Object = h.collider
					if col is CharacterBody3D or (col is Node and nd.is_ancestor_of(col as Node)):
						continue
					if col is Node:
						var par := (col as Node).get_parent()
						names.append(String((col as Node).name) if par == null else "%s/%s" % [par.name, (col as Node).name])
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos - Vector3.UP * 4.0, 0x7FFFFFFF, own))
				var note := ""
				if ground.is_empty():
					note = "KEIN BODEN"
				elif (ground.normal as Vector3).y < 0.9:
					note = "HANG (Neigung %.0f°)" % rad_to_deg(acos((ground.normal as Vector3).y))
				elif absf(float(ground.position.y) - pos.y) > 0.25:
					note = "SCHWEBT %.2f m" % (pos.y - float(ground.position.y))
				var want_at: Array = e.get("at", [0, 0])
				if want_at.size() == 2 and Vector2(pos.x, pos.z).distance_to(Vector2(float(want_at[0]), float(want_at[1]))) > 0.3:
					note = ("%s · " % note if note != "" else "") + "verschoben von (%.1f, %.1f)" % [float(want_at[0]), float(want_at[1])]
				if not names.is_empty():
					note = ("%s · " % note if note != "" else "") + "KOLLISION " + ", ".join(names)
				if note != "":
					bad += 1
					print("AUSSTATTUNG %s #%d %s bei (%.1f, %.1f): %s" % [l.id, nd.get_index(), nd.name, pos.x, pos.z, note])
			print("AUSSTATTUNG %s: %d Stücke, %d auffällig" % [l.id, holder.get_child_count(), bad])
		print("DRESSDONE")
		get_tree().quit()
		return
	if only == "doors":
		# Türen: Ort laden, zur ersten Tür gehen, hinein, Bild, hinaus, Bild (DOORLOC=e_rantel)
		var lid := OS.get_environment("DOORLOC") if OS.get_environment("DOORLOC") != "" else "e_rantel"
		await w.load_location(lid)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var door: Actor3D = null
		var want_door := OS.get_environment("DOORID")
		for a in w.actors:
			if is_instance_valid(a) and String(a.id).begins_with("door:") and (want_door == "" or String(a.id) == "door:" + want_door):
				door = a
		if door == null:
			print("DOORS: keine Tür in %s" % lid)
			get_tree().quit()
			return
		w.player.global_position = door.global_position + Vector3(0, 0.1, 1.2)
		w.player.face(0.0)
		await _wait(1.0)
		_shot("doors_vor_der_tuer")
		print("DOORS Tür %s bei %s" % [door.label, door.global_position.snapped(Vector3(0.1, 0.1, 0.1))])
		w._interact(door)
		await _wait(4.0)
		print("DOORS drinnen: %s · Spieler %s · Figuren: %s" % [w.loc.id, w.player.global_position.snapped(Vector3(0.1, 0.1, 0.1)), ", ".join(w.actors.map(func(x): return String(x.id)))])
		_shot("doors_drinnen")
		# Rundblick innen
		for k in 4:
			w.player.cam_yaw = k * PI * 0.5
			await _wait(0.5)
			_shot("doors_innen_%d" % k)
		# DOORWALK="x,z,yaw_grad,sekunden": an eine Stelle treten und geradeaus gehen (Treppen prüfen)
		if OS.get_environment("DOORWALK") != "":
			var dw := OS.get_environment("DOORWALK").split(",")
			w.player.global_position = Vector3(float(dw[0]), 0.2, float(dw[1]))
			w.player.face(deg_to_rad(float(dw[2])))
			await _wait(0.3)
			Input.action_press("move_forward")
			await _wait(float(dw[3]))
			Input.action_release("move_forward")
			await _wait(0.4)
			print("DOORWALK Spieler jetzt bei %s" % w.player.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
			_shot("doors_walk")
		var ex: Actor3D = null
		for a in w.actors:
			if is_instance_valid(a) and a.id == "exit":
				ex = a
		if ex:
			w.player.global_position = ex.global_position + Vector3(0, 0.1, -1.0)
			await _wait(0.5)
			w._interact(ex)
			await _wait(4.0)
			print("DOORS draußen: %s · Spieler %s" % [w.loc.id, w.player.global_position.snapped(Vector3(0.1, 0.1, 0.1))])
			_shot("doors_draussen")
		get_tree().quit()
		return
	if only == "stageview":
		# Rundblick von möglichen Bühnen: STAGEVIEW="sumpf:-64,48;katze:8,64" – je Ort vier Blickrichtungen (N, O, S, W)
		for spec in OS.get_environment("STAGEVIEW").split(";", false):
			var lid := spec.get_slice(":", 0)
			var xz := spec.get_slice(":", 1).split(",")
			if w.loc.get("id", "") != lid:
				await w.load_location(lid)
				for c in w.overlay_layer.get_children():
					c.queue_free()
				if OS.get_environment("TOD") != "":
					# feste Tageszeit für Bilder (0 = Sonnenaufgang, 0,25 = Mittag, 0,5 = Abend, 0,8 = Nacht)
					w.day_cycle.force = float(OS.get_environment("TOD"))
					w.day_cycle.update(0.0)
					print("TAGESZEIT %s: Phase %.2f (%s), aktiv %s" % [lid, w.day_cycle.phase, w.day_cycle.time_name(), w.day_cycle.active])
				if OS.get_environment("WEATHER") != "":
					# festes Wetter für Bilder (clear, overcast, rain, fog, snow, sand)
					w.weather.force = OS.get_environment("WEATHER")
					w.weather.refresh(int(Game.state.get("day", 1)), true)
					print("WETTER %s: %s (Partikel %s)" % [lid, w.weather.kind, w.weather._particles != null])
				if OS.get_environment("TOD") != "":
					await _wait(0.5)
					print("NACHT %s: Gegner %d · Fensterlichter %d" % [lid, w.enemies.size(), get_tree().get_nodes_in_group("window_glow").size()])
				await _wait(1.0)
				for gm in w.level.find_children("*", "MeshInstance3D", true, false):
					if String(gm.name).to_lower().begins_with("ground"):
						var gb: AABB = (gm as MeshInstance3D).global_transform * (gm as MeshInstance3D).get_aabb()
						print("BODEN %s: %s … %s" % [lid, gb.position.snapped(Vector3.ONE), gb.end.snapped(Vector3.ONE)])
			if spec.get_slice(":", 1) == "map":
				# Draufsicht über den ganzen Ort (Norden = oben), Raster alle 50 m als Säulen
				var mc := Camera3D.new()
				mc.far = 4000.0
				mc.fov = 55.0
				w.add_child(mc)
				mc.look_at_from_position(Vector3(0, 320, 0.5), Vector3.ZERO, Vector3(0, 0, -1))
				mc.current = true
				# Karte ohne Nebel und heller (sonst versinken Wald und Nacht im Dunst)
				var menv: Environment = null
				for c in w.level.get_children():
					if c is WorldEnvironment:
						menv = (c as WorldEnvironment).environment
				var saved := []
				if menv:
					saved = [menv.fog_enabled, menv.volumetric_fog_enabled, menv.tonemap_exposure, menv.ambient_light_energy]
					menv.fog_enabled = false
					menv.volumetric_fog_enabled = false
					menv.tonemap_exposure = maxf(menv.tonemap_exposure, 1.0) * 1.4
					menv.ambient_light_energy = maxf(menv.ambient_light_energy, 1.0) * 1.8
				var marks: Array = []
				await _wait(0.5)
				for pk in w.quest_world.pickups:
					if not is_instance_valid(pk) or not pk.kind in ["lore", "shrine", "cache"]:
						continue
					var mk2 := MeshInstance3D.new()
					var cy2 := CylinderMesh.new()
					cy2.top_radius = 1.5
					cy2.bottom_radius = 1.5
					cy2.height = 40.0
					mk2.mesh = cy2
					var mm2 := StandardMaterial3D.new()
					mm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mm2.albedo_color = {"lore": Color(0.3, 0.8, 1.0), "shrine": Color(1.0, 0.85, 0.3), "cache": Color(1.0, 0.2, 0.9)}[pk.kind]
					mk2.material_override = mm2
					w.level.add_child(mk2)
					mk2.global_position = pk.global_position + Vector3(0, 20, 0)
					marks.append(mk2)
					print("ENTDECKUNG %s %s bei %s" % [lid, pk.kind, pk.global_position.snapped(Vector3(0.1, 0.1, 0.1))])
				for gx in range(-100, 101, 50):
					for gz in range(-100, 101, 50):
						var mk := MeshInstance3D.new()
						var cy := CylinderMesh.new()
						cy.top_radius = 1.2
						cy.bottom_radius = 1.2
						cy.height = 30.0
						mk.mesh = cy
						var mm := StandardMaterial3D.new()
						mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						mm.albedo_color = Color.RED if gx == 0 and gz == 0 else (Color.YELLOW if gz < 0 else Color.CYAN)
						mk.material_override = mm
						w.level.add_child(mk)
						mk.global_position = Vector3(gx, 15, gz)
						marks.append(mk)
				for cl in w.find_children("*", "CanvasLayer", true, false):
					(cl as CanvasLayer).visible = false
				await _wait(1.5)
				_shot("map_%s" % lid)
				if menv:
					menv.fog_enabled = saved[0]
					menv.volumetric_fog_enabled = saved[1]
					menv.tonemap_exposure = saved[2]
					menv.ambient_light_energy = saved[3]
				for mk in marks:
					mk.queue_free()
				mc.queue_free()
				w.player.camera.current = true
				for cl in w.find_children("*", "CanvasLayer", true, false):
					(cl as CanvasLayer).visible = true
				continue
			var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
			var hit: Dictionary = w.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 80.0, p - Vector3.UP * 80.0, 1))
			if hit:
				p.y = float(hit.position.y)
			w.player.global_position = p + Vector3.UP * 0.1
			var cam := Camera3D.new()
			cam.far = 3000.0
			cam.fov = 70.0
			w.add_child(cam)
			cam.current = true
			for cl in w.find_children("*", "CanvasLayer", true, false):
				(cl as CanvasLayer).visible = false
			var interior: bool = w.loc.get("group", "") in ["interior", "nazarick"]
			if interior:
				cam.current = false
				w.player.camera.current = true     # drinnen: die Spielerkamera (eine frische Kamera bleibt dort dunkel)
			for k in 4:
				var yaw := k * PI * 0.5
				var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
				if interior:
					w.player.cam_yaw = yaw
				else:
					cam.look_at_from_position(p - fwd * 7.0 + Vector3.UP * 3.0, p + fwd * 12.0 + Vector3.UP * 1.5)
				await _wait(1.2)
				_shot("view_%s_%s_%s_%d" % [lid, xz[0], xz[1], k])
			cam.queue_free()
			w.player.camera.current = true
			for cl in w.find_children("*", "CanvasLayer", true, false):
				(cl as CanvasLayer).visible = true
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
			for k in a:
				if a[k] is Array:
					print("ANKER %s %s: %s" % [lid, k, ", ".join((a[k] as Array).map(func(p): return str((p as Vector3).snapped(Vector3(0.1, 0.1, 0.1)))))])
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
		w._time_running = false
		await w.load_location(l.id)
		await _wait(0.6)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		# HIDE="muster,muster" – Teile des Ortes für die Aufnahmen ausblenden (Zuordnung einzelner Modellteile)
		# PROBEMATS="x,y,z" – Musterklötze der Fotomaterialien nebeneinander (Klasse/Foto), um schwarze Materialien zu finden
		var pmv := OS.get_environment("PROBEMATS").split(",", false)
		if pmv.size() == 3:
			var base := Vector3(float(pmv[0]), float(pmv[1]), float(pmv[2]))
			var specs := [["bark", "wood"], ["planks", "wood"], ["logs", "wood"], ["wood", "wood"], ["limestone", "stone"], ["cliff", "stone"], ["planks", "plaster"], ["bark", "stone"]]
			for k in specs.size():
				var sp: Array = specs[k]
				var pm := BuildingLook.photo_material(String(sp[0]), String(sp[1]), Color(1, 1, 1), 0.1)
				B3.box(w.level, Vector3(0.5, 0.5, 0.5), base + Vector3((k - 3.5) * 0.7, 0.25, 0), pm, false)
				B3.box(w.level, Vector3(0.5, 0.5, 0.5), base + Vector3((k - 3.5) * 0.7, 1.6, 0), pm, false)
		for pat in OS.get_environment("HIDE").split(",", false):
			for hn in w.level.find_children(pat, "Node3D", true, false):
				(hn as Node3D).visible = false
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
## Freie, ebene Plätze für Story-Bühnen suchen (LOC=stageprobe STAGELOCS=sumpf,katze …): Raster um den Startpunkt,
## je Punkt freier Radius (keine Kollision außer Boden bis 3 m Höhe), Steigung auf 10 m und Wasser; Bestenliste.
func _stage_probe(w: Node) -> void:
	for lid in OS.get_environment("STAGELOCS").split(",", false):
		await w.load_location(lid)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		await _wait(1.0)
		var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
		var waters: Array = []
		for mi in w.level.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name).to_lower()
			if nm.begins_with("water") or nm.contains("nocol_water"):
				waters.append((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb())
		var ground := func(p: Vector3) -> Dictionary:
			return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 80.0, p.z), Vector3(p.x, p.y - 80.0, p.z), 1))
		var spawn: Vector3 = w.anchors.spawn
		var cands: Array = []
		var span := int(OS.get_environment("STAGESPAN")) if OS.get_environment("STAGESPAN") != "" else 96
		for gz in range(-span, span + 1, 4):
			for gx in range(-span, span + 1, 4):
				var p := spawn + Vector3(gx, 0, gz)
				var hit: Dictionary = ground.call(p)
				if hit.is_empty():
					continue
				var c: Vector3 = hit.position
				var under := false
				for wa in waters:
					var a: AABB = wa
					if c.x > a.position.x and c.x < a.end.x and c.z > a.position.z and c.z < a.end.z and c.y < a.end.y - 0.05:
						under = true
				if under:
					continue
				# Steigung: Höhen auf einem 10-m-Ring
				var slope := 0.0
				for k in 8:
					var q := c + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * 10.0
					var hq: Dictionary = ground.call(q)
					slope = maxf(slope, absf(float(hq.position.y) - c.y) if not hq.is_empty() else 9.0)
				if slope > 2.5:
					continue
				# freier Radius: Zylinder 0,6–3,6 m über dem Boden, Boden selbst ausgenommen
				var free := 0.0
				for r in [4.0, 5.5, 7.0, 8.5, 10.0, 13.0, 16.0, 20.0]:
					var cyl := CylinderShape3D.new()
					cyl.radius = r
					cyl.height = 3.0
					var qp := PhysicsShapeQueryParameters3D.new()
					qp.shape = cyl
					qp.transform = Transform3D(Basis(), c + Vector3(0, 0.6 + 1.5 + slope * 0.5, 0))
					qp.exclude = [hit.rid]
					qp.collision_mask = 0xFFFFFFFF
					var res := space.intersect_shape(qp, 4)
					var blocked := false
					for hr in res:
						if not (hr.collider is CharacterBody3D):
							blocked = true
					if blocked:
						break
					free = r
				if free < (float(OS.get_environment("STAGEMIN")) if OS.get_environment("STAGEMIN") != "" else 10.0):
					continue
				cands.append([free, slope, c, c.distance_to(spawn)])
		cands.sort_custom(func(a, b): return a[0] * 10.0 - a[1] * 3.0 - a[3] * 0.02 > b[0] * 10.0 - b[1] * 3.0 - b[3] * 0.02)
		print("STAGE %s · Start %s · %d Kandidaten" % [lid, spawn.snapped(Vector3(0.1, 0.1, 0.1)), cands.size()])
		var marks: Array = []
		var n := 0
		for cd in cands.slice(0, 10):
			n += 1
			var c: Vector3 = cd[2]
			print("STAGE   #%d frei %4.0f m · Steigung %4.1f m · Abstand Start %5.1f m · pos [%d, %d] (y %.1f)" % [n, cd[0], cd[1], cd[3], roundi(c.x), roundi(c.z), c.y])
			if n <= 4:
				var m := MeshInstance3D.new()
				var cy := CylinderMesh.new()
				cy.top_radius = 0.6
				cy.bottom_radius = 0.6
				cy.height = 12.0
				m.mesh = cy
				var mat := StandardMaterial3D.new()
				mat.albedo_color = [Color.RED, Color.ORANGE, Color.YELLOW, Color.CYAN][n - 1]
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 3.0
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.material_override = mat
				w.level.add_child(m)
				m.global_position = c + Vector3(0, 6, 0)
				marks.append(m)
		if not cands.is_empty() and OS.get_environment("STAGESHOT") != "":
			var cam := Camera3D.new()
			cam.far = 3000.0
			cam.fov = 70.0
			w.add_child(cam)
			var best: Vector3 = cands[0][2]
			cam.look_at_from_position(best + Vector3(0, 70, 30), best)
			cam.current = true
			for cl in w.find_children("*", "CanvasLayer", true, false):
				(cl as CanvasLayer).visible = false
			await _wait(1.5)
			_shot("stage_%s" % lid)
			cam.queue_free()
			w.player.camera.current = true
			for cl in w.find_children("*", "CanvasLayer", true, false):
				(cl as CanvasLayer).visible = true
		for m in marks:
			m.queue_free()


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


## Leistungsmessung je Ort: 8 s aufwärmen (Shader, Streaming), dann 10 s messen, während die Kamera einmal rundum
## schwenkt. Ohne VSync und Bildratenbegrenzung, sonst mit den Einstellungen des Spielers (Auflösung, FSR).
##   LOC=bench BENCHLOCS=carne,e_rantel   (leer = alle Orte)
func _bench(w: Node) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vrid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	if OS.get_environment("BENCHQ") != "":
		Settings.graphics = int(OS.get_environment("BENCHQ"))
		GraphicsQuality.apply_global()
	var want: PackedStringArray = OS.get_environment("BENCHLOCS").split(",", false)
	var locs: Array = []
	for l in Content.locations:
		if want.is_empty() or String(l.id) in want:
			locs.append(String(l.id))
	var vp_size := get_viewport().get_visible_rect().size
	print("BENCH Fenster %dx%d · 3D-Skalierung %.2f (%s) · AA %d · Grafik %s" % [vp_size.x, vp_size.y, get_viewport().scaling_3d_scale,
		"FSR2" if get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 else "bilinear", Settings.antialias, GraphicsQuality.NAMES[GraphicsQuality.level()]])
	var summary: Array = []
	for lid in locs:
		await w.load_location(lid)
		for c in w.overlay_layer.get_children():
			c.queue_free()
		var p: Player3D = w.player
		p.max_hp = 99999.0
		p.hp = p.max_hp
		if OS.get_environment("BENCHLEVELS") != "":
			summary.append(await _bench_levels(w, vrid, lid))
			continue
		var y0 := p.cam_yaw
		var t := 0.0
		while t < 8.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			w.cinematic = true                 # Gegner ruhen (Animation läuft), keine Eingaben
			p.cam_yaw = y0 + t / 8.0 * TAU
		var frames: Array = []
		var acc := {"cpu": 0.0, "gpu": 0.0, "setup": 0.0, "proc": 0.0, "phys": 0.0, "dc": 0.0, "dcs": 0.0, "obj": 0.0, "prim": 0.0}
		t = 0.0
		while t < 10.0:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			frames.append(dt)
			w.cinematic = true
			p.cam_yaw = y0 + t / 10.0 * TAU
			acc.cpu += RenderingServer.viewport_get_measured_render_time_cpu(vrid)
			acc.gpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			acc.setup += RenderingServer.get_frame_setup_time_cpu()
			acc.proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			acc.phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			acc.dc += RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			acc.dcs += RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			acc.obj += RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
			acc.prim += RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		w.cinematic = false
		var n := maxi(1, frames.size())
		frames.sort()
		var fps := n / maxf(t, 0.001)
		var low := 1.0 / maxf(float(frames[mini(n - 1, int(n * 0.99))]), 0.0001)
		var line := "BENCH %-17s FPS %5.1f (1%%-Tief %5.1f) | Render-CPU %5.1f ms · GPU %5.1f ms · Aufbau %4.1f · Skripte %4.1f · Physik %4.1f | Draw %5d + Schatten %5d · Objekte %5d · Dreiecke %5.1f M · VRAM %4d MB" % [
			lid, fps, low, acc.cpu / n, acc.gpu / n, acc.setup / n, acc.proc / n, acc.phys / n, int(acc.dc / n), int(acc.dcs / n), int(acc.obj / n),
			acc.prim / n / 1000000.0, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576)]
		print(line)
		summary.append(line)
		if OS.get_environment("BENCHSHOT") != "":
			_shot("bench_" + lid)
		if OS.get_environment("BENCHINFO") != "":
			_geo_info(w)
		if OS.get_environment("BENCHAB") != "":
			await _bench_ab(w, vrid)
		if OS.get_environment("BENCHOPT") != "":
			await _bench_opt(w, vrid, lid)
	print("BENCH fertig: %d Orte" % summary.size())


## Grafikstufen nacheinander (BENCHLEVELS="2,1,0"): je Stufe dieselbe Kamerafahrt messen und ein Bild aus
## derselben Blickrichtung speichern (BENCHSHOT) – zum Vergleich von Bildrate und Bildwirkung.
func _bench_levels(w: Node, vrid: RID, lid: String) -> String:
	var y0: float = w.player.cam_yaw
	var levels := OS.get_environment("BENCHLEVELS").split(",", false)
	var settle := func(secs: float) -> void:
		var t0 := 0.0
		while t0 < secs:                   # GI/SDFGI nach dem Umschalten einschwingen lassen
			await get_tree().process_frame
			t0 += get_process_delta_time()
			w.cinematic = true
			w.player.cam_yaw = y0
	# 1) Bilder: Kamera bleibt stehen (gleiche Detailstufen, gleicher Schattenwurf) – nur die Stufe wechselt
	if OS.get_environment("BENCHSHOT") != "":
		# Zeit anhalten (Wind in Laub und Schatten, Animationen): sonst wandern die Lichtflecken zwischen den Bildern
		Engine.time_scale = 0.0
		var idx := 0
		for lv in levels:
			idx += 1
			_bench_set_level(lv)
			var t_end := Time.get_ticks_msec() + 4000
			while Time.get_ticks_msec() < t_end:
				await get_tree().process_frame
				w.cinematic = true
			_shot("q_%s_%d_%s" % [lid, idx, lv])
		Engine.time_scale = 1.0
	# 2) Messung: je Stufe dieselbe Kamerafahrt
	var line := "BENCHQ %-17s" % lid
	for lv in levels:
		_bench_set_level(lv)
		await settle.call(2.0)
		var g := 0.0
		var frames: Array = []
		var tt := 0.0
		while tt < 6.0:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			tt += dt
			frames.append(dt)
			w.cinematic = true
			w.player.cam_yaw = y0 + tt / 6.0 * TAU
			g += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		var n := maxi(1, frames.size())
		frames.sort()
		var low := 1.0 / maxf(float(frames[mini(n - 1, int(n * 0.99))]), 0.0001)
		line += " | %s: %5.1f FPS (1%% %5.1f) GPU %5.1f ms" % [GraphicsQuality.NAMES[int(lv)].get_slice(" ", 0), n / maxf(tt, 0.001), low, g / n]
	w.cinematic = false
	w.player.cam_yaw = y0
	print(line)
	return line


## Stufe für den Vergleich setzen (wie in den Einstellungen).
func _bench_set_level(lv: String) -> void:
	Settings.graphics = int(lv)
	GraphicsQuality._applied = -1
	GraphicsQuality.apply_global()


## Sparmaßnahmen nacheinander (kumulativ) einschalten und messen – immer dieselbe Kamerafahrt.
func _bench_opt(w: Node, vrid: RID, lid: String) -> void:
	var env: Environment = null
	var sun: DirectionalLight3D = null
	for c in w.level.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D and sun == null:
			sun = c
	var y0: float = w.player.cam_yaw
	var measure := func() -> Array:
		w.player.cam_yaw = y0
		var t0 := 0.0
		while t0 < 1.5:
			await get_tree().process_frame
			t0 += get_process_delta_time()
			w.cinematic = true
		var g := 0.0
		var tt := 0.0
		var n := 0
		while tt < 5.0:
			await get_tree().process_frame
			tt += get_process_delta_time()
			w.cinematic = true
			w.player.cam_yaw = y0 + tt / 5.0 * TAU
			g += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			n += 1
		return [g / maxi(1, n), n / maxf(tt, 0.001)]
	var steps := [
		["Grundlage", func(): pass],
		["GI halbe Auflösung", func(): RenderingServer.gi_set_use_half_resolution(true)],
		["SDFGI 8 Strahlen, Licht alle 8 Bilder", func():
			RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8)
			RenderingServer.environment_set_sdfgi_frames_to_update_light(RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES)],
		["PCF statt PCSS", func():
			if sun:
				sun.light_angular_distance = 0.0
				sun.shadow_blur = 2.0],
		["SSR 32 Schritte", func():
			if env:
				env.ssr_max_steps = 32],
		["SSIL niedrig", func(): RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)],
		["Nebel 48er-Raster", func(): RenderingServer.environment_set_volumetric_fog_volume_size(48, 48)],
		["SSR aus", func():
			if env:
				env.ssr_enabled = false],
	]
	if OS.get_environment("BENCHSET") == "forest":
		steps += [
			["SDFGI ohne Verdeckung", func():
				if env:
					env.sdfgi_use_occlusion = false],
			["SDFGI 3 Kaskaden", func():
				if env:
					env.sdfgi_cascades = 3],
			["SDFGI Zelle 0.2", func():
				if env:
					env.sdfgi_min_cell_size = 0.2],
			["Schatten bis 50 m", func():
				if sun:
					sun.directional_shadow_max_distance = 50.0],
			["Volumennebel aus (Probe)", func():
				if env:
					env.volumetric_fog_enabled = false],
		]
	var base := 0.0
	for st in steps:
		(st[1] as Callable).call()
		var r: Array = await measure.call()
		if st[0] == "Grundlage":
			base = r[0]
		print("BENCHOPT %-14s + %-40s GPU %5.1f ms (%+5.1f) · FPS %5.1f" % [lid, st[0], r[0], float(r[0]) - base, r[1]])
		if OS.get_environment("BENCHSHOT") != "":
			w.player.cam_yaw = y0
			await _wait(0.6)
			_shot("opt_%s_%s" % [lid, String(st[0]).left(8).replace(" ", "_")])
	# zurück auf die eingestellte Grafikstufe (für den nächsten Ort)
	GraphicsQuality._applied = -1
	GraphicsQuality.apply_global()
	w.cinematic = false


## Wohin gehen die Dreiecke? Sichtbare Instanzen × Dreiecke je Netz, gruppiert nach Herkunft (Bäume je LOD-Stufe, Gras …).
func _geo_info(w: Node) -> void:
	var tris := func(m: Mesh) -> int:
		var n := 0
		if m is ArrayMesh:
			for s in m.get_surface_count():
				var il: int = (m as ArrayMesh).surface_get_array_index_len(s)
				n += (il if il > 0 else (m as ArrayMesh).surface_get_array_len(s)) / 3
		elif m:
			for s in m.get_surface_count():
				var a := m.surface_get_arrays(s)
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				n += (idx.size() if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		return n
	var cam := get_viewport().get_camera_3d()
	var groups := {}
	for mmi in w.level.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or not (mmi as Node3D).is_visible_in_tree():
			continue
		var vis := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		var gi := mmi as GeometryInstance3D
		if gi.visibility_range_end > 0.0 and cam and cam.global_position.distance_to(gi.global_transform * mm.get_aabb().get_center()) > gi.visibility_range_end + mm.get_aabb().size.length() * 0.5:
			continue
		var par: Node = mmi.get_parent()
		var kind := "FoliageLod" if par is FoliageLod else ("Gras" if par is GrassField else ("Bodendetails" if par is DetailField or (par and par.get_parent() is DetailField) else String(mmi.name).get_slice("_", 0)))
		if par is FoliageLod:
			kind += " L%d" % (mmi.get_index() % 3)
		var t: int = tris.call(mm.mesh)
		var key := "%s · %s (%d Dr.)" % [kind, mm.mesh.resource_name if mm.mesh.resource_name != "" else str(mm.mesh.get_instance_id() % 10000), t]
		if not groups.has(key):
			groups[key] = [0, 0, 0, gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF]
		groups[key][0] += vis
		groups[key][1] += vis * t
		groups[key][2] += 1
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	var total := 0
	for k in keys:
		total += int(groups[k][1])
	print("BENCHINFO Instanz-Dreiecke gesamt (vor Frustum-Culling): %.2f M" % (total / 1000000.0))
	for k in keys.slice(0, 22):
		print("BENCHINFO %-70s Inst %6d · %6.2f M Dr. · %3d Knoten%s" % [k, groups[k][0], groups[k][1] / 1000000.0, groups[k][2], " · Schatten" if groups[k][3] else ""])


## GPU-Kosten einzelner Effekte: jeweils abschalten, kurz messen, wieder einschalten.
func _bench_ab(w: Node, vrid: RID) -> void:
	var env: Environment = null
	var sun: DirectionalLight3D = null
	for c in w.level.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D and sun == null:
			sun = c
	var y0: float = w.player.cam_yaw
	var measure := func() -> Array:
		var g := 0.0
		var tt := 0.0
		var n := 0
		var t0 := 0.0
		w.player.cam_yaw = y0
		while t0 < 1.5:
			await get_tree().process_frame
			t0 += get_process_delta_time()
			w.cinematic = true
		while tt < 5.0:
			await get_tree().process_frame
			tt += get_process_delta_time()
			w.cinematic = true
			w.player.cam_yaw = y0 + tt / 5.0 * TAU
			g += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			n += 1
		return [g / maxi(1, n), n / maxf(tt, 0.001)]
	var base: Array = await measure.call()
	print("BENCHAB   Grundlage        GPU %5.1f ms · FPS %5.1f" % [base[0], base[1]])
	var hide := func(nodes: Array, on: bool) -> void:
		for nd in nodes:
			if is_instance_valid(nd):
				nd.visible = on
	var cases: Array = [
		["SDFGI", func(on): env.sdfgi_enabled = on],
		["SSIL", func(on): env.ssil_enabled = on],
		["SSAO", func(on): env.ssao_enabled = on],
		["SSR", func(on): env.ssr_enabled = on],
		["Volumennebel", func(on): env.volumetric_fog_enabled = on],
		["Glow", func(on): env.glow_enabled = on],
		["Sonnenschatten", func(on): sun.shadow_enabled = on],
		["Weiche Schatten", func(on): sun.light_angular_distance = 0.6 if on else 0.0],
		["Gras", func(on): hide.call(w.level.find_children("*", "GrassField", true, false), on)],
		["Streu-Laub", func(on): hide.call(w.level.find_children("*", "MultiMeshInstance3D", true, false).filter(func(m): return not m is GrassField and m.get_parent() and not m.get_parent() is GrassField), on)],
		["Punktlichter", func(on): hide.call(w.level.find_children("*", "OmniLight3D", true, false) + w.level.find_children("*", "SpotLight3D", true, false), on)],
		["Partikel", func(on): hide.call(w.level.find_children("*", "GPUParticles3D", true, false), on)],
		["Bewohner", func(on): hide.call(w.level.find_children("*", "Townsfolk", true, false), on)],
		["Figuren", func(on): hide.call(w.actors, on)],
		["Gegner", func(on): hide.call(w.enemies, on)],
	]
	if OS.get_environment("BENCHSET") == "forest":
		# Wald im Detail: welche Pflanzengruppe kostet im Bild bzw. im Schattendurchgang?
		var shadows := func(nodes: Array, on: bool) -> void:
			for nd in nodes:
				if not is_instance_valid(nd) or not nd is GeometryInstance3D:
					continue
				if not on:
					nd.set_meta("ab_cs", nd.cast_shadow)
					nd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				elif nd.has_meta("ab_cs"):
					nd.cast_shadow = nd.get_meta("ab_cs")
		var lod := func() -> Array: return w.level.find_children("FoliageLod", "", true, false)
		var lod_mm := func() -> Array:
			var r: Array = []
			for f in w.level.find_children("FoliageLod", "", true, false):
				r += f.get_children()
			return r
		var foto := func() -> Array: return w.level.find_children("foto_streu_*", "MultiMeshInstance3D", true, false)
		var streu := func() -> Array: return w.level.find_children("mm_*", "MultiMeshInstance3D", true, false)
		var inst := func() -> Array: return w.level.find_children("inst_*", "MultiMeshInstance3D", true, false)
		var detail := func() -> Array: return w.level.find_children("*", "DetailField", true, false)
		var detail_mm := func() -> Array:
			var r: Array = []
			for f in w.level.find_children("*", "DetailField", true, false):
				r += f.find_children("*", "MultiMeshInstance3D", true, false)
			return r
		var meshes := func() -> Array: return w.level.find_children("*", "MeshInstance3D", true, false)
		cases = [
			["Bäume (LOD)", func(on): hide.call(lod.call(), on)],
			["Baum-Schatten", func(on): shadows.call(lod_mm.call(), on)],
			["Fotopflanzen", func(on): hide.call(foto.call(), on)],
			["Fotopfl.-Schatten", func(on): shadows.call(foto.call(), on)],
			["Streu mm_", func(on): hide.call(streu.call(), on)],
			["Streu-Schatten", func(on): shadows.call(streu.call(), on)],
			["inst_-Modelle", func(on): hide.call(inst.call(), on)],
			["inst_-Schatten", func(on): shadows.call(inst.call(), on)],
			["Bodendetails", func(on): hide.call(detail.call(), on)],
			["Bodendet.-Schatten", func(on): shadows.call(detail_mm.call(), on)],
			["Gras", func(on): hide.call(w.level.find_children("*", "GrassField", true, false), on)],
			["Mesh-Schatten", func(on): shadows.call(meshes.call(), on)],
			["Sonnenschatten", func(on): sun.shadow_enabled = on],
			["Filter sehr niedrig", func(on): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if on else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)],
			["Schattenkarte 2048", func(on): RenderingServer.directional_shadow_atlas_set_size(4096 if on else 2048, true)],
			["SDFGI", func(on): env.sdfgi_enabled = on],
			["SSR", func(on): env.ssr_enabled = on],
			["Volumennebel", func(on): env.volumetric_fog_enabled = on],
		]
	for cs in cases:
		if (String(cs[0]) in ["SDFGI", "SSIL", "SSAO", "SSR", "Volumennebel", "Glow"] and env == null) or (String(cs[0]).ends_with("chatten") and sun == null):
			continue
		var f: Callable = cs[1]
		var keep_ad := sun.light_angular_distance if sun else 0.0
		f.call(false)
		var r: Array = await measure.call()
		f.call(true)
		if cs[0] == "Weiche Schatten" and sun:
			sun.light_angular_distance = keep_ad
		print("BENCHAB   ohne %-19s GPU %5.1f ms (%+5.1f) · FPS %5.1f" % [cs[0], r[0], float(r[0]) - float(base[0]), r[1]])
	w.cinematic = false


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
		var r := CharacterRig.create(ProcModel.model_of(ids[i]), func(rr): ProcModel.figure(rr, ids[i]))
		ProcModel.accessories(r, ids[i])
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


## Controller-Simulation: Taste drücken und loslassen (Input.parse_input_event braucht kein echtes Gerät).
func _pad_button(b: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = b
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.1)
	var up := InputEventJoypadButton.new()
	up.device = 0
	up.button_index = b
	up.pressed = false
	Input.parse_input_event(up)


func _pad_axis(a: JoyAxis, v: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = a
	ev.axis_value = v
	Input.parse_input_event(ev)

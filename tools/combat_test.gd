extends Node3D
## Kampf- und Modelltest (headless lauffähig):
##   godot --headless --path . res://tools/combat_test.tscn
## Prüft Treffer, Kombo, schwere Attacke, Ausweichen (i-Frames), Block, Parade, Ausdauer,
## Mana, alle Zauber/Techniken, Statuseffekte, Lock-on, Tod – und das Laden echter .glb-Modelle
## (inkl. Animationszuordnung) über eine zur Laufzeit erzeugte Testdatei.

var player: Player3D
var fails := 0


func _ready() -> void:
	Game.rng.seed = 3
	Game.new_game()
	B3.ground(self, 30, B3.mat(Color(0.3, 0.3, 0.3)))
	player = Player3D.new()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.face(0.0)   # Blick nach −Z
	await _wait(0.3)
	await _test_light()
	await _test_heavy_and_stamina()
	await _test_dodge()
	await _test_block_and_parry()
	await _test_spells()
	await _test_momon()
	await _test_lock_and_kill()
	await _test_models()
	print("KAMPFTEST: %s (%d Fehler)" % ["OK" if fails == 0 else "FEHLER", fails])
	get_tree().quit(1 if fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	print(("  ✔ " if cond else "  ✗ ") + what)
	if not cond:
		fails += 1


func _enemy(id: String, dist: float = 1.6, ai: bool = false) -> Enemy3D:
	var e := Enemy3D.create(id)
	e.position = player.global_position + Vector3(0, 0, -dist)
	add_child(e)
	e.add_to_group("enemies")
	e.target = player if ai else null
	e.face_towards(player.global_position)
	return e


func _reset_player() -> void:
	player.revive()
	player.set_state(Fighter.S.IDLE)
	player.cooldowns.clear()
	player.shield_time = 0.0
	player.global_position = Vector3(0, 0.1, 0)
	player.face(0.0)
	player.knock = Vector3.ZERO


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	await _wait(0.1)


func _test_light() -> void:
	print("Leichte Attacke & Kombo")
	var e := _enemy("golem")
	await _wait(0.2)
	var hp0 := e.hp
	check(player.request("light"), "Leichte Attacke startet")
	check(player.state == Fighter.S.ATTACK and player.phase == "windup", "Wind-up-Phase aktiv")
	player.request("light")   # gepuffert → Kombo
	await _wait(1.4)
	check(e.hp < hp0, "Golem nimmt Schaden (%.0f → %.0f)" % [hp0, e.hp])
	check(player._combo != 0 or e.hp < hp0 - 10.0, "Kombo wurde fortgesetzt")
	await _clear()


func _test_heavy_and_stamina() -> void:
	print("Schwere Attacke & Ausdauer")
	_reset_player()
	var e := _enemy("golem")
	await _wait(0.2)
	var st0 := player.stamina
	var hp0 := e.hp
	check(player.request("heavy"), "Schwere Attacke startet")
	check(player.stamina < st0, "Schwere Attacke kostet Ausdauer")
	await _wait(1.5)
	check(e.hp < hp0 - 15.0, "Schwerer Treffer (%.0f Schaden)" % (hp0 - e.hp))
	player.stamina = 2.0
	player.set_state(Fighter.S.IDLE)
	check(not player.request("heavy"), "Ohne Ausdauer keine schwere Attacke")
	await _clear()


func _test_dodge() -> void:
	print("Ausweichen mit i-Frames")
	_reset_player()
	var e := _enemy("skeleton", 1.4)
	await _wait(0.2)
	var atk: Dictionary = e.data.attacks[0]
	e.face_towards(player.global_position)
	e.start_attack(atk)
	await _wait(float(atk.windup) - 0.12)
	var hp0 := player.hp
	player.request("dodge")
	check(player.state == Fighter.S.DODGE, "Rolle gestartet")
	await _wait(0.12)
	check(player.invulnerable, "i-Frames aktiv")
	await _wait(0.6)
	check(is_equal_approx(player.hp, hp0), "Kein Schaden während der Rolle")
	# Ohne Ausweichen trifft der Angriff
	_reset_player()
	e.global_position = player.global_position + Vector3(0, 0, -1.4)
	e.set_state(Fighter.S.IDLE)
	e.face_towards(player.global_position)
	e.start_attack(atk)
	await _wait(float(atk.windup) + float(atk.active) + 0.1)
	check(player.hp < player.max_hp, "Ohne Rolle trifft der Säbelhieb (%.0f Schaden)" % (player.max_hp - player.hp))
	await _clear()


func _test_block_and_parry() -> void:
	print("Blocken & Parieren")
	_reset_player()
	var e := _enemy("skeleton", 1.4)
	await _wait(0.2)
	var atk: Dictionary = e.data.attacks[0]
	# Block (früh begonnen → kein Parierfenster mehr)
	player.set_state(Fighter.S.BLOCK)
	e.face_towards(player.global_position)
	e.start_attack(atk)
	await _wait(float(atk.windup) + float(atk.active) + 0.1)
	var blocked := player.max_hp - player.hp
	check(blocked < float(atk.damage) * 0.3, "Block hält den Großteil ab (%.1f Schaden)" % blocked)
	check(player.stamina < player.max_stamina, "Block kostet Ausdauer")
	# Parade: Block kurz vor dem Treffer
	_reset_player()
	e.set_state(Fighter.S.IDLE)
	await _wait(0.1)
	e.face_towards(player.global_position)
	e.start_attack(atk)
	await _wait(float(atk.windup) - 0.05)
	player.set_state(Fighter.S.BLOCK)
	await _wait(float(atk.active) + 0.1)
	check(is_equal_approx(player.hp, player.max_hp), "Parade: kein Schaden")
	check(e.state == Fighter.S.STAGGER, "Parade lässt den Gegner taumeln")
	# Rote Angriffe sind nicht blockbar
	_reset_player()
	var dk := _enemy("death_knight", 1.8)
	await _wait(0.2)
	player.set_state(Fighter.S.BLOCK)
	var red: Dictionary = dk.data.attacks[2]
	dk.face_towards(player.global_position)
	dk.start_attack(red)
	await _wait(float(red.windup) + float(red.active) + 0.1)
	check(player.hp < player.max_hp - 20.0, "Unblockbarer Angriff trifft trotz Block")
	player.set_state(Fighter.S.IDLE)
	await _clear()


func _test_spells() -> void:
	print("Zauber (Ainz)")
	_reset_player()
	var e := _enemy("golem", 6.0)
	await _wait(0.2)
	var m0 := player.mana
	var hp0 := e.hp
	check(player.cast("fireball"), "Feuerkugel gewirkt")
	check(player.mana < m0, "Mana verbraucht")
	await _wait(1.0)
	check(e.hp < hp0, "Feuerkugel trifft (%.0f)" % (hp0 - e.hp))
	check(e.has_status("burn"), "Ziel brennt")
	check(not player.cast("fireball") or player.cooldowns.fireball > 0.0, "Abklingzeit greift")
	await _wait(1.0)
	e.global_position = player.global_position + Vector3(0, 0, -3.0)
	await _wait(0.2)
	var p0 := e.global_position
	check(player.cast("shockwave"), "Druckwelle gewirkt")
	await _wait(0.6)
	check(e.global_position.distance_to(player.global_position) > p0.distance_to(player.global_position), "Druckwelle stößt zurück")
	await _wait(0.3)
	check(player.cast("shield"), "Schutzbarriere gewirkt")
	await _wait(0.4)
	check(player.shield_time > 0.0, "Barriere aktiv")
	var r := player.take_hit({"amount": 50.0, "type": "physical", "stagger": 10.0}, e)
	check(r == "shield" and is_equal_approx(player.hp, player.max_hp), "Barriere absorbiert einen Treffer")
	check(player.cast("hold"), "Lähmung gewirkt")
	await _wait(0.6)
	check(e.has_status("stun") and e.state == Fighter.S.STUN, "Ziel gelähmt")
	player.mana = player.max_mana
	var hp1 := e.hp
	check(player.cast("grasp_heart"), "Herzgriff gewirkt")
	await _wait(1.4)
	check(e.hp < hp1 - 100.0, "Herzgriff verheerend (%.0f)" % (hp1 - e.hp))
	await _clear()


func _test_momon() -> void:
	print("Momon – zwei Großschwerter")
	_reset_player()
	player.set_style("momon")
	check(player.max_hp > 400 and player.armor > 50, "Momon: mehr Leben und Rüstung")
	check(player.spells() == ["leap", "whirl"], "Momon nutzt Techniken statt Zauber")
	var e := _enemy("golem", 5.0)
	await _wait(0.2)
	var hp0 := e.hp
	for i in 3:
		player.request("light")
		await _wait(0.75)
	await _wait(1.2)
	check(player.state in [Fighter.S.IDLE, Fighter.S.MOVE], "Kombo ausgeführt und beendet")
	var st0 := player.stamina
	check(player.cast("leap"), "Sprungangriff")
	await _wait(1.0)
	check(player.stamina < st0, "Technik kostet Ausdauer")
	check(e.hp < hp0, "Momon trifft (%.0f Schaden gesamt)" % (hp0 - e.hp))
	player.stamina = player.max_stamina
	var hp1 := e.hp
	e.set_state(Fighter.S.IDLE)
	e.global_position = player.global_position + Vector3(2.0, 0, 0)
	await _wait(0.2)
	check(player.cast("whirl"), "Schwerterwirbel")
	await _wait(0.7)
	check(e.hp < hp1, "Wirbel trifft auch seitlich")
	player.set_style("ainz")
	await _clear()


func _test_lock_and_kill() -> void:
	print("Lock-on, Tod, Gegner-KI")
	_reset_player()
	var e := _enemy("skeleton", 5.0, true)
	await _wait(0.3)
	player.toggle_lock()
	check(player.lock == e, "Lock-on fixiert das Skelett")
	await _wait(2.5)
	check(e.global_position.distance_to(player.global_position) < 4.0, "Skelett nähert sich (KI)")
	var killed := [false]
	e.died.connect(func(_f): killed[0] = true)
	e.take_hit({"amount": 999.0, "type": "physical"}, player)
	check(killed[0] and e.state == Fighter.S.DEAD, "Gegner stirbt")
	await _wait(0.2)
	check(player.lock == null, "Lock-on löst sich nach dem Tod")
	await _clear()


func _test_models() -> void:
	print("3D-Modelle (.glb)")
	# Testfigur mit zwei Animationen bauen und als .glb exportieren
	var root := Node3D.new()
	root.name = "TestDummy"
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 1.8, 0.4)
	mi.mesh = bm
	mi.position.y = 0.9
	root.add_child(mi)
	mi.owner = root
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.owner = root
	var lib := AnimationLibrary.new()
	for spec in [["Idle_Loop", 0.0], ["Sword_Attack", 1.0], ["Run", 0.5], ["Death", 0.2]]:
		var a := Animation.new()
		a.length = 1.0
		var tr := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(tr, "Body")
		a.position_track_insert_key(tr, 0.0, Vector3(0, 0.9, 0))
		a.position_track_insert_key(tr, 1.0, Vector3(0, 0.9 + float(spec[1]), 0))
		lib.add_animation(spec[0], a)
	ap.add_animation_library("", lib)
	add_child(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://models/characters"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://models/props"))
	var path := ProjectSettings.globalize_path("user://models/characters/test_dummy.glb")
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	check(doc.append_from_scene(root, st) == OK and doc.write_to_filesystem(st, path) == OK, "Test-.glb geschrieben")
	DirAccess.copy_absolute(path, ProjectSettings.globalize_path("user://models/props/test_house.glb"))
	root.queue_free()
	ModelLib.clear_cache()
	check(ModelLib.has("characters", "test_dummy"), "ModelLib findet das Modell zur Laufzeit")
	var rig := CharacterRig.create("test_dummy", Callable())
	add_child(rig)
	check(rig.has_model and rig.anim != null, "Rig nutzt das .glb mit AnimationPlayer")
	check(rig.anim_map.get("idle", "") == "Idle_Loop", "Animation »idle« zugeordnet")
	check(rig.anim_map.get("attack_light", "") == "Sword_Attack", "Animation »attack_light« zugeordnet")
	check(rig.anim_map.has("run") and rig.anim_map.has("death"), "run/death zugeordnet")
	rig.pose(Fighter.S.ATTACK, "active", 0.5, 0.0, "light", 1.0)
	check(rig.anim.current_animation == "Sword_Attack", "Angriff spielt die Modell-Animation")
	var holder := Node3D.new()
	add_child(holder)
	check(ModelLib.place_prop(holder, "test_house", Vector3(5, 0, 5)), "Requisit aus .glb platziert")
	check(holder.find_children("*", "StaticBody3D", true, false).size() > 0, "Requisit erhält Kollision")
	check(not ModelLib.has("characters", "gibt_es_nicht"), "Fehlendes Modell → Ersatzfigur")
	var fb := CharacterRig.create("gibt_es_nicht", func(r): ProcModel.ainz(r))
	add_child(fb)
	check(not fb.has_model and fb.parts.has("arm_r"), "Prozeduraler Ersatz mit Gelenken")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

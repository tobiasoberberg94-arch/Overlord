extends Node3D
## Effekt-Labor: einfacher Boden, feste Kamera, Effekte nacheinander – mit Bildfolgen zum Begutachten.
##   godot --path . res://tools/fx_lab.tscn            (FXCASE=<name> nur ein Fall, DARK=1 Nachtlicht)
## Bilder: tools/screenshots3d/lab_<fall>_<n>.png

var shots_dir := "res://tools/screenshots3d/"
var cam := Camera3D.new()
var player: Player3D
var only := OS.get_environment("FXCASE")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	Game.rng.seed = 5
	Game.new_game()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var dark := OS.get_environment("DARK") != ""
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.08) if dark else Color(0.55, 0.65, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.2, 0.2, 0.28) if dark else Color(0.6, 0.62, 0.68)
	e.ambient_light_energy = 0.6 if dark else 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 0.9
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.25 if dark else 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position.y = -0.5
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	mi.mesh = pm
	mi.material_override = BuildingLook.photo_material("flagstone", "stone", Color(0.8, 0.78, 0.74), 0.3)
	ground.add_child(mi)
	add_child(ground)
	player = Player3D.new()
	add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	player.face(0.0)
	player.max_hp = 99999.0
	player.hp = player.max_hp
	player.max_mana = 9999.0
	player.mana = 9999.0
	cam.fov = 60.0
	add_child(cam)
	await _wait(0.5)
	cam.current = true
	CombatFX.prewarm(self, cam)
	await _wait(0.5)
	var cases := ["hit_bone", "hit_armor", "hit_flesh", "slash", "parry", "fireball", "chain", "shockwave", "barrier", "bind", "heart",
		"telegraph", "aoe", "leap", "super", "arrows", "death"]
	for c in cases:
		if only != "" and c != only:
			continue
		await call("_case_" + c)
		await _clear()
	print("FX-LABOR fertig")
	get_tree().quit()


func _view(pos: Vector3, look: Vector3) -> void:
	cam.look_at_from_position(pos, look)
	cam.current = true


func _enemy(id: String, at: Vector3) -> Enemy3D:
	var en := Enemy3D.create(id)
	en.position = at
	add_child(en)
	en.face_towards(player.global_position)
	return en


func _reset_player() -> void:
	player.revive()
	player.set_state(Fighter.S.IDLE)
	player.cooldowns.clear()
	player.mana = player.max_mana
	player.global_position = Vector3(0, 0.05, 0)
	player.face(0.0)


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		n.remove_from_group("enemies")
		n.queue_free()
	_reset_player()
	await _wait(0.6)


## Bildfolge: n Bilder im Abstand dt (Sekunden Spielzeit).
func _seq(name: String, n: int, dt: float) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
		_shot("lab_%s_%d" % [name, i])
		await _wait(dt)


func _case_hit_bone() -> void:
	var en := _enemy("skeleton", Vector3(0, 0, -1.8))
	_view(Vector3(2.6, 1.6, -0.4), Vector3(0, 1.1, -1.6))
	await _wait(0.4)
	en.take_hit({"amount": 24.0, "type": "physical", "stagger": 5.0}, player)
	await _seq("hit_bone", 4, 0.06)


func _case_hit_armor() -> void:
	var en := _enemy("soldier", Vector3(0, 0, -1.8))
	_view(Vector3(2.6, 1.6, -0.4), Vector3(0, 1.1, -1.6))
	await _wait(0.4)
	en.take_hit({"amount": 36.0, "type": "physical", "stagger": 5.0, "kind": "heavy"}, player)
	await _seq("hit_armor", 4, 0.06)


func _case_hit_flesh() -> void:
	var en := _enemy("mercenary", Vector3(0, 0, -1.8))
	_view(Vector3(2.6, 1.6, -0.4), Vector3(0, 1.1, -1.6))
	await _wait(0.4)
	en.take_hit({"amount": 30.0, "type": "physical", "stagger": 5.0}, player)
	await _seq("hit_flesh", 4, 0.08)


func _case_slash() -> void:
	_enemy("golem", Vector3(0, 0, -2.2))
	_view(Vector3(3.2, 2.2, 1.2), Vector3(0, 1.0, -1.0))
	await _wait(0.4)
	player.request("light")
	await _wait(float(player.attack.windup))
	await _seq("slash", 5, 0.04)
	await _wait(0.6)
	player.set_style("momon")
	await _wait(0.3)
	player.request("heavy")
	await _wait(float(player.attack.windup))
	await _seq("slash_momon", 5, 0.05)
	player.set_style("ainz")


func _case_parry() -> void:
	var en := _enemy("skeleton", Vector3(0, 0, -1.5))
	_view(Vector3(2.4, 1.5, 0.2), Vector3(0, 1.1, -0.8))
	await _wait(0.4)
	var atk: Dictionary = en.data.attacks[0]
	en.start_attack(atk)
	await _wait(float(atk.windup) - 0.06)
	player.set_state(Fighter.S.BLOCK)
	await _wait(0.07)
	await _seq("parry", 4, 0.05)
	player.set_state(Fighter.S.IDLE)


func _case_fireball() -> void:
	_enemy("death_knight", Vector3(0, 0, -9))
	_view(Vector3(4.5, 2.2, -2.0), Vector3(0, 1.2, -6.5))
	await _wait(0.4)
	player.toggle_lock()
	player.cast("fireball")
	await _wait(0.3)
	await _seq("fireball", 7, 0.07)


func _case_chain() -> void:
	for i in 3:
		_enemy("skeleton", Vector3((i - 1) * 2.2, 0, -6.0 - i * 1.5))
	_view(Vector3(5.0, 3.0, 1.0), Vector3(0, 1.0, -6.0))
	await _wait(0.4)
	player.toggle_lock()
	player.cast("chain_lightning")
	await _wait(0.36)
	await _seq("chain", 4, 0.06)


func _case_shockwave() -> void:
	for i in 3:
		_enemy("soldier", Vector3((i - 1) * 1.6, 0, -3.0))
	_view(Vector3(4.0, 2.5, 1.5), Vector3(0, 0.8, -2.5))
	await _wait(0.4)
	player.cast("shockwave")
	await _wait(0.3)
	await _seq("shockwave", 4, 0.08)


func _case_barrier() -> void:
	_view(Vector3(2.8, 1.8, 2.5), Vector3(0, 1.0, 0))
	await _wait(0.2)
	player.cast("shield")
	await _wait(0.7)
	await _seq("barrier", 1, 0.1)
	var en := _enemy("skeleton", Vector3(0, 0, -1.6))
	await _wait(0.2)
	en.take_hit({"amount": 1.0}, player)
	player.take_hit({"amount": 20.0, "type": "physical"}, en)
	await _seq("barrier_break", 3, 0.08)


func _case_bind() -> void:
	_enemy("death_knight", Vector3(0, 0, -5))
	_view(Vector3(3.5, 2.0, -1.5), Vector3(0, 1.2, -5))
	await _wait(0.4)
	player.toggle_lock()
	player.cast("hold")
	await _wait(0.5)
	await _seq("bind", 2, 0.4)


func _case_heart() -> void:
	_enemy("soldier", Vector3(0, 0, -6))
	_view(Vector3(2.2, 1.9, 1.2), Vector3(0, 1.5, -1.5))
	await _wait(0.4)
	player.toggle_lock()
	player.cast("grasp_heart")
	await _wait(0.6)
	await _seq("heart", 3, 0.2)
	await _wait(0.05)
	await _seq("heart_crush", 3, 0.08)


func _case_telegraph() -> void:
	var dk := _enemy("death_knight", Vector3(0, 0, -3.5))
	var wolf := _enemy("wolf", Vector3(3.0, 0, -4.0))
	_view(Vector3(4.5, 4.0, 3.0), Vector3(0, 0, -3.0))
	await _wait(0.4)
	dk.target = player
	dk._begin_attack(dk._attack_by_id("overhead"))
	wolf.target = player
	wolf._begin_attack(wolf._attack_by_id("pounce"))
	await _wait(0.5)
	await _seq("telegraph", 3, 0.3)


func _case_aoe() -> void:
	var lich := _enemy("elder_lich", Vector3(0, 0, -9))
	_view(Vector3(5.0, 3.5, 3.0), Vector3(0, 0.5, -3.0))
	await _wait(0.4)
	lich.target = player
	lich._begin_attack(lich._attack_by_id("fireball"))
	await _wait(0.7)
	await _seq("aoe", 2, 0.6)
	await _seq("aoe_boom", 3, 0.08)
	await _wait(0.5)
	lich.set_state(Fighter.S.IDLE)
	lich._begin_attack(lich._attack_by_id("raise"))
	await _wait(1.9)
	await _seq("summon", 2, 0.25)


func _case_leap() -> void:
	player.set_style("momon")
	for i in 3:
		_enemy("skeleton", Vector3((i - 1) * 1.4, 0, -6.0))
	_view(Vector3(6.0, 2.5, -1.0), Vector3(0, 1.0, -4.0))
	await _wait(0.4)
	player.toggle_lock()
	player.cast("leap")
	await _wait(0.5)
	await _seq("leap", 6, 0.06)
	player.set_style("ainz")


func _case_super() -> void:
	for i in 4:
		_enemy("soldier", Vector3((i - 1.5) * 2.0, 0, -14.0))
	_view(Vector3(10.0, 6.0, 8.0), Vector3(0, 2.0, -5.0))
	await _wait(0.4)
	player.toggle_lock()
	player.cast("fallen_down")
	await _wait(1.5)
	await _seq("super_charge", 2, 1.2)
	await _wait(0.5)
	await _seq("super_blast", 5, 0.12)


func _case_arrows() -> void:
	for i in 2:
		var a := _enemy("skeleton_archer", Vector3((i * 2 - 1) * 3.0, 0, -11.0))
		a.target = player
		a.notice(player)
		a._alert_t = 0.0
		a._cooldown = 0.0
	_view(Vector3(4.0, 2.2, 2.5), Vector3(0, 1.2, -6.0))
	await _wait(1.0)
	await _seq("arrows", 4, 0.12)


func _case_death() -> void:
	var a := _enemy("skeleton", Vector3(-1.2, 0, -3))
	var b := _enemy("soldier", Vector3(1.2, 0, -3))
	_view(Vector3(3.0, 2.0, 1.5), Vector3(0, 0.8, -3))
	await _wait(0.4)
	a.take_hit({"amount": 999.0}, player)
	b.take_hit({"amount": 999.0}, player)
	await _wait(1.85)
	await _seq("death", 3, 0.25)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(shots_dir + n + ".png"))

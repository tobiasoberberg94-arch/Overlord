extends Node3D
## Third-Person-Welt: Ainz bewegt sich frei durch Nazarick und die Neue Welt.
##
## • Orte aus data/locations.json, gebaut vom LocationBuilder
## • Wächter stehen dort, wo sie gerade sind (Thronsaal, eigene Ebene, Einsatzort, Feldzug)
## • Interaktion [E]: Gespräch/Audienz, Thron (Zeit), Kriegstisch (Aufträge, Karte, Diplomatie),
##   Albedos Pult (Verwaltung, Nazarick), Gate (Reisen), Lagetafel (regionale Aufträge)
## • Die Zeit läuft in Echtzeit weiter (ein Tag je DAY_SECONDS), Depeschen öffnen sich als Fenster
## Alle Systeme (Game, World, Military, Diplomacy, Progress) laufen direkt in dieser 3D-Welt.

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const DAY_SECONDS := 45.0

var player := Player3D.new()
var level: Node3D
var loc: Dictionary = {}
var actors: Array[Actor3D] = []
var anchors: Dictionary = {}

var ui := CanvasLayer.new()
var ui_root := Control.new()
var overlay_layer := Control.new()
var celebrations := CelebrationLayer.new()
var hud := WorldHud.new()
var quest_world := QuestWorld.new(self)
## Tag-Nacht-Wechsel (per preload, damit der Klassen-Cache des Editors nicht gebraucht wird)
var day_cycle: Node = preload("res://scripts/world3d/day_cycle.gd").new()
var _time_name := ""
const BARKS := preload("res://scripts/world3d/barks.gd")
var _bark_t := 0.0
## Wetter je Spieltag (scripts/world3d/weather.gd)
var weather: Node = preload("res://scripts/world3d/weather.gd").new()
var _weather_day := -1
## Fotomodus (F9), Ankunftskamera, dynamische Musik, Blätter und Schmetterlinge
var photo: Node = preload("res://scripts/world3d/photo_mode.gd").new()
var arrival_pans := true
var _panning := false
var _music_t := 0.0
var _music_state := "calm"
var _music_calm_t := 0.0
var _ambient: Array = []
var _pickup_focus: Pickup
var hud_feedback := Label.new()
var hud_vignette := ColorRect.new()
var enemies: Array[Enemy3D] = []
var _spell_slots: Array = []
var _focus: Actor3D
var _day_timer := 0.0
var _time_running := true
var _busy := false
var _last_autosave := 0
var _spinners: Array = []
var _flickers: Array = []
var allies: Array = []
var story: StoryMission                ## laufender Story-Einsatz
var cinematic := false                 ## Filmszene läuft (Eingabe gesperrt, Kampf ruht, HUD aus)
var suppress_encounters := false
var _cine_ui: CinematicUI


func _ready() -> void:
	add_to_group("world3d")
	if Game.state.is_empty():
		Game.new_game()
	add_child(player)
	add_child(quest_world)
	add_child(day_cycle)
	add_child(weather)
	add_child(photo)
	Actor3D.player = player
	_build_ui()
	player.feedback.connect(_on_feedback)
	player.style_changed.connect(func(_s): _rebuild_spell_bar())
	player.damaged.connect(_on_player_damaged)
	player.struck.connect(_on_player_struck)
	player.died.connect(func(_f): _on_player_died())
	Enemy3D.spawner = spawn_enemy
	Enemy3D.ally_spawner = spawn_ally
	Progress.grimoire_changed.connect(_rebuild_spell_bar)
	Progress.souls_changed.connect(_on_souls_hint)
	_rebuild_spell_bar()
	Game.state_changed.connect(_refresh_hud)
	Game.dispatches_arrived.connect(func(_n): Audio.sfx("dispatch", 0.8))
	var w3: Dictionary = Game.state.get("world3d", {})
	var start: String = w3.get("loc", "throne")
	load_location(start if Content.location_by_id.has(start) else "throne")
	_refresh_hud()
	await get_tree().create_timer(0.8).timeout
	_open_next_dispatch()
	if not Settings.tutorial_done:
		while overlay_layer.get_child_count() > 0:
			await get_tree().create_timer(0.5).timeout
		start_tutorial()


# =====================================================================
#  Orte laden
# =====================================================================

## arrive = {"pos": Vector3, "yaw": float}: Ankunft an einer Tür statt am Startpunkt des Ortes.
func load_location(id: String, fade: bool = false, arrive: Dictionary = {}) -> void:
	if fade:
		await _fade(1.0, 0.35)
	actors.clear()
	enemies.clear()
	allies.clear()
	_focus = null
	player.lock = null
	CombatDirector.reset()
	CombatFX.reset_time()
	quest_world.clear()
	if level:
		# alten Ort erst vollständig freigeben, dann den neuen bauen (halbiert den Speicher-Spitzenwert)
		remove_child(level)
		level.queue_free()
		level = null
		await get_tree().process_frame
		await get_tree().process_frame
	loc = Content.location_by_id[id]
	level = Node3D.new()
	level.name = "Level_" + id
	add_child(level)
	LocationBuilder.environment(level, loc, LocationBuilder.preset(loc.kind))
	anchors = LocationBuilder.build(loc, level)
	_spinners = level.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.has_meta("spin"))
	_flickers = level.find_children("*", "OmniLight3D", true, false).filter(func(n): return n.has_meta("flicker"))
	day_cycle.setup(level, loc)
	weather.setup(self, loc)
	_weather_day = int(Game.state.get("day", 1))
	_place_actors()
	_spawn_encounters()
	quest_world.apply_story()
	quest_world.spawn_pickups()
	quest_world.spawn_discoveries()
	player.global_position = anchors.spawn
	player.velocity = Vector3.ZERO
	player.face(anchors.get("yaw", 0.0))
	if not arrive.is_empty():
		player.global_position = _on_ground(arrive.pos) + Vector3.UP * 0.1
		player.face(float(arrive.yaw))
	Audio.set_space(String(loc.get("kind", "")))
	Audio.play_ambience_for(loc)
	# Kampfeffekte einmal zeigen (unsichtbar), damit der erste Treffer nicht ruckelt
	await get_tree().process_frame
	if is_instance_valid(level):
		CombatFX.prewarm(level, player.camera)
	if not Game.state.has("world3d"):
		Game.state["world3d"] = {}
	Game.state.world3d["loc"] = id
	Audio.play_music(loc.get("music", "throne"))
	_music_state = "calm"
	_music_calm_t = 0.0
	hud.set_location(loc.name)
	_ambient_particles()
	if story == null:
		_show_banner(loc.name, loc.get("desc", ""))
	if arrival_pans and arrive.is_empty() and story == null and loc.group == "world":
		_arrival_pan()
	if fade:
		await _fade(0.0, 0.5)


## Ankunft: kurzer Kameraschwenk von oben hinter dem Spieler hinunter in die Spielkamera (nur Außenorte).
func _arrival_pan() -> void:
	if _panning:
		return
	_panning = true
	var cam := Camera3D.new()
	cam.far = player.camera.far
	cam.fov = 58.0
	add_child(cam)
	var fwd := Basis(Vector3.UP, player.cam_yaw) * Vector3(0, 0, -1)
	var p0 := player.global_position
	var start := p0 - fwd * 24.0 + Vector3(0, 15.0, 0)
	var look0 := p0 + fwd * 36.0 + Vector3(0, 5.0, 0)
	cam.look_at_from_position(start, look0)
	cam.current = true
	var tw := create_tween()
	tw.tween_method(_pan_step.bind(cam, start, look0), 0.0, 1.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if is_instance_valid(player) and not photo.active:
		player.camera.current = true
	if is_instance_valid(cam):
		cam.queue_free()
	_panning = false


func _pan_step(t: float, cam: Camera3D, start: Vector3, look0: Vector3) -> void:
	if not is_instance_valid(cam) or not is_instance_valid(player):
		return
	var end_xf: Transform3D = player.camera.global_transform
	var pos := start.lerp(end_xf.origin, t)
	var look := look0.lerp(end_xf.origin - end_xf.basis.z * 20.0, t)
	if pos.distance_to(look) > 0.1:
		cam.look_at_from_position(pos, look)


## Blätter im Wald, Schmetterlinge über Wiesen und Dörfern (folgen dem Spieler, siehe _process).
func _ambient_particles() -> void:
	for a in _ambient:
		if is_instance_valid(a):
			a.queue_free()
	_ambient.clear()
	var kind := String(loc.get("kind", ""))
	if not Settings.particles or (loc.group != "world" and kind != "jungle"):
		return
	if kind in ["forest", "jungle", "village", "grassland"]:
		var leaves := CPUParticles3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.14, 0.09)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.72, 0.5, 0.2)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.material = mat
		leaves.mesh = qm
		leaves.amount = 70 if kind != "jungle" else 110
		leaves.lifetime = 9.0
		leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		leaves.emission_box_extents = Vector3(22, 2, 22)
		leaves.direction = Vector3(0.3, -1, 0.2)
		leaves.spread = 40.0
		leaves.initial_velocity_min = 0.4
		leaves.initial_velocity_max = 1.2
		leaves.gravity = Vector3(0, -0.7, 0)
		leaves.angular_velocity_min = -120.0
		leaves.angular_velocity_max = 120.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.85, 0.6, 0.2))
		ramp.set_color(1, Color(0.45, 0.55, 0.15) if kind == "jungle" else Color(0.6, 0.25, 0.1))
		leaves.color_initial_ramp = ramp
		leaves.set_meta("offset", Vector3(0, 10.0, 0))
		level.add_child(leaves)
		_ambient.append(leaves)
	if kind in ["village", "grassland", "forest", "swamp"]:
		var flies := CPUParticles3D.new()
		var qm2 := QuadMesh.new()
		qm2.size = Vector2(0.11, 0.09)
		var mat2 := StandardMaterial3D.new()
		mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat2.albedo_color = Color(1.0, 0.95, 0.75)
		mat2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm2.material = mat2
		flies.mesh = qm2
		flies.amount = 14
		flies.lifetime = 12.0
		flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		flies.emission_box_extents = Vector3(14, 0.8, 14)
		flies.direction = Vector3(1, 0.2, 0)
		flies.spread = 180.0
		flies.initial_velocity_min = 0.6
		flies.initial_velocity_max = 1.4
		flies.gravity = Vector3.ZERO
		flies.damping_min = 0.2
		flies.damping_max = 0.6
		flies.scale_amount_min = 0.7
		flies.scale_amount_max = 1.2
		var ramp2 := Gradient.new()
		ramp2.set_color(0, Color(1.0, 0.95, 0.7))
		ramp2.set_color(1, Color(0.95, 0.6, 0.3))
		flies.color_initial_ramp = ramp2
		flies.set_meta("offset", Vector3(0, 1.3, 0))
		level.add_child(flies)
		_ambient.append(flies)


## Dynamische Musik: ruhig (Ortsmusik) → Spannung, wenn Gegner nahe sind → Schlacht, wenn gekämpft wird; zurück mit Nachhall.
func _music_tick(delta: float) -> void:
	_music_t += delta
	if _music_t < 0.5 or story != null or cinematic or level == null:
		return
	_music_t = 0.0
	var near := INF
	var engaged := false
	for e in enemies:
		if not is_instance_valid(e) or e.state == Fighter.S.DEAD:
			continue
		near = minf(near, player.global_position.distance_to(e.global_position))
		if e.engaged:
			engaged = true
	var want := "calm"
	if engaged or near < 10.0:
		want = "combat"
	elif near < 30.0:
		want = "alert"
	# nach dem Kampf nicht sofort abblenden
	if want == "calm" or (want == "alert" and _music_state == "combat"):
		_music_calm_t += 0.5
		if _music_calm_t < 6.0:
			return
	else:
		_music_calm_t = 0.0
	if want == _music_state:
		return
	_music_state = want
	match want:
		"combat":
			Audio.play_music("battle")
		"alert":
			Audio.play_music("tension")
		_:
			Audio.play_music(loc.get("music", "throne"))


func _place_actors() -> void:
	var slots: Array = anchors.get("slots", []).duplicate()
	var region: String = loc.get("region", "nazarick" if loc.group == "nazarick" else "")
	var placed: Array = []
	# Wächter: jeder ist an seinem Platz – im Thronsaal nur Albedo und wer gerade Aufmerksamkeit sucht
	var guests := _throne_guests()
	for cid in Game.unlocked_chars():
		var c := Game.cs(cid)
		var where := _char_whereabouts(cid)
		var here := false
		var variant := ""
		if where == "nazarick":
			here = (loc.id == "throne" and cid in guests) or (loc.id != "throne" and HOME.get(cid, "") == loc.id)
		elif loc.group == "world" and where == region:
			here = true
			variant = "battle" if c.status == "feldzug" else ""
		if not here:
			continue
		if variant == "":
			variant = "love" if c.favor >= 80 else ("sad" if c.favor < 30 else "")
		var pos: Vector3
		if loc.get("keeper", "") == cid and anchors.has("keeper"):
			pos = anchors.keeper
		elif not slots.is_empty():
			pos = slots.pop_front()
		else:
			pos = Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		var a := Actor3D.character(cid, variant)
		a.prompt = "Audienz"
		_add_actor(a, pos)
		placed.append(cid)
	# Story-Figuren und Diener
	for n in loc.get("npcs", []):
		if not Game.check(n.get("requires", {})):
			continue
		var pos: Vector3 = slots.pop_front() if not slots.is_empty() else Vector3(randf_range(-6, 6), 0, randf_range(-8, 0))
		var a := Actor3D.character(n.id, "", 2.6 if n.id in ["death_knight", "platinum_dragon"] else 2.3)
		a.line = n.get("line", "")
		_add_actor(a, pos)
	quest_world.spawn_givers(slots)
	# Objekte
	if anchors.has("throne"):
		_add_actor(Actor3D.object("throne", "Thron von Nazarick", "Zeit vergehen lassen", Palette.GOLD_BRIGHT, 3.2), anchors.throne)
	if anchors.has("table"):
		_add_actor(Actor3D.object("table", "Kriegsrat", "Aufträge, Karte & Diplomatie", Palette.GOLD, 3.2), anchors.table)
	if anchors.has("desk"):
		_add_actor(Actor3D.object("desk", "Albedos Pult", "Verwaltung, Ausbau & Wochenziele", Palette.VIOLET_GLOW, 3.0), anchors.desk)
	if anchors.has("board"):
		var rname: String = World.region(region).get("name", loc.name) if region != "" else loc.name
		var a := Actor3D.object("board", "Lage: " + rname, "Lage & Aufträge der Region", Palette.GOLD, 2.8)
		_add_actor(a, anchors.board)
		_build_board(anchors.board)
	if anchors.has("gate"):
		_add_actor(Actor3D.object("gate", "Gate", "Reisen", Color(0.75, 0.5, 1.0), 3.0), anchors.gate)
	# Türen zu Innenräumen (data/locations.json → doors) und die Tür hinaus
	for d in loc.get("doors", []):
		var at: Array = d.at
		var locked := _door_locked(d)
		var prompt := "Betreten"
		if locked:
			prompt = "Aufschließen" if Quests.count(String(d.key)) > 0 else "Verschlossen"
		var door := Actor3D.object("door:" + String(d.id), String(d.name), prompt, Palette.GOLD if not locked else Color(0.78, 0.72, 0.6), 2.4)
		door.set_meta("door", d)
		_add_actor(door, _on_ground(Vector3(float(at[0]), float(at[1]), float(at[2]))))
		match String(d.get("style", "sign")):
			"grate": _dungeon_entrance(door, d, true)
			"crypt": _dungeon_entrance(door, d, false)
			_: _door_sign(door, d)
	if String(loc.get("kind", "")) == "forge_hall":
		# Runenrätsel: vier Pfeiler mit Runen (Reihenfolge im Buch der Runen), siehe QuestWorld.rune_touch
		var runes := [["wasser", "Rune des Wassers", -7.0], ["erde", "Rune der Erde", -2.3], ["luft", "Rune der Luft", 2.3], ["feuer", "Rune des Feuers", 7.0]]
		for r in runes:
			var ra := Actor3D.object("rune:" + String(r[0]), String(r[1]), "Berühren", Color(0.45, 0.9, 1.0), 2.0)
			_add_actor(ra, Vector3(float(r[2]), 0, 2.6))
	if anchors.has("exit"):
		var parent_loc: Dictionary = Content.location_by_id.get(String(loc.get("parent", "")), {})
		_add_actor(Actor3D.object("exit", "Hinaus · " + String(parent_loc.get("name", "Draußen")), "Verlassen", Palette.GOLD, 2.4), anchors.exit)


## Heimat in Nazarick (Ebene/Raum). Wer hier fehlt, hält sich im Thronsaal bereit.
const HOME := {
	"albedo": "throne", "shalltear": "tombs", "cocytus": "glacier", "aura": "jungle", "mare": "jungle",
	"demiurge": "lava", "sebas": "royal", "pandora": "treasury", "narberal": "royal", "yuri": "royal",
	"lupusregina": "royal", "solution": "royal", "entoma": "royal", "cz": "royal", "victim": "lava", "neuronist": "lava",
}


## Wer im Thronsaal wartet: Albedo, wer Ainz sprechen will (verliebt oder unzufrieden),
## dazu reihum ein Wächter für die tägliche Audienz.
func _throne_guests() -> Array:
	var out := ["albedo"]
	var pool: Array = []
	for cid in Game.unlocked_chars():
		var c := Game.cs(cid)
		if cid == "albedo" or _char_whereabouts(cid) != "nazarick":
			continue
		if not HOME.has(cid) or c.favor >= 85 or c.favor < 25:
			out.append(cid)
		elif HOME.get(cid, "") != "royal":
			pool.append(cid)
	if not pool.is_empty():
		pool.sort()
		out.append(pool[int(Game.state.day) % pool.size()])
	return out.slice(0, 5)


## Anschlagtafel: zwei Pfosten, Brett, kleines Schindeldach, angeheftete Aushänge (mehr bei offenen Kopfgeldern).
func _build_board(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	var look: Vector3 = anchors.get("spawn", Vector3.ZERO)
	root.rotation.y = atan2(look.x - at.x, look.z - at.z)
	level.add_child(root)
	var wood := BuildingLook.photo_material("planks", "wood", Color(0.85, 0.75, 0.62), 0.5)
	var dark := BuildingLook.photo_material("logs", "wood", Color(0.62, 0.52, 0.42), 0.6)
	for sx in [-0.95, 0.95]:
		B3.box(root, Vector3(0.14, 2.6, 0.14), Vector3(sx, 1.3, 0), dark)
	B3.box(root, Vector3(1.9, 1.25, 0.08), Vector3(0, 1.55, 0.02), wood, false)
	B3.box(root, Vector3(2.0, 0.08, 0.12), Vector3(0, 2.2, 0.02), dark, false)
	B3.box(root, Vector3(2.0, 0.08, 0.12), Vector3(0, 0.9, 0.02), dark, false)
	var roof := B3.box(root, Vector3(2.3, 0.06, 0.6), Vector3(0, 2.7, 0.08), BuildingLook.photo_material("roof_slate", "roof", Color(0.7, 0.7, 0.72), 0.8), false)
	roof.rotation.x = -0.35
	var paper := B3.mat(Color(0.86, 0.8, 0.64), 0.95)
	var n := 3 + mini(4, Quests.board_quests(board_loc()).size() * 2)
	for i in n:
		var w := randf_range(0.28, 0.42)
		var note := B3.box(root, Vector3(w, w * randf_range(1.1, 1.4), 0.01), Vector3(randf_range(-0.7, 0.7), randf_range(1.2, 1.95), 0.075), paper, false)
		note.rotation.z = randf_range(-0.15, 0.15)
		B3.box(root, Vector3(0.04, 0.04, 0.02), note.position + Vector3(0, w * 0.55, 0.01), B3.mat(Color(0.7, 0.1, 0.1), 0.5), false)


## Wo hält sich ein Wächter auf? "nazarick" oder eine Regions-ID.
func _char_whereabouts(cid: String) -> String:
	var c := Game.cs(cid)
	if c.status == Game.STATUS_MISSION:
		for am in Game.state.active:
			if am.char_id == cid or am.get("partner", "") == cid:
				var r: String = Game.mission(am.mission_id).get("region", "")
				return r if r != "" else "unterwegs"
		return "unterwegs"
	if c.status == "feldzug":
		for a in Game.state.armies:
			if a.commander == cid:
				return a.location
	return "nazarick"


func _add_actor(a: Actor3D, pos: Vector3) -> void:
	a.position = pos
	level.add_child(a)
	actors.append(a)
	# Figuren schauen zur Raummitte/zum Spieler-Startpunkt
	if a.kind != "object":
		var look: Vector3 = anchors.get("spawn", Vector3.ZERO)
		a.rotation.y = atan2(look.x - pos.x, look.z - pos.z)


# =====================================================================
#  Ablauf
# =====================================================================

func _process(delta: float) -> void:
	var blocked := overlay_layer.get_child_count() > 0 or _busy or cinematic or _panning
	# Gras weicht dem Spieler aus (Shader-Global), Blätter und Schmetterlinge folgen ihm, Musik folgt der Gefahr
	RenderingServer.global_shader_parameter_set("player_pos", player.global_position)
	for a in _ambient:
		if is_instance_valid(a):
			(a as Node3D).global_position = player.global_position + (a.get_meta("offset") as Vector3)
	_music_tick(delta)
	player.input_enabled = not blocked
	# Während ein Fenster offen ist, steht der Kampf still. In Filmszenen ruhen die Kämpfer nur
	# (atmen, Flammen lodern weiter, niemand greift an), und Namensschilder verschwinden.
	var freeze := blocked and not cinematic
	Enemy3D.hold = cinematic
	Actor3D.hide_labels = cinematic
	for e in enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED if freeze else Node.PROCESS_MODE_INHERIT
	for a in allies:
		if is_instance_valid(a):
			a.process_mode = Node.PROCESS_MODE_DISABLED if freeze else Node.PROCESS_MODE_INHERIT
	if blocked and not photo.active and not _panning:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if Pad.active else Input.MOUSE_MODE_VISIBLE
	_update_focus()
	_animate(delta)
	_update_combat_hud(blocked)
	# Echtzeit: Tage vergehen, solange niemand wartet (nicht während eines Story-Einsatzes)
	if not blocked and _time_running and Game.pending().is_empty() and story == null:
		_day_timer += delta
		if _day_timer >= DAY_SECONDS:
			_day_timer = 0.0
			_advance(1, false)
	hud.day_line.set_values(_day_timer, DAY_SECONDS)
	day_cycle.update(float(Game.state.get("day", 1)) + _day_timer / DAY_SECONDS)
	# Figuren sprechen, wenn man nahe vorbeigeht (data/barks.json → chars)
	_bark_t += delta
	if _bark_t >= 0.5 and not blocked:
		_bark_t = 0.0
		var now := Time.get_ticks_msec() / 1000.0
		for a in actors:
			if is_instance_valid(a) and a.kind in ["char", "npc"] and float(a.get_meta("bark_cool", 0.0)) < now 					and player.global_position.distance_to(a.global_position) < 5.0:
				a.set_meta("bark_cool", now + randf_range(25.0, 40.0))
				a.say(BARKS.for_char(String(a.id)))
	var today := int(Game.state.get("day", 1))
	if today != _weather_day:
		_weather_day = today
		weather.refresh(today)
	var tn: String = day_cycle.time_name()
	var wl: String = weather.label()
	if tn + wl != _time_name:
		_time_name = tn + wl
		var txt := ""
		if tn != "":
			txt = ("☾ " if day_cycle.night else "☀ ") + tn + (" · " + wl if wl != "" else "")
		hud.set_time_of_day(txt)


func _animate(delta: float) -> void:
	if level == null:
		return
	for n in _spinners:
		if is_instance_valid(n):
			n.rotate_object_local(Vector3.UP, float(n.get_meta("spin")) * delta)
	for l in _flickers:
		if is_instance_valid(l):
			# Flackern um die Grundhelligkeit des Lichts (Kerze 0,35 … Feuerschale 2,2)
			if not l.has_meta("base"):
				l.set_meta("base", l.light_energy)
			var base: float = l.get_meta("base")
			l.light_energy = base * (1.0 + sin(Time.get_ticks_msec() * 0.013 + l.position.x) * 0.12 + randf() * 0.1)


func _update_focus() -> void:
	if _focus and not is_instance_valid(_focus):
		_focus = null                      # (eine Szene hat die Figur entfernt)
	var best: Actor3D = null
	var best_d := INF
	for a in actors:
		if not is_instance_valid(a):
			continue
		var d := Vector2(a.global_position.x - player.global_position.x, a.global_position.z - player.global_position.z).length()
		if d < a.radius and d < best_d:
			best = a
			best_d = d
	if best != _focus:
		if _focus and is_instance_valid(_focus):
			_focus.set_highlight(false)
		_focus = best
		if _focus:
			_focus.set_highlight(true)
	_pickup_focus = quest_world.nearest(player.global_position) if overlay_layer.get_child_count() == 0 else null
	if _pickup_focus and (_focus == null or player.global_position.distance_to(_pickup_focus.global_position) < player.global_position.distance_to(_focus.global_position)):
		hud.set_prompt("%s  ·  %s" % [_pickup_focus.prompt(), _pickup_focus.label])
	elif _focus and overlay_layer.get_child_count() == 0:
		hud.set_prompt("%s  ·  %s" % [_focus.prompt, _focus.label])
	else:
		hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if overlay_layer.get_child_count() > 0 or _busy or cinematic:
		return
	if event.is_action_pressed("interact") and _pickup_focus and is_instance_valid(_pickup_focus) and 			(_focus == null or player.global_position.distance_to(_pickup_focus.global_position) < player.global_position.distance_to(_focus.global_position)):
		quest_world.collect(_pickup_focus)
		_pickup_focus = null
		return
	if event.is_action_pressed("interact") and _focus:
		_interact(_focus)
		return
	# Controller: Start = Menü, Back = Weltkarte (alles Weitere über „Bücher, Karten & Berichte“ im Menü)
	var jb := event as InputEventJoypadButton
	if jb and jb.pressed:
		match jb.button_index:
			JOY_BUTTON_START: _pause_menu()
			JOY_BUTTON_BACK: _open_map()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE: _pause_menu()
		KEY_B: _open(Grimoire.new())
		KEY_J: _open_journal()
		KEY_K: _open(MissionBoard.new(loc.get("region", "")))
		KEY_M: _open_map()
		KEY_P: _open(DiplomacyView.new())
		KEY_V: _open(AdministrationView.new())
		KEY_N: _open(NazarickView.new())
		KEY_U: _open(CharacterView.new("albedo"))
		KEY_C: _open(ChronicleView.new())
		KEY_G: _gate_menu()
		KEY_T: _time_menu()
		KEY_H, KEY_F1: hud.toggle_help()
		KEY_F9: photo.toggle()
		KEY_TAB: hud.toggle_goals()
		KEY_ENTER, KEY_KP_ENTER: _open_next_dispatch(true)
		KEY_F5:
			SaveSystem.save_game(1)
			toast("Gespeichert in Chronik 1.")


func _interact(a: Actor3D) -> void:
	match a.kind:
		"char":
			if quest_world.talk(a):
				return
			var cv := CharacterView.new(a.id)
			cv.closed.connect(_refresh_actors_soft)
			_open(cv)
		"npc":
			if quest_world.talk(a):
				return
			_open(TalkDialog.new(a.id, a.line if a.line != "" else "…"))
		"object":
			if a.id.begins_with("door:"):
				_enter_door(a.get_meta("door"))
				return
			if a.id.begins_with("rune:"):
				quest_world.rune_touch(a)
				return
			match a.id:
				"throne": _time_menu()
				"table": _war_table()
				"desk": _desk_menu()
				"gate": _gate_menu()
				"exit": _leave_building()
				"board":
					if not quest_world.board_menu():
						_region_menu()


## Hängendes Wirtshausschild mit Namen, Laterne mit warmem Licht und Fußmatte vor einer Tür.
func _door_sign(door: Actor3D, d: Dictionary) -> void:
	var yaw := deg_to_rad(float(d.get("yaw", 180.0)))
	var out := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)       # Richtung aus dem Haus heraus
	var side := Vector3(-out.z, 0, out.x)
	var wood := BuildingLook.photo_material("logs", "wood", Color(0.45, 0.36, 0.28), 0.6)
	var iron := B3.mat(Color(0.2, 0.19, 0.18), 0.5, 0.7)
	var holder := Node3D.new()
	holder.position = side * 1.1 + Vector3(0, 0, 0)
	holder.rotation.y = yaw + PI
	door.add_child(holder)
	# Ausleger an der Wand, Schild hängt an zwei Ketten
	B3.box(holder, Vector3(0.06, 0.06, 1.0), Vector3(0, 2.85, -0.5), iron, false)
	for sx in [-0.38, 0.38]:
		B3.box(holder, Vector3(0.015, 0.3, 0.015), Vector3(sx, 2.7, -0.15), iron, false)
	B3.box(holder, Vector3(0.95, 0.5, 0.05), Vector3(0, 2.3, -0.15), wood, false)
	B3.box(holder, Vector3(1.0, 0.04, 0.07), Vector3(0, 2.56, -0.15), iron, false)
	var lb := Label3D.new()
	lb.text = String(d.name)
	lb.font = NazarickTheme.display_font(700)
	lb.font_size = 40
	lb.pixel_size = 0.004
	lb.modulate = Color(0.95, 0.85, 0.6)
	lb.outline_size = 6
	lb.outline_modulate = Color(0.1, 0.06, 0.03)
	lb.position = Vector3(0, 2.3, -0.12)
	lb.width = 230.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(lb)
	var lb2 := lb.duplicate() as Label3D
	lb2.position = Vector3(0, 2.3, -0.18)
	lb2.rotation.y = PI
	holder.add_child(lb2)
	# Laterne auf der anderen Seite der Tür
	var lh := Node3D.new()
	lh.position = -side * 1.1 + Vector3(0, 2.4, 0)
	door.add_child(lh)
	B3.box(lh, Vector3(0.05, 0.05, 0.4), Vector3(0, 0.2, 0), iron, false)
	if PhProps.attach(lh, "wooden_lantern_01", Transform3D(Basis(), Vector3(0, -0.5, 0))) == Vector3.ZERO:
		B3.box(lh, Vector3(0.2, 0.3, 0.2), Vector3(0, -0.3, 0), iron, false)
	B3.sphere(lh, 0.05, Vector3(0, -0.24, 0), B3.mat(Color(1.0, 0.85, 0.55), 0.3, 0.0, Color(1.0, 0.78, 0.5), 4.0))
	var l := B3.light(lh, Vector3(0, -0.3, 0.2), Color(1.0, 0.78, 0.5), 1.2, 7.0)
	l.shadow_enabled = false
	l.set_meta("flicker", true)
	# Fußmatte
	var mat := B3.box(door, Vector3(1.2, 0.03, 0.7), out * 0.45 + Vector3(0, 0.015, 0), B3.mat(Color(0.3, 0.24, 0.16), 0.98), false)
	mat.rotation.y = yaw


## Verschlossene Tür (doors → "key": Gegenstand im Beutel): bleibt zu, bis sie einmal aufgeschlossen wurde.
func _door_locked(d: Dictionary) -> bool:
	return d.has("key") and not Game.has_flag("unlocked_" + String(d.to))


## Eingang eines Verlieses statt Wirtshausschild: Kanalgitter im Boden (grate) oder Gruftportal mit dunkler Öffnung;
## daneben ein Steinpfosten mit Namenstafel. Lokal zeigt -z aus dem Eingang heraus (wie bei den Türen).
func _dungeon_entrance(door: Actor3D, d: Dictionary, grate: bool) -> void:
	var holder := Node3D.new()
	holder.rotation.y = deg_to_rad(float(d.get("yaw", 180.0)))
	door.add_child(holder)
	var iron := B3.mat(Color(0.18, 0.17, 0.16), 0.55, 0.8)
	var stone := BuildingLook.photo_material("rubble", "stone", Color(0.42, 0.41, 0.4), 0.85)
	var bone := B3.mat(Color(0.8, 0.76, 0.66), 0.8)
	if grate:
		# Steinrahmen, schwarzer Schacht, Gitterstäbe, Ring zum Heben, fauliger Dunst
		B3.box(holder, Vector3(2.4, 0.14, 2.4), Vector3(0, 0.07, 0), stone, false)
		B3.box(holder, Vector3(1.8, 0.08, 1.8), Vector3(0, 0.1, 0), B3.mat(Color(0.01, 0.01, 0.01), 1.0), false)
		for k in 7:
			B3.box(holder, Vector3(0.07, 0.07, 1.8), Vector3(-0.75 + k * 0.25, 0.17, 0), iron, false)
		for k in 3:
			B3.box(holder, Vector3(1.8, 0.07, 0.07), Vector3(0, 0.17, -0.6 + k * 0.6), iron, false)
		B3.cyl(holder, 0.14, 0.14, 0.035, Vector3(0, 0.22, 0.7), iron, false, 12).rotation_degrees = Vector3(90, 0, 0)
		B3.motes(holder, Vector3(0, 0.6, 0), Vector3(0.7, 0.3, 0.7), Color(0.5, 0.75, 0.5, 0.3), 14)
		var gl := B3.light(holder, Vector3(0, 0.35, 0), Color(0.45, 0.9, 0.5), 0.7, 4.0)
		gl.shadow_enabled = false
	else:
		# Portal: zwei Pfeiler, Sturz mit Schädeln, dunkle Öffnung, Erdwall dahinter, Schwelle, kaltes Licht
		for sx in [-1.0, 1.0]:
			B3.box(holder, Vector3(0.7, 3.2, 0.7), Vector3(sx * 1.4, 1.6, 0.6), stone)
			B3.sphere(holder, 0.13, Vector3(sx * 1.4, 3.84, 0.6), bone, Vector3(1, 1.1, 1.15))
		B3.box(holder, Vector3(3.6, 0.6, 0.9), Vector3(0, 3.4, 0.6), stone, false)
		B3.box(holder, Vector3(2.1, 3.0, 0.2), Vector3(0, 1.5, 0.95), B3.mat(Color(0.01, 0.01, 0.015), 1.0), false)
		B3.box(holder, Vector3(3.8, 1.6, 1.4), Vector3(0, 0.8, 1.7), stone)
		B3.box(holder, Vector3(2.1, 0.1, 0.5), Vector3(0, 0.05, 0.2), stone, false)
		var l := B3.light(holder, Vector3(0, 2.2, 0.0), Color(0.5, 0.65, 1.0), 1.0, 6.0)
		l.shadow_enabled = false
		l.set_meta("flicker", true)
		B3.motes(holder, Vector3(0, 1.0, 0.3), Vector3(1.0, 0.8, 0.5), Color(0.55, 0.65, 0.9, 0.35), 16)
		# kalte Feuerschalen vor den Pfeilern – im Nebel der Ebene von Weitem zu sehen
		for sx in [-1.0, 1.0]:
			B3.brazier(holder, Vector3(sx * 2.7, 0, -1.7), Color(0.45, 0.65, 1.0))
	# Steinpfosten mit Namenstafel neben dem Eingang
	var px := 1.5 if grate else 2.4
	B3.box(holder, Vector3(0.28, 1.3, 0.28), Vector3(px, 0.65, -0.3), stone, false)
	B3.box(holder, Vector3(0.9, 0.5, 0.08), Vector3(px, 1.45, -0.3), stone, false)
	var lb := Label3D.new()
	lb.text = String(d.name)
	lb.font = NazarickTheme.display_font(700)
	lb.font_size = 36
	lb.pixel_size = 0.004
	lb.modulate = Color(0.88, 0.84, 0.74)
	lb.outline_size = 6
	lb.outline_modulate = Color(0.05, 0.05, 0.05)
	lb.position = Vector3(px, 1.45, -0.35)
	lb.rotation.y = PI
	lb.width = 210.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(lb)


## Ort, dessen Aushänge an der Tafel hängen: in Innenräumen die des umgebenden Ortes.
func board_loc() -> String:
	return String(loc.get("parent", loc.id))


## Durch eine Tür in einen Innenraum; der Weg zurück führt vor dieselbe Tür.
## Punkt auf den Boden des Ortes setzen – Türen und Rückkehrpunkte brauchen so keine genaue Höhe in den Daten
## (Vorplätze liegen erhöht, Gassen gesenkt; ohne Boden darunter bleibt der Punkt, wie er ist).
func _on_ground(p: Vector3) -> Vector3:
	# alle Flächen zwischen 8 m über und 8 m unter dem Punkt sammeln und die nehmen, die der Datenhöhe am
	# nächsten liegt (Gemächer Nazaricks haben Stockwerke, Vorplätze liegen erhöht)
	var space := level.get_world_3d().direct_space_state
	var excl: Array[RID] = []
	var best := p
	var best_d := INF
	for k in 4:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 8.0, p - Vector3.UP * 8.0, 0x7FFFFFFF, excl))
		if hit.is_empty():
			break
		var dd := absf(float(hit.position.y) - p.y)
		if dd < best_d:
			best_d = dd
			best = Vector3(p.x, float(hit.position.y), p.z)
		excl.append(hit.rid)
	return best


func _enter_door(d: Dictionary) -> void:
	if _busy or not Content.location_by_id.has(String(d.to)):
		return
	# Verschlossene Türen (Verliese): ohne den passenden Schlüssel im Beutel bleibt es beim Hinweis
	if _door_locked(d):
		var key := String(d.key)
		if Quests.count(key) <= 0:
			Audio.sfx("click", 0.6)
			toast(String(d.get("hint", "Verschlossen. Irgendwo muss ein Schlüssel sein.")), Palette.MUTED)
			return
		Game.set_flag("unlocked_" + String(d.to))
		Progress.bump("unlocked")
		toast("Aufgeschlossen: %s" % String(Quests.material(key).get("name", key)), Palette.GOLD_BRIGHT)
		Audio.sfx("loot", 0.5)
	var at: Array = d.at
	var yaw := deg_to_rad(float(d.get("yaw", 180.0)))
	var out := Vector3(float(at[0]), float(at[1]), float(at[2])) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -1.4)
	if not Game.state.has("world3d"):
		Game.state["world3d"] = {}
	Game.state.world3d["return"] = {"loc": loc.id, "pos": [out.x, out.y, out.z], "yaw": yaw}
	# Führt am Ziel eine Tür zurück hierher (Treppen zwischen den Ebenen Nazaricks), kommt man vor ihr an
	var arrive := {}
	var target: Dictionary = Content.location_by_id[String(d.to)]
	for back in target.get("doors", []):
		if String(back.get("to", "")) == String(loc.id):
			var bat: Array = back.at
			var byaw := deg_to_rad(float(back.get("yaw", 180.0)))
			arrive = {"pos": Vector3(float(bat[0]), float(bat[1]), float(bat[2])) + Basis(Vector3.UP, byaw) * Vector3(0, 0, -1.4), "yaw": byaw}
			break
	Audio.sfx("page", 0.5)
	await load_location(String(d.to), true, arrive)


func _leave_building() -> void:
	if _busy:
		return
	var r: Dictionary = Game.state.get("world3d", {}).get("return", {})
	var target := String(loc.get("parent", r.get("loc", "throne")))
	if not Content.location_by_id.has(target):
		target = "throne"
	var arrive := {}
	if r.get("loc", "") == target and r.has("pos"):
		arrive = {"pos": Vector3(float(r.pos[0]), float(r.pos[1]), float(r.pos[2])), "yaw": float(r.yaw)}
	Audio.sfx("page", 0.5)
	await load_location(target, true, arrive)


func _refresh_actors_soft() -> void:
	_refresh_hud()


# =====================================================================
#  Menüs
# =====================================================================

func _open(o: Control) -> Control:
	overlay_layer.add_child(o)
	return o


func _open_map() -> void:
	var m := WorldMapView.new(loc.get("region", "nazarick"))
	m.open_missions.connect(func(rid): await get_tree().create_timer(0.3).timeout; _open(MissionBoard.new(rid)))
	_open(m)


func _time_menu() -> void:
	var pend := not Game.pending().is_empty()
	_open(ChoiceMenu.new("Der Thron von Nazarick", "Tag %d · %s" % [Game.state.day, Game.format_date(Game.state.day)], [
		{"text": "◷  Einen Tag vergehen lassen", "action": func(): _advance(1), "disabled": pend},
		{"text": "◷  Eine Woche vergehen lassen", "action": func(): _advance(7), "disabled": pend},
		{"text": "◷  Einen Monat vergehen lassen", "action": func(): _advance(30), "disabled": pend},
		{"text": ("⏸  Zeitfluss anhalten" if _time_running else "▶  Zeitfluss fortsetzen"), "sub": "Ohne Eingriff vergeht alle %d Sekunden ein Tag." % int(DAY_SECONDS),
			"action": func(): _time_running = not _time_running; toast("Die Zeit %s." % ("fließt wieder" if _time_running else "steht still"))},
		{"text": "❤  Wochenziele & Nazarick", "sub": "Albedos Truhe, Ausbau, Schatzkammer [N]", "action": func(): _open(NazarickView.new(2))},
	], 700, "ainz"))


func _war_table() -> void:
	_open(ChoiceMenu.new("Kriegsrat", "Die Weltkarte liegt vor Euch ausgebreitet.", [
		{"text": "✦  Auftragstafel", "sub": "Wächter entsenden [J]", "action": func(): _open(MissionBoard.new()), "style": "ButtonPrimary"},
		{"text": "⚑  Weltkarte & Legionen", "sub": "Regionen, Heere, Feldzüge [M]", "action": _open_map},
		{"text": "⚖  Diplomatie", "sub": "Fraktionen & Gesandtschaften [P]", "action": func(): _open(DiplomacyView.new())},
		{"text": "☰  Chronik", "sub": "Alle Ereignisse [C]", "action": func(): _open(ChronicleView.new())},
	], 700, "demiurge"))


func _desk_menu() -> void:
	_open(ChoiceMenu.new("Albedos Pult", "»Alles ist vorbereitet, %s.«" % Game.lord(), [
		{"text": "❤  Wochenziele & Truhe", "action": func(): _open(NazarickView.new(2)), "style": "ButtonPrimary" if Progress.can_claim_chest() else "Button"},
		{"text": "⚒  Ausbau der Ebenen", "action": func(): _open(NazarickView.new(0))},
		{"text": "◈  Schatzkammer & Ausrüstung", "action": func(): _open(NazarickView.new(1))},
		{"text": "★  Errungenschaften", "action": func(): _open(NazarickView.new(3))},
		{"text": "⚙  Reichsverwaltung & Erlasse", "sub": "[V]", "action": func(): _open(AdministrationView.new())},
	], 700, "albedo"))


func _gate_menu() -> void:
	var entries: Array = []
	for l in Content.locations:
		if l.get("group", "") == "interior":
			continue
		var ok := true
		var why := ""
		if l.group == "world":
			var r: String = l.get("region", "")
			ok = r == "" or World.rs(r).get("discovered", false)
			why = "Noch nicht erkundet – entsendet einen Wächter zur Erkundung."
		var here: bool = l.id == loc.id
		entries.append({"text": ("☗  " if l.group == "nazarick" else "✧  ") + l.name + ("   (hier)" if here else ""),
			"sub": _short(l.get("desc", "")), "disabled": not ok or here, "tip": why if not ok else "",
			"action": func(): _travel(l.id)})
	_open(ChoiceMenu.new("Gate", "Wohin soll das Tor sich öffnen?", entries, 980))


## Kurzbeschreibung: erster Satz, sonst an einer Wortgrenze gekürzt.
func _short(t: String, n: int = 110) -> String:
	var dot := t.find(". ")
	if dot > 0 and dot < n:
		return t.substr(0, dot + 1)
	if t.length() <= n:
		return t
	var cut := t.substr(0, n)
	return cut.substr(0, cut.rfind(" ")) + " …"


func _region_menu_info() -> void:
	_region_menu()


func _region_menu() -> void:
	var rid: String = loc.get("region", "")
	var r := World.region(rid)
	var st := World.rs(rid)
	var txt := "Einfluss %d %% · Unruhe %d · %s" % [int(st.get("influence", 0)), int(st.get("unrest", 0)), World.control_label(int(st.get("influence", 0)))]
	_open(ChoiceMenu.new(r.get("name", loc.name), txt, [
		{"text": "✦  Aufträge in dieser Region", "action": func(): _open(MissionBoard.new(rid)), "style": "ButtonPrimary"},
		{"text": "⚑  Auf der Weltkarte zeigen", "action": func(): _open(WorldMapView.new(rid))},
	], 700))


func _open_journal() -> void:
	var qj := QuestJournal.new()
	qj.replay_requested.connect(func(mid: String): replay_story(mid))
	_open(qj)


## Alle Fenster, die sonst auf Tasten liegen – für Controller-Spieler und als Übersicht.
func _books_menu() -> void:
	_open(ChoiceMenu.new("Bücher, Karten & Berichte", "Alles, was sonst auf Tasten liegt", [
		{"text": "📜  Zauberbuch", "sub": "Seelen, Zauber, Ringe (B)", "action": func(): _open(Grimoire.new())},
		{"text": "📔  Questbuch (J)", "action": _open_journal},
		{"text": "🗺  Weltkarte & Legionen (M)", "action": _open_map},
		{"text": "⚔  Entsendungen der Wächter (K)", "action": func(): _open(MissionBoard.new(loc.get("region", "")))},
		{"text": "✉  Nächste Depesche (Enter)", "action": func(): _open_next_dispatch(true)},
		{"text": "◷  Zeit verstreichen lassen (T)", "action": _time_menu},
		{"text": "🌀  Gate – Reisen (G)", "action": _gate_menu},
		{"text": "🎭  Ainz ↔ Momon (X)", "action": player.toggle_style},
		{"text": "🤝  Diplomatie (P)", "action": func(): _open(DiplomacyView.new())},
		{"text": "🏛  Verwaltung (V)", "action": func(): _open(AdministrationView.new())},
		{"text": "🏰  Nazarick (N)", "action": func(): _open(NazarickView.new())},
		{"text": "👑  Wächter & Audienzen (U)", "action": func(): _open(CharacterView.new("albedo"))},
		{"text": "📚  Chronik (C)", "action": func(): _open(ChronicleView.new())},
		{"text": "🎯  Wochenziele (Tab)", "action": hud.toggle_goals},
	], 700))


func _pause_menu() -> void:
	_open(ChoiceMenu.new("Pause", "%s · Tag %d" % [Game.state.lord_name, Game.state.day], [
		{"text": "▶  Weiter", "action": func(): pass, "style": "ButtonPrimary"},
		{"text": "📖  Bücher, Karten & Berichte", "sub": "Zauberbuch, Questbuch, Karte, Depeschen, Gate …", "action": _books_menu},
		{"text": "📷  Fotomodus", "sub": "Freie Kamera, Filter, Foto speichern (F9)", "action": func(): await get_tree().create_timer(0.3).timeout; photo.toggle()},
		{"text": "🧪  Testmodus", "sub": "Alle Orte, Gegner, Story-Einsätze, Tageszeit, Wetter – zum Prüfen", "action": _test_menu},
		{"text": "✎  Speichern", "action": func(): _open(SaveLoadDialog.new(true))},
		{"text": "☰  Laden", "action": _load_menu},
		{"text": "⚙  Einstellungen", "action": _settings},
		{"text": "?  Einführung erneut zeigen", "action": start_tutorial},
		{"text": "✕  Zum Titelbildschirm", "action": func(): get_tree().change_scene_to_file(TITLE_SCENE)},
	], 620))


# =====================================================================
#  Testmodus: Orte, Gegner und Story-Einsätze ohne Freischaltung prüfen
# =====================================================================

func _test_menu() -> void:
	var tw: bool = Game.state.get("testwelt", false)
	_open(ChoiceMenu.new("Testmodus", "Zum Prüfen von Orten und Kämpfen – ohne Folgen für die Geschichte." if tw else "Nur zum Prüfen. Tipp: „Alles freischalten“ öffnet Gate, Wächter und Kapitel-Momente.", [
		{"text": "✧  Zu einem Ort reisen …", "sub": "Alle Außenorte, Nazarick-Ebenen und Innenräume", "action": _test_travel_menu, "style": "ButtonPrimary"},
		{"text": "⚔  Gegner beschwören …", "sub": "Jeder Gegner aus data/combat.json erscheint vor Euch", "action": _test_enemy_menu},
		{"text": "⚜  Story-Einsatz starten …", "sub": "Alle Kapitel-Momente als Erinnerung (ohne Folgen)", "action": _test_story_menu},
		{"text": "☀  Tageszeit: Tag / ☾ Nacht / ◐ Abend", "sub": "Sonnenstand sofort umstellen", "action": _test_time_menu},
		{"text": "☂  Wetter: klar / Regen / Nebel / Schnee / Sand", "sub": "Wetter des Ortes sofort umstellen", "action": _test_weather_menu},
		{"text": "❤  Heilen & Gegner entfernen", "sub": "Volle Werte, alle Gegner verschwinden", "action": _test_heal},
		{"text": "✦  Alles freischalten", "sub": "Letztes Kapitel, alle Wächter, alle Gegenden, alle Kapitel-Momente, 5000 Gold", "action": _test_unlock, "disabled": tw},
	], 760))


func _test_heal() -> void:
	player.heal(1.0, 1.0, 1.0)
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	toast("Geheilt – keine Gegner mehr.", Palette.GOLD_BRIGHT)


func _test_unlock() -> void:
	Game.unlock_everything()
	_refresh_hud()
	toast("Testwelt: alles freigeschaltet.", Palette.GOLD_BRIGHT)


func _test_travel_menu() -> void:
	var entries: Array = []
	for grp in ["world", "nazarick", "interior"]:
		for l in Content.locations:
			if l.get("group", "") != grp:
				continue
			var mark := "✧  " if grp == "world" else ("☗  " if grp == "nazarick" else "⌂  ")
			var sub := String(l.get("kind", ""))
			if grp == "interior":
				sub += " · in " + String(Content.location_by_id.get(String(l.get("parent", "")), {}).get("name", "?"))
			entries.append({"text": mark + l.name + ("   (hier)" if l.id == loc.id else ""), "sub": sub, "disabled": l.id == loc.id,
				"action": func(): _test_travel(l.id)})
	_open(ChoiceMenu.new("Testreise", "Alle %d Orte – Ankunft am Startpunkt des Ortes." % entries.size(), entries, 980))


func _test_travel(id: String) -> void:
	if _busy:
		return
	Audio.sfx("gong", 0.5)
	await load_location(id, true)


func _test_enemy_menu() -> void:
	var entries: Array = []
	var ids: Array = Content.combat.enemies.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = Content.combat.enemies[id]
		if String(d.get("team", "")) == "ally" or String(id).ends_with("_ally"):
			continue
		var boss: bool = d.get("boss", false)
		var elite: bool = d.get("elite", false)
		entries.append({"text": ("☠  " if boss else ("◆  " if elite else "•  ")) + String(d.get("name", id)), "sub": "%s · %d LP%s" % [id, int(d.get("hp", 0)), "  · Boss" if boss else ("  · Elite" if elite else "")],
			"action": func(): test_spawn(String(id), 1 if (boss or elite) else 3)})
	_open(ChoiceMenu.new("Gegner beschwören", "%d Gegnerarten – Bosse und Eliten einzeln, andere zu dritt." % entries.size(), entries, 940))


## Gegner vor dem Spieler erscheinen lassen (Testmodus und Testwerkzeug).
func test_spawn(id: String, n: int = 1) -> Array:
	var out: Array = []
	if not Content.combat.enemies.has(id) or level == null:
		return out
	var fwd := Basis(Vector3.UP, player.cam_yaw) * Vector3(0, 0, -1)
	for i in n:
		var side := Vector3(-fwd.z, 0, fwd.x) * float(i - (n - 1) * 0.5) * 2.5
		var p := player.global_position + fwd * 9.0 + side
		p = _on_ground(p) + Vector3(0, 0.2, 0)
		out.append(spawn_enemy(id, p))
	toast("%d × %s erscheint." % [n, String(Content.combat.enemies[id].get("name", id))], Palette.GOLD_BRIGHT)
	return out


func _test_story_menu() -> void:
	var entries: Array = []
	var all := StoryMission.load_all()
	for mid in all:
		var m: Dictionary = all[mid]
		var where: String = String(Content.location_by_id.get(String(m.get("loc", "")), {}).get("name", ""))
		entries.append({"text": "⚜  " + String(m.get("title", mid)), "sub": "%s · %s" % [String(mid), where],
			"action": func(): replay_story(String(mid))})
	_open(ChoiceMenu.new("Story-Einsatz starten", "Als Erinnerung: ohne Lohn und ohne Folgen; Esc überspringt Szenen.", entries, 900))


func _test_time_menu() -> void:
	var set_tod := func(f: float, name: String) -> void:
		if day_cycle.active:
			day_cycle.force = f
			day_cycle.update(f)
			toast("Tageszeit: %s" % name, Palette.GOLD_BRIGHT)
		else:
			toast("Hier gibt es keinen Tag-Nacht-Wechsel (Innenraum oder feste Nacht).", Palette.MUTED)
	_open(ChoiceMenu.new("Tageszeit", "Sofort umstellen – wirkt bis zur nächsten Reise.", [
		{"text": "☀  Mittag", "action": func(): set_tod.call(0.5, "Mittag")},
		{"text": "◐  Abend", "action": func(): set_tod.call(0.78, "Abend")},
		{"text": "☾  Nacht", "action": func(): set_tod.call(0.95, "Nacht")},
		{"text": "☼  Morgen", "action": func(): set_tod.call(0.22, "Morgen")},
		{"text": "↺  Wieder nach Spielzeit", "action": func(): day_cycle.force = -1.0; toast("Tageszeit folgt wieder der Spielzeit.", Palette.MUTED)},
	], 620))


func _test_weather_menu() -> void:
	var set_w := func(kind: String, name: String) -> void:
		weather.force = kind
		weather.refresh(int(Game.state.get("day", 1)), true)
		toast("Wetter: %s" % name, Palette.GOLD_BRIGHT)
	_open(ChoiceMenu.new("Wetter", "Sofort umstellen – wirkt bis zur nächsten Reise.", [
		{"text": "☀  Klar", "action": func(): set_w.call("clear", "klar")},
		{"text": "☁  Bedeckt", "action": func(): set_w.call("overcast", "bedeckt")},
		{"text": "☂  Regen (mit Gewitter)", "action": func(): set_w.call("rain", "Regen")},
		{"text": "≋  Nebel", "action": func(): set_w.call("fog", "Nebel")},
		{"text": "❄  Schneefall", "action": func(): set_w.call("snow", "Schneefall")},
		{"text": "≈  Sandsturm", "action": func(): set_w.call("sand", "Sandsturm")},
		{"text": "↺  Wieder nach Tag und Gegend", "action": func(): weather.force = ""; weather.refresh(int(Game.state.get("day", 1)), true); toast("Wetter folgt wieder Tag und Gegend.", Palette.MUTED)},
	], 620))


func _settings() -> void:
	var dlg := SettingsDialog.new(true)
	dlg.tutorial_requested.connect(func(): await get_tree().create_timer(0.3).timeout; start_tutorial())
	_open(dlg)


func _load_menu() -> void:
	var dlg := SaveLoadDialog.new(false)
	dlg.loaded.connect(func(): get_tree().reload_current_scene())
	_open(dlg)


func _travel(id: String) -> void:
	Audio.sfx("gong", 0.6)
	await load_location(id, true)


# =====================================================================
#  Zeit & Depeschen
# =====================================================================

func _advance(days: int, show_veil: bool = true) -> void:
	if _busy:
		return
	if not Game.pending().is_empty():
		_open_next_dispatch(true)
		return
	_busy = true
	if show_veil:
		Audio.sfx("gong", 0.5)
		await _fade(0.6, 0.3)
	var res := Game.advance(days)
	_autosave()
	if show_veil:
		_show_banner("%d %s vergangen" % [res.days, "Tag" if res.days == 1 else "Tage"], Game.format_date(Game.state.day))
		await _fade(0.0, 0.4)
	_busy = false
	_refresh_hud()
	_open_next_dispatch()


func _open_next_dispatch(force: bool = false) -> void:
	if overlay_layer.get_child_count() > 0 or story != null or cinematic:
		return
	var pending := Game.pending()
	if pending.is_empty():
		return
	if in_combat() and not force:
		toast("Eine Depesche wartet – erst der Kampf. [Enter] öffnet sie.", Palette.GOLD_BRIGHT)
		return
	if not Settings.auto_open and not force:
		toast("Eine Depesche ist eingetroffen – [Enter] zum Öffnen.", Palette.GOLD_BRIGHT)
		return
	var d: Dictionary = pending[0]
	var battle_uid: String = d.get("context", {}).get("battle", "") if d.kind == "battle" else ""
	if battle_uid != "" and Game.state.battles.has(battle_uid) and not _has_option(d, "lead"):
		# Ainz kann jede Schlacht persönlich anführen – sie wird dann in 3D ausgetragen
		d.options.push_front({"key": "lead", "label": "⚔ Persönlich in die Schlacht ziehen (3D-Kampf)", "variant": "primary", "effects": {}, "reaction": "Ihr erhebt Euch vom Thron. Das Gate öffnet sich zum Schlachtfeld …"})
	# Story-Momente lassen sich selbst erleben: passende Antwort(en) starten einen Einsatz in 3D
	var ev_id: String = String(d.get("context", {}).get("event_id", ""))
	var sm := StoryMission.for_event(ev_id) if ev_id != "" else []
	var has_play := false
	for o in d.options:
		has_play = has_play or o.has("play")
	if not sm.is_empty() and not has_play and not Game.has_flag("story_" + String(sm[0])):
		var mdef: Dictionary = sm[1]
		var plays: Array = mdef.get("plays", ["c0"])
		if mdef.get("replace", false) and plays.size() == 1:
			for o in d.options:
				if o.key == plays[0]:
					o["play"] = sm[0]
					o["label"] = String(o.label) + "  ⚔ (selbst erleben)"
					o["variant"] = "primary"
		else:
			d.options.push_front({"key": "play", "play": sm[0], "label": String(mdef.get("label", "⚔ Selbst erleben (3D)")), "variant": "primary", "effects": {}, "reaction": ""})
	var dlg: DispatchDialog = DispatchDialog.new(d)
	dlg.play_requested.connect(func(mid: String): _start_story(mid, String(d.uid)))
	dlg.closed.connect(func():
		await get_tree().create_timer(0.15).timeout
		if battle_uid != "" and Game.state.battles.has(battle_uid):
			_lead_battle(battle_uid)
			return
		_open_next_dispatch(true)
		_refresh_hud())
	_open(dlg)


func _autosave() -> void:
	var every := Settings.autosave_days()
	if every > 0 and Game.state.day - _last_autosave >= every:
		_last_autosave = Game.state.day
		SaveSystem.save_game(0)


# =====================================================================
#  HUD
# =====================================================================

func _build_ui() -> void:
	add_child(ui)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = load("res://assets/ui/nazarick_theme.tres")
	ui.add_child(ui_root)
	hud_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_vignette.color = Color(0.6, 0.0, 0.05, 0.0)
	hud_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_vignette)
	ui_root.add_child(hud)
	hud.setup(self)
	hud_feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_feedback.offset_top = 60
	hud_feedback.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_feedback.theme_type_variation = "GoldLabel"
	hud_feedback.add_theme_font_size_override("font_size", 28)
	hud_feedback.add_theme_constant_override("outline_size", 8)
	hud_feedback.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_feedback.modulate.a = 0.0
	ui_root.add_child(hud_feedback)
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(overlay_layer)
	ui_root.add_child(hud.toast_box)
	ui_root.add_child(celebrations)


func _refresh_hud() -> void:
	if is_inside_tree():
		hud.refresh()


func toast(text: String, color: Color = Palette.GOLD_BRIGHT) -> void:
	hud.toast(text, color)


var _banner: Control


func _show_banner(title: String, sub: String) -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	var vb := VBoxContainer.new()
	_banner = vb
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_top = -280
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.text = title.to_upper()
	t.theme_type_variation = "TitleLabel"
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02, 0.9))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var orn := Label.new()
	orn.text = "━━━━━━━━  ◆  ━━━━━━━━"
	orn.add_theme_color_override("font_color", Color(Palette.GOLD, 0.8))
	orn.add_theme_font_size_override("font_size", 14)
	orn.add_theme_constant_override("outline_size", 4)
	orn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(orn)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_override("font", NazarickTheme.italic_font(600))
	s.add_theme_font_size_override("font_size", 21)
	s.add_theme_color_override("font_color", Palette.PARCHMENT)
	s.add_theme_constant_override("outline_size", 7)
	s.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 860
	vb.add_child(s)
	hud.add_child(vb)
	vb.modulate.a = 0.0
	t.pivot_offset = Vector2(430, 28)
	t.scale = Vector2(1.06, 1.06)
	var tw := vb.create_tween()
	tw.tween_property(vb, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(t, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.2)
	tw.tween_property(vb, "modulate:a", 0.0, 0.9)
	tw.tween_callback(vb.queue_free)


var _veil: ColorRect


func _fade(to: float, t: float) -> void:
	if _veil == null:
		_veil = ColorRect.new()
		_veil.color = Color(0.02, 0.0, 0.04, 0.0)
		_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(_veil)
		ui_root.move_child(_veil, overlay_layer.get_index())
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", to, t)
	await tw.finished


# =====================================================================
#  Kampf
# =====================================================================

## Nachts wird die Welt gefährlicher: Begegnungen mit "night": true erscheinen erst, wenn es dunkel wird.
func _night_changed(night: bool) -> void:
	if night:
		_spawn_encounters(true)
	for t in level.find_children("Townsfolk_guard", "Townsfolk", true, false):
		(t as Townsfolk).set_torches(night)


func _spawn_encounters(night_only: bool = false) -> void:
	if suppress_encounters:
		return
	for enc in loc.get("encounters", []):
		var at_night: bool = enc.get("night", false)
		if night_only and not at_night:
			continue
		if at_night and not night_only and not day_cycle.night:
			continue
		if not Game.check(enc.get("requires", {})):
			continue
		var at: Array = enc.get("at", [0, 0])
		var center := Vector3(float(at[0]), 0.2, float(at[1]))
		for i in int(enc.get("count", 1)):
			var off := Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)) if i > 0 else Vector3.ZERO
			spawn_enemy(enc.enemy, center + off)


func spawn_enemy(id: String, pos: Vector3) -> Enemy3D:
	var e := Enemy3D.create(id)
	e.position = pos
	e.target = player
	level.add_child(e)
	enemies.append(e)
	e.defeated.connect(_on_enemy_defeated)
	e.telegraphed.connect(func(en: Enemy3D, a: Dictionary): hud.indicators.warn(en, float(a.get("windup", 0.5)), bool(a.get("unblockable", false))))
	return e


func _on_player_damaged(_f: Fighter, amount: int, _kind: String) -> void:
	hud_vignette.color.a = clampf(0.15 + amount / 120.0, 0.0, 0.5)


## Treffer auf Ainz: Richtungsbogen zur Quelle (auch bei Block).
func _on_player_struck(_f: Fighter, res: String, info: Dictionary, dealt: float) -> void:
	if res in ["hit", "kill", "block", "guardbreak", "shield"] and info.has("_src"):
		hud.indicators.hit_from(info._src, 0.6 + clampf(dealt / 40.0, 0.0, 0.8))


func _on_enemy_defeated(e: Enemy3D) -> void:
	enemies.erase(e)
	var memory := story != null and story.replay        # Erinnerungen bringen keinen Lohn
	if not memory:
		quest_world.on_enemy_defeated(e)
		# Verliesbosse nur in ihrem Verlies (Khajit und der General tauchen auch in Story-Einsätzen und im Testmodus auf)
		if (e.type_id == "fallen_general" and String(loc.id) == "katze_gruft") or (e.type_id == "khajit" and String(loc.id) == "erantel_mausoleum"):
			quest_world.dungeon_boss_defeated(e)
		if e.data.has("drops_key"):
			quest_world.drop_key(e, String(e.data.drops_key))
	var gold := 0 if memory else int(e.data.get("gold", 0))
	if gold > 0 and not e.ally:
		Game.apply_effects({"res": {"gold": gold}})
		CombatFX.float_text(level, e.global_position + Vector3(0, e.body_height + 1.0, 0), "+%d Gold" % gold, Palette.GOLD_BRIGHT, 40)
	# Siegmoment: Elite, Boss oder der letzte Gegner im Kampf → kurze Zeitlupe
	var last := CombatDirector.engaged(player).is_empty()
	if e.data.get("boss", false) or e.data.get("elite", false):
		CombatFX.slowmo(0.28, 0.55)
		CombatFX.shake(0.3)
		CombatFX.sound("kill_big", e.global_position + Vector3.UP, 1.0)
	elif last:
		CombatFX.slowmo(0.4, 0.32)
		CombatFX.sound("kill_big", e.global_position + Vector3.UP, 0.8)
	Progress.bump("enemies_slain")
	if not memory:
		# Seelen fliegen zu Ainz, Eliten und Bosse lassen Beute zum Aufheben fallen
		SoulOrbs.spawn(level, e.global_position + Vector3.UP * e.body_height * 0.6, player, Progress.souls_for(e.data, e.summoned))
		_drop_loot(e)
		Game.log_msg("%s bezwingt %s." % [Game.state.lord_name, e.display_name], "mission")
	if e.data.get("respawn", false):
		var id := e.type_id
		var home := e.home
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(level) and loc.get("encounters", []).size() > 0:
				spawn_enemy(id, home))
	_check_battle_end.call_deferred()
	if enemies.is_empty() and not e.data.get("respawn", false) and story == null:
		toast("Die Gegend ist gesäubert.", Palette.SUCCESS)
	_refresh_hud()


## Einmaliger Hinweis, sobald die Seelen für die erste Aufwertung reichen.
func _on_souls_hint(total: int, gained: int) -> void:
	if gained <= 0 or Game.has_flag("hint_grimoire") or total < int(Progress.gcfg().get("rank_cost", {}).get("2", 120)):
		return
	Game.set_flag("hint_grimoire")
	toast("❖ Genug Seelen für eine Aufwertung – öffnet das Zauberbuch [B].", Color(0.78, 0.6, 1.0))


## Beute eines Elite-Gegners oder Bosses: Artefakt für die Schatzkammer und/oder ein Ring für Ainz – als leuchtender
## Fund am Boden, den Ainz im Vorbeigehen aufhebt.
func _drop_loot(e: Enemy3D) -> void:
	var boss: bool = e.data.get("boss", false)
	if not (boss or e.data.get("elite", false)) or e.data.get("noloot", false) or e.summoned:
		return
	var drops: Array = []
	var chance := float(Progress.data.loot_chance.get("battle", 0.3)) * (2.0 if boss else 1.0) + Progress.floor_value("loot")
	if Game.rng.randf() < chance:
		var iid := Progress.roll_item("common", 0.12 if boss else 0.0)
		drops.append(["item", iid, String(Progress.item_def(iid).get("rarity", "common"))])
	var rc := float(Progress.gcfg().get("ring_drop", {}).get("boss" if boss else "elite", 0.12))
	if Game.rng.randf() < rc:
		var rid := Progress.roll_ring()
		if rid != "":
			drops.append(["ring", rid, String(Progress.ring_def(rid).get("rarity", "common"))])
	for i in drops.size():
		var off := Vector3(cos(i * 2.4), 0.0, sin(i * 2.4)) * 1.4 if drops.size() > 1 else Vector3.ZERO
		LootDrop.drop(level, e.global_position + off, drops[i][0], drops[i][1], drops[i][2], "Bezwungen: " + e.display_name)


func _on_player_died() -> void:
	_busy = true
	var memory := story != null and story.replay
	if story != null:
		var title: String = String(story.def.get("title", ""))
		story.abort()
		if memory:
			toast("Die Erinnerung an „%s“ verblasst." % title, Palette.VIOLET_GLOW)
		else:
			toast("„%s“ gescheitert – die Depesche wartet. Versucht es erneut oder entscheidet anders." % title, Palette.DANGER)
	if not _battle.is_empty():
		Military.resolve_battle(_battle.uid, "overlord_fallen")
		_battle = {}
	await get_tree().create_timer(1.8).timeout
	if not memory:
		_show_banner("Ainz zieht sich zurück", "Ein Overlord stirbt nicht – doch die Niederlage schmerzt Nazarick.")
		Game.apply_effects({"res": {"morale": -4}})
		Game.log_msg("Ainz musste sich aus %s nach Nazarick zurückziehen." % loc.name, "warning")
	await _fade(1.0, 0.6)
	player.revive()
	_busy = false
	await load_location("throne")
	await _fade(0.0, 0.6)


func _on_feedback(text: String, color: Color) -> void:
	hud_feedback.text = text
	hud_feedback.add_theme_color_override("font_color", color)
	hud_feedback.modulate.a = 1.0
	var tw := hud_feedback.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(hud_feedback, "modulate:a", 0.0, 0.5)


func _exit_tree() -> void:
	Enemy3D.hold = false
	Actor3D.hide_labels = false
	CombatFX.reset_time()
	CombatDirector.reset()


func _float_text(at: Vector3, text: String, col: Color, size: int) -> void:
	CombatFX.float_text(level, at, text, col, size)


func _rebuild_spell_bar() -> void:
	hud.rebuild_spells(player)


func _update_combat_hud(blocked: bool = false) -> void:
	hud.tick(get_process_delta_time(), blocked or _busy)
	if hud_vignette.color.a > 0.0:
		hud_vignette.color.a = maxf(0.0, hud_vignette.color.a - get_process_delta_time() * 0.8)


## Kampf läuft, wenn ein lebender Gegner Ainz bemerkt hat.
func in_combat() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD and e.global_position.distance_to(player.global_position) < e.aggro * 1.3:
			return true
	return false


# =====================================================================
#  Story-Einsätze und Filmszenen
# =====================================================================

func cinematic_ui() -> CinematicUI:
	if _cine_ui == null or not is_instance_valid(_cine_ui):
		_cine_ui = CinematicUI.new()
		_cine_ui.visible = false
		ui_root.add_child(_cine_ui)
		ui_root.move_child(_cine_ui, overlay_layer.get_index())
	return _cine_ui


func _start_story(mid: String, uid: String) -> void:
	if story != null:
		return
	await get_tree().create_timer(0.2).timeout
	var m := StoryMission.new(self, mid, uid)
	m.start()


## Ende eines Einsatzes: Depesche mit der erspielten Wahl beantworten, Reaktion zeigen, feiern.
func story_finished(m: StoryMission, key: String) -> void:
	var d := Game.get_dispatch(m.dispatch_uid)
	var title: String = String(m.def.get("title", "Story"))
	if d.is_empty():
		return
	# „Selbst erleben“ ist erledigt: die Option verschwindet, ersetzte Antworten werden wieder normale Antworten
	d.options = d.options.filter(func(o): return String(o.key) != "play")
	for o in d.options:
		o.erase("play")
	var found := false
	for o in d.options:
		found = found or String(o.key) == key
	if not found and not d.options.is_empty():
		key = String(d.options[0].key)
	# liegen gebliebene Beute einsammeln, dann der Lohn des Kapitel-Moments (Seelen, einzigartiger Ring)
	for ld in get_tree().get_nodes_in_group("loot_drops"):
		if is_instance_valid(ld):
			ld.collect()
	Progress.celebrate.emit({"kind": "achievement", "title": "Kapitel-Moment", "text": title, "sub": "Selbst erlebt", "icon": "⚜", "color": Palette.GOLD_BRIGHT})
	Progress.story_reward(m.id)
	# Die Depesche zeigt die Folgen der erspielten Wahl wie gewohnt: Reaktion (mit Farben) und Auswirkungen
	var dlg: DispatchDialog = DispatchDialog.new(d)
	dlg.closed.connect(func():
		await get_tree().create_timer(0.15).timeout
		_open_next_dispatch(true)
		_refresh_hud())
	_open(dlg)
	await get_tree().process_frame
	if is_instance_valid(dlg):
		dlg._choose(key)
	_refresh_hud()


## Erinnerung: einen erlebten Story-Einsatz erneut spielen – ohne Folgen, danach zurück an den Ausgangsort.
func replay_story(mid: String) -> void:
	if story != null:
		return
	await get_tree().create_timer(0.3).timeout
	var m := StoryMission.new(self, mid, "")
	m.replay = true
	m.return_loc = String(loc.get("id", "throne"))
	m.start()


func spawn_ally(id: String, pos: Vector3) -> Enemy3D:
	var e := Enemy3D.create(id, true)
	e.position = pos
	level.add_child(e)
	allies.append(e)
	return e


func _has_option(d: Dictionary, key: String) -> bool:
	for o in d.get("options", []):
		if o.get("key", "") == key:
			return true
	return false


# =====================================================================
#  Schlachten persönlich anführen
# =====================================================================

var _battle: Dictionary = {}


## Teleportiert Ainz zum Schlachtfeld der Region und lässt die feindliche Armee als Welle antreten.
func _lead_battle(uid: String) -> void:
	var b: Dictionary = Game.state.battles[uid]
	var target := "katze"
	for l in Content.locations:
		if l.get("region", "") == b.region and l.get("group", "") == "world":
			target = l.id
	_battle = {"uid": uid, "enemies": [], "left": 0}
	await load_location(target, true)
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	var strength := int(b.enemy_strength)
	var n := clampi(strength / 40, 3, 9)
	var kinds := _battle_roster(b)
	var center: Vector3 = anchors.spawn + Vector3(0, 0, -16)
	for i in n:
		var kind: String = kinds[mini(i, kinds.size() - 1)] if i < 2 else kinds[i % kinds.size()]
		var e := spawn_enemy(kind, center + Vector3((i % 3 - 1) * 3.0, 0, -(i / 3) * 3.0))
		e.aggro = 60.0
		_battle.enemies.append(e)
	_battle.left = n
	_show_banner("Schlacht um " + World.region(b.region).get("short", ""), "%s – %d Gegner. Besiegt sie alle!" % [b.enemy_name, n])
	Audio.play_music("battle")


func _battle_roster(b: Dictionary) -> Array:
	var name := String(b.enemy_name).to_lower()
	if "engel" in name or "theokratie" in name or "schrift" in name:
		return ["angel", "soldier", "scripture_archer", "soldier", "sunlit_caster", "scripture_archer"]
	if "elf" in name:
		return ["elf", "elf_archer", "elf", "elf_archer"]
	if "untot" in name or "katze" in name:
		return ["death_knight", "skeleton", "skeleton_archer", "skeleton", "elder_lich", "skeleton_archer"]
	if "quagoa" in name or "frost" in name:
		return ["quagoa"]
	if "echsen" in name or "sumpf" in name:
		return ["lizard", "lizard", "lizard_shaman"]
	return ["soldier", "soldier", "bandit_archer", "death_knight", "bandit_archer"]


func _check_battle_end() -> void:
	if _battle.is_empty():
		return
	var alive := 0
	for e in _battle.enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD:
			alive += 1
	if alive > 0:
		return
	var uid: String = _battle.uid
	_battle = {}
	var summary := Military.resolve_battle(uid, "personal")
	Game.state_changed.emit()
	_show_banner("Sieg!", Military.last_result.get("text", "Der Feind ist vernichtet.").substr(0, 160))
	toast("Schlacht gewonnen – %d Auswirkungen." % summary.size(), Palette.SUCCESS)
	Audio.play_music(loc.get("music", "throne"))


# =====================================================================
#  Einführung (3D)
# =====================================================================

func start_tutorial() -> void:
	var steps := [
		["albedo", "Willkommen in Eurem Thronsaal, {lord}. Ihr bewegt Euch mit [b]WASD[/b], die Maus lenkt den Blick. Tretet an uns Wächter heran und drückt [b]E[/b], um eine Audienz zu gewähren."],
		["demiurge", "Am [b]Kriegsrat[/b] (links) liegen die Auftragstafel, die Karte des Kriegstisches und die Diplomatie. Befehle an uns Wächter erteilt Ihr dort – oder jederzeit mit [b]J[/b]."],
		["albedo", "Mein [b]Pult[/b] (rechts) birgt Verwaltung, Ausbau, Schatzkammer und meine Wochenziele für Euch. Der [b]Thron[/b] lässt die Zeit verstreichen – sie fließt aber auch von selbst."],
		["cocytus", "Das [b]Gate[/b] am Ende der Halle führt in jede erkundete Region. Dort lauern Feinde: [b]linke Maustaste[/b] leichter Schlag, [b]rechte[/b] schwerer, [b]Leertaste[/b] ausweichen, [b]F[/b] blocken – im rechten Moment pariert. [b]Q[/b] fixiert ein Ziel."],
		["shalltear", "Und Zauber, ~arinsu! [b]1–5[/b] und [b]R[/b] wirken Eure Magie, [b]%s[/b] entfesselt Superrang-Magie, mit [b]X[/b] werdet Ihr zu Momon mit zwei Großschwertern. Und wenn Ihr mich lobt statt diese gehörnte Kuh – umso besser!" % Player3D.key_label("spell_super")],
	]
	_tutorial_step(steps, 0)


func _tutorial_step(steps: Array, i: int) -> void:
	if i >= steps.size():
		Settings.set_value("tutorial_done", true)
		toast("Die Einführung ist beendet. Ihr findet sie im Menü (Esc).")
		return
	var dlg := TalkDialog.new(steps[i][0], steps[i][1])
	dlg.closed.connect(func(): await get_tree().create_timer(0.2).timeout; _tutorial_step(steps, i + 1))
	_open(dlg)

class_name StoryMission
extends Node
## Spielbarer Story-Moment (data/story_missions.json): ersetzt eine Entscheidung aus einer Story-Depesche durch
## einen Einsatz in 3D – Filmszenen, Kämpfe mit Verbündeten, Bosse mit Zwischenszenen, Wegpunkte. Am Ende wird die
## Depesche mit der im Einsatz getroffenen (oder erspielten) Wahl beantwortet, ihre Folgen gelten wie gewohnt.
##
## Schritte:
##   {"scene": [...]}                                   Filmszene (siehe Cutscene)
##   {"objective": text, "wave": [[gegner, anzahl, [x, z]], …], "allies": [[id, [x, z]], …]}
##   {"objective": text, "boss": gegner, "at": [x, z], "adds": [...], "scenes": [{"hp": 0.5, "steps": [...]}]}
##   {"objective": text, "goto": [x, z], "radius": 3}
##   {"ally": [id, [x, z]]} · {"dismiss": id} · {"set": {schlüssel: wert}} · {"stage": {"pos": [x, z], "yaw": °}}
## Boss: "intro" (Szene direkt nach dem Erscheinen), "scenes" bei Lebensschwellen, "yield_at" (Anteil Leben, bei dem
## der Boss aufgibt und niederkniet – danach folgt meist eine Entscheidung; Untote seines Gefolges zerfallen, Lebende
## ergeben sich). Jeder Schritt kann "only_if": {"key": k, "in": [werte]} tragen.

signal ended(success: bool)

var w: Node
var id := ""
var def: Dictionary = {}
var dispatch_uid := ""
var result: Dictionary = {}
var stage := Transform3D.IDENTITY
var actors: Dictionary = {}
var allies: Array = []
var objective := ""
var objective_sub := ""
var marker := Vector3.INF
var failed := false
var _beam: Node3D
var _used_spells: Dictionary = {}
var boss: Enemy3D                      ## aktueller Boss (für kill_boss / remove_boss in Szenen)
var temp_fx: Array = []                ## Brände u. Ä. aus Szenen – verlöschen am Ende
var _hidden: Array = []                ## Figuren des Ortes, die während des Einsatzes ruhen
var _folk: Array = []                  ## Bewohner (Townsfolk), die sich während eines Kampfes in die Häuser zurückziehen
var _start_style := ""
var loot: Array = []                   ## Bezwungene Elite-Gegner – ihre Beute gibt es nach dem Einsatz
var replay := false                    ## Erinnerung (Questbuch): keine Depesche, keine Folgen
var return_loc := ""                   ## Erinnerung: danach zurück an diesen Ort


static func load_all() -> Dictionary:
	var f := FileAccess.open("res://data/story_missions.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d.get("missions", {}) if d is Dictionary else {}


## Einsatz zu einer Depesche (Ereignis + Antwort), falls vorhanden: [missions-id, beschreibung] oder [].
static func for_event(event_id: String) -> Array:
	var all := load_all()
	for mid in all:
		if String(all[mid].get("event", "")) == event_id:
			return [mid, all[mid]]
	return []


func _init(world: Node, mission_id: String, uid: String) -> void:
	w = world
	id = mission_id
	dispatch_uid = uid
	def = load_all().get(mission_id, {})
	name = "StoryMission"


func start() -> void:
	w.add_child(self)
	w.story = self
	w.suppress_encounters = true
	_start_style = String(w.player.style)
	w.player.spell_cast.connect(_on_spell)
	Audio.sfx("gong", 0.7)
	await w._fade(1.0, 0.5)
	await w.load_location(String(def.loc), false)
	if def.has("mood"):
		StoryFX.mood(w.level, String(def.mood))
	# Figuren des Ortes ruhen – die Szenen stellen ihre eigenen
	for a in w.actors.duplicate():
		if is_instance_valid(a) and a.kind != "object":
			a.visible = false
			a.process_mode = Node.PROCESS_MODE_DISABLED
			w.actors.erase(a)
			_hidden.append(a)
	if def.get("hide_folk", false):
		show_folk(false)
	_set_stage(def.get("stage", {}))
	if def.has("player_at"):
		w.player.global_position = pos(def.player_at) + Vector3.UP * 0.1
	if def.has("music"):
		Audio.play_music(String(def.music))
	for st in def.get("steps", []):
		if failed or not is_instance_valid(w.level):
			break
		# Bild noch schwarz und keine Szene, die selbst aufblendet → jetzt aufblenden
		if not st.has("scene"):
			await _unveil()
		await _step(st)
		await _unveil()
	if failed:
		return
	_finish(true)


func _unveil() -> void:
	if w._veil and w._veil.color.a > 0.01 and not failed:
		await w._fade(0.0, 0.7)


func _set_stage(s: Dictionary) -> void:
	if s.is_empty():
		var yaw: float = w.anchors.get("yaw", 0.0)
		stage = Transform3D(Basis(Vector3.UP, yaw), w.anchors.spawn)
		return
	var p: Array = s.get("pos", [0, 0])
	var at := Vector3(float(p[0]), 0.0, float(p[1]))
	var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at - Vector3.UP * 60.0, 1))
	if hit:
		at.y = float(hit.position.y)
	stage = Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.get("yaw", 0.0)))), at)


func pos(p: Variant) -> Vector3:
	var arr: Array = p
	var wp := stage * Vector3(float(arr[0]), 0.0, float(arr[1]))
	var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(wp + Vector3.UP * 40.0, wp - Vector3.UP * 40.0, 1))
	return Vector3(wp.x, float(hit.position.y) if hit else stage.origin.y, wp.z)


func _step(st: Dictionary) -> void:
	if st.has("only_if"):
		var c: Dictionary = st.only_if
		var want: Array = (c.get("in", []) as Array).map(func(x): return str(x))
		if not str(result.get(String(c.get("key", "c")), "")) in want:
			return
	if st.has("stage"):
		_set_stage(st.stage)
	if st.has("scene"):
		var cs := Cutscene.new(w, st.scene, stage, actors)
		var r := await cs.play()
		for k in r:
			result[k] = r[k]
	elif st.has("wave"):
		if st.has("intro"):
			w.cinematic = true
		_set_objective(String(st.get("objective", "Besiegt die Feinde")), "")
		var list := _spawn_wave(st.wave)
		for a in st.get("allies", []):
			_ally(a)
		if st.has("intro"):
			await _intro(st.intro)
		await _until_cleared(list, st)
	elif st.has("boss"):
		if st.has("intro"):
			w.cinematic = true             # niemand greift an, bevor die Szene beginnt
		_set_objective(String(st.get("objective", "Besiegt den Feind")), "")
		boss = w.spawn_enemy(String(st.boss), pos(st.get("at", [0, -8])))
		boss.aggro = 80.0
		var yield_at := float(st.get("yield_at", -1.0))
		if yield_at > 0.0:
			boss.hp_floor = maxf(1.0, boss.max_hp * yield_at * 0.5)
			boss.undying = false
		var list := [boss] + _spawn_wave(st.get("adds", []))
		for a in st.get("allies", []):
			_ally(a)
		if st.has("intro"):
			await _intro(st.intro)
		if is_instance_valid(boss):
			boss.notice(w.player)
		var scenes: Array = st.get("scenes", []).duplicate(true)
		var yielded := false
		while not failed and is_instance_valid(boss) and boss.state != Fighter.S.DEAD:
			await get_tree().create_timer(0.15, false).timeout
			if failed or not is_instance_valid(boss):
				break
			var ratio := boss.hp / maxf(boss.max_hp, 1.0)
			for sc in scenes:
				if not sc.get("done", false) and ratio <= float(sc.get("hp", 0.5)):
					sc["done"] = true
					var cs := Cutscene.new(w, sc.steps, stage, actors)
					var rs := await cs.play()
					for k in rs:
						result[k] = rs[k]
			objective_sub = "%s  %d %%" % [boss.display_name, int(ceil(ratio * 100.0))]
			w._refresh_hud()
			if yield_at > 0.0 and ratio <= yield_at + 0.0001:
				yielded = true
				await _yield_boss(String(st.get("yield_text", "Gibt auf")))
				break
		if not yielded:
			await _until_cleared(list, st)
	elif st.has("goto"):
		_set_objective(String(st.get("objective", "Geht zum Ziel")), "")
		marker = pos(st.goto)
		_show_beam(marker)
		var r := float(st.get("radius", 3.0))
		while not failed and is_instance_valid(w.level):
			var d := Vector2(w.player.global_position.x - marker.x, w.player.global_position.z - marker.z).length()
			objective_sub = "%d m" % int(d)
			if d <= r:
				break
			await get_tree().create_timer(0.2, false).timeout
		marker = Vector3.INF
		_hide_beam()
	elif st.has("ally"):
		_ally(st.ally)
	elif st.has("dismiss"):
		dismiss(String(st.dismiss))
	elif st.has("set"):
		for k in st.set:
			result[k] = st.set[k]
	elif st.has("heal"):
		heal()
	_set_objective("", "")


## Szene direkt nach dem Erscheinen der Gegner (alle stehen still, bis sie endet).
func _intro(steps: Array) -> void:
	await get_tree().process_frame
	var ci := Cutscene.new(w, steps, stage, actors)
	var ri := await ci.play()
	for k in ri:
		result[k] = ri[k]


## Bewohner ausblenden (Kampf im Dorf) oder wieder hervorkommen lassen (nach der Schlacht).
func show_folk(on: bool) -> void:
	if not on:
		for t in w.level.find_children("*", "Townsfolk", true, false):
			if t.visible:
				t.visible = false
				t.process_mode = Node.PROCESS_MODE_DISABLED
				_folk.append(t)
	else:
		for t in _folk:
			if is_instance_valid(t):
				t.visible = true
				t.process_mode = Node.PROCESS_MODE_INHERIT
		_folk.clear()


func dismiss(ally_id: String) -> void:
	for a in allies.duplicate():
		if is_instance_valid(a) and a.type_id == ally_id:
			allies.erase(a)
			w.allies.erase(a)
			a.queue_free()


## Boss gibt auf: kniet nieder; Untote seines Gefolges zerfallen, Lebende ergeben sich ebenfalls.
func _yield_boss(text: String) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	boss.surrender(text)
	CombatFX.slowmo(0.3, 0.6)
	for e in w.enemies.duplicate():
		if not is_instance_valid(e) or e == boss or e.state == Fighter.S.DEAD:
			continue
		if e.fx_material in ["bone", "undead_lord", "dark_armor"] or e.data.get("bound", false):
			e.undying = false
			e.die()
		else:
			e.surrender("Ergibt sich")
	for a in allies:
		if is_instance_valid(a):
			a.target = null
			a._disengage()
	await get_tree().create_timer(1.2, false).timeout


## Szenen-Aufrufe: {"call": "kill_boss"} · {"call": "remove_boss"} · {"call": "kill", "args": {"id": gegner}}
func kill_boss(_args: Dictionary = {}) -> void:
	if boss and is_instance_valid(boss) and boss.state != Fighter.S.DEAD:
		boss.yielded = false
		boss.invulnerable = false
		boss.hp_floor = 0.0
		boss.undying = false
		boss.die()


## Boss verschwindet (gefangen, durch ein Gate fortgebracht).
func remove_boss(_args: Dictionary = {}) -> void:
	if boss and is_instance_valid(boss):
		_vanish(boss)
		boss = null


func kill(args: Dictionary) -> void:
	var ids: Array = args.get("ids", [args.get("id", "")])
	for e in w.enemies.duplicate():
		if is_instance_valid(e) and e.type_id in ids and e.state != Fighter.S.DEAD:
			e.yielded = false
			e.invulnerable = false
			e.hp_floor = 0.0
			e.undying = false
			e.die()


func heal(_args: Dictionary = {}) -> void:
	w.player.hp = w.player.max_hp
	w.player.mana = w.player.max_mana
	w.player.stamina = w.player.max_stamina


func _vanish(e: Enemy3D) -> void:
	w.enemies.erase(e)
	e.remove_from_group("enemies")
	CombatFX.burst(w.level, "wisps", e.global_position + Vector3.UP * 0.8, Color(0.08, 0.0, 0.12), Vector3.UP, 1.6, Color(0.6, 0.25, 1.0, 0.8))
	var tw := e.create_tween()
	tw.tween_property(e, "scale", Vector3(0.05, 1.3, 0.05), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(e.queue_free)


func _spawn_wave(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var n := int(e[1]) if e.size() > 1 else 1
		var at: Array = e[2] if e.size() > 2 else [0, -12]
		for i in n:
			var jitter := Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)) if n > 1 else Vector2.ZERO
			var en: Enemy3D = w.spawn_enemy(String(e[0]), pos([float(at[0]) + jitter.x, float(at[1]) + jitter.y]) + Vector3.UP * 0.2)
			en.aggro = 60.0
			en.home = en.global_position
			_face_to(en, stage.origin)
			out.append(en)
	return out


func _ally(a: Array) -> Enemy3D:
	var al: Enemy3D = w.spawn_ally(String(a[0]), pos(a[1] if a.size() > 1 else [2, 2]) + Vector3.UP * 0.2)
	allies.append(al)
	_face_to(al, al.global_position + stage.basis * Vector3.FORWARD)
	return al


## Blick sofort setzen (auch während einer Szene, in der die Kämpfer ruhen).
func _face_to(f: Enemy3D, to: Vector3) -> void:
	var d := to - f.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	f.facing = d.normalized()
	if f.rig:
		f.rig.rotation.y = atan2(f.facing.x, f.facing.z)


## Warten, bis alle Gegner der Welle (samt Beschwörungen) fallen.
func _until_cleared(list: Array, st: Dictionary) -> void:
	while not failed and is_instance_valid(w.level):
		var alive := 0
		for e in w.enemies:
			if is_instance_valid(e) and e.state != Fighter.S.DEAD:
				alive += 1
		objective_sub = ("noch %d" % alive) if alive > 0 and objective_sub.find("%") < 0 else objective_sub
		w._refresh_hud()
		if alive == 0:
			break
		await get_tree().create_timer(0.25, false).timeout
	await get_tree().create_timer(0.8, false).timeout


func _set_objective(text: String, sub: String) -> void:
	if text != "" and text != objective:
		CombatFX.sound("lock_on", w.player.global_position + Vector3.UP, 0.8, 0.0)
		w.toast("◆ " + text, Palette.GOLD_BRIGHT)
	objective = text
	objective_sub = sub
	w._refresh_hud()


func _show_beam(at: Vector3) -> void:
	_hide_beam()
	_beam = Node3D.new()
	w.level.add_child(_beam)
	_beam.global_position = at
	var m := SpellFX._mesh(_beam, SpellFX._cylinder(), SpellFX._beam_mat(), Vector3(0, 12.0, 0), Vector3(0.6, 24.0, 0.6))
	m.position = Vector3(0, 12.0, 0)
	m.set_instance_shader_parameter("tint", Palette.GOLD_BRIGHT)
	m.set_instance_shader_parameter("energy", 2.0)
	m.set_instance_shader_parameter("scroll", 0.6)
	GroundMark.rune(w.level, at, 1.6, Palette.GOLD_BRIGHT, 3600.0, "a", null, 0.4)


func _hide_beam() -> void:
	if _beam and is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null


func _on_spell(sid: String) -> void:
	_used_spells[sid] = true


## Hilfsaufruf aus Szenen: {"call": "used_spell", "args": {"id": "fallen_down", "key": "c", "yes": "c0", "no": "c1"}}
func used_spell(args: Dictionary) -> void:
	result[String(args.get("key", "c"))] = args.get("yes") if _used_spells.has(String(args.get("id", ""))) else args.get("no")


func abort() -> void:
	if failed:
		return
	failed = true
	_cleanup()
	ended.emit(false)
	queue_free()


func _cleanup() -> void:
	_hide_beam()
	# Wer sich ergeben hat, wird fortgebracht (Nazaricks Kerker)
	for e in w.enemies.duplicate():
		if is_instance_valid(e) and e.yielded:
			_vanish(e)
	boss = null
	for a in allies:
		if is_instance_valid(a):
			w.allies.erase(a)
			a.queue_free()
	allies.clear()
	for f in temp_fx:
		StoryFX.extinguish(f)
	temp_fx.clear()
	# Szenenfiguren gehen, die Figuren des Ortes kehren zurück
	for k in actors:
		var a = actors[k]
		if is_instance_valid(a) and a.has_meta("story_spawned"):
			w.actors.erase(a)
			a.queue_free()
	actors.clear()
	for a in _hidden:
		if is_instance_valid(a):
			a.visible = true
			a.process_mode = Node.PROCESS_MODE_INHERIT
			w.actors.append(a)
	_hidden.clear()
	if is_instance_valid(w.level):
		show_folk(true)
	if is_instance_valid(w.player):
		w.player.visible = true
		if _start_style != "" and String(w.player.style) != _start_style:
			w.player.set_style(_start_style, true)
	if w.player.spell_cast.is_connected(_on_spell):
		w.player.spell_cast.disconnect(_on_spell)
	w.story = null
	w.suppress_encounters = false
	_set_objective("", "")


func _finish(ok: bool) -> void:
	await w._fade(1.0, 0.8)
	_cleanup()
	if replay:
		if return_loc != "":
			await w.load_location(return_loc, false)
		await w._fade(0.0, 0.9)
		w.toast("Die Erinnerung verblasst …", Palette.VIOLET_GLOW)
		ended.emit(ok)
		queue_free()
		return
	if is_instance_valid(w.level):
		w.player.global_position = pos(def.get("end_at", [0, 4])) + Vector3.UP * 0.1
		w.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	await w._fade(0.0, 0.9)
	var key := String(result.get(String(def.get("result_key", "c")), def.get("plays", ["c0"])[0]))
	Game.set_flag("story_" + id)
	ended.emit(ok)
	w.story_finished(self, key)
	queue_free()

class_name Cutscene
extends Node
## Filmszene in der 3D-Welt: Kamerafahrten, Figuren (stellen, gehen, knien, zaubern), Untertitel mit Porträt,
## Ainz' Gedanken, Effekte, Klänge, Entscheidungen. Schritte als Liste von Wörterbüchern (data/story_missions.json):
##
##   {"cam": {"at": P, "look": Z, "dur": s, "fov": f, "wait": false}}      Kamerafahrt (dur 0 = Schnitt)
##   {"cam": {"orbit": Z, "radius": r, "height": h, "from": °, "to": °, "dur": s}}
##   {"say": [wer, text]}  ·  {"think": text}                                Untertitel / Gedanken
##   {"actor": {"id": cid, "at": P, "face": Z, "pose": "kneel|bow|stand|battle|cast", "variant": ""}}
##   {"move": {"id": cid, "to": P, "dur": s, "run": false, "wait": true}}   gehen
##   {"pose": {"id": cid, "pose": …}} · {"anim": {"id": cid|"player", "play": key}} · {"remove": cid}
##   {"player": {"at": P, "face": Z, "visible": true, "style": "momon"}}
##   {"fx": {"kind": …, "at": P, …}}   gate · summon · explosion · holy · lightning · negative · ring · flash · shake · smoke · fire · circle
##                                      blaze (Großbrand) · dome (Schutzkuppel) · teleport · heal · beam · blood · heart
##   {"mood": "dusk" | "night" | "fog_night"}   Tageszeit/Himmel wechseln (am besten bei schwarzem Bild)
## Figuren: "pose" auch "fall" / "fall_back" (stürzt zu Boden); "rise": true lässt sie aus dem Boden steigen.
## Kamera relativ zu Figuren (Szenen mitten im Kampf): "ots": [A, B] über die Schulter von A auf B ·
##   "near": [Ziel, von] nah am Ziel, schräg ("angle") · "two": [A, B] beide im Bild – mit "back"/"dist", "side", "h", "look_h".
## {"ally": [id, P]} / {"dismiss": id} Verbündete tauschen · {"spawn": {"id", "at" | "near", "count"}} Gegner rufen
## {"if_alive": {"ref": "enemy:…", "then": [...], "else": [...]}} · {"player": {"near": ref, "dist": m}}
##   {"sound": name | {"name", "at", "vol"}} · {"music": name} · {"wait": s} · {"fade": 1|0} · {"title": [titel, unterzeile]}
##   {"choice": {"prompt": text, "key": k, "options": [{"text", "value", "variant"}]}}
##   {"if": {"key": k, "is": v, "then": [...], "else": [...]}} · {"flag": name} · {"effects": {...}}
##
## Positionen P/Z: [x, z] oder [x, y, z] auf der Bühne (Meter; −z = vorn in Blickrichtung des Ortes, y über Grund),
## "actor:<id>" (Kopfhöhe der Figur), "player", "enemy:<id>", "ally:<id>".
##   {"sfx": name}  Oberflächenklang (Gong, Erfolg …) ohne Raumposition

signal finished(result: Dictionary)

const RIG_Y := 0.13                    ## Grundhöhe der Figur im Actor3D (siehe Actor3D._make_standee)

var w: Node
var steps: Array = []
var stage := Transform3D.IDENTITY
var actors: Dictionary = {}           ## von der Szene gestellte Figuren (bleiben für folgende Szenen erhalten)
var result: Dictionary = {}
var cam := Camera3D.new()
var ui: CinematicUI
var _skip := false
var _shake := 0.0
var _shake_t := 0.0
var _noise := FastNoiseLite.new()
var _cam_tween: Tween
var _moves: Dictionary = {}            ## Figur → laufender Weg (wird beim Neustellen abgebrochen)
var _fill: OmniLight3D                 ## weiches Aufhelllicht an der Kamera (Gesichter in Nachtszenen)


func _init(world: Node, scene_steps: Array, stage_xf: Transform3D, shared_actors: Dictionary = {}) -> void:
	w = world
	steps = scene_steps
	stage = stage_xf
	actors = shared_actors
	name = "Cutscene"
	_noise.frequency = 0.8


## Szene abspielen (await). Liefert die Ergebnisse der Entscheidungen.
func play() -> Dictionary:
	w.add_child(self)
	ui = w.cinematic_ui()
	ui.visible = true
	w.cinematic = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cam.fov = 55.0
	cam.far = 4000.0
	w.level.add_child(cam)
	var pc: Camera3D = w.player.camera
	cam.global_transform = pc.global_transform
	cam.fov = pc.fov
	cam.current = true
	# Aufhelllicht wie beim Film: folgt der Kamera, ohne Schatten; nachts kühl und kräftiger
	var night: bool = w.story != null and String(w.story.def.get("mood", "")).contains("night")
	_fill = OmniLight3D.new()
	_fill.omni_range = 14.0
	_fill.omni_attenuation = 1.4
	_fill.light_energy = float(w.story.def.get("cine_fill", 1.1 if night else 0.45)) if w.story else 0.45
	_fill.light_color = Color(0.78, 0.86, 1.0) if night else Color(1.0, 0.95, 0.88)
	_fill.light_specular = 0.15
	_fill.shadow_enabled = false
	_fill.position = Vector3(0.6, 0.4, 0.0)
	cam.add_child(_fill)
	if not ui.skip_requested.is_connected(_on_skip):
		ui.skip_requested.connect(_on_skip)
	ui.bars(true, 0.7)
	await _run(steps)
	ui.hide_box()
	await ui.bars(false, 0.6)
	ui.visible = false
	if is_instance_valid(pc):
		pc.current = true
	cam.queue_free()
	w.cinematic = false
	queue_free()
	finished.emit(result)
	return result


func _on_skip() -> void:
	_skip = true


func _process(delta: float) -> void:
	if _shake > 0.0 and is_instance_valid(cam):
		_shake = maxf(0.0, _shake - delta * 1.5)
		_shake_t += delta
		var s := _shake * _shake
		cam.h_offset = _noise.get_noise_2d(_shake_t * 30.0, 1.0) * 0.12 * s
		cam.v_offset = _noise.get_noise_2d(_shake_t * 30.0, 40.0) * 0.1 * s
	elif is_instance_valid(cam):
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# =====================================================================
#  Ablauf
# =====================================================================

func _run(list: Array) -> void:
	for st in list:
		if not is_instance_valid(w) or not is_instance_valid(w.level):
			return
		await _step(st)


func _step(st: Dictionary) -> void:
	if st.has("cam"):
		_camera(st.cam)
		if st.cam.get("wait", false) and not _skip and _cam_tween and _cam_tween.is_running():
			await _cam_tween.finished
	elif st.has("say"):
		var s: Variant = st.say
		if _skip:
			return
		var who := String(s[0])
		_face_speaker(who)
		var sa := _get_actor(who)
		await ui.say(String(sa.get_meta("figure", who)) if sa else who, String(s[1]))
	elif st.has("think"):
		if _skip:
			return
		await ui.say("ainz_momon" if String(w.player.style) == "momon" else "ainz", String(st.think), true)
	elif st.has("actor"):
		_actor(st.actor)
	elif st.has("move"):
		await _move(st.move)
	elif st.has("pose"):
		var a := _get_actor(String(st.pose.id))
		if a:
			_set_pose(a, String(st.pose.pose))
	elif st.has("anim"):
		_anim(st.anim)
	elif st.has("remove"):
		var a := _get_actor(String(st.remove))
		if _moves.has(String(st.remove)):
			var mv: Tween = _moves[String(st.remove)]
			if mv and mv.is_valid():
				mv.kill()
			_moves.erase(String(st.remove))
		if a:
			actors.erase(String(st.remove))
			w.actors.erase(a)
			a.queue_free()
	elif st.has("player"):
		_player(st.player)
	elif st.has("fx"):
		_fx(st.fx)
	elif st.has("sound"):
		if _skip:
			return
		var sd: Variant = st.sound
		if sd is String:
			CombatFX.sound(sd, cam.global_position + (-cam.global_basis.z) * 3.0, 1.0, 0.0)
		else:
			CombatFX.sound(String(sd.name), _pos(sd.get("at", "camera")), float(sd.get("vol", 1.0)), 0.0)
	elif st.has("music"):
		Audio.play_music(String(st.music))
	elif st.has("sfx"):
		if not _skip:
			Audio.sfx(String(st.sfx), float(st.get("vol", 0.8)))
	elif st.has("wait"):
		if not _skip:
			await get_tree().create_timer(float(st.wait)).timeout
	elif st.has("fade"):
		await w._fade(float(st.fade), 0.0 if _skip else float(st.get("dur", 0.6)))
	elif st.has("title"):
		if not _skip:
			ui.title_card(String(st.title[0]), String(st.title[1]) if st.title.size() > 1 else "", float(st.get("dur", 2.6)))
	elif st.has("choice"):
		_skip = false
		ui.hide_box()
		var c: Dictionary = st.choice
		var opts: Array = _check_options(c)
		var i := await ui.choose(String(c.get("prompt", "")), opts)
		var o: Dictionary = opts[i]
		result[String(c.get("key", "choice"))] = o.get("value", i)
		if o.has("effects"):
			Game.apply_effects(o.effects)
		if o.has("then"):
			await _run(o.then)
	elif st.has("if"):
		var c: Dictionary = st["if"]
		var v: Variant = result.get(String(c.key), w.story.result.get(String(c.key)) if w.story else null)
		var ok := str(v) == str(c.get("is", ""))
		await _run(c.get("then", []) if ok else c.get("else", []))
	elif st.has("mood"):
		StoryFX.mood(w.level, String(st.mood))
	elif st.has("spawn"):
		# Gegner erscheinen lassen (Beschwörung in einer Zwischenszene): {"spawn": {"id", "at" | "near", "count"}}
		var sp: Dictionary = st.spawn
		var at: Variant = sp.get("at", [0, -10])
		if sp.has("near"):
			var lp := stage.affine_inverse() * _pos(sp.near, false)
			at = [lp.x + randf_range(-2.2, 2.2), lp.z + randf_range(-2.2, 2.2)]
		if w.story:
			for e in w.story._spawn_wave([[String(sp.id), int(sp.get("count", 1)), at]]):
				e.notice(w.player)
	elif st.has("ally"):
		if w.story:
			w.story._ally(st.ally)
	elif st.has("dismiss"):
		if w.story:
			w.story.dismiss(String(st.dismiss))
	elif st.has("folk"):
		if w.story:
			w.story.show_folk(bool(st.folk))
	elif st.has("if_alive"):
		var ia: Dictionary = st.if_alive
		await _run(ia.get("then", []) if _ref_ok(ia.get("ref", "")) else ia.get("else", []))
	elif st.has("flag"):
		Game.set_flag(String(st.flag))
	elif st.has("effects"):
		Game.apply_effects(st.effects)
	elif st.has("call"):
		if w.story and w.story.has_method(String(st.call)):
			await w.story.call(String(st.call), st.get("args", {}))


## Antworten, die eine Antwort der Depesche wählen ("value" = c0, c1 …), sind gesperrt, wenn deren Bedingung
## (z. B. 150 Gold) nicht erfüllt ist – wie im Depeschenfenster.
func _check_options(c: Dictionary) -> Array:
	var opts: Array = (c.options as Array).duplicate(true)
	var m = w.story
	if m == null or String(c.get("key", "")) != String(m.def.get("result_key", "c")):
		return opts
	var d: Dictionary = Game.get_dispatch(m.dispatch_uid)
	if d.is_empty():
		return opts
	var ev: Dictionary = Content.events.get(String(m.def.get("event", "")), {})
	for o in opts:
		var v := String(o.get("value", ""))
		if not v.begins_with("c"):
			continue
		var found := false
		for dop in d.options:
			if String(dop.key) == v:
				found = true
		if not found:
			o["disabled"] = true
			var idx := int(v.substr(1))
			var req: Dictionary = (ev.get("choices", [])[idx] if idx < ev.get("choices", []).size() else {}).get("requires", {})
			var parts := PackedStringArray()
			for k in req.get("res_min", {}):
				parts.append("%d %s" % [int(req.res_min[k]), Game.RESOURCE_LABELS.get(k, k)])
			o["hint"] = ("benötigt " + ", ".join(parts)) if not parts.is_empty() else "nicht möglich"
	return opts


# =====================================================================
#  Positionen
# =====================================================================

## Bühnenkoordinaten → Welt (y über Grund). Auch relativ: {"ref": A, "away": B, "dist": m, "side": m}
## = von A aus "dist" Meter weiter weg von B (z. B. hinter einem Boss, von Ainz aus gesehen).
func _pos(p: Variant, head: bool = true) -> Vector3:
	if p is Dictionary:
		var r := _pos(p.get("ref", "player"), false)
		var aw := _pos(p.get("away", "player"), false)
		var d := r - aw
		d.y = 0.0
		d = d.normalized() if d.length() > 0.05 else stage.basis * Vector3.FORWARD
		var wp := r + d * float(p.get("dist", 3.0)) + d.cross(Vector3.UP) * float(p.get("side", 0.0))
		return Vector3(wp.x, _ground(wp) + float(p.get("h", 0.0)), wp.z)
	if p is String:
		var s: String = p
		if s == "player":
			return w.player.global_position + Vector3.UP * (w.player.body_height * 0.85 if head else 0.0)
		if s == "camera":
			return cam.global_position
		if s.begins_with("actor:"):
			var a := _get_actor(s.substr(6))
			if a:
				return a.global_position + Vector3.UP * (1.65 if head else 0.0)
		if s.begins_with("enemy:") or s.begins_with("ally:"):
			var list: Array = w.enemies if s.begins_with("enemy:") else w.allies
			var want := s.get_slice(":", 1)
			for e in list:
				if is_instance_valid(e) and e.type_id == want:
					return e.global_position + Vector3.UP * (e.body_height * 0.8 if head else 0.0)
		return stage.origin
	var arr: Array = p
	var local := Vector3(float(arr[0]), 0.0, float(arr[1])) if arr.size() == 2 else Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	var wp := stage * Vector3(local.x, 0.0, local.z)
	var g := _ground(wp)
	return Vector3(wp.x, g + local.y, wp.z)


## Einstellungen relativ zu Figuren: [Kameraposition, Blickpunkt] oder [] (keine solche Angabe).
func _shot(c: Dictionary) -> Array:
	for mode in ["ots", "near", "two"]:
		if not c.has(mode):
			continue
		var refs: Array = c[mode]
		var a := _pos(refs[0], false)
		var b := _pos(refs[1], false)
		var d := a - b
		d.y = 0.0
		d = d.normalized() if d.length() > 0.05 else stage.basis * Vector3.BACK
		var side := d.cross(Vector3.UP).normalized() * float(c.get("side", 0.7))
		match mode:
			"ots":
				# hinter A (von B abgewandt), leicht seitlich, Blick auf B – verdeckt? dann die andere Schulter / näher
				var lk := b + Vector3.UP * float(c.look_h) if c.has("look_h") else _pos(refs[1])
				var p := a + d * float(c.get("back", 2.2)) + side + Vector3.UP * float(c.get("h", 1.9))
				for alt in [p, a + d * float(c.get("back", 2.2)) - side + Vector3.UP * float(c.get("h", 1.9)),
						a + d * float(c.get("back", 2.2)) * 0.55 + side * 0.7 + Vector3.UP * float(c.get("h", 1.9))]:
					if _clear(alt, lk):
						return [alt, lk]
				return [_pull(p, lk), lk]
			"near":
				# nah an A (dem Ziel), schräg von der Seite von B aus ("angle", Grad) – B steht so nicht im Bild.
				# Steht ein Baum oder eine Mauer im Weg, wird ein freier Winkel gesucht.
				var lk := a + Vector3.UP * float(c.look_h) if c.has("look_h") else _pos(refs[0])
				var base := float(c.get("angle", 45.0))
				var first := Vector3.ZERO
				for off in [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0]:
					var dir := (-d).rotated(Vector3.UP, deg_to_rad(base + off))
					var p := a + dir * float(c.get("dist", 2.0)) + Vector3.UP * float(c.get("h", 1.5))
					if off == 0.0:
						first = p
					if _clear(p, lk):
						return [p, lk]
				return [_pull(first, lk), lk]
			"two":
				var mid := (a + b) * 0.5
				var lk := mid + Vector3.UP * float(c.get("look_h", 1.3))
				var sg := signf(float(c.get("side", 1.0)))
				for s in [sg, -sg]:
					var p: Vector3 = mid + side.normalized() * float(c.get("dist", 4.0)) * float(s) + Vector3.UP * float(c.get("h", 1.6))
					if _clear(p, lk):
						return [p, lk]
				return [_pull(mid + side.normalized() * float(c.get("dist", 4.0)) * sg + Vector3.UP * float(c.get("h", 1.6)), lk), lk]
	return []


## Freie Sicht vom Blickpunkt zur Kamera (Gelände, Häuser, Stämme – keine Figuren)?
func _clear(p: Vector3, lk: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(lk, p, 1)).is_empty()


## Kamera vor das Hindernis ziehen (wie ein Federarm).
func _pull(p: Vector3, lk: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(lk, p, 1))
	if hit.is_empty():
		return p
	var hp: Vector3 = hit.position
	return hp + (lk - hp).normalized() * 0.35


## Gibt es das Ziel einer Positionsangabe ("enemy:…", "ally:…", "actor:…") noch?
func _ref_ok(p: Variant) -> bool:
	if not (p is String):
		return true
	var s: String = p
	if s.begins_with("actor:"):
		return _get_actor(s.substr(6)) != null
	if s.begins_with("enemy:") or s.begins_with("ally:"):
		var list: Array = w.enemies if s.begins_with("enemy:") else w.allies
		for e in list:
			if is_instance_valid(e) and e.type_id == s.get_slice(":", 1) and e.state != Fighter.S.DEAD:
				return true
		return false
	return true


func _ground(wp: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = w.level.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(wp.x, stage.origin.y + 30.0, wp.z), Vector3(wp.x, stage.origin.y - 40.0, wp.z), 1)
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else stage.origin.y


# =====================================================================
#  Kamera
# =====================================================================

func _camera(c: Dictionary) -> void:
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()
	var dur := 0.0 if _skip else float(c.get("dur", 0.0))
	if c.has("fov"):
		var f := float(c.fov)
		if dur <= 0.0:
			cam.fov = f
		else:
			create_tween().tween_property(cam, "fov", f, dur).set_trans(Tween.TRANS_SINE)
	if c.has("shake"):
		_shake = maxf(_shake, float(c.shake))
	if c.has("orbit"):
		var center := _pos(c.orbit, false) + Vector3.UP * float(c.get("look_h", 1.4))
		var r := float(c.get("radius", 6.0))
		var h := float(c.get("height", 2.0))
		var base := stage.basis
		var a0 := deg_to_rad(float(c.get("from", 0.0)))
		var a1 := deg_to_rad(float(c.get("to", 30.0)))
		var place := func(k: float):
			var a := lerpf(a0, a1, k)
			var off := base * Vector3(sin(a) * r, 0.0, cos(a) * r)
			cam.global_position = center + off + Vector3.UP * h
			cam.look_at(center, Vector3.UP)
		if dur <= 0.0:
			place.call(1.0)
			return
		place.call(0.0)
		_cam_tween = create_tween()
		_cam_tween.tween_method(place, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	var to_pos := _pos(c.at, false) if c.has("at") else cam.global_position
	var look := _pos(c.look) if c.has("look") else to_pos - cam.global_basis.z
	var shot := _shot(c)
	if not shot.is_empty():
		to_pos = shot[0]
		look = shot[1]
		c = c.duplicate()
		c.erase("look")
	if dur <= 0.0:
		cam.global_position = to_pos
		if to_pos.distance_to(look) > 0.01:
			cam.look_at(look, Vector3.UP)
		return
	var from_pos := cam.global_position
	var from_look := cam.global_position - cam.global_basis.z * maxf(2.0, from_pos.distance_to(look))
	var look_node: Variant = c.get("look", null)
	_cam_tween = create_tween()
	_cam_tween.tween_method(func(k: float):
		cam.global_position = from_pos.lerp(to_pos, k)
		var lk: Vector3 = _pos(look_node) if look_node is String else look
		var l := from_look.lerp(lk, k)
		if cam.global_position.distance_to(l) > 0.01:
			cam.look_at(l, Vector3.UP), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# =====================================================================
#  Figuren
# =====================================================================

func _get_actor(id: String) -> Actor3D:
	if actors.has(id) and is_instance_valid(actors[id]):
		return actors[id]
	for a in w.actors:
		if is_instance_valid(a) and a.id == id and a.kind != "object":
			actors[id] = a
			return a
	return null


func _actor(d: Dictionary) -> void:
	var id := String(d.id)
	var a := _get_actor(id)
	if a == null:
		a = Actor3D.character(String(d.get("figure", id)), String(d.get("variant", "")), float(d.get("label_h", 2.3)))
		a.id = id
		if d.has("name"):
			a.label = String(d.name)
		a.prompt = "Sprechen"
		a.set_meta("story_spawned", true)
		a.set_meta("figure", String(d.get("figure", id)))
		w.level.add_child(a)
		w.actors.append(a)
		actors[id] = a
	a.scripted = true
	a.wander_radius = 0.0
	a.process_mode = Node.PROCESS_MODE_INHERIT
	if d.has("at") and _moves.has(id):
		var old: Tween = _moves[id]
		if old and old.is_valid():
			old.kill()
		_moves.erase(id)
	if d.has("at"):
		a.global_position = _pos(d.at, false)
		a.home = a.global_position
	if d.has("face"):
		_face(a, _pos(d.face, false))
	if d.has("scale") and a.rig:
		a.rig.scale = Vector3.ONE * float(d.scale)
	_set_pose(a, String(d.get("pose", "stand")))
	a.visible = bool(d.get("visible", true))
	if d.get("rise", false) and a.rig and not _skip:
		a.rig.position.y = RIG_Y - 2.4
		var tw := a.rig.create_tween()
		tw.tween_property(a.rig, "position:y", RIG_Y, float(d.get("rise_dur", 1.6))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _face(a: Node3D, target: Vector3) -> void:
	var to := target - a.global_position
	to.y = 0.0
	if to.length() > 0.05:
		a.rotation.y = atan2(to.x, to.z)


## Sprecher dreht sich leicht zur Kamera (wirkt lebendiger).
func _face_speaker(id: String) -> void:
	var a := _get_actor(id)
	if a and a.rig:
		a.rig.flash(Color(1, 1, 1), 0.25, 0.08)


func _set_pose(a: Actor3D, pose: String) -> void:
	if a.rig == null:
		return
	a.scripted_pose = pose
	if not pose.begins_with("fall") and a.rig.rotation.x != 0.0:
		a.rig.rotation.x = 0.0
		a.rig.position.y = RIG_Y
	a.rig.set_kneel(1.0 if pose == "kneel" else 0.0)
	match pose:
		"kneel":
			a.rig.set_bend(0.32, 0.0)
		"bow":
			a.rig.set_bend(0.45, 0.0)
		"fall", "fall_back":
			# zu Boden stürzen (Herzgriff, Schwerthieb): ganze Figur kippt um die Füße
			a.rig.set_bend(0.0, 0.0)
			var to := 1.45 if pose == "fall" else -1.45
			if _skip:
				a.rig.rotation.x = to
			else:
				var tw := a.rig.create_tween()
				tw.tween_property(a.rig, "rotation:x", to * 0.25, 0.25).set_trans(Tween.TRANS_SINE)
				tw.tween_property(a.rig, "rotation:x", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(a.rig, "position:y", RIG_Y + 0.1, 0.4)
				tw.tween_callback(func(): CombatFX.burst(w.level, "dust_puff", a.global_position + Vector3.UP * 0.2, Color(0.55, 0.5, 0.44), Vector3.UP, 0.8))
		_:
			a.rig.set_bend(0.0, 0.0)


func _move(d: Dictionary) -> void:
	var a := _get_actor(String(d.id))
	if a == null:
		return
	var to := _pos(d.to, false)
	if _skip:
		a.global_position = to
		return
	var from := a.global_position
	var dur := float(d.get("dur", from.distance_to(to) / (3.2 if d.get("run", false) else 1.4)))
	_face(a, to)
	a.scripted_pose = "run" if d.get("run", false) else "walk"
	var mid := String(d.id)
	if _moves.has(mid):
		var old: Tween = _moves[mid]
		if old and old.is_valid():
			old.kill()
	var tw := create_tween()
	_moves[mid] = tw
	tw.tween_method(func(k: float):
		if not is_instance_valid(a):
			return
		var p := from.lerp(to, k)
		p.y = _ground(p)
		a.global_position = p, 0.0, 1.0, maxf(dur, 0.05))
	tw.tween_callback(func():
		if not is_instance_valid(a):
			return
		a.scripted_pose = "stand"
		if d.has("face"):
			_face(a, _pos(d.face, false)))
	if d.get("wait", true):
		await tw.finished


func _anim(d: Dictionary) -> void:
	var id := String(d.id)
	var key := String(d.get("play", "cast"))
	if id == "player":
		if w.player.rig:
			w.player.rig.play(key, float(d.get("speed", 1.0)), true)
		return
	var a := _get_actor(id)
	if a and a.rig:
		a.scripted_pose = "anim:" + key


func _player(d: Dictionary) -> void:
	var p: Player3D = w.player
	if d.has("style") and p.style != String(d.style):
		p.set_style(String(d.style), true)
	if d.has("near"):
		# neben ein Ziel treten (Abstand "dist"), Blick zum Ziel
		var t := _pos(d.near, false)
		var dir := p.global_position - t
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.05 else stage.basis * Vector3.BACK
		p.global_position = t + dir * float(d.get("dist", 1.3)) + Vector3.UP * 0.05
		p.velocity = Vector3.ZERO
		d = d.duplicate()
		d["face"] = d.near
	if d.has("at"):
		p.global_position = _pos(d.at, false) + Vector3.UP * 0.05
		p.velocity = Vector3.ZERO
	if d.has("face"):
		var to := _pos(d.face, false) - p.global_position
		to.y = 0.0
		if to.length() > 0.05:
			p.facing = to.normalized()
			p.cam_yaw = atan2(-to.x, -to.z)
	if d.has("visible"):
		p.visible = bool(d.visible)


# =====================================================================
#  Effekte
# =====================================================================

func _fx(d: Dictionary) -> void:
	if _skip:
		return
	var lvl: Node = w.level
	var at := _pos(d.get("at", "player"), false)
	var col := Color(d.get("color", "#b070ff"))
	match String(d.kind):
		"gate":
			StoryFX.gate(lvl, at + Vector3.UP * float(d.get("h", 1.6)), float(d.get("dur", 4.0)), stage.basis * Vector3(0, 0, 1) if not d.has("face") else (_pos(d.face, false) - at).normalized())
		"summon":
			StoryFX.summon_undead(lvl, at, col)
		"explosion":
			SpellFX.explosion(lvl, at + Vector3.UP * 0.8, float(d.get("radius", 2.0)), String(d.get("el", "fire")), col)
			CombatFX.sound("fire_explode", at, 1.0)
		"holy":
			SpellFX.pillar(lvl, at, float(d.get("radius", 1.5)), 26.0, Color(d.get("color", "#fff0b0")), float(d.get("hold", 0.6)), 6.0)
			CombatFX.sound("holy_impact", at, 1.0)
		"lightning":
			if not _ref_ok(d.get("from", "player")) or not _ref_ok(d.get("to", "player")):
				return
			var b0 := _pos(d.get("from", "player"))
			var b1 := _pos(d.get("to", "player"))
			for i in int(d.get("bolts", 1)):
				SpellFX.bolt(lvl, b0, b1 + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * float(i > 0), Color(d.get("color", "#8fc8ff")), 0.3, 0.4 + i * 0.08)
			CombatFX.burst(lvl, "sparks", b1, Color(d.get("color", "#8fc8ff")), Vector3.UP, 1.5)
			CombatFX.flash(lvl, b1, Color(d.get("color", "#8fc8ff")), 5.0, 8.0, 0.3)
			CombatFX.sound("lightning", b1, 1.0)
		"blackhole":
			StoryFX.black_hole(lvl, at + Vector3.UP * float(d.get("h", 2.0)), float(d.get("radius", 3.0)))
			if d.has("swallow"):
				for sid in (d.swallow if d.swallow is Array else [d.swallow]):
					var victim := _get_actor(String(sid))
					if victim:
						var tw := victim.create_tween()
						tw.tween_interval(0.35)
						tw.tween_property(victim, "global_position", at + Vector3.UP * float(d.get("h", 2.0)), 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
						tw.parallel().tween_property(victim, "scale", Vector3.ONE * 0.02, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
						tw.tween_callback(func():
							actors.erase(String(sid))
							w.actors.erase(victim)
							victim.queue_free())
		"negative":
			StoryFX.negative_burst(lvl, at, float(d.get("radius", 14.0)))
		"ring":
			GroundMark.ring(lvl, at, float(d.get("radius", 4.0)), col, float(d.get("dur", 0.6)))
		"circle":
			GroundMark.rune(lvl, at, float(d.get("radius", 2.0)), col, float(d.get("dur", 3.0)), String(d.get("design", "a")), null, float(d.get("spin", 0.6)))
		"flash":
			SpellFX.screen_flash(Color(d.get("color", "#ffffff"), float(d.get("alpha", 0.8))), float(d.get("dur", 0.6)))
		"shake":
			_shake = maxf(_shake, float(d.get("amount", 0.5)))
		"smoke":
			CombatFX.burst(lvl, "smoke", at + Vector3.UP * 0.5, Color(d.get("color", "#2a2624")), Vector3.UP, float(d.get("amount", 2.0)))
		"fire":
			var e := CombatFX.emitter(lvl, "burning", Color(d.get("color", "#ff7a2a")))
			if e:
				e.global_position = at + Vector3.UP * 0.3
				e.amount = 60
				get_tree().create_timer(float(d.get("dur", 8.0)), false).timeout.connect(func(): CombatFX.stop(e))
		"blood":
			CombatFX.burst(lvl, "blood", at + Vector3.UP * 1.2, Color(0.4, 0.01, 0.02), Vector3.UP, 1.5)
			CombatFX.burst(lvl, "blood_mist", at + Vector3.UP * 1.2, Color(0.5, 0.02, 0.04), Vector3.UP, 1.5)
		"heart":
			StoryFX.heart_on(lvl, _pos(d.get("from", "player")), _pos(d.get("to", "player")), float(d.get("dur", 1.4)))
		"blaze":
			var b := StoryFX.blaze(lvl, at, float(d.get("dur", 0.0)), float(d.get("size", 1.0)))
			if b and w.story:
				w.story.temp_fx.append(b)
		"dome":
			StoryFX.dome(lvl, at, float(d.get("radius", 2.0)), Color(d.get("color", "#7dffb0")), float(d.get("dur", 6.0)))
		"teleport":
			StoryFX.teleport(lvl, at, Color(d.get("color", "#9f4dff")))
		"heal":
			StoryFX.heal(lvl, at, Color(d.get("color", "#ff4050")))
		"beam":
			SpellFX.beam(lvl, _pos(d.get("from", "player")), _pos(d.get("to", "player")), Color(d.get("color", "#fff0b0")), float(d.get("width", 0.3)), float(d.get("dur", 0.4)))
			CombatFX.sound(String(d.get("sound", "holy_impact")), at, 1.0)

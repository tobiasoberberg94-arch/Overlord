class_name Player3D
extends Fighter
## Ainz Ooal Gown in der dritten Person – mit Echtzeit-Kampf im Stil von The Witcher 3.
##
## Bewegung: WASD · Shift rennen · Maus Kamera (Klick fängt den Zeiger) · Mausrad Zoom
## Kampf:    Linke Maustaste leichte Attacke (Kombo) · Rechte Maustaste schwere Attacke
##           Leertaste Ausweichrolle (i-Frames) · F halten Blocken (früh = Parieren)
##           Q Ziel fixieren (Lock-on) · 1–4 / R Zauber bzw. Techniken · X Ainz ↔ Momon
## Zwei Kampfstile (data/combat.json → player.styles):
##   Ainz  – magiefokussiert: Stabhiebe + fünf Zauber (Mana)
##   Momon – Nahkampf mit zwei Großschwertern, Techniken kosten Ausdauer

signal feedback(text: String, color: Color)
signal style_changed(style: String)
signal spell_cast(id: String)

const ACCEL := 10.0
const GRAVITY := 18.0
const SPRINT_MULT := 1.75

var input_enabled := true
var cam_yaw := 0.0
var cam_pitch := -0.38
var cam_distance := 6.5
var camera := Camera3D.new()
var style := "ainz"
var style_data: Dictionary = {}
var lock: Fighter                       ## fixiertes Ziel
var cooldowns: Dictionary = {}          ## Zauber-ID → verbleibende Sekunden
var casting: Dictionary = {}            ## Zauber in Vorbereitung
var cfg: Dictionary = {}
var _pivot := Node3D.new()
var _arm := SpringArm3D.new()
var _combo := 0
var _combo_timer := 0.0
var _queued := ""                       ## gepufferte Eingabe (light/heavy)
var _dodge_dir := Vector3.ZERO
var _move_amount := 0.0
var _input_block := false
var _shield_fx: MeshInstance3D
var _lock_marker: Label3D


func _ready() -> void:
	cfg = Content.combat.player
	setup_combat(true)
	parry_window = float(cfg.parry_window)
	block_stamina_mult = float(cfg.block_stamina_mult)
	stamina_regen = float(cfg.stamina_regen)
	mana_regen = float(cfg.mana_regen)
	max_poise = float(cfg.poise)
	poise = max_poise
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	_pivot.position = Vector3(0, 1.75, 0)
	_pivot.top_level = true
	add_child(_pivot)
	_arm.spring_length = cam_distance
	_arm.margin = 0.3
	_arm.collision_mask = 1
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	camera.position = Vector3(0.6, 0, 0)
	camera.fov = 68.0
	camera.far = 4000.0
	_arm.add_child(camera)
	camera.current = true
	var sm := SphereMesh.new()
	sm.radius = 1.2
	sm.height = 2.4
	_shield_fx = B3.mesh(self, sm, Vector3(0, 1.1, 0), B3.mat(Color(1, 0.85, 0.4, 0.18), 0.1, 0.0, Color(1, 0.8, 0.3), 0.8))
	_shield_fx.visible = false
	_lock_marker = Label3D.new()
	_lock_marker.text = "◆"
	_lock_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lock_marker.font_size = 64
	_lock_marker.modulate = Color(1, 0.3, 0.3)
	_lock_marker.outline_size = 8
	_lock_marker.no_depth_test = true
	_lock_marker.top_level = true
	_lock_marker.visible = false
	add_child(_lock_marker)
	_ensure_actions()
	var saved: String = Game.state.get("world3d", {}).get("style", "ainz")
	set_style(saved if saved in ["ainz", "momon"] else "ainz", true)


static func _ensure_actions() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "dodge": [KEY_SPACE], "interact": [KEY_E], "block": [KEY_F],
		"lock_on": [KEY_Q], "switch_style": [KEY_X],
		"spell_1": [KEY_1], "spell_2": [KEY_2], "spell_3": [KEY_3], "spell_4": [KEY_4], "spell_5": [KEY_R],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for spec in [["attack_light", MOUSE_BUTTON_LEFT], ["attack_heavy", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(spec[0]):
			InputMap.add_action(spec[0])
			var mb := InputEventMouseButton.new()
			mb.button_index = spec[1]
			InputMap.action_add_event(spec[0], mb)


# =====================================================================
#  Kampfstil
# =====================================================================

func set_style(s: String, silent: bool = false) -> void:
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	style = s
	style_data = cfg.styles[s]
	display_name = style_data.name
	max_hp = float(style_data.hp)
	hp = max_hp * ratio if not silent else max_hp
	max_stamina = float(style_data.stamina)
	stamina = minf(stamina, max_stamina) if not silent else max_stamina
	max_mana = float(style_data.mana)
	mana = minf(mana, max_mana) if not silent else max_mana
	armor = float(style_data.armor)
	move_speed = float(style_data.speed)
	if rig:
		rig.queue_free()
	var model_id: String = style_data.get("model", "ainz" if s == "ainz" else "ainz_momon")
	var fb: Callable
	if s == "ainz":
		fb = func(r): ProcModel.ainz(r)
	elif s == "momon":
		fb = func(r): ProcModel.momon(r)
	else:
		fb = func(r): ProcModel.figure(r, model_id)   # Wächter: Modell oder prozedurale Gestalt
	rig = CharacterRig.create(model_id, fb)
	add_child(rig)
	rig.rotation.y = atan2(facing.x, facing.z)
	if not Game.state.has("world3d"):
		Game.state["world3d"] = {}
	Game.state.world3d["style"] = s
	if not silent:
		rig.flash(Color(0.6, 0.3, 1.0), 0.5)
		feedback.emit(String(style_data.name), Palette.GOLD_BRIGHT)
	style_changed.emit(s)


func spells() -> Array:
	return style_data.get("spells", [])


func spell_ready(id: String) -> bool:
	var sp: Dictionary = Content.combat.spells[id]
	var pool := mana if sp.cost_type == "mana" else stamina
	return float(cooldowns.get(id, 0.0)) <= 0.0 and pool >= float(sp.cost)


# =====================================================================
#  Eingabe
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * 0.0035
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.003, -1.2, 0.5)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = maxf(2.5, cam_distance - 0.5)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = minf(11.0, cam_distance + 0.5)
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Erster Klick fängt nur den Zeiger
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("attack_light"):
		request("light")
	elif event.is_action_pressed("attack_heavy"):
		request("heavy")
	elif event.is_action_pressed("dodge"):
		request("dodge")
	elif event.is_action_pressed("lock_on"):
		toggle_lock()
	elif event.is_action_pressed("switch_style"):
		if can_act():
			if style.begins_with("g_"):
				feedback.emit("%s kämpft für Euch – erst nach dem Einsatz zurück" % style_data.name, Color(0.8, 0.8, 0.9))
			else:
				set_style("momon" if style == "ainz" else "ainz")
	else:
		for i in 5:
			if event.is_action_pressed("spell_%d" % (i + 1)):
				var sp := spells()
				if i < sp.size():
					cast(sp[i])


## Aktionen können auch aus Tests/KI ausgelöst werden.
func request(what: String) -> bool:
	if state == S.DEAD:
		return false
	match what:
		"light", "heavy":
			if state == S.ATTACK:
				_queued = what   # Eingabepuffer für Kombos
				return true
			if not can_act() and state != S.BLOCK:
				return false
			return _do_attack(what)
		"dodge":
			if (can_act() or state == S.BLOCK or (state == S.ATTACK and phase == "recovery")) and stamina >= float(cfg.dodge_stamina) * 0.5:
				_start_dodge()
				return true
	return false


func _do_attack(kind: String) -> bool:
	_aim_soft()
	var a: Dictionary
	if kind == "heavy":
		a = style_data.heavy.duplicate()
		a["kind"] = "heavy"
		_combo = 0
	else:
		var chain: Array = style_data.light
		if _combo_timer <= 0.0:
			_combo = 0
		a = chain[_combo % chain.size()].duplicate()
		a["kind"] = "light"
		_combo = (_combo + 1) % chain.size()
		_combo_timer = 1.1
	if not start_attack(a):
		feedback.emit("Zu erschöpft", Color(0.8, 0.8, 0.8))
		return false
	return true


func _start_dodge() -> void:
	use_stamina(float(cfg.dodge_stamina))
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	_dodge_dir = Basis(Vector3.UP, cam_yaw) * Vector3(iv.x, 0, iv.y)
	var stand := _dodge_dir.length() < 0.1
	if stand:
		_dodge_dir = -facing
	_dodge_dir = _dodge_dir.normalized()
	# Animation nach Richtung: frei → Rolle in Laufrichtung, im Stand → Sprung zurück,
	# mit fixiertem Ziel → vor/zurück/seitlich relativ zur Blickrichtung
	if rig:
		if stand:
			rig.dodge_key = "dodge_back"
		elif lock and is_instance_valid(lock):
			var fwd := facing.dot(_dodge_dir)
			var right := facing.cross(Vector3.UP).normalized().dot(_dodge_dir)
			if absf(fwd) >= absf(right):
				rig.dodge_key = "dodge_fwd" if fwd > 0.0 else "dodge_back"
			else:
				rig.dodge_key = "dodge_right" if right > 0.0 else "dodge_left"
		else:
			facing = _dodge_dir
			rig.dodge_key = "dodge_fwd"
	set_state(S.DODGE)
	Audio.sfx("page", 0.5)


func toggle_lock() -> void:
	if lock:
		lock = null
		return
	lock = _find_target(25.0, 140.0)
	if lock:
		feedback.emit("Ziel: " + lock.display_name, Color(1, 0.6, 0.6))


func _find_target(max_dist: float, arc: float) -> Fighter:
	var best: Fighter = null
	var best_score := INF
	var cam_fwd := Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)
	for e in get_tree().get_nodes_in_group("enemies"):
		var f := e as Fighter
		if f == null or f.state == S.DEAD:
			continue
		var to := f.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > max_dist:
			continue
		var ang := rad_to_deg(cam_fwd.angle_to(to.normalized())) if d > 0.1 else 0.0
		if ang > arc / 2.0:
			continue
		var score := d + ang * 0.1
		if score < best_score:
			best_score = score
			best = f
	return best


## Weiche Zielhilfe: ohne Lock-on zum nächsten Gegner vor Ainz drehen.
func _aim_soft() -> void:
	if lock and is_instance_valid(lock):
		face_towards(lock.global_position)
		return
	var near := _find_target(5.0, 160.0)
	if near:
		face_towards(near.global_position)
	else:
		facing = (Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)).normalized() if _move_amount < 0.1 else facing


# =====================================================================
#  Zauber & Techniken
# =====================================================================

func cast(id: String) -> bool:
	if not can_act() and state != S.BLOCK:
		return false
	var sp: Dictionary = Content.combat.spells[id]
	if float(cooldowns.get(id, 0.0)) > 0.0:
		feedback.emit("%s lädt noch (%.0f s)" % [sp.name, float(cooldowns[id])], Color(0.8, 0.8, 0.8))
		return false
	var pool := mana if sp.cost_type == "mana" else stamina
	if pool < float(sp.cost):
		feedback.emit("Nicht genug " + ("Mana" if sp.cost_type == "mana" else "Ausdauer"), Color(0.6, 0.7, 1.0))
		return false
	if sp.kind in ["target"] and _spell_target(float(sp.get("range", 12))) == null:
		feedback.emit("Kein Ziel", Color(0.8, 0.8, 0.8))
		return false
	if sp.cost_type == "mana":
		mana -= float(sp.cost)
	else:
		use_stamina(float(sp.cost))
	cooldowns[id] = float(sp.cooldown)
	casting = sp.duplicate()
	casting["id"] = id
	if rig:
		match String(sp.kind):
			"projectile": rig.cast_key = "cast_projectile"
			"cone": rig.cast_key = "cast_area"
			"self": rig.cast_key = "cast_self"
			"target": rig.cast_key = "cast_heavy" if float(sp.get("damage", 0)) >= 100.0 else "cast_target"
			_: rig.cast_key = "cast"
	_aim_soft()
	set_state(S.CAST)
	rig.flash(Color(sp.color), float(sp.cast))
	spell_cast.emit(id)
	return true


func _release_spell() -> void:
	var sp := casting
	casting = {}
	var info := {
		"amount": float(sp.get("damage", 0)), "type": sp.get("type", "physical"), "stagger": float(sp.get("stagger", 0)),
		"knockback": float(sp.get("knockback", 0)), "status": sp.get("status", {}), "name": sp.name,
	}
	var col := Color(sp.color)
	Audio.sfx("order", 0.5)
	match sp.kind:
		"projectile":
			var dir := facing
			if lock and is_instance_valid(lock):
				dir = (lock.global_position + Vector3.UP * 1.1) - (global_position + Vector3.UP * 1.4)
			Projectile.spawn(get_parent(), self, global_position + Vector3.UP * 1.4 + facing * 0.8, dir, float(sp.speed), info, col)
		"cone":
			_burst_fx(global_position + Vector3.UP, col, float(sp.range))
			for e in get_tree().get_nodes_in_group("enemies"):
				var f := e as Fighter
				if f and f.state != S.DEAD and global_position.distance_to(f.global_position) <= float(sp.range) and is_facing(f.global_position, float(sp.get("arc", 360))):
					f.take_hit(info, self)
		"self":
			shield_time = float(sp.get("duration", 10))
			feedback.emit(sp.name, col)
		"target":
			var t := _spell_target(float(sp.get("range", 12)))
			if t:
				_burst_fx(t.global_position + Vector3.UP, col, 1.5)
				if float(info.amount) > 0.0:
					t.take_hit(info, self)
				else:
					for k in info.status:
						t.add_status(k, float(info.status[k]))
		"leap":
			# Satz nach vorn (zum Ziel), Aufschlag mit Flächenschaden
			var dest := global_position + facing * float(sp.get("range", 6))
			if lock and is_instance_valid(lock) and global_position.distance_to(lock.global_position) <= float(sp.range) + 2.0:
				dest = lock.global_position - facing * 1.2
			var tw := create_tween()
			tw.tween_property(self, "global_position", Vector3(dest.x, global_position.y, dest.z), 0.25)
			await tw.finished
			_burst_fx(global_position + Vector3.UP * 0.3, col, float(sp.get("radius", 3)))
			for e in get_tree().get_nodes_in_group("enemies"):
				var f := e as Fighter
				if f and f.state != S.DEAD and global_position.distance_to(f.global_position) <= float(sp.get("radius", 3)):
					f.take_hit(info, self)


func _spell_target(rng: float) -> Fighter:
	if lock and is_instance_valid(lock) and lock.state != S.DEAD and global_position.distance_to(lock.global_position) <= rng:
		return lock
	return _find_target(rng, 100.0)


func _burst_fx(at: Vector3, col: Color, radius: float) -> void:
	var p := B3.fire(get_parent(), at, col, 60)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.direction = Vector3.UP
	p.initial_velocity_min = radius * 1.5
	p.initial_velocity_max = radius * 3.0
	p.gravity = Vector3.ZERO
	p.lifetime = 0.5
	p.emitting = true
	var l := B3.light(get_parent(), at, col, 4.0, radius * 2.5)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# =====================================================================
#  Ablauf
# =====================================================================

func _physics_process(delta: float) -> void:
	tick_combat(delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	if _combo_timer > 0.0:
		_combo_timer -= delta
	if lock and (not is_instance_valid(lock) or lock.state == S.DEAD):
		lock = _find_target(18.0, 360.0) if lock != null else null
	var iv := Vector2.ZERO
	if input_enabled:
		iv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		# Blocken solange F gehalten wird
		var want_block := Input.is_action_pressed("block")
		if want_block and can_act():
			set_state(S.BLOCK)
			_input_block = true
		elif not want_block and state == S.BLOCK and _input_block:
			_input_block = false
			set_state(S.IDLE)
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(iv.x, 0, iv.y)
	var sprint := input_enabled and Input.is_action_pressed("sprint") and state != S.BLOCK and not lock
	var speed := move_speed * speed_mult() * (SPRINT_MULT if sprint else 1.0)
	match state:
		S.DODGE:
			var t := state_time / float(cfg.dodge_time)
			var iframes: Array = cfg.iframes
			invulnerable = state_time >= float(iframes[0]) and state_time <= float(iframes[1])
			var sp := float(cfg.dodge_speed) * (1.0 - t * 0.6)
			velocity.x = _dodge_dir.x * sp
			velocity.z = _dodge_dir.z * sp
			if state_time >= float(cfg.dodge_time):
				invulnerable = false
				set_state(S.IDLE)
		S.ATTACK, S.STAGGER, S.STUN, S.DEAD:
			if state != S.ATTACK or phase != "active":
				velocity.x = move_toward(velocity.x, 0, 25 * delta)
				velocity.z = move_toward(velocity.z, 0, 25 * delta)
		S.CAST:
			velocity.x = move_toward(velocity.x, 0, 25 * delta)
			velocity.z = move_toward(velocity.z, 0, 25 * delta)
			if lock and is_instance_valid(lock):
				face_towards(lock.global_position, 10 * delta)
			if state_time >= float(casting.get("cast", 0.3)):
				set_state(S.IDLE)
				_release_spell()
		_:
			var target := dir * speed * (0.45 if state == S.BLOCK else 1.0)
			velocity.x = lerpf(velocity.x, target.x, minf(1.0, ACCEL * delta))
			velocity.z = lerpf(velocity.z, target.z, minf(1.0, ACCEL * delta))
			if state in [S.IDLE, S.MOVE]:
				state = S.MOVE if dir.length() > 0.1 else S.IDLE
			# Blickrichtung: zum Ziel (Lock-on) oder in Laufrichtung
			if lock and is_instance_valid(lock):
				face_towards(lock.global_position, 12 * delta)
			elif Vector2(velocity.x, velocity.z).length() > 0.3:
				face_towards(global_position + Vector3(velocity.x, 0, velocity.z), 10 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	velocity += knock
	move_with_steps(delta)
	velocity -= Vector3(knock.x, 0, knock.z)
	_move_amount = clampf(Vector2(velocity.x, velocity.z).length() / (move_speed * SPRINT_MULT), 0.0, 1.0)
	_update_camera(delta)


func _on_attack_end() -> void:
	if _queued != "":
		var q := _queued
		_queued = ""
		call_deferred("_do_attack", q)


func _on_state(s: int) -> void:
	if s != S.ATTACK:
		_queued = "" if s != S.IDLE else _queued
	if s == S.DEAD:
		feedback.emit("Ainz fällt …", Palette.DANGER)


func _update_camera(delta: float) -> void:
	if lock and is_instance_valid(lock):
		var d := lock.global_position - global_position
		d.y = 0.0
		if d.length() > 0.5:
			cam_yaw = lerp_angle(cam_yaw, atan2(-d.x, -d.z), minf(1.0, 6.0 * delta))
		_lock_marker.visible = true
		_lock_marker.global_position = lock.global_position + Vector3.UP * 3.3
	else:
		_lock_marker.visible = false
	_pivot.global_position = global_position + Vector3(0, 1.75, 0)
	_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	_arm.spring_length = lerpf(_arm.spring_length, cam_distance, minf(1.0, 6.0 * delta))


func _process(_delta: float) -> void:
	if rig == null:
		return
	var prog := 0.0
	var total := 1.0
	var kind := "light"
	match state:
		S.ATTACK:
			var w := float(attack.windup)
			var a := float(attack.active)
			var r := float(attack.recovery)
			total = w + a + r
			kind = attack.get("kind", "light")
			match phase:
				"windup": prog = state_time / w
				"active": prog = (state_time - w) / a
				_: prog = (state_time - w - a) / maxf(r, 0.01)
		S.DODGE:
			prog = state_time / float(cfg.dodge_time)
			total = float(cfg.dodge_time)
		S.CAST:
			total = float(casting.get("cast", 0.3))
		S.STAGGER: prog = state_time / 0.75
		S.DEAD: prog = state_time
	rig.pose(state, phase, clampf(prog, 0.0, 1.0), _move_amount, kind, total)
	rig.rotation.y = atan2(facing.x, facing.z)
	_shield_fx.visible = shield_time > 0.0


## Kamera direkt hinter Ainz ausrichten (nach Teleport).
func face(yaw: float) -> void:
	cam_yaw = yaw
	facing = (Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)).normalized()
	lock = null


func revive() -> void:
	state = S.IDLE
	state_time = 0.0
	hp = max_hp
	stamina = max_stamina
	mana = max_mana
	status.clear()
	hurtbox.set_deferred("monitorable", true)


func _feedback(text: String, color: Color) -> void:
	feedback.emit(text, color)


func _on_hurt() -> void:
	rig.flash(Color(1, 0.2, 0.2), 0.2)


func _on_parry() -> void:
	Audio.sfx("gong", 0.4)
	rig.flash(Palette.GOLD_BRIGHT, 0.3)

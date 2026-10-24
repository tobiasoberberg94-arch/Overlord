class_name Player3D
extends Fighter
## Ainz Ooal Gown in der dritten Person – mit Echtzeit-Kampf im Stil von The Witcher 3.
##
## Bewegung: WASD · Shift rennen · Maus Kamera (Klick fängt den Zeiger) · Mausrad Zoom
## Kampf:    Linke Maustaste leichte Attacke (Kombo) · Rechte Maustaste schwere Attacke
##           Leertaste Ausweichrolle (i-Frames) · F halten Blocken (früh = Parieren)
##           Q Ziel fixieren (Lock-on) · 1–5 / R Zauber bzw. Techniken · Y Superrang-Magie · X Ainz ↔ Momon
## Zwei Kampfstile (data/combat.json → player.styles):
##   Ainz  – magiefokussiert: Stabhiebe + Zauber (Mana), Superrang-Magie „Fallen Down“
##   Momon – Nahkampf mit zwei Großschwertern, Techniken kosten Ausdauer
## Treffergefühl: Kamera-Erschütterung (add_trauma), Blickwinkel-Stoß (fov_kick), Hiebspuren, Trefferstopp.

signal feedback(text: String, color: Color)
signal style_changed(style: String)
signal spell_cast(id: String)
signal attack_started(attack: Dictionary)      ## Gegner können blocken oder ausweichen

const ACCEL := 10.0
const GRAVITY := 18.0
const SPRINT_MULT := 1.75
const BASE_FOV := 54.0            # senkrechtes Sichtfeld: Häuser und Figuren behalten ihre Größe (68° ließ alles klein wirken)
const SPELL_ACTIONS := ["spell_1", "spell_2", "spell_3", "spell_4", "spell_5", "spell_6", "spell_super"]
## Farbe der Hiebspuren je Stil
const STYLE_TINT := {
	"ainz": Color(0.72, 0.45, 1.0), "momon": Color(0.95, 0.9, 0.82), "g_shalltear": Color(1.0, 0.22, 0.32),
	"g_cocytus": Color(0.62, 0.9, 1.0), "g_demiurge": Color(1.0, 0.45, 0.15), "g_sebas": Color(1.0, 0.95, 0.82), "g_aura": Color(0.62, 1.0, 0.42),
}

var input_enabled := true
var cam_yaw := 0.0
var cam_pitch := -0.38
var cam_distance := 7.0
var camera := Camera3D.new()
var style := "ainz"
var style_data: Dictionary = {}
var lock: Fighter                       ## fixiertes Ziel
var cooldowns: Dictionary = {}          ## Zauber-ID → verbleibende Sekunden
var casting: Dictionary = {}            ## Zauber in Vorbereitung
var cfg: Dictionary = {}
var trauma := 0.0                       ## Kamera-Erschütterung 0…1 (wirkt quadratisch)
var _pivot := Node3D.new()
var _arm := SpringArm3D.new()
var _combo := 0
var _combo_timer := 0.0
var _queued := ""                       ## gepufferte Eingabe (light/heavy)
var _dodge_dir := Vector3.ZERO
var _move_amount := 0.0
var _input_block := false
var _lock_marker: Label3D
var _shake_noise := FastNoiseLite.new()
var _shake_t := 0.0
var _fov_kick := 0.0
var _sprinting := false
var _cast_fx := {}
var _heart := {}
var _super := {}
var _super_center := Vector3.ZERO
var _barrier: MeshInstance3D
var _leap := {}
var _ghost_t := 0.0
var _combo_index := 0
var _releasing := false
var _mount := Node3D.new()            ## Halter der Kamera am Federarm (der Federarm setzt seine Kinder zurück)
var _summoned: Array = []             ## beschworene Verbündete (Todesritter)
var _buff_armor := 0.0
var _unbreakable := 0.0               ## Momons Unbeugsame Haltung: kein Taumeln
var _buff_fx: GPUParticles3D


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
	camera.fov = BASE_FOV
	camera.far = 4000.0
	_arm.add_child(_mount)
	_mount.add_child(camera)
	camera.current = true
	_shake_noise.frequency = 0.9
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
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
	CombatFX.player = self
	if not Progress.grimoire_changed.is_connected(_apply_rings):
		Progress.grimoire_changed.connect(_apply_rings)
	var saved: String = Game.state.get("world3d", {}).get("style", "ainz")
	set_style(saved if saved in ["ainz", "momon"] else "ainz", true)


static func _ensure_actions() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "dodge": [KEY_SPACE], "interact": [KEY_E], "block": [KEY_F],
		"lock_on": [KEY_Q], "switch_style": [KEY_X],
		"spell_1": [KEY_1], "spell_2": [KEY_2], "spell_3": [KEY_3], "spell_4": [KEY_4], "spell_5": [KEY_5],
		"spell_6": [KEY_R], "spell_super": [KEY_Z],
	}
	# alte Belegung (R = fünfter Zauber) aus früheren Versionen ablösen
	if InputMap.has_action("spell_5"):
		for ev in InputMap.action_get_events("spell_5"):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_R:
				InputMap.erase_action("spell_5")
				break
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
	# Controller (Xbox-Namen; PlayStation entsprechend) – Symbole und Übersicht in scripts/autoload/pad.gd
	var pad_buttons := {"interact": JOY_BUTTON_A, "dodge": JOY_BUTTON_B, "attack_light": JOY_BUTTON_X, "attack_heavy": JOY_BUTTON_Y,
		"spell_super": JOY_BUTTON_LEFT_SHOULDER, "spell_5": JOY_BUTTON_RIGHT_SHOULDER, "lock_on": JOY_BUTTON_RIGHT_STICK,
		"sprint": JOY_BUTTON_LEFT_STICK, "spell_1": JOY_BUTTON_DPAD_UP, "spell_2": JOY_BUTTON_DPAD_RIGHT,
		"spell_3": JOY_BUTTON_DPAD_DOWN, "spell_4": JOY_BUTTON_DPAD_LEFT, "ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
	for action in pad_buttons:
		_add_pad_button(action, pad_buttons[action])
	var pad_axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_forward": [JOY_AXIS_LEFT_Y, -1.0],
		"move_back": [JOY_AXIS_LEFT_Y, 1.0], "cam_left": [JOY_AXIS_RIGHT_X, -1.0], "cam_right": [JOY_AXIS_RIGHT_X, 1.0],
		"cam_up": [JOY_AXIS_RIGHT_Y, -1.0], "cam_down": [JOY_AXIS_RIGHT_Y, 1.0], "block": [JOY_AXIS_TRIGGER_LEFT, 1.0],
		"spell_6": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0],
		"ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0]}
	for action in pad_axes:
		_add_pad_axis(action, pad_axes[action][0], pad_axes[action][1])
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		InputMap.action_set_deadzone(action, 0.25)
	for action in ["cam_left", "cam_right", "cam_up", "cam_down"]:
		InputMap.action_set_deadzone(action, 0.18)


static func _add_pad_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return
	var jb := InputEventJoypadButton.new()
	jb.button_index = button
	InputMap.action_add_event(action, jb)


static func _add_pad_axis(action: String, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		var jm := ev as InputEventJoypadMotion
		if jm and jm.axis == axis and signf(jm.axis_value) == signf(direction):
			return
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = direction
	InputMap.action_add_event(action, m)


## Rechter Stick dreht die Kamera (Empfindlichkeit und Y-Umkehr aus den Einstellungen).
func _pad_camera(delta: float) -> void:
	if not input_enabled:
		return
	var v := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down", 0.18)
	if v == Vector2.ZERO:
		return
	var s: float = Settings.pad_sensitivity
	cam_yaw -= v.x * absf(v.x) * 3.2 * s * delta
	var dy := v.y * absf(v.y) * 2.2 * s * delta * (-1.0 if Settings.pad_invert_y else 1.0)
	cam_pitch = clampf(cam_pitch - dy, -1.2, 0.5)


## Ainz ↔ Momon (Taste X, Controller-Menü „Bücher, Karten & Berichte“).
func toggle_style() -> void:
	if not can_act():
		return
	if style.begins_with("g_"):
		feedback.emit("%s kämpft für Euch – erst nach dem Einsatz zurück" % style_data.name, Color(0.8, 0.8, 0.9))
	else:
		set_style("momon" if style == "ainz" else "ainz")


## Tastenbeschriftung einer Zauber-Aktion für die Zauberleiste (berücksichtigt das Tastaturlayout, z. B. Y/Z);
## mit aktivem Controller das Tastensymbol des Gamepads.
static func key_label(action: String) -> String:
	_ensure_actions()
	if Pad.active:
		return Pad.glyph(action)
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k:
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_label_from_physical(code)
			return OS.get_keycode_string(code)
	return "?"


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
	crit_chance = float(style_data.get("crit", 0.08))
	fx_material = String(style_data.get("material", "undead_lord" if s == "ainz" else "armor"))
	body_height = float(style_data.get("height", 1.9))
	if _barrier and is_instance_valid(_barrier):
		_barrier.queue_free()
		_barrier = null
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
	if shield_time > 0.0:
		_barrier = SpellFX.barrier(self, Color(1.0, 0.82, 0.38))
	_apply_rings()
	if not silent:
		rig.flash(Color(0.6, 0.3, 1.0), 0.5)
		CombatFX.burst(get_parent(), "motes", global_position + Vector3.UP, Color(0.6, 0.3, 1.0), Vector3.UP, 1.5)
		CombatFX.sound("cast_small", global_position + Vector3.UP, 0.7)
		feedback.emit(String(style_data.name), Palette.GOLD_BRIGHT)
	style_changed.emit(s)


## Zauberleiste (6 Tasten): Belegung aus dem Zauberbuch, sonst die Grundzauber des Stils.
func spells() -> Array:
	var base: Array = style_data.get("spells", [])
	if not Game.state.has("progress"):
		return base
	return Progress.loadout(style, base)


func super_spell() -> String:
	return String(style_data.get("super", ""))


func spell_ready(id: String) -> bool:
	if id == "" or not Content.combat.spells.has(id):
		return false
	var sp := Progress.effective_spell(id)
	var pool := mana if sp.cost_type == "mana" else stamina
	return float(cooldowns.get(id, 0.0)) <= 0.0 and pool >= float(sp.cost)


func tint() -> Color:
	return STYLE_TINT.get(style, Color(0.9, 0.85, 1.0))


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
		toggle_style()
	elif event.is_action_pressed("spell_super"):
		if super_spell() != "":
			cast(super_spell())
		else:
			feedback.emit("Nur Ainz beherrscht Superrang-Magie", Color(0.8, 0.8, 0.9))
	else:
		for i in 6:
			if event.is_action_pressed(SPELL_ACTIONS[i]):
				var sp := spells()
				if i < sp.size() and String(sp[i]) != "":
					cast(sp[i])
				elif not style.begins_with("g_"):
					feedback.emit("Taste nicht belegt – Zauberbuch [B]", Color(0.8, 0.8, 0.9))


## Aktionen können auch aus Tests/KI ausgelöst werden.
func request(what: String) -> bool:
	if state == S.DEAD or not _leap.is_empty():
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
		_combo_index = 0
	else:
		var chain: Array = style_data.light
		if _combo_timer <= 0.0:
			_combo = 0
		_combo_index = _combo
		a = chain[_combo % chain.size()].duplicate()
		a["kind"] = "light"
		_combo = (_combo + 1) % chain.size()
		_combo_timer = 1.1
	if not start_attack(a):
		feedback.emit("Zu erschöpft", Color(0.8, 0.8, 0.8))
		return false
	attack_started.emit(a)
	return true


func _start_dodge() -> void:
	use_stamina(float(cfg.dodge_stamina) * (1.0 - (clampf(Progress.ring_effect("dodge_cost"), 0.0, 0.6) if Game.state.has("progress") else 0.0)))
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
	CombatFX.sound("dodge", global_position + Vector3.UP, 0.6)
	CombatFX.burst(get_parent(), "dust_puff", global_position + Vector3.UP * 0.15, Color(0.6, 0.56, 0.5), -_dodge_dir + Vector3.UP, 0.6)
	if style == "ainz":
		SpellFX.ghost(rig, Color(0.55, 0.3, 1.0), 0.35)


func toggle_lock() -> void:
	if lock:
		lock = null
		return
	lock = _find_target(25.0, 140.0)
	if lock:
		feedback.emit("Ziel: " + lock.display_name, Color(1, 0.6, 0.6))
		CombatFX.sound("lock_on", global_position + Vector3.UP, 0.5, 0.0)


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
#  Treffergefühl: Kamera
# =====================================================================

func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


func fov_kick(deg: float) -> void:
	_fov_kick = maxf(_fov_kick, deg)


# =====================================================================
#  Zauber & Techniken
# =====================================================================

func cast(id: String) -> bool:
	if not can_act() and state != S.BLOCK:
		return false
	if not Content.combat.spells.has(id):
		return false
	var sp := Progress.effective_spell(id)
	if float(cooldowns.get(id, 0.0)) > 0.0:
		feedback.emit("%s lädt noch (%.0f s)" % [sp.name, float(cooldowns[id])], Color(0.8, 0.8, 0.8))
		return false
	var pool := mana if sp.cost_type == "mana" else stamina
	if pool < float(sp.cost):
		feedback.emit("Nicht genug " + ("Mana" if sp.cost_type == "mana" else "Ausdauer"), Color(0.6, 0.7, 1.0))
		return false
	if sp.kind in ["target", "chain"] and _spell_target(float(sp.get("range", 12))) == null:
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
			"cone", "nova", "vortex": rig.cast_key = "cast_area"
			"self", "buff", "summon_ally": rig.cast_key = "cast_self"
			"line": rig.cast_key = "cast_heavy"
			"target", "chain": rig.cast_key = "cast_heavy" if float(sp.get("damage", 0)) >= 100.0 else "cast_target"
			"super": rig.cast_key = "cast_heavy"
			_: rig.cast_key = "cast"
	_aim_soft()
	set_state(S.CAST)
	rig.flash(Color(sp.color), float(sp.cast), 0.16)
	_cast_fx = SpellFX.cast_begin(self, casting)
	if id == "grasp_heart":
		_heart = SpellFX.heart_begin(self, _spell_target(float(sp.get("range", 12))), casting)
	if sp.kind == "super":
		_super_center = _super_target(float(sp.get("range", 30)))
		_super = SpellFX.super_begin(self, _super_center, casting)
		feedback.emit(String(sp.name), Color(sp.color))
		CombatDirector.alarm(self, 40.0)
	spell_cast.emit(id)
	return true


## Abbruch eines Zaubers (Taumeln, Lähmung, Tod): Effekte aufräumen, Mana bleibt verbraucht.
func _cancel_cast() -> void:
	SpellFX.cast_end(_cast_fx)
	_cast_fx = {}
	if not _heart.is_empty():
		if _heart.has("heart") and is_instance_valid(_heart.heart):
			_heart.heart.queue_free()
		if _heart.has("aura") and is_instance_valid(_heart.aura):
			CombatFX.stop(_heart.aura)
		var t: Variant = _heart.get("target")
		if t is Fighter and is_instance_valid(t) and t.rig:
			t.rig.glow(Color.WHITE, 0.0)
		_heart = {}
	if not _super.is_empty():
		for nd in _super.get("nodes", []):
			if is_instance_valid(nd):
				nd.release()
		for k in ["aura", "light", "warn"]:
			if _super.has(k) and is_instance_valid(_super[k]):
				_super[k].queue_free()
		_super = {}
	casting = {}


func stagger(strength: float, src: Vector3) -> void:
	Pad.rumble(clampf(0.3 + strength * 0.4, 0.3, 1.0), 0.2)
	# Superrang-Magie lässt sich nicht unterbrechen, Momons Unbeugsame Haltung auch nicht
	if state == S.CAST and String(casting.get("kind", "")) == "super":
		return
	if _unbreakable > 0.0:
		return
	super(strength, src)


func _spell_info(sp: Dictionary) -> Dictionary:
	return {
		"amount": float(sp.get("damage", 0)), "type": sp.get("type", "physical"), "stagger": float(sp.get("stagger", 0)),
		"knockback": float(sp.get("knockback", 0)), "status": sp.get("status", {}), "name": sp.name, "kind": "spell",
		"crit_bonus": float(sp.get("crit", 0.0)), "guard_mult": float(sp.get("guard_mult", 1.0)),
		"unblockable": sp.get("unblockable", false),
	}


## Nahkampf: Ringe (Schaden, Nahkampf) wirken auf jeden Hieb.
func _attack_info(a: Dictionary) -> Dictionary:
	var info := super(a)
	if Game.state.has("progress"):
		info.amount = float(info.amount) * (1.0 + Progress.ring_effect("dmg_all") + Progress.ring_effect("dmg_melee"))
	return info


## Lebensraub der Ringe: ein Teil des angerichteten Schadens heilt Ainz.
func on_dealt(dealt: float, _victim: Fighter) -> void:
	if state == S.DEAD or not Game.state.has("progress"):
		return
	var ls := Progress.ring_effect("lifesteal")
	if ls > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + dealt * ls)


func _release_spell() -> void:
	var sp := casting
	casting = {}
	SpellFX.cast_end(_cast_fx)
	_cast_fx = {}
	var info := _spell_info(sp)
	var col := Color(sp.color)
	var el := SpellFX.element(sp)
	var lvl := get_parent()
	CombatFX.fov_kick(1.5 if float(sp.get("cast", 0.3)) < 0.6 else 3.0)
	match sp.kind:
		"projectile":
			var count := int(sp.get("count", 1))
			var spread := float(sp.get("spread", 0.0))
			var origin := SpellFX._hand_pos(self) + facing * 0.4
			var aim := facing
			if lock and is_instance_valid(lock):
				aim = (lock.global_position + Vector3.UP * lock.body_height * 0.6) - origin
			for i in count:
				var off := 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
				var dir := aim.normalized().rotated(Vector3.UP, deg_to_rad(off))
				var p := Projectile.spawn(lvl, self, origin, dir, float(sp.speed), info, col, el)
				if lock and is_instance_valid(lock):
					p.homing = lock
					p.turn = float(sp.get("homing", 2.5))
			CombatFX.sound(String(sp.get("sound", el + "_launch")), origin, 0.9)
		"cone":
			_cone(sp, info)
			for k in range(1, int(sp.get("repeat", 1))):
				get_tree().create_timer(0.38 * k, false).timeout.connect(func():
					if is_instance_valid(self) and state != S.DEAD:
						_cone(sp, info))
		"nova":
			var r := float(sp.get("radius", 7.0))
			StoryFX.negative_burst(lvl, global_position, r, 1.45)   # Kugel bleibt vor der Spielkamera
			for e in get_tree().get_nodes_in_group("enemies"):
				var f := e as Fighter
				if f and f.state != S.DEAD and global_position.distance_to(f.global_position) <= r:
					f.take_hit(info, self)
		"summon_ally":
			_summon_ally(sp, col)
		"vortex":
			_black_hole(sp, info)
		"line":
			_reality_slash(sp, info, 0.0)
			if sp.get("cross", false):
				get_tree().create_timer(0.22, false).timeout.connect(func():
					if is_instance_valid(self):
						_reality_slash(sp, info, PI * 0.5))
		"buff":
			_buff(sp, col)
		"self":
			shield_charges = int(sp.get("charges", 1))
			shield_time = float(sp.get("duration", 10))
			if _barrier and is_instance_valid(_barrier):
				_barrier.queue_free()
			_barrier = SpellFX.barrier(self, col)
			feedback.emit(sp.name, col)
		"target":
			var t := _spell_target(float(sp.get("range", 12)))
			if t:
				_target_spell(sp, t, info, col, el)
			elif not _heart.is_empty():
				SpellFX.heart_release(_heart, self, false)
				_heart = {}
		"chain":
			_chain_lightning(sp, info, col)
		"leap":
			_start_leap(sp, info)
		"super":
			_fallen_down(sp, info)


func _target_spell(sp: Dictionary, t: Fighter, info: Dictionary, col: Color, el: String) -> void:
	var lvl := get_parent()
	var chest := t.global_position + Vector3.UP * t.body_height * 0.6
	var id := String(sp.get("id", ""))
	if id == "grasp_heart":
		var r := t.take_hit(info, self)
		SpellFX.heart_release(_heart, self, r == "kill")
		_heart = {}
		return
	if float(info.amount) <= 0.0:
		# reine Kontrollzauber: Bannkreis statt Schaden
		for k in info.status:
			t.add_status(k, float(info.status[k]))
		var secs := float(info.status.values().max()) if not info.status.is_empty() else 2.0
		SpellFX.bind(t, col, secs, "b" if el != "dark" else "a")
		var extra := int(sp.get("extra", 0))
		if extra > 0:
			var near: Array = get_tree().get_nodes_in_group("enemies").filter(func(o): return o != t and o is Fighter and o.state != S.DEAD and o.global_position.distance_to(t.global_position) <= float(sp.get("area", 5.0)))
			near.sort_custom(func(a, b): return a.global_position.distance_to(t.global_position) < b.global_position.distance_to(t.global_position))
			for i in mini(extra, near.size()):
				var o: Fighter = near[i]
				for k in info.status:
					o.add_status(k, float(info.status[k]))
				SpellFX.bind(o, col, secs, "b")
				SpellFX.beam(lvl, chest, o.global_position + Vector3.UP * o.body_height * 0.6, col, 0.08, 0.35)
		if id == "command":
			CombatFX.float_text(lvl, chest + Vector3.UP * 1.0, "»Kniet nieder.«", col, 34)
		return
	match id:
		"purify_lance":
			SpellFX.sky_lance(lvl, t.global_position, col)
			get_tree().create_timer(0.16, false).timeout.connect(func():
				if is_instance_valid(t):
					t.take_hit(info, self))
		"ki_strike":
			SpellFX.beam(lvl, SpellFX._hand_pos(self), chest, col, 0.35, 0.3)
			GroundMark.ring(lvl, t.global_position, 2.2, col, 0.4)
			CombatFX.sound("shockwave", chest, 0.8)
			t.take_hit(info, self)
		_:
			SpellFX.projectile_burst(lvl, chest, el, col, 1.0)
			t.take_hit(info, self)


## Kettendrachenblitz: springt vom Ziel auf bis zu `chains` weitere Gegner, jeder Sprung etwas schwächer.
func _chain_lightning(sp: Dictionary, info: Dictionary, col: Color) -> void:
	var lvl := get_parent()
	var cur := _spell_target(float(sp.get("range", 16)))
	var from := SpellFX._hand_pos(self)
	var hit: Array = []
	var dmg := float(info.amount)
	for i in int(sp.get("chains", 4)) + 1:
		if cur == null:
			break
		hit.append(cur)
		var to := cur.global_position + Vector3.UP * cur.body_height * 0.6
		var inf := info.duplicate()
		inf["amount"] = dmg
		var a := from
		var target := cur
		get_tree().create_timer(i * 0.09, false).timeout.connect(func():
			if is_instance_valid(lvl):
				SpellFX.bolt(lvl, a, to, col, 0.34 if i == 0 else 0.26)
				CombatFX.sound("lightning", to, 0.9 if i == 0 else 0.7)
			if is_instance_valid(target) and target.state != S.DEAD:
				target.take_hit(inf, self))
		from = to
		dmg *= 0.82
		var nxt: Fighter = null
		var best := float(sp.get("jump", 7.0))
		for e in get_tree().get_nodes_in_group("enemies"):
			var f := e as Fighter
			if f and f.state != S.DEAD and not f in hit:
				var d := f.global_position.distance_to(cur.global_position)
				if d < best:
					best = d
					nxt = f
		cur = nxt
	CombatFX.shake(0.25)


func _cone(sp: Dictionary, info: Dictionary) -> void:
	SpellFX.wave(self, sp)
	for e in get_tree().get_nodes_in_group("enemies"):
		var f := e as Fighter
		if f and f.state != S.DEAD and global_position.distance_to(f.global_position) <= float(sp.range) and is_facing(f.global_position, float(sp.get("arc", 360))):
			f.take_hit(info, self)


## Erschaffe Untoten: Todesritter erheben sich aus dem Boden und kämpfen eine Weile an Ainz' Seite.
func _summon_ally(sp: Dictionary, col: Color) -> void:
	var lvl := get_parent()
	for old in _summoned:
		if is_instance_valid(old):
			_unsummon(old)
	_summoned.clear()
	var n := int(sp.get("count", 1))
	for i in n:
		var side := (float(i) - (n - 1) * 0.5) * 2.2
		var at := global_position + facing * 2.6 + facing.cross(Vector3.UP) * side
		var g := CombatFX._ground_below(lvl, at + Vector3.UP * 2.0)
		if g != Vector3.INF:
			at = g
		StoryFX.summon_undead(lvl, at, col)
		var e: Enemy3D = Enemy3D.ally_spawner.call(String(sp.summon), at) if Enemy3D.ally_spawner.is_valid() else null
		if e == null:
			e = Enemy3D.create(String(sp.summon), true)
			e.position = at
			lvl.add_child(e)
		e.facing = facing
		if e.rig:
			e.rig.rotation.y = atan2(facing.x, facing.z)
			e.rig.position.y = -2.2
			e.rig.create_tween().tween_property(e.rig, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_summoned.append(e)
		get_tree().create_timer(float(sp.get("duration", 40)), false).timeout.connect(func():
			if is_instance_valid(e):
				_unsummon(e))
	CombatFX.sound("roar", global_position + facing * 2.6 + Vector3.UP * 2.0, 0.9)
	feedback.emit(String(sp.name), col)


func _unsummon(e: Enemy3D) -> void:
	if not is_instance_valid(e):
		return
	e.remove_from_group("allies")
	var lvl := e.get_parent()
	if lvl:
		CombatFX.burst(lvl, "wisps", e.global_position + Vector3.UP, Color(0.08, 0.0, 0.12), Vector3.UP, 1.6, Color(0.6, 0.25, 1.0, 0.8))
	var tw := e.create_tween()
	tw.tween_property(e, "scale", Vector3(0.05, 1.2, 0.05), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(e.queue_free)


## Schwarzes Loch: saugt alle Feinde im Umkreis an, dann fällt es in sich zusammen und verschlingt sie.
func _black_hole(sp: Dictionary, info: Dictionary) -> void:
	var lvl := get_parent()
	var center := _super_target(float(sp.get("range", 22)))
	var r := float(sp.get("radius", 8.0))
	var dur := float(sp.get("duration", 2.2))
	var pull := float(sp.get("pull", 7.0))
	StoryFX.black_hole(lvl, center + Vector3.UP * 1.7, minf(3.2, r * 0.4), maxf(0.3, dur - 0.45))
	var drv := create_tween()
	drv.tween_method(func(_k: float):
		for e in get_tree().get_nodes_in_group("enemies"):
			var f := e as Fighter
			if f == null or f.state == S.DEAD:
				continue
			var to := center - f.global_position
			to.y = 0.0
			var d := to.length()
			if d <= r and d > 0.6:
				f.knock = to.normalized() * pull * (0.55 + 0.45 * (1.0 - d / r)), 0.0, 1.0, dur)
	drv.tween_callback(func():
		for e in get_tree().get_nodes_in_group("enemies"):
			var f := e as Fighter
			if f == null or f.state == S.DEAD:
				continue
			var d := Vector2(f.global_position.x - center.x, f.global_position.z - center.z).length()
			if d <= r * 0.55:
				f.take_hit(info, self)
			elif d <= r:
				var weak := info.duplicate()
				weak["amount"] = float(info.amount) * 0.5
				f.take_hit(weak, self))
	CombatDirector.alarm(self, 30.0)


## Realitätsschnitt: der Raum selbst wird entlang einer Linie zerschnitten (unblockbar).
func _reality_slash(sp: Dictionary, info: Dictionary, angle_off: float) -> void:
	var lvl := get_parent()
	var dir := facing
	if lock and is_instance_valid(lock) and lock.state != S.DEAD:
		dir = lock.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else facing
	dir = dir.rotated(Vector3.UP, angle_off)
	var rng := float(sp.get("range", 20))
	var half := float(sp.get("width", 1.6)) * 0.5
	var start := global_position + Vector3.UP * 1.2 + dir * 0.8
	if angle_off != 0.0:
		start = global_position + Vector3.UP * 1.2 + facing * rng * 0.45 - dir * rng * 0.5
	var stop := start + dir * rng
	# ein Riss im Raum: drei gleißende Linien übereinander, Verzerrung, Risse im Boden entlang des Schnitts
	for k in 3:
		var hh := Vector3.UP * (-0.7 + k * 0.7)
		SpellFX.beam(lvl, start + hh, stop + hh, Color(0.96, 0.98, 1.0), 0.09 if k == 1 else 0.05, 0.6 + k * 0.08)
	SpellFX.beam(lvl, start, stop, Color(0.55, 0.65, 1.0), 0.35, 0.35)
	SpellFX.distortion(lvl, (start + stop) * 0.5, rng * 0.5, 0.08, 0.5)
	var steps := int(rng / 3.0)
	for i in steps:
		var gp := CombatFX._ground_below(lvl, start + dir * (1.5 + i * 3.0) + Vector3.UP * 2.0)
		if gp != Vector3.INF:
			CombatFX.decal(lvl, gp, "crack", 2.2, 10.0, Color(0.85, 0.9, 1.0), 1.5)
			CombatFX.burst(lvl, "sparks", gp + Vector3.UP * 0.3, Color(0.85, 0.9, 1.0), Vector3.UP, 0.5)
	var yaw := atan2(-dir.x, -dir.z)
	var gm := GroundMark.telegraph_line(lvl, Vector3(start.x, global_position.y, start.z), yaw, rng, half, Color(0.8, 0.9, 1.0), 0.12)
	if gm:
		get_tree().create_timer(0.12, false).timeout.connect(func():
			if is_instance_valid(gm):
				gm.release())
	CombatFX.flash(lvl, (start + stop) * 0.5, Color(0.85, 0.9, 1.0), 6.0, rng, 0.3)
	CombatFX.sound("shield_break", start, 1.0)
	CombatFX.sound("swing_heavy", start, 0.9)
	CombatFX.shake(0.35)
	var a2 := Vector2(start.x, start.z)
	var b2 := Vector2(stop.x, stop.z)
	for e in get_tree().get_nodes_in_group("enemies"):
		var f := e as Fighter
		if f == null or f.state == S.DEAD:
			continue
		var p2 := Vector2(f.global_position.x, f.global_position.z)
		var q := Geometry2D.get_closest_point_to_segment(p2, a2, b2)
		if p2.distance_to(q) <= half + f.body_radius:
			CombatFX.burst(lvl, "sparks_big", f.global_position + Vector3.UP * f.body_height * 0.55, Color(0.85, 0.9, 1.0), Vector3.UP, 0.8)
			f.take_hit(info, self)


## Momons Unbeugsame Haltung: mehr Rüstung, kein Taumeln.
func _buff(sp: Dictionary, col: Color) -> void:
	var dur := float(sp.get("duration", 8))
	var add := float(sp.get("armor", 60))
	_unbreakable = dur
	_buff_armor = add
	_apply_rings()
	if _buff_fx and is_instance_valid(_buff_fx):
		CombatFX.stop(_buff_fx)
	_buff_fx = CombatFX.emitter(self, "aura", col)
	rig.glow(col, 0.12)
	GroundMark.ring(get_parent(), global_position, 2.4, col, 0.6)
	CombatFX.sound("shield_up", global_position + Vector3.UP, 0.9)
	feedback.emit(String(sp.name), col)
	get_tree().create_timer(dur, false).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_buff_armor = 0.0
		_apply_rings()
		if rig:
			rig.glow(Color.WHITE, 0.0)
		if _buff_fx and is_instance_valid(_buff_fx):
			CombatFX.stop(_buff_fx)
		_buff_fx = null)


## Ringe des Overlords: Leben, Mana, Rüstung, Kritisch, Erholung, Schutz vor Heiligem.
func _apply_rings() -> void:
	if style_data.is_empty():
		return
	var hr := hp / maxf(max_hp, 1.0)
	var mr := mana / maxf(max_mana, 1.0)
	var rings := Game.state.has("progress")
	max_hp = float(style_data.hp) + (Progress.ring_effect("max_hp") if rings else 0.0)
	hp = clampf(max_hp * hr, 0.0, max_hp) if state != S.DEAD else hp
	max_mana = float(style_data.mana) + (Progress.ring_effect("max_mana") if rings else 0.0)
	mana = clampf(max_mana * mr, 0.0, max_mana)
	armor = float(style_data.armor) + (Progress.ring_effect("armor") if rings else 0.0) + _buff_armor
	crit_chance = float(style_data.get("crit", 0.08)) + (Progress.ring_effect("crit") if rings else 0.0)
	mana_regen = float(cfg.mana_regen) * (1.0 + (Progress.ring_effect("mana_regen") if rings else 0.0))
	stamina_regen = float(cfg.stamina_regen) * (1.0 + (Progress.ring_effect("stamina_regen") if rings else 0.0))
	var base_resist: Dictionary = style_data.get("resist", {})
	resist = base_resist.duplicate()
	if rings and Progress.ring_effect("holy_resist") > 0.0:
		resist["holy"] = float(base_resist.get("holy", 1.0)) * (1.0 - clampf(Progress.ring_effect("holy_resist"), 0.0, 0.8))


func _super_target(rng: float) -> Vector3:
	if lock and is_instance_valid(lock) and lock.state != S.DEAD and global_position.distance_to(lock.global_position) <= rng:
		return lock.global_position
	var t := _find_target(rng, 120.0)
	if t:
		return t.global_position
	var at := global_position + facing * 14.0
	var g := CombatFX._ground_below(get_parent(), at + Vector3.UP * 3.0)
	return g if g != Vector3.INF else at


## Superrang-Magie „Fallen Down“: Lichtsäule aus dem Himmel – vernichtend im Kern, schwer im weiten Umkreis.
func _fallen_down(sp: Dictionary, info: Dictionary) -> void:
	var center := _super_center
	SpellFX.super_release(_super, self, center, sp)
	_super = {}
	var inner := float(sp.get("radius", 9.0))
	var outer := float(sp.get("outer", 15.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		var f := e as Fighter
		if f == null or f.state == S.DEAD:
			continue
		var d := Vector2(f.global_position.x - center.x, f.global_position.z - center.z).length()
		if d <= inner:
			f.take_hit(info, self)
		elif d <= outer:
			var weak := info.duplicate()
			weak["amount"] = float(info.amount) * float(sp.get("outer_mult", 0.3))
			weak["stagger"] = float(info.stagger) * 0.5
			f.take_hit(weak, self)


## Sprungangriff: Bogen zum Ziel mit Nachbildern, i-Frames in der Luft, Aufschlag mit Flächenschaden.
func _start_leap(sp: Dictionary, info: Dictionary) -> void:
	var rng := float(sp.get("range", 6))
	var dest := global_position + facing * rng
	if lock and is_instance_valid(lock) and global_position.distance_to(lock.global_position) <= rng + 2.0:
		dest = lock.global_position - facing * 1.2
	var g := CombatFX._ground_below(get_parent(), dest + Vector3.UP * 2.0)
	if g != Vector3.INF:
		dest.y = g.y
	var dist := global_position.distance_to(dest)
	_leap = {"start": global_position, "dest": dest, "h": clampf(dist * 0.32, 1.0, 2.8), "t": 0.0,
		"dur": clampf(0.22 + dist * 0.03, 0.28, 0.5), "sp": sp, "info": info}
	invulnerable = true
	set_state(S.DODGE)
	if rig:
		rig.dodge_key = "leap"
	CombatFX.sound("dodge", global_position + Vector3.UP, 0.8)


func _tick_leap(delta: float) -> void:
	_leap.t = float(_leap.t) + delta
	var k := clampf(float(_leap.t) / float(_leap.dur), 0.0, 1.0)
	var p: Vector3 = (_leap.start as Vector3).lerp(_leap.dest, k)
	p.y += sin(k * PI) * float(_leap.h)
	velocity = (p - global_position) / maxf(delta, 0.001)
	move_and_slide()
	state_time = k * float(cfg.dodge_time)
	invulnerable = true
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.045
		SpellFX.ghost(rig, Color((_leap.sp as Dictionary).get("color", "#d4af37")), 0.3)
	if k >= 1.0:
		var sp: Dictionary = _leap.sp
		var info: Dictionary = _leap.info
		_leap = {}
		invulnerable = false
		velocity = Vector3.ZERO
		set_state(S.IDLE)
		SpellFX.leap_land(self, sp)
		for e in get_tree().get_nodes_in_group("enemies"):
			var f := e as Fighter
			if f and f.state != S.DEAD and global_position.distance_to(f.global_position) <= float(sp.get("radius", 3)):
				f.take_hit(info, self)


func _spell_target(rng: float) -> Fighter:
	if lock and is_instance_valid(lock) and lock.state != S.DEAD and global_position.distance_to(lock.global_position) <= rng:
		return lock
	return _find_target(rng, 100.0)


# =====================================================================
#  Ablauf
# =====================================================================

func _physics_process(delta: float) -> void:
	tick_combat(delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	_unbreakable = maxf(0.0, _unbreakable - delta)
	if _combo_timer > 0.0:
		_combo_timer -= delta
	if lock and (not is_instance_valid(lock) or lock.state == S.DEAD):
		lock = _find_target(18.0, 360.0) if lock != null else null
	if not _leap.is_empty():
		_tick_leap(delta)
		_move_amount = 1.0
		_update_camera(delta)
		return
	_pad_camera(delta)
	if frozen():
		velocity = Vector3.ZERO
		_update_camera(delta)
		return
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
	_sprinting = sprint and dir.length() > 0.1 and state in [S.IDLE, S.MOVE]
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
				_releasing = true
				set_state(S.IDLE)
				_releasing = false
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


func _on_attack_active() -> void:
	SlashFX.spawn(self, attack, tint(), 3.6 if attack.get("kind", "light") == "light" else 4.6, _combo_index)
	var heavy: bool = attack.get("kind", "light") == "heavy"
	var snd := "swing_heavy" if heavy else ("swing_staff" if style == "ainz" else "swing_light")
	CombatFX.sound(snd, global_position + Vector3.UP * 1.2, 0.8)


func _on_attack_end() -> void:
	if _queued != "":
		var q := _queued
		_queued = ""
		call_deferred("_do_attack", q)


func _on_state(s: int) -> void:
	if s != S.ATTACK:
		_queued = "" if s != S.IDLE else _queued
	if s != S.CAST and not casting.is_empty() and not _releasing:
		_cancel_cast()
	if s == S.DEAD:
		feedback.emit("Ainz fällt …", Palette.DANGER)


func _update_camera(delta: float) -> void:
	if lock and is_instance_valid(lock):
		var d := lock.global_position - global_position
		d.y = 0.0
		if d.length() > 0.5:
			cam_yaw = lerp_angle(cam_yaw, atan2(-d.x, -d.z), minf(1.0, 6.0 * delta))
		_lock_marker.visible = true
		_lock_marker.global_position = lock.global_position + Vector3.UP * (lock.body_height + 1.3)
	else:
		_lock_marker.visible = false
	_pivot.global_position = global_position + Vector3(0, 1.75, 0)
	_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	_arm.spring_length = lerpf(_arm.spring_length, cam_distance, minf(1.0, 6.0 * delta))


func _process(delta: float) -> void:
	_update_shake(delta)
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
			total = float(cfg.dodge_time) if _leap.is_empty() else float(_leap.dur) * 1.3
		S.CAST:
			total = float(casting.get("cast", 0.3))
		S.STAGGER: prog = state_time / 0.75
		S.DEAD: prog = state_time
	rig.pose(state, phase, clampf(prog, 0.0, 1.0), _move_amount, kind, total)
	rig.rotation.y = atan2(facing.x, facing.z)
	if _barrier and is_instance_valid(_barrier) and shield_time <= 0.0:
		SpellFX.barrier_break(_barrier, false)
		_barrier = null


## Erschütterung und Blickwinkel in Echtzeit (auch während einer Zeitlupe).
func _update_shake(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.05)
	_shake_t += rd
	trauma = maxf(0.0, trauma - rd * 1.6)
	var s := trauma * trauma
	if s > 0.0001:
		camera.rotation = Vector3(
			_shake_noise.get_noise_2d(_shake_t * 28.0, 10.0) * 0.05 * s,
			_shake_noise.get_noise_2d(_shake_t * 28.0, 40.0) * 0.05 * s,
			_shake_noise.get_noise_2d(_shake_t * 22.0, 80.0) * 0.07 * s)
		camera.h_offset = _shake_noise.get_noise_2d(_shake_t * 30.0, 120.0) * 0.1 * s
		camera.v_offset = _shake_noise.get_noise_2d(_shake_t * 30.0, 160.0) * 0.08 * s
	elif camera.rotation != Vector3.ZERO:
		camera.rotation = Vector3.ZERO
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	_fov_kick = maxf(0.0, _fov_kick - rd * 16.0)
	var target_fov := BASE_FOV + _fov_kick + (5.0 if _sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, rd * (14.0 if _fov_kick > 0.0 else 5.0)))


## Kamera direkt hinter Ainz ausrichten (nach Teleport).
func face(yaw: float) -> void:
	cam_yaw = yaw
	facing = (Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)).normalized()
	lock = null


## Heilung durch Tränke, Rast oder Segen – Anteile (0–1) des jeweiligen Maximums.
func heal(hp_frac: float, mana_frac: float = 0.0, stamina_frac: float = 0.0) -> void:
	if state == S.DEAD:
		return
	hp = minf(max_hp, hp + max_hp * hp_frac)
	mana = minf(max_mana, mana + max_mana * mana_frac)
	stamina = minf(max_stamina, stamina + max_stamina * stamina_frac)


func revive() -> void:
	state = S.IDLE
	state_time = 0.0
	hp = max_hp
	stamina = max_stamina
	mana = max_mana
	status.clear()
	_clear_status_fx()
	_leap = {}
	invulnerable = false
	hurtbox.set_deferred("monitorable", true)


func _feedback(text: String, color: Color) -> void:
	feedback.emit(text, color)


func _on_hurt() -> void:
	rig.flash(Color(1, 0.25, 0.2), 0.18, 0.28)


func _on_parry() -> void:
	rig.flash(Palette.GOLD_BRIGHT, 0.3, 0.3)


func _on_shield_hit(src: Vector3 = Vector3.ZERO) -> void:
	if _barrier and is_instance_valid(_barrier):
		SpellFX.barrier_hit(_barrier, src)


func _on_shield_break(src: Vector3 = Vector3.ZERO) -> void:
	if _barrier and is_instance_valid(_barrier):
		SpellFX.barrier_hit(_barrier, src)
		SpellFX.barrier_break(_barrier, true)
		_barrier = null

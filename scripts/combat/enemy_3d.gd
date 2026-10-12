class_name Enemy3D
extends Fighter
## Gegner mit klar lesbaren Angriffsmustern:
##   Annähern → Abstand halten/umkreisen → Wind-up (leuchtet: orange = blockbar,
##   rot = nur ausweichen!) → Angriff (Hitbox aktiv) → Recovery (verwundbar) → Pause.
## Werte und Angriffe stammen aus data/combat.json → enemies.

signal defeated(e: Enemy3D)

var type_id := ""
var data: Dictionary = {}
var target: Fighter
var home := Vector3.ZERO
var aggro := 14.0
var _cooldown := 1.0
var _strafe_dir := 1.0
var _think := 0.0
var _hpbar: MeshInstance3D
var _hpbar_bg: MeshInstance3D
var _label: Label3D
var _fx_label: Label3D
var _fx_time := 0.0


static func create(id: String) -> Enemy3D:
	var e := Enemy3D.new()
	e.type_id = id
	e.data = Content.combat.enemies[id]
	return e


func _ready() -> void:
	setup_combat(false)
	display_name = data.name
	max_hp = float(data.hp)
	hp = max_hp
	armor = float(data.get("armor", 0))
	resist = data.get("resist", {})
	max_poise = float(data.get("poise", 30))
	poise = max_poise
	move_speed = float(data.get("speed", 3.5))
	max_stamina = 100.0
	stamina = 100.0
	aggro = float(data.get("aggro", 14))
	home = global_position
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5 if data.get("model", "") != "golem" else 0.8
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	var c := Color(data.get("color", "#cccccc"))
	rig = CharacterRig.create(data.get("model", type_id), func(r): ProcModel.enemy(r, data.get("model", type_id), c))
	add_child(rig)
	_build_bars()
	facing = Vector3.BACK
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_cooldown = randf_range(0.8, 1.8)


func _build_bars() -> void:
	var h := 2.9 if data.get("elite", false) or data.get("model", "") == "golem" else 2.5
	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = NazarickTheme.display_font(700)
	_label.font_size = 36
	_label.outline_size = 8
	_label.pixel_size = 0.005
	_label.modulate = Color(1, 0.6, 0.6) if not data.get("elite", false) else Palette.GOLD_BRIGHT
	_label.position.y = h + 0.25
	_label.visible = false
	add_child(_label)
	var bg := QuadMesh.new()
	bg.size = Vector2(1.2, 0.1)
	var m_bg := B3.mat(Color(0, 0, 0, 0.7))
	m_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hpbar_bg = B3.mesh(self, bg, Vector3(0, h, 0), m_bg)
	var fg := QuadMesh.new()
	fg.size = Vector2(1.16, 0.07)
	var m_fg := StandardMaterial3D.new()
	m_fg.albedo_color = Color(0.9, 0.15, 0.2)
	m_fg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_fg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m_fg.billboard_keep_scale = true
	m_fg.no_depth_test = true
	m_bg.no_depth_test = true
	_hpbar = B3.mesh(self, fg, Vector3(0, h, 0), m_fg)
	_hpbar.visible = false
	_hpbar_bg.visible = false
	_fx_label = Label3D.new()
	_fx_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_fx_label.font = NazarickTheme.display_font(800)
	_fx_label.font_size = 48
	_fx_label.outline_size = 10
	_fx_label.pixel_size = 0.006
	_fx_label.position.y = h + 0.7
	_fx_label.no_depth_test = true
	add_child(_fx_label)


func _physics_process(delta: float) -> void:
	tick_combat(delta)
	if state == S.DEAD:
		velocity = Vector3.ZERO
		_pose(delta)
		return
	_ai(delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	velocity += knock
	move_and_slide()
	velocity -= Vector3(knock.x, 0, knock.z)
	_pose(delta)


func _ai(delta: float) -> void:
	var flat := Vector3.ZERO
	if target == null or not is_instance_valid(target) or target.state == S.DEAD:
		_move(flat, delta)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var engaged := dist < aggro or hp < max_hp
	if state == S.ATTACK:
		# Bis kurz vor Ende des Wind-ups zielen, danach Richtung festhalten (Ausweichen lohnt sich!)
		if phase == "windup" and state_time < float(attack.windup) * 0.7:
			face_towards(target.global_position, 8.0 * delta)
		if phase != "active":
			velocity.x = move_toward(velocity.x, 0, 20 * delta)
			velocity.z = move_toward(velocity.z, 0, 20 * delta)
		return
	if busy():
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		return
	if not engaged:
		var back := home - global_position
		back.y = 0.0
		_move(back.normalized() if back.length() > 1.0 else Vector3.ZERO, delta, 0.5)
		return
	face_towards(target.global_position, 6.0 * delta)
	_cooldown -= delta
	var best := _pick_attack(dist)
	if _cooldown <= 0.0 and not best.is_empty():
		if start_attack(best):
			_cooldown = randf_range(1.0, 2.2)
			_on_windup()
			return
	# Annähern, im Nahbereich umkreisen
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(1.2, 2.5)
		_strafe_dir = -_strafe_dir if randf() < 0.4 else _strafe_dir
	if dist > 2.4:
		_move(to.normalized(), delta)
	else:
		var side := to.normalized().cross(Vector3.UP) * _strafe_dir
		_move(side * 0.45 - to.normalized() * (0.3 if dist < 1.5 else 0.0), delta, 0.5)


func _pick_attack(dist: float) -> Dictionary:
	var options: Array = []
	for a in data.attacks:
		if dist <= float(a.range) + 0.4:
			options.append(a)
	if options.is_empty():
		return {}
	return options[randi() % options.size()]


func _move(dir: Vector3, delta: float, mult: float = 1.0) -> void:
	var sp := move_speed * mult * speed_mult()
	velocity.x = move_toward(velocity.x, dir.x * sp, 18 * delta)
	velocity.z = move_toward(velocity.z, dir.z * sp, 18 * delta)


func _on_windup() -> void:
	# Telegraf: Leuchten + Warnzeichen
	var red: bool = attack.get("unblockable", false)
	rig.glow(Color(1, 0.1, 0.1) if red else Color(1, 0.6, 0.15), 0.45 if red else 0.3)
	_show_fx("!" if not red else "‼", Color(1, 0.2, 0.2) if red else Color(1, 0.7, 0.2), float(attack.windup))


func _on_attack_active() -> void:
	rig.glow(Color.WHITE, 0.0)


func _on_state(s: int) -> void:
	if s != S.ATTACK and rig:
		rig.glow(Color.WHITE, 0.0)
	if s == S.DEAD:
		_hpbar.visible = false
		_hpbar_bg.visible = false
		_label.visible = false
		set_collision_layer_value(2, false)
		Audio.sfx("rebuke", 0.4)
		defeated.emit(self)


func _pose(_delta: float) -> void:
	var move := Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1)
	var prog := 0.0
	var total := 1.0
	if state == S.ATTACK and not attack.is_empty():
		var w := float(attack.windup)
		var a := float(attack.active)
		var r := float(attack.recovery)
		total = w + a + r
		match phase:
			"windup": prog = state_time / w
			"active": prog = (state_time - w) / a
			_: prog = (state_time - w - a) / r
	elif state == S.DEAD:
		prog = state_time
	elif state == S.STAGGER:
		prog = state_time / 0.75
	rig.pose(state, phase, clampf(prog, 0.0, 1.0), clampf(move, 0.0, 1.0), "heavy" if float(attack.get("damage", 0)) >= 30 else "light", total)
	rig.rotation.y = atan2(facing.x, facing.z)
	# Lebensbalken
	var show := hp < max_hp and state != S.DEAD
	_hpbar.visible = show
	_hpbar_bg.visible = show
	_label.visible = show or (target != null and is_instance_valid(target) and global_position.distance_to(target.global_position) < 8.0 and state != S.DEAD)
	_hpbar.scale.x = maxf(0.001, hp / max_hp)
	if state == S.DEAD and state_time > 2.5:
		queue_free()
	if _fx_time > 0.0:
		_fx_time -= _delta
		if _fx_time <= 0.0:
			_fx_label.text = ""


func _show_fx(text: String, color: Color, secs: float = 0.8) -> void:
	_fx_label.text = text
	_fx_label.modulate = color
	_fx_time = secs


func _feedback(text: String, color: Color) -> void:
	_show_fx(text, color, 0.8)


func _on_hurt() -> void:
	rig.flash(Color(1, 0.3, 0.3), 0.18)


func _on_parry() -> void:
	rig.flash(Palette.GOLD_BRIGHT, 0.25)

class_name Player3D
extends CharacterBody3D
## Ainz Ooal Gown in der dritten Person: WASD/Pfeiltasten, Maus dreht die Kamera,
## Shift = schneller, Leertaste = Schweben (Fly). Das Modell entsteht aus Primitiven:
## Robe, Schultern, Totenschädel mit glühenden Augen, Stab von Ainz Ooal Gown.

const SPEED := 5.0
const SPRINT := 9.0
const ACCEL := 10.0
const GRAVITY := 18.0
const FLY_UP := 6.0

var input_enabled := true
var cam_yaw := 0.0
var cam_pitch := -0.38
var cam_distance := 6.5
var model := Node3D.new()
var camera := Camera3D.new()
var _pivot := Node3D.new()
var _arm := SpringArm3D.new()
var _robe: MeshInstance3D
var _staff := Node3D.new()
var _orbs: Array[MeshInstance3D] = []
var _t := 0.0
var _move_amount := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	add_child(model)
	_build_model()
	# Kamera: Drehpunkt auf Schulterhöhe, Federarm verhindert Clipping durch Wände
	_pivot.position = Vector3(0, 1.75, 0)
	_pivot.top_level = true
	add_child(_pivot)
	_arm.spring_length = cam_distance
	_arm.margin = 0.3
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	camera.position = Vector3(0.6, 0, 0)
	camera.fov = 68.0
	camera.far = 400.0
	_arm.add_child(camera)
	camera.current = true
	_ensure_actions()


static func _ensure_actions() -> void:
	var binds := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "fly": [KEY_SPACE], "interact": [KEY_E],
	}
	for action in binds:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * 0.0035
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.003, -1.2, 0.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = maxf(2.5, cam_distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = minf(11.0, cam_distance + 0.5)
		elif event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var flying := false
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (Basis(Vector3.UP, cam_yaw) * Vector3(iv.x, 0, iv.y))
		flying = Input.is_action_pressed("fly")
	var speed := SPRINT if input_enabled and Input.is_action_pressed("sprint") else SPEED
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, minf(1.0, ACCEL * delta))
	velocity.z = lerpf(velocity.z, target.z, minf(1.0, ACCEL * delta))
	if flying and position.y < 6.0:
		velocity.y = lerpf(velocity.y, FLY_UP, minf(1.0, 4.0 * delta))
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta * (0.35 if Input.is_action_pressed("fly") else 1.0)
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()
	# Modell dreht sich in Laufrichtung
	var flat := Vector2(velocity.x, velocity.z)
	_move_amount = clampf(flat.length() / SPRINT, 0.0, 1.0)
	if flat.length() > 0.3:
		var want := atan2(velocity.x, velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, want, minf(1.0, 10.0 * delta))
	_pivot.global_position = global_position + Vector3(0, 1.75, 0)
	_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	_arm.spring_length = lerpf(_arm.spring_length, cam_distance, minf(1.0, 6.0 * delta))


func _process(delta: float) -> void:
	_t += delta
	# Gehen: leichtes Wippen; Stillstand: majestätisches Atmen
	var bob := sin(_t * 9.0) * 0.05 * _move_amount + sin(_t * 1.6) * 0.015
	model.position.y = bob
	if _robe:
		_robe.rotation.x = -_move_amount * 0.12
	_staff.rotation.x = -_move_amount * 0.25
	for i in _orbs.size():
		var a := _t * 1.4 + TAU * i / _orbs.size()
		_orbs[i].position = Vector3(cos(a) * 0.2, 2.25 + sin(_t * 2.0 + i) * 0.03, sin(a) * 0.2)


## Blick der Kamera direkt hinter Ainz ausrichten (nach Teleport).
func face(yaw: float) -> void:
	cam_yaw = yaw
	model.rotation.y = yaw + PI


func _build_model() -> void:
	var robe_m := B3.mat(Color(0.05, 0.03, 0.07), 0.75, 0.1)
	var trim := B3.mat(Color(0.85, 0.66, 0.22), 0.3, 0.9)
	var violet := B3.mat(Color(0.22, 0.07, 0.32), 0.5, 0.2, Color(0.3, 0.05, 0.5), 0.3)
	var bone := B3.mat(Color(0.88, 0.85, 0.76), 0.6)
	var red := B3.mat(Color(1, 0.15, 0.1), 1.0, 0.0, Color(1, 0.1, 0.05), 6.0)
	# Robe (Kegelstumpf) mit Goldsaum und violettem Innenfutter
	_robe = B3.cyl(model, 0.3, 0.62, 1.55, Vector3(0, 0.78, 0), robe_m, false, 18)
	B3.cyl(model, 0.63, 0.64, 0.08, Vector3(0, 0.05, 0), trim, false, 18)
	# Goldene Borte vorne und violettes Futter am Saum
	B3.box(model, Vector3(0.12, 1.45, 0.05), Vector3(0, 0.8, 0.47), trim, false, Vector3(-11, 0, 0))
	B3.cyl(model, 0.6, 0.63, 0.12, Vector3(0, 0.14, 0), violet, false, 18)
	# Umhang über den Rücken
	B3.box(model, Vector3(0.9, 1.6, 0.06), Vector3(0, 0.95, -0.42), robe_m, false, Vector3(12, 0, 0))
	B3.box(model, Vector3(0.92, 0.06, 0.08), Vector3(0, 0.16, -0.58), trim, false, Vector3(12, 0, 0))
	# Schultern mit Dornen
	for s in [-1.0, 1.0]:
		B3.sphere(model, 0.24, Vector3(0.36 * s, 1.55, 0), robe_m, Vector3(1.2, 0.8, 1.1))
		B3.cone(model, 0.05, 0.35, Vector3(0.42 * s, 1.68, 0), trim).rotation_degrees.z = -25.0 * s
		B3.cyl(model, 0.05, 0.07, 0.75, Vector3(0.45 * s, 1.15, 0.08), robe_m, false, 8).rotation_degrees.z = 8.0 * s
		B3.sphere(model, 0.07, Vector3(0.5 * s, 0.75, 0.15), bone)
	# Hoher Kragen
	B3.cyl(model, 0.34, 0.24, 0.35, Vector3(0, 1.78, -0.04), violet, false, 14)
	# Totenschädel mit roten Augenlichtern
	B3.sphere(model, 0.19, Vector3(0, 1.98, 0.02), bone, Vector3(0.95, 1.05, 1.0))
	B3.sphere(model, 0.12, Vector3(0, 1.86, 0.08), bone, Vector3(0.9, 0.7, 1.0))
	for s in [-1.0, 1.0]:
		B3.sphere(model, 0.035, Vector3(0.07 * s, 1.99, 0.17), red)
	var eye := B3.light(model, Vector3(0, 2.0, 0.3), Color(1, 0.15, 0.1), 0.8, 2.5)
	eye.shadow_enabled = false
	# Kapuze hinter dem Kopf
	B3.sphere(model, 0.26, Vector3(0, 2.0, -0.08), robe_m, Vector3(1.05, 1.1, 1.0))
	# Kugel der Herrschaft (rotes Juwel auf der Brust)
	B3.sphere(model, 0.08, Vector3(0, 1.45, 0.27), B3.mat(Color(0.9, 0.05, 0.1), 0.1, 0.3, Color(1, 0, 0.1), 3.0))
	# Stab von Ainz Ooal Gown
	_staff.position = Vector3(0.55, 0, 0.18)
	model.add_child(_staff)
	B3.cyl(_staff, 0.03, 0.03, 2.2, Vector3(0, 1.1, 0), trim, false, 8)
	for i in 3:
		var snake := B3.cyl(_staff, 0.012, 0.012, 0.5, Vector3(0, 2.25, 0), trim, false, 6)
		snake.rotation_degrees = Vector3(0, i * 60, 50)
	var cols := [Color(1, 0.2, 0.2), Color(0.3, 0.6, 1), Color(0.3, 1, 0.4), Color(1, 0.9, 0.3), Color(0.8, 0.3, 1), Color(1, 0.5, 0.1), Color(0.9, 0.9, 1)]
	for c in cols:
		_orbs.append(B3.sphere(_staff, 0.055, Vector3.ZERO, B3.mat(c, 0.1, 0.2, c, 3.0)))
	B3.light(_staff, Vector3(0, 2.25, 0), Color(0.7, 0.5, 1.0), 1.0, 3.5)
	# Dunkle Aura
	B3.motes(model, Vector3(0, 0.6, 0), Vector3(0.6, 0.5, 0.6), Color(0.5, 0.15, 0.8), 18)

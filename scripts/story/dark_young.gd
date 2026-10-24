class_name DarkYoung
extends Node3D
## Dunkles Junges (Beschwörung von »Iä Shub-Niggurath«): ein haushohes Wesen aus schwarzem Fleisch auf fünf
## Ziegenbeinen mit Hufen, aus dem sich Tentakel winden; Mäuler mit Zahnkränzen geifern grünen Schleim.
## Ganz prozedural (keine Modelldatei): Körper, Tentakel und Beine mit assets/shaders/dark_young.gdshader,
## Gang, Stampfen (Staub, Beben), Aufsteigen aus dem Boden und Brüllen per Skript.

const LEGS := 5
const TENTACLES := 10
const MOUTHS := 7
const HIP_Y := 4.1

var walking := false
var stomp_shake := 0.12            ## Beben je Huftritt (in der Nähe der Kamera)
var on_stomp: Callable             ## (Welt-Position) – z. B. Soldaten zertrampeln

var _body: Node3D
var _model: Node3D                 ## echtes Modell (assets/models/characters/dark_young.glb), sonst null
var _anim: AnimationPlayer         ## Animationen des Modells: Idle, Walk, Roar, Hit, Death
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _hooves: Array[Node3D] = []
var _down: Array[bool] = []
var _mats: Array[ShaderMaterial] = []
var _walk := 0.0
var _t := 0.0
var _move_tw: Tween
var _ground_ray := true


static func spawn(parent: Node, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> DarkYoung:
	var d := DarkYoung.new()
	d.name = "DunklesJunges"
	parent.add_child(d)
	d.global_position = at
	d.rotation.y = yaw
	d.scale = Vector3.ONE * size
	d._build(randi())
	return d


func _material(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/dark_young.gdshader")
	m.set_shader_parameter("mode", mode)
	_mats.append(m)
	return m


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _build(seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# Echtes Modell (10 m hoch, Tripo-Modell mit Tentakel- und Beinrig aus tools/pipeline/build_darkyoung.py):
	# Gang, Stampfen, Beben und Brüllen laufen weiter über dieses Skript, die Glieder über die Animationen des Modells.
	_model = ModelLib.instance("characters", "dark_young")
	if _model:
		_body = Node3D.new()
		add_child(_body)
		_body.add_child(_model)
		var players := _model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_anim = players[0]
			for n in ["Idle", "Walk"]:
				if _anim.has_animation(n):
					_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			_anim.play("Idle")
		for i in LEGS:
			_down.append(true)
		return
	var body_mat := _material(0)
	var tent_mat := _material(1)
	var leg_mat := _material(2)
	_body = Node3D.new()
	add_child(_body)
	# Körper: Hauptklumpen und Auswüchse (unregelmäßige Silhouette wie ein verwachsener Baumstumpf)
	var sph := SphereMesh.new()
	sph.radial_segments = 48
	sph.rings = 24
	var core := _mi(_body, sph, body_mat, Vector3(0, 5.7, 0), Vector3(2.3, 2.8, 2.1))
	core.set_instance_shader_parameter("phase", rng.randf() * 10.0)
	for k in 4:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 1.3, rng.randf_range(4.6, 7.6), sin(a) * 1.2)
		var blob := _mi(_body, sph, body_mat, p, Vector3.ONE * rng.randf_range(1.1, 1.6))
		blob.set_instance_shader_parameter("phase", rng.randf() * 10.0)
	# Tentakel: aus dem oberen Körper, nach außen und oben, mit Durchhängen
	for i in TENTACLES:
		var a := TAU * i / TENTACLES + rng.randf_range(-0.25, 0.25)
		var up := rng.randf_range(0.15, 0.95)
		var dir := Vector3(cos(a) * (1.0 - up * 0.6), up, sin(a) * (1.0 - up * 0.6)).normalized()
		var base := Vector3(0, 5.7, 0) + Vector3(dir.x * 1.9, dir.y * 2.2 + rng.randf_range(0.0, 1.2), dir.z * 1.7)
		var pivot := Node3D.new()
		_body.add_child(pivot)
		pivot.position = base
		pivot.basis = _basis_y(dir)
		var length := rng.randf_range(4.0, 7.0)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = rng.randf_range(0.32, 0.5)
		cyl.height = length
		cyl.radial_segments = 12
		cyl.rings = 26
		var t := _mi(pivot, cyl, tent_mat, Vector3(0, length * 0.5, 0))
		t.set_instance_shader_parameter("phase", rng.randf() * 20.0)
		t.set_instance_shader_parameter("t_len", length)
	# Ziegenbeine mit Hufen (Knie nach hinten), im Kreis unter dem Körper
	var hoof_mat := B3.mat(Color(0.02, 0.018, 0.02), 0.2, 0.0)
	for i in LEGS:
		var a := TAU * i / LEGS + 0.3
		var hip := Node3D.new()
		_body.add_child(hip)
		hip.position = Vector3(cos(a) * 1.15, HIP_Y, sin(a) * 1.05)
		hip.rotation.y = -a + PI * 0.5             # lokales +Z zeigt nach außen
		var thigh := Node3D.new()
		hip.add_child(thigh)
		var c1 := CylinderMesh.new()
		c1.top_radius = 0.46
		c1.bottom_radius = 0.3
		c1.height = 2.2
		c1.radial_segments = 12
		c1.rings = 6
		var tm := _mi(thigh, c1, leg_mat, Vector3(0, -1.1, 0))
		tm.set_instance_shader_parameter("phase", rng.randf() * 10.0)
		var knee := Node3D.new()
		knee.position = Vector3(0, -2.2, 0)
		thigh.add_child(knee)
		var c2 := CylinderMesh.new()
		c2.top_radius = 0.3
		c2.bottom_radius = 0.2
		c2.height = 2.1
		c2.radial_segments = 10
		c2.rings = 6
		_mi(knee, c2, leg_mat, Vector3(0, -1.05, 0))
		var hoof := Node3D.new()
		hoof.position = Vector3(0, -2.1, 0)
		knee.add_child(hoof)
		var c3 := CylinderMesh.new()
		c3.top_radius = 0.24
		c3.bottom_radius = 0.34
		c3.height = 0.42
		c3.radial_segments = 10
		_mi(hoof, c3, hoof_mat, Vector3(0, -0.12, 0.04))
		_hips.append(thigh)
		_knees.append(knee)
		_hooves.append(hoof)
		_down.append(true)
	# Mäuler: dunkler Schlund, wulstige Lippen, Zahnkranz, grüner Geifer
	var inner := B3.mat(Color(0.14, 0.0, 0.03), 0.3, 0.0, Color(0.35, 0.02, 0.05), 0.7)
	var tooth := B3.mat(Color(0.82, 0.78, 0.62), 0.35)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.56
	torus.rings = 16
	torus.ring_segments = 8
	for i in MOUTHS:
		var a := TAU * i / MOUTHS + rng.randf_range(-0.3, 0.3)
		var phi := rng.randf_range(-0.45, 0.6)
		var e := Vector3(2.3 * cos(phi) * cos(a), 2.8 * sin(phi), 2.1 * cos(phi) * sin(a))
		var n := Vector3(e.x / 5.29, e.y / 7.84, e.z / 4.41).normalized()
		var surf := Vector3(0, 5.7, 0) + e + n * 0.12
		var m := Node3D.new()
		_body.add_child(m)
		m.position = surf
		m.basis = _basis_y(n)
		m.scale = Vector3.ONE * rng.randf_range(0.75, 1.15)
		_mi(m, sph, inner, Vector3(0, -0.02, 0), Vector3(0.42, 0.14, 0.3))
		var lips := _mi(m, torus, body_mat, Vector3.ZERO, Vector3(1.0, 1.0, 0.72))
		lips.set_instance_shader_parameter("phase", rng.randf() * 10.0)
		for k in 9:
			var ta := TAU * k / 9.0
			var tc := B3.cone(m, 0.05, 0.22, Vector3(cos(ta) * 0.36, 0.06, sin(ta) * 0.26), tooth)
			tc.basis = _basis_y(Vector3(-cos(ta) * 0.8, 0.6, -sin(ta) * 0.8))
		if i % 2 == 0:
			_drool(m)


## Basis, deren +Y in Richtung `d` zeigt.
static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Grüner Geifer, der aus einem Maul tropft.
func _drool(at: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.8
	p.randomness = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.gravity = Vector3(0, -9.0, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.6
	pm.scale_min = 0.05
	pm.scale_max = 0.13
	p.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.4
	drop.radial_segments = 6
	drop.rings = 4
	drop.material = B3.mat(Color(0.32, 0.55, 0.08), 0.15, 0.0, Color(0.25, 0.5, 0.05), 0.8)
	p.draw_pass_1 = drop
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -12, -4), Vector3(8, 14, 8))
	at.add_child(p)


func _process(delta: float) -> void:
	_t += delta
	# Atmen/Wogen
	_body.position.y = sin(_t * 1.1) * 0.12 + (sin(_walk * 2.0) * 0.18 if walking else 0.0)
	_body.rotation.z = sin(_t * 0.7) * 0.03
	if walking:
		_walk += delta * 3.2
	if _anim:
		# Modell: Gang-/Ruheanimation nach Zustand, Brüllen läuft zu Ende; Huftritte im Takt des Gangs
		var want := "Walk" if walking else "Idle"
		var roaring := _anim.current_animation == "Roar" and _anim.is_playing()
		if not roaring and _anim.current_animation != want and _anim.has_animation(want):
			_anim.play(want, 0.3)
		for i in LEGS:
			var ph := _walk + i * TAU * 2.0 / LEGS
			var down := (maxf(0.0, sin(ph)) if walking else 0.0) < 0.05
			if down and not _down[i] and walking:
				var a := TAU * i / LEGS + 0.3
				_stomp(global_position + Basis(Vector3.UP, rotation.y) * Vector3(cos(a) * 2.6 * scale.x, 0.0, sin(a) * 2.6 * scale.z))
			_down[i] = down
	for i in (0 if _anim else LEGS):
		var ph := _walk + i * TAU * 2.0 / LEGS
		var lift := maxf(0.0, sin(ph)) if walking else 0.0
		# Grundhaltung: Oberschenkel nach außen, Unterschenkel zurück (Ziegenbein); beim Heben stärker angewinkelt
		_hips[i].rotation.x = -0.55 - lift * 0.35
		_knees[i].rotation.x = 0.9 + lift * 0.7
		var down := lift < 0.05
		if down and not _down[i] and walking:
			_stomp(_hooves[i].global_position)
		_down[i] = down
	if _ground_ray and is_inside_tree():
		var g := CombatFX._ground_below(get_parent(), global_position + Vector3.UP * 12.0)
		if g != Vector3.INF:
			global_position.y = lerpf(global_position.y, g.y, minf(1.0, delta * 6.0))


func _stomp(at: Vector3) -> void:
	CombatFX.burst(get_parent(), "dust_ring", at + Vector3.UP * 0.1, Color(0.32, 0.29, 0.25), Vector3.UP, 1.4)
	CombatFX.sound("stomp", at, 0.55, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(at)
		CombatFX.shake(stomp_shake * clampf(1.0 - d / 60.0, 0.0, 1.0))
	if on_stomp.is_valid():
		on_stomp.call(at)


## Steigt aus dem Boden (Erde bricht auf, Staub, Beben) und brüllt.
func rise(dur: float = 3.0) -> void:
	_ground_ray = false
	var target := global_position
	global_position = target - Vector3.UP * 10.0 * scale.y
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _ground_ray = true)
	for k in 4:
		get_tree().create_timer(dur * k / 4.0, false).timeout.connect(func():
			CombatFX.burst(get_parent(), "dust_ring", target + Vector3.UP * 0.2, Color(0.3, 0.27, 0.24), Vector3.UP, 2.6)
			CombatFX.burst(get_parent(), "stone", target + Vector3.UP * 0.5, Color(0.28, 0.25, 0.22), Vector3.UP, 2.0)
			CombatFX.shake(0.25))
	get_tree().create_timer(dur * 0.7, false).timeout.connect(roar)


## Brüllen: der Körper bläht sich, die Tentakel peitschen.
func roar() -> void:
	CombatFX.sound("dark_young_roar", global_position + Vector3.UP * 6.0, 1.3, 0.0)
	var tw := create_tween()
	tw.tween_method(_set_pulse, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_method(_set_pulse, 1.0, 0.0, 0.9)
	CombatFX.shake(0.3)


func _set_pulse(v: float) -> void:
	if _anim:
		# Modell: beim Brüllen die Brüll-Animation anstoßen, der Körper bläht sich leicht
		if v > 0.5 and _anim.current_animation != "Roar" and _anim.has_animation("Roar"):
			_anim.play("Roar", 0.15)
		_body.scale = Vector3.ONE * (1.0 + v * 0.06)
		return
	for m in _mats:
		m.set_shader_parameter("pulse", v)
		m.set_shader_parameter("writhe", 1.0 + v * 0.9)


## Stapft zum Ziel (Welt-Position) – dreht sich hin, läuft `dur` Sekunden.
func walk_to(target: Vector3, dur: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return
	var yaw := atan2(to.x, to.z)
	var tw0 := create_tween()
	tw0.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), 0.6)
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	walking = true
	var from := global_position
	_move_tw = create_tween()
	_move_tw.tween_method(func(k: float):
		var p := from.lerp(Vector3(target.x, from.y, target.z), k)
		global_position = Vector3(p.x, global_position.y, p.z), 0.0, 1.0, dur)
	_move_tw.tween_callback(func(): walking = false)

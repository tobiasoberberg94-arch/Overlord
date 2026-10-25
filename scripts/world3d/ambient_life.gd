class_name AmbientLife
extends Node3D
## Leben in der Kulisse, je nach Ortsart: kreisende Vogelschwärme, Schmetterlinge über Wiesen, fallendes Laub
## im Wald, Glühwürmchen bei Nacht/im Moor, Rauch aus Kaminen in Dörfern und Städten.
## Alles folgt grob dem Spieler (Partikel um die Kamera), damit es überall lebt, aber wenig kostet.

const KINDS := {
	"grassland": ["birds", "butterflies"], "village": ["birds", "butterflies", "smoke"], "city": ["birds", "smoke"],
	"palace": ["birds", "smoke"], "cathedral": ["birds", "smoke"], "wall": ["birds", "smoke"], "forest": ["birds", "leaves", "butterflies"],
	"jungle": ["birds", "butterflies", "fireflies"], "swamp": ["fireflies", "birds"], "cemetery": ["fireflies"],
	"battlefield": ["crows"], "mountain": ["birds"], "peaks": ["crows"], "glacier": [],
	"throne": ["dust"], "library": ["dust"], "royal": ["dust"], "tombs": ["wisps", "dust"], "treasury": ["sparkle", "dust"],
	"lava": ["embers"],
}

var _birds: Array = []        ## {node, wing_l, wing_r, center, radius, speed, height, phase}
var _follow: Array[Node3D] = []
var _t := 0.0


static func create(loc: Dictionary, scene: Node3D) -> AmbientLife:
	var kinds: Array = KINDS.get(loc.get("kind", ""), [])
	if kinds.is_empty() or not Settings.particles:
		return null
	var a := AmbientLife.new()
	a.name = "Umgebungsleben"
	scene.add_child(a)
	for k in kinds:
		match k:
			"birds": a._flock(Color(0.16, 0.14, 0.13), 3, 9)
			"crows": a._flock(Color(0.05, 0.05, 0.06), 2, 7)
			"butterflies": a._particles_follow(_butterflies())
			"leaves": a._particles_follow(_leaves())
			"fireflies": a._particles_follow(_fireflies())
			"smoke": a._smoke(scene)
			"dust": a._particles_follow(_motes(Color(1.0, 0.92, 0.75), 160, 0.025, 1.5, 2.5))
			"wisps": a._particles_follow(_motes(Color(0.55, 0.85, 1.0), 26, 0.12, 5.0, 1.4))
			"sparkle": a._particles_follow(_motes(Color(1.0, 0.85, 0.35), 80, 0.04, 6.0, 1.0))
			"embers": a._particles_follow(_embers())
	return a


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		for f in _follow:
			f.global_position = cam.global_position * Vector3(1, 0, 1) + Vector3(0, f.get_meta("y", 0.0), 0)
	for b in _birds:
		var ph: float = b.phase + _t * b.speed / b.radius
		var c: Vector3 = b.center
		var p := c + Vector3(cos(ph) * b.radius, b.height + sin(_t * 0.4 + b.phase) * 3.0, sin(ph) * b.radius)
		var n: Node3D = b.node
		n.global_position = p
		n.look_at(p + Vector3(-sin(ph), 0, cos(ph)) * (1.0 if b.speed > 0 else -1.0), Vector3.UP)
		n.rotate_object_local(Vector3.FORWARD, 0.25)
		# Flügelschlag mit Gleitphasen
		var flap := sin(_t * 9.0 + b.phase * 5.0) * (0.15 + 0.85 * clampf(sin(_t * 0.7 + b.phase) + 0.3, 0.0, 1.0))
		(b.wing_l as Node3D).rotation.z = 0.15 + flap * 0.8
		(b.wing_r as Node3D).rotation.z = -0.15 - flap * 0.8


# ------------------------------------------------------------------ Vögel

func _flock(col: Color, flocks: int, per: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for f in flocks:
		var center := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		var radius := rng.randf_range(35, 80)
		var height := rng.randf_range(28, 50)
		var speed := rng.randf_range(7.0, 11.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var base := rng.randf() * TAU
		for i in per:
			var root := Node3D.new()
			add_child(root)
			var body := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.1, 0.45)
			body.mesh = bm
			body.material_override = mat
			root.add_child(body)
			var wings := []
			for side in [-1, 1]:
				var piv := Node3D.new()
				root.add_child(piv)
				var w := MeshInstance3D.new()
				var wm := BoxMesh.new()
				wm.size = Vector3(0.6, 0.02, 0.22)
				w.mesh = wm
				w.material_override = mat
				w.position = Vector3(0.32 * side, 0, 0.02)
				piv.add_child(w)
				wings.append(piv)
			root.scale = Vector3.ONE * rng.randf_range(1.6, 2.2)
			_birds.append({"node": root, "wing_l": wings[0], "wing_r": wings[1], "center": center + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)),
				"radius": radius + rng.randf_range(-5, 5), "speed": speed, "height": height + rng.randf_range(-3, 3), "phase": base + i * 0.12 + rng.randf() * 0.05})


# ------------------------------------------------------------------ Partikel um den Spieler

func _particles_follow(p: GPUParticles3D) -> void:
	add_child(p)
	_follow.append(p)


static func _quad_mat(col: Color, emissive: float, tex_round: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emissive > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emissive
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex_round or emissive > 0.0:
		# leuchtende Punkte (Glut, Glühwürmchen, Funken) weich und rund statt quadratisch
		m.albedo_texture = _soft_dot()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _proc(amount: int, life: float, box: Vector3, vel: Vector2, grav: Vector3) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.spread = 180.0
	pm.gravity = grav
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.15
	pm.turbulence_influence_max = 0.35
	return pm


static func _butterflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 8, 80))
	var pm := _proc(40, 9.0, Vector3(28, 0.8, 28), Vector2(0.4, 1.0), Vector3(0, 0.02, 0))
	pm.color = Color.WHITE
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.2))
	g.set_color(1, Color(0.95, 0.95, 1.0))
	g.add_point(0.5, Color(0.9, 0.45, 0.9))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.11, 0.09)
	qm.material = _critter_mat(_butterfly_tex(), true)
	p.draw_pass_1 = qm
	p.set_meta("y", 1.0)
	return p


static func _leaves() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 24, 80))
	var pm := _proc(120, 10.0, Vector3(30, 2, 30), Vector2(0.1, 0.4), Vector3(0.3, -0.45, 0.1))
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.45, 0.12))
	g.set_color(1, Color(0.55, 0.62, 0.2))
	g.add_point(0.5, Color(0.9, 0.7, 0.2))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.1)
	qm.material = _critter_mat(_leaf_tex(), false)
	p.draw_pass_1 = qm
	p.set_meta("y", 14.0)
	return p


static func _fireflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 8, 80))
	var pm := _proc(90, 6.0, Vector3(26, 1.4, 26), Vector2(0.1, 0.4), Vector3.ZERO)
	pm.color = Color(0.85, 1.0, 0.45)
	var a := Curve.new()
	a.add_point(Vector2(0, 0))
	a.add_point(Vector2(0.3, 1))
	a.add_point(Vector2(0.7, 1))
	a.add_point(Vector2(1, 0))
	var ac := CurveTexture.new()
	ac.curve = a
	pm.scale_curve = ac
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var fm := _quad_mat(Color(0.85, 1.0, 0.45), 6.0)
	fm.albedo_texture = _soft_dot()
	qm.material = fm
	p.draw_pass_1 = qm
	p.set_meta("y", 1.2)
	return p


## Schwebende Teilchen (Staub im Licht, Geisterlichter, Goldglitzern): langsam, leuchtend, um die Kamera.
static func _motes(col: Color, amount: int, size: float, glow: float, y: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.visibility_aabb = AABB(Vector3(-30, -3, -30), Vector3(60, 12, 60))
	var pm := _proc(amount, 8.0, Vector3(18, 2.5, 18), Vector2(0.02, 0.12), Vector3(0, 0.01, 0))
	pm.turbulence_noise_strength = 0.6
	var a := Curve.new()
	a.add_point(Vector2(0, 0))
	a.add_point(Vector2(0.25, 1))
	a.add_point(Vector2(0.75, 1))
	a.add_point(Vector2(1, 0))
	var ac := CurveTexture.new()
	ac.curve = a
	pm.scale_curve = ac
	pm.color = col
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := _quad_mat(col, glow)
	m.albedo_texture = _soft_dot()
	qm.material = m
	p.draw_pass_1 = qm
	p.set_meta("y", y)
	return p


static func _embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 110
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 12, 60))
	# langsam aufsteigend und taumelnd, nach 1–4 m verglüht (schnelle, grelle Punkte zogen Spuren in den Himmel)
	var pm := _proc(110, 3.0, Vector3(22, 0.4, 22), Vector2(0.2, 0.6), Vector3(0, 0.35, 0))
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.12
	pm.lifetime_randomness = 0.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.3))
	g.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	qm.material = _quad_mat(Color(1.0, 0.6, 0.2), 3.0, true)
	p.draw_pass_1 = qm
	p.set_meta("y", 0.0)
	return p


# ------------------------------------------------------------------ Kaminrauch

func _smoke(scene: Node3D) -> void:
	var n := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name).to_lower()
		if not (nm.contains("house") or nm.contains("build") or nm.contains("chimney") or nm.contains("accoms")):
			continue
		if n >= 14 or randf() > 0.45:
			continue
		var aabb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		if aabb.size.y < 4.0 or aabb.size.y > 40.0:
			continue
		var top := Vector3(aabb.position.x + aabb.size.x * randf_range(0.3, 0.7), aabb.end.y - 0.3, aabb.position.z + aabb.size.z * randf_range(0.3, 0.7))
		var p := GPUParticles3D.new()
		p.amount = 24
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 24, 16))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.2, 1, 0)
		pm.spread = 10.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.1
		pm.gravity = Vector3(0.35, 0.15, 0.1)
		pm.scale_min = 1.2
		pm.scale_max = 2.2
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 2.6))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		var g := Gradient.new()
		g.set_color(0, Color(0.5, 0.48, 0.46, 0.45))
		g.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		p.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_dot()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.material = m
		p.draw_pass_1 = qm
		add_child(p)
		p.global_position = top
		n += 1


static var _dot: Texture2D
static var _bfly: Texture2D
static var _leaf: Texture2D


static func _critter_mat(t: Texture2D, flapping: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/critter.gdshader")
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("flap", 1.0 if flapping else 0.0)
	return m


## Schmetterling: zwei Flügelpaare (oben groß, unten klein), dunkler Rand, Flecken, schmaler Körper.
static func _butterfly_tex() -> Texture2D:
	if _bfly:
		return _bfly
	var n := 64
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := absf((x + 0.5) / n * 2.0 - 1.0)
			var v := (y + 0.5) / n * 2.0 - 1.0
			var e1 := Vector2((u - 0.48) / 0.48, (v + 0.28) / 0.42).length()
			var e2 := Vector2((u - 0.36) / 0.32, (v - 0.38) / 0.3).length()
			var e := minf(e1, e2)
			var c := Color(0, 0, 0, 0)
			if e < 1.0:
				var w := 1.0 - smoothstep(0.72, 1.0, e) * 0.75          # dunkler Rand
				var spot := 1.0 - (1.0 - smoothstep(0.08, 0.13, Vector2(u - 0.62, v + 0.3).length())) * 0.7
				c = Color(w * spot, w * spot, w * spot, 1.0)
			if u < 0.06 and absf(v) < 0.62:
				c = Color(0.12, 0.09, 0.06, 1.0)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_bfly = ImageTexture.create_from_image(img)
	return _bfly


## Blatt: spitz zulaufend, Mittelrippe, Farbe kommt aus der Partikelfarbe.
static func _leaf_tex() -> Texture2D:
	if _leaf:
		return _leaf
	var n := 64
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var half_w := 0.55 * (1.0 - v * v) * (1.0 - 0.25 * v)
			var c := Color(0, 0, 0, 0)
			if absf(u) < half_w:
				var shade := 0.75 + 0.25 * (absf(u) / maxf(half_w, 0.01))
				if absf(u) < 0.04:
					shade = 0.6
				c = Color(shade, shade, shade, 1.0)
			if absf(u) < 0.03 and v > 0.85:
				c = Color(0.35, 0.3, 0.2, 1.0)                      # Stiel
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_leaf = ImageTexture.create_from_image(img)
	return _leaf


static func _soft_dot() -> Texture2D:
	if _dot:
		return _dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	_dot = ImageTexture.create_from_image(img)
	return _dot

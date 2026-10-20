class_name GrassBlades
## Büschel-Meshes für das GrassField: spitz zulaufende, gebogene Halme mit gerundeten Normalen
## (wirken plastisch statt flach) und Wildblumen mit fünfblättrigen Blüten.
## Farbattribut: r = Höhe am Halm (0…1), g = Zufall je Halm, b = 1 bei Blütenblatt, a = Blütenfarbe.

static var _cache: Dictionary = {}
const SHADER := "res://assets/shaders/grass_field.gdshader"


static func _material(tint: Dictionary) -> ShaderMaterial:
	var key := "mat" + str(tint.hash())
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	for k in tint:
		mat.set_shader_parameter(k, tint[k])
	_cache[key] = mat
	return mat


static func tuft(blades: int, segs: int, radius: float, tint: Dictionary = {}) -> ArrayMesh:
	var key := "t%d_%d_%f_%d" % [blades, segs, radius, tint.hash()]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + blades
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in blades:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var height := rng.randf_range(0.22, 0.78) * (1.15 - r / radius * 0.35)
		if rng.randf() < 0.08:
			height *= 1.45                                   # einzelne hohe Halme/Rispen
		var width := rng.randf_range(0.012, 0.024)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face))
		var out := Vector3(-side.z, 0, side.x)
		if out.dot(base) < 0.0:
			out = -out
		var lean := out * rng.randf_range(0.08, 0.32) * height
		var g := rng.randf()
		var prev: Array = []
		for i in segs + 1:
			var t := float(i) / segs
			var c := base + Vector3(0, height * t, 0) + lean * t * t
			var w := width * (1.0 - pow(t, 1.6))
			# Halm leicht v-förmig gefaltet + gerundete Normalen
			var fold := out * w * 0.35
			var l := c - side * w + fold
			var rr := c + side * w + fold
			var dir := (Vector3(0, height, 0) + lean * 2.0 * t).normalized()
			var nrm := side.cross(dir).normalized()
			if nrm.dot(out) < 0.0:
				nrm = -nrm
			var nl := (nrm - side * 0.55).normalized()
			var nr := (nrm + side * 0.55).normalized()
			if i > 0:
				var pl: Vector3 = prev[0]
				var pr: Vector3 = prev[1]
				var t0: float = prev[2]
				var pnl: Vector3 = prev[3]
				var pnr: Vector3 = prev[4]
				_v(st, pl, pnl, t0, g)
				_v(st, pr, pnr, t0, g)
				_v(st, rr, nr, t, g)
				_v(st, pl, pnl, t0, g)
				_v(st, rr, nr, t, g)
				_v(st, l, nl, t, g)
			prev = [l, rr, t, nl, nr]
	var m := st.commit()
	m.surface_set_material(0, _material(tint))
	_cache[key] = m
	return m


static func flowers(tint: Dictionary = {}) -> ArrayMesh:
	var key := "f" + str(tint.hash())
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := float(rng.randi_range(0, 4)) / 4.0
	for f in 3:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.16
		var h := rng.randf_range(0.32, 0.55)
		var c := Vector3(cos(a) * r, h, sin(a) * r)
		var g := rng.randf()
		# Stängel (zwei gekreuzte schmale Flächen)
		for d in [Vector3(0.006, 0, 0), Vector3(0, 0, 0.006)]:
			var b0 := Vector3(c.x, 0, c.z)
			_v(st, b0 - d, Vector3.UP, 0.0, g); _v(st, b0 + d, Vector3.UP, 0.0, g); _v(st, c + d, Vector3.UP, 0.8, g)
			_v(st, b0 - d, Vector3.UP, 0.0, g); _v(st, c + d, Vector3.UP, 0.8, g); _v(st, c - d, Vector3.UP, 0.8, g)
		# Blüte: 5 Blätter, leicht nach oben geneigt, Mitte als kleine Scheibe
		var s := rng.randf_range(0.028, 0.045)
		col = float((f + rng.randi_range(0, 4)) % 5) / 4.0
		for p in 5:
			var pa := TAU * p / 5.0 + rng.randf() * 0.3
			var dir := Vector3(cos(pa), 0.35, sin(pa)).normalized()
			var perp := Vector3(-sin(pa), 0, cos(pa)) * s * 0.55
			var tip := c + dir * s * 1.6
			for v in [c, c + dir * s * 0.8 + perp, tip, c, tip, c + dir * s * 0.8 - perp]:
				st.set_color(Color(1.0, g, 1.0, col))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		for p in 6:
			var a0 := TAU * p / 6.0
			var a1 := TAU * (p + 1) / 6.0
			for v in [c + Vector3(0, 0.004, 0), c + Vector3(cos(a0), 0.5, sin(a0)) * s * 0.35, c + Vector3(cos(a1), 0.5, sin(a1)) * s * 0.35]:
				st.set_color(Color(1.0, g, 1.0, 0.25))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var m := st.commit()
	m.surface_set_material(0, _material(tint))
	_cache[key] = m
	return m


static func _v(st: SurfaceTool, p: Vector3, n: Vector3, h: float, g: float) -> void:
	st.set_color(Color(h, g, 0.0, 0.0))
	st.set_normal(n)
	st.add_vertex(p)

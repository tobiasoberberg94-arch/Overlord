class_name Grass
## Prozedurale Grasbüschel und Wildblumen für die Wiesen der Ortsmodelle (Positionen aus
## <ort>_scatter.json unter „@grass“/„@flower“). Ein Büschel = viele gebogene Halme, Farbe/Wind im Shader.

static var _cache: Dictionary = {}


static func tuft(flower: bool) -> ArrayMesh:
	var key := "flower" if flower else "grass"
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 if flower else 13
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := 12 if flower else 18
	for b in blades:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.28
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var height := rng.randf_range(0.3, 0.75)
		var width := rng.randf_range(0.025, 0.045)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * width
		var lean := Vector3(-sin(face), 0, cos(face)) * rng.randf_range(0.05, 0.2) + base.normalized() * 0.08
		var g := rng.randf()
		var seg := 3
		var prev_l := base - side
		var prev_r := base + side
		for i in range(1, seg + 1):
			var t := float(i) / seg
			var c := base + Vector3(0, height * t, 0) + lean * t * t
			var w := 1.0 - t
			var l := c - side * w
			var rr := c + side * w
			var t0 := float(i - 1) / seg
			_quad(st, prev_l, prev_r, rr, l, t0, t, g)
			prev_l = l
			prev_r = rr
	if flower:
		for f in 4:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 0.22
			var h := rng.randf_range(0.45, 0.7)
			var c := Vector3(cos(a) * r, h, sin(a) * r)
			var col := float(rng.randi_range(0, 4)) / 4.0
			# Stängel
			_quad(st, Vector3(c.x - 0.008, 0, c.z), Vector3(c.x + 0.008, 0, c.z), c + Vector3(0.008, 0, 0), c - Vector3(0.008, 0, 0), 0.0, 0.9, 0.5)
			# Blüte: zwei gekreuzte und eine liegende Fläche
			var s := rng.randf_range(0.035, 0.06)
			_petal(st, c, Vector3(s, 0, 0), Vector3(0, s, 0), col)
			_petal(st, c, Vector3(0, 0, s), Vector3(0, s, 0), col)
			_petal(st, c, Vector3(s, 0, 0), Vector3(0, 0, s), col)
	st.generate_normals()
	var m := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/grass.gdshader")
	m.surface_set_material(0, mat)
	_cache[key] = m
	return m


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, h0: float, h1: float, g: float) -> void:
	for v in [[a, h0], [b, h0], [c, h1], [a, h0], [c, h1], [d, h1]]:
		st.set_color(Color(v[1], g, 0.0, 0.0))
		st.add_vertex(v[0])


static func _petal(st: SurfaceTool, c: Vector3, u: Vector3, v: Vector3, col: float) -> void:
	for p in [c - u - v, c + u - v, c + u + v, c - u - v, c + u + v, c - u + v]:
		st.set_color(Color(1.0, 0.5, 1.0, col))
		st.add_vertex(p)

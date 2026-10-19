class_name Horizon
## Fernkulisse um Außenorte: ein Geländering vom Kartenrand bis ~1,8 km mit Hügeln oder Bergketten,
## im Shader (horizon.gdshader) als dichtes Kronendach, Fels und Schnee gezeichnet. Keine Kollision.

const OUTER := 3200.0
const RINGS := 64
const SEGS := 512


## style: "forest" (bewaldete Hügel), "mountain" (Bergketten mit Schnee), "plain" (flaches Land mit Wäldern)
static func build(root: Node3D, ground: MeshInstance3D, style: String, tint: Color = Color(0.16, 0.24, 0.1), trees: Array = []) -> MeshInstance3D:
	var aabb := ground.get_aabb()
	var gx := ground.global_transform
	var c := gx * aabb.get_center()
	var half := minf(aabb.size.x, aabb.size.z) * 0.5
	var r0 := half * 0.86                     # beginnt unter dem Gelände: keine Lücke am Rand
	var seed_v := int(abs(c.x * 13.0 + c.z * 7.0)) % 1000
	# echte Randhöhe des Geländes je Richtung (höchster Punkt nahe der Kante)
	var edge := PackedFloat32Array()
	edge.resize(SEGS)
	edge.fill(-INF)
	for si in ground.mesh.get_surface_count():
		for v in (ground.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var w := gx * v
			var dx := w.x - c.x
			var dz := w.z - c.z
			if Vector2(dx, dz).length() < half * 0.9:
				continue
			var k := posmod(int(round(atan2(dz, dx) / TAU * SEGS)), SEGS)
			edge[k] = maxf(edge[k], w.y)
	for k in SEGS:
		if edge[k] == -INF:
			edge[k] = c.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in RINGS + 1:
		var t := float(i) / RINGS
		var r := r0 + (OUTER - r0) * pow(t, 1.6)
		var row: Array = []
		for j in SEGS:
			var a := TAU * j / SEGS
			var eh: float = edge[j] - c.y
			var h := _height(r, a, t, style, seed_v)
			# innen 3 m unter der Geländekante, dann über die Kante hinaus ansteigen
			if r < half:
				h = eh - 3.0
			else:
				h = maxf(h + eh, eh + (r - half) * 0.08) if t < 0.25 else h + eh * 0.6
			row.append(Vector3(c.x + cos(a) * r, c.y + h, c.z + sin(a) * r))
		pts.append(row)
	for i in RINGS:
		for j in SEGS:
			var j2 := (j + 1) % SEGS
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j2]
			var cc: Vector3 = pts[i + 1][j2]
			var d: Vector3 = pts[i + 1][j]
			for v in [a, d, cc, a, cc, b]:
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
	st.index()                        # gemeinsame Eckpunkte → weiche Normalen statt Facetten
	st.generate_normals()
	if not trees.is_empty():
		_forest(root, pts, half, r0, trees, style)
	var mi := MeshInstance3D.new()
	mi.name = "nocol_Horizont"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/horizon.gdshader")
	m.set_shader_parameter("canopy", tint)
	m.set_shader_parameter("mountain", 1.0)
	m.set_shader_parameter("snow_line", 380.0 if style == "mountain" else 480.0)
	m.set_shader_parameter("rock_tex", load("res://assets/textures/terrain/cliff_side/cliff_side_diff.jpg"))
	m.set_shader_parameter("snow_tex", load("res://assets/textures/terrain/snow_02/snow_02_diff.jpg"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.extra_cull_margin = 200.0
	root.add_child(mi)
	return mi


static func _height(r: float, a: float, t: float, style: String, seed_v: int) -> float:
	var x := cos(a) * r
	var z := sin(a) * r
	var n1 := _noise(x * 0.004 + seed_v, z * 0.004)
	var n2 := _noise(x * 0.012, z * 0.012 + seed_v)
	var n3 := _noise(x * 0.04 + 7.0, z * 0.04)
	# ferne Bergketten (Grat-Rauschen) für alle Stile – große Fernsicht
	var r1 := 1.0 - absf(_noise(x * 0.0011 + seed_v * 0.3, z * 0.0011) * 2.0 - 1.0)
	var r2 := 1.0 - absf(_noise(x * 0.0032, z * 0.0032 + 3.0) * 2.0 - 1.0)
	var base_m := _noise(x * 0.0006 + 5.0, z * 0.0006)
	var ridge := (r1 * r1 * 0.8 + r2 * r2 * 0.2) * (0.55 + 0.45 * base_m)
	match style:
		"mountain":
			return (40.0 + ridge * 900.0 + n2 * 90.0) * smoothstep(0.0, 0.4, t) + n3 * 10.0
		"plain":
			return (n1 * 30.0 + n2 * 12.0) * smoothstep(0.0, 0.25, t) + smoothstep(0.4, 0.85, t) * (110.0 + ridge * 500.0)
		_:
			return (n1 * 70.0 + n2 * 25.0 + 15.0) * smoothstep(0.0, 0.2, t) + smoothstep(0.35, 0.8, t) * (140.0 + ridge * 560.0) + n3 * 5.0


static func _noise(x: float, z: float) -> float:
	# geglättetes Werterauschen 0..1
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	return lerpf(lerpf(_h(ix, iz), _h(ix + 1, iz), fx), lerpf(_h(ix, iz + 1), _h(ix + 1, iz + 1), fx), fz)


static func _h(x: int, z: int) -> float:
	var n := (x * 374761393 + z * 668265263) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177 & 0x7fffffff
	return float(n % 10000) / 10000.0



## Fernwald: niedrig aufgelöste Bäume des Ortes (lod2) dicht auf dem inneren Horizontband (bis +420 m).
static func _forest(root: Node3D, pts: Array, half: float, r0: float, trees: Array, style: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var per_mesh: Array = []
	for t in trees:
		per_mesh.append([])
	var dens := 0.35 if style == "mountain" else 1.0
	for i in RINGS:
		var ra: Vector3 = pts[i][0]
		var rb: Vector3 = pts[i + 1][0]
		var c0 := Vector2(ra.x, ra.z).distance_to(Vector2(rb.x, rb.z))
		for j in SEGS:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % SEGS]
			var c: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][(j + 1) % SEGS]
			var center := (a + b + c + d) * 0.25
			var rr := Vector2(center.x, center.z).length()
			if rr < half * 1.02 or rr > half + 420.0:
				continue
			var area := a.distance_to(b) * a.distance_to(c)
			# nah am Rand dicht, nach außen lichter (dort deckt der Dunst)
			var fall := 1.0 - smoothstep(half + 60.0, half + 420.0, rr) * 0.75
			var n := int(area / 150.0 * dens * fall)
			for k in n:
				var u := rng.randf()
				var v := rng.randf()
				var p := a.lerp(b, u).lerp(c.lerp(d, u), v)
				if absf((b - a).normalized().cross((c - a).normalized()).y) < 0.75:
					continue      # zu steil
				var s := rng.randf_range(1.0, 1.8)
				var mi := rng.randi() % trees.size()
				per_mesh[mi].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p - Vector3(0, 0.3, 0)))
	for m in trees.size():
		var list: Array = per_mesh[m]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = trees[m]
		mm.instance_count = list.size()
		for q in list.size():
			mm.set_instance_transform(q, list[q])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "nocol_Fernwald"
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		root.add_child(mmi)

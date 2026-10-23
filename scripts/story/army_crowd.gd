class_name ArmyCrowd
extends Node3D
## Ein Heer aus Tausenden Soldaten (Story »Katze-Ebene«): Blöcke in Formation mit Wappenfarben, Speerwald und
## Bannerträgern – je Block ein MultiMesh (ein Zeichenaufruf, Kachel-Culling). Alles fällt im Shader
## (assets/shaders/army.gdshader): die Welle des schwarzen Windes über wave(), einzelne Soldaten über trample()
## (z. B. unter den Hufen der Dunklen Jungen). Die Soldaten selbst sind einfache Gestalten – das Heer wirkt aus
## der Ferne und im Dunst, aus der Nähe sieht man es nie.

const SPACING := 1.3
const CELL := 6.0
const PALETTE := [Color(0.55, 0.1, 0.1), Color(0.12, 0.2, 0.5), Color(0.62, 0.52, 0.2), Color(0.18, 0.35, 0.16),
	Color(0.45, 0.42, 0.4), Color(0.4, 0.12, 0.35), Color(0.75, 0.72, 0.65), Color(0.2, 0.18, 0.16)]

static var _soldier_mesh: ArrayMesh
static var _banner_mesh: ArrayMesh

var clock := 0.0
var _mats: Array[ShaderMaterial] = []
var _mms: Array[MultiMesh] = []
var _pos: Array = []            ## je Soldat: [MultiMesh, Index, Welt-Position, tot?]
var _grid := {}                 ## Vector2i → Array[int] (Indizes in _pos)
var _probe: PhysicsShapeQueryParameters3D
var _blocked := 0


## blocks: [[dx, dz, Spalten, Reihen, Wappen 0–7], …] in Metern relativ zu `center` (x rechts, z nach hinten,
## von der Blickrichtung `yaw` aus gesehen – das Heer schaut in Richtung -z).
static func create(parent: Node, center: Vector3, yaw: float, blocks: Array) -> ArmyCrowd:
	var a := ArmyCrowd.new()
	a.name = "Heer"
	parent.add_child(a)
	a.global_position = center
	a._build(blocks, yaw)
	return a


func _material(is_banner: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/army.gdshader")
	var pal := PackedVector3Array()
	for c in PALETTE:
		var l := (c as Color).srgb_to_linear()
		pal.append(Vector3(l.r, l.g, l.b))
	m.set_shader_parameter("palette", pal)
	m.set_shader_parameter("banner", is_banner)
	_mats.append(m)
	return m


func _build(blocks: Array, yaw: float) -> void:
	if _soldier_mesh == null:
		_soldier_mesh = _make_soldier()
		_banner_mesh = _make_banner()
	var mat := _material(false)
	var bmat := _material(true)
	var basis := Basis(Vector3.UP, yaw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 260000
	var space := get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.7
	_probe = PhysicsShapeQueryParameters3D.new()
	_probe.shape = ball
	for b in blocks:
		var cols := int(b[2])
		var rows := int(b[3])
		var house := float(b[4])
		var xf: Array[Transform3D] = []
		var bxf: Array[Transform3D] = []
		for r in rows:
			for c in cols:
				var lx := float(b[0]) + (c - (cols - 1) * 0.5) * SPACING + rng.randf_range(-0.25, 0.25)
				var lz := float(b[1]) + r * SPACING + rng.randf_range(-0.25, 0.25)
				var wp := global_position + basis * Vector3(lx, 0.0, lz)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(wp + Vector3.UP * 60.0, wp - Vector3.UP * 60.0, 1))
				if hit.is_empty():
					continue                                       # außerhalb des Geländes
				wp.y = float(hit.position.y)
				# kein Platz in Palisaden, Zelten, Häusern: kleine Kugel über dem Boden darf nichts treffen
				_probe.transform = Transform3D(Basis(), wp + Vector3.UP * 1.0)
				_probe.exclude = [hit.rid]
				var hits := space.intersect_shape(_probe, 1)
				if not hits.is_empty():
					if OS.get_environment("ARMYDEBUG") != "" and rng.randf() < 0.02:
						print("HEER blockiert bei %s durch %s" % [wp.snapped(Vector3.ONE), hits[0].collider])
					_blocked += 1
					continue
				var t := Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.12, 0.12)).scaled(Vector3.ONE * rng.randf_range(0.94, 1.08)), wp)
				if c % 9 == 4 and r == 1:
					bxf.append(t)
				else:
					xf.append(t)
		if OS.get_environment("ARMYDEBUG") != "":
			print("HEER Block %s: %d Soldaten, %d blockiert" % [str(b), xf.size() + bxf.size(), _blocked])
		_add_mm(_soldier_mesh, mat, xf, house, rng)
		if not bxf.is_empty():
			_add_mm(_banner_mesh, bmat, bxf, house, rng)


func _add_mm(mesh: Mesh, mat: Material, xf: Array[Transform3D], house: float, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	var inv := global_transform.affine_inverse()
	for i in xf.size():
		mm.set_instance_transform(i, inv * xf[i])
		mm.set_instance_custom_data(i, Color(99999.0, rng.randf(), rng.randf(), house))
		var idx := _pos.size()
		_pos.append([mm, i, xf[i].origin, false])
		var key := Vector2i(floori(xf[i].origin.x / CELL), floori(xf[i].origin.z / CELL))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(idx)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mmi)
	_mms.append(mm)


func _process(delta: float) -> void:
	clock += delta
	for m in _mats:
		m.set_shader_parameter("clock", clock)


## Welle (schwarzer Wind): alle innerhalb des Radius fallen (Shader); Radius wächst über die Zeit.
func wave(center: Vector3, r: float) -> void:
	for m in _mats:
		m.set_shader_parameter("wave_center", center)
		m.set_shader_parameter("wave_r", r)
	for p in _pos:
		if not p[3] and Vector2(p[2].x - center.x, p[2].z - center.z).length() < r - 3.0:
			p[3] = true


## Einzelne Soldaten im Umkreis fallen (zertrampelt, vom Schlag getroffen …).
func trample(at: Vector3, radius: float = 4.0) -> int:
	var n := 0
	var c0 := Vector2i(floori((at.x - radius) / CELL), floori((at.z - radius) / CELL))
	var c1 := Vector2i(floori((at.x + radius) / CELL), floori((at.z + radius) / CELL))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for idx in _grid.get(Vector2i(cx, cz), []):
				var p: Array = _pos[idx]
				if p[3] or Vector2(p[2].x - at.x, p[2].z - at.z).length() > radius:
					continue
				p[3] = true
				var mm: MultiMesh = p[0]
				var cd := mm.get_instance_custom_data(p[1])
				mm.set_instance_custom_data(p[1], Color(clock + randf() * 0.25, randf(), cd.b, cd.a))
				n += 1
	return n


func alive() -> int:
	var n := 0
	for p in _pos:
		if not p[3]:
			n += 1
	return n


# --------------------------------------------------------------------- Gestalten (einmal gebaut, geteilt)

## Vertexfarbe a: 0 = Wappenfarbe (palette), 0,6 = Stoff/Haut/Holz, 1 = Metall.
static func _box(st: SurfaceTool, size: Vector3, c: Vector3, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var q: Array = f[1]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(c + q[idx])


static func _ball(st: SurfaceTool, r: float, c: Vector3, col: Color, sy: float = 1.0, top_only: bool = false) -> void:
	var seg := 8
	var rings := 4 if top_only else 6
	for j in rings:
		var a0 := PI * 0.5 * (1.0 - float(j) / rings) if top_only else PI * (0.5 - float(j) / rings)
		var a1 := PI * 0.5 * (1.0 - float(j + 1) / rings) if top_only else PI * (0.5 - float(j + 1) / rings)
		for i in seg:
			var b0 := TAU * i / seg
			var b1 := TAU * (i + 1) / seg
			var p := [Vector3(cos(a0) * cos(b0), sin(a0), cos(a0) * sin(b0)), Vector3(cos(a0) * cos(b1), sin(a0), cos(a0) * sin(b1)),
				Vector3(cos(a1) * cos(b1), sin(a1), cos(a1) * sin(b1)), Vector3(cos(a1) * cos(b0), sin(a1), cos(a1) * sin(b0))]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = p[idx]
				st.set_normal(v)
				st.set_color(col)
				st.add_vertex(c + Vector3(v.x * r, v.y * r * sy, v.z * r))


static func _make_soldier() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth := Color(0.24, 0.21, 0.18, 0.6)
	var leather := Color(0.2, 0.13, 0.07, 0.6)
	var mail := Color(0.42, 0.42, 0.45, 1.0)
	var steel := Color(0.58, 0.59, 0.63, 1.0)
	var skin := Color(0.72, 0.55, 0.42, 0.6)
	var wood := Color(0.33, 0.23, 0.13, 0.6)
	var house := Color(1, 1, 1, 0.0)
	for s in [-1.0, 1.0]:
		_box(st, Vector3(0.14, 0.82, 0.16), Vector3(0.1 * s, 0.41, 0.0), cloth)
		_box(st, Vector3(0.11, 0.55, 0.12), Vector3(0.27 * s, 1.08, 0.0), mail)
	_box(st, Vector3(0.42, 0.6, 0.26), Vector3(0, 1.12, 0), house)
	_box(st, Vector3(0.44, 0.06, 0.28), Vector3(0, 0.86, 0), leather)
	_box(st, Vector3(0.46, 0.12, 0.28), Vector3(0, 1.38, 0), mail)
	_ball(st, 0.115, Vector3(0, 1.56, 0), skin)
	_ball(st, 0.135, Vector3(0, 1.6, 0), steel, 0.9, true)
	_box(st, Vector3(0.04, 2.5, 0.04), Vector3(0.3, 1.45, -0.04), wood)
	_box(st, Vector3(0.07, 0.24, 0.025), Vector3(0.3, 2.82, -0.04), steel)
	_box(st, Vector3(0.48, 0.62, 0.05), Vector3(-0.33, 1.05, -0.14), house)
	_ball(st, 0.06, Vector3(-0.33, 1.05, -0.17), steel)
	return st.commit()


static func _make_banner() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth := Color(0.24, 0.21, 0.18, 0.6)
	var mail := Color(0.42, 0.42, 0.45, 1.0)
	var steel := Color(0.58, 0.59, 0.63, 1.0)
	var skin := Color(0.72, 0.55, 0.42, 0.6)
	var wood := Color(0.33, 0.23, 0.13, 0.6)
	var house := Color(1, 1, 1, 0.0)
	for s in [-1.0, 1.0]:
		_box(st, Vector3(0.14, 0.82, 0.16), Vector3(0.1 * s, 0.41, 0.0), cloth)
		_box(st, Vector3(0.11, 0.55, 0.12), Vector3(0.27 * s, 1.08, 0.0), mail)
	_box(st, Vector3(0.42, 0.6, 0.26), Vector3(0, 1.12, 0), house)
	_ball(st, 0.115, Vector3(0, 1.56, 0), skin)
	_ball(st, 0.135, Vector3(0, 1.6, 0), steel, 0.9, true)
	_box(st, Vector3(0.06, 4.2, 0.06), Vector3(0.05, 2.1, 0.0), wood)
	_box(st, Vector3(0.9, 0.05, 0.05), Vector3(0.5, 4.1, 0.0), wood)
	# Tuch: in Streifen unterteilt, damit es im Shader flattern kann
	var n := 6
	for i in n:
		var x0 := 0.08 + 0.85 * float(i) / n
		var x1 := 0.08 + 0.85 * float(i + 1) / n
		var q := [Vector3(x0, 2.75, 0), Vector3(x1, 2.75, 0), Vector3(x1, 4.05, 0), Vector3(x0, 4.05, 0)]
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3(0, 0, 1))
			st.set_color(house)
			st.add_vertex(q[idx])
	return st.commit()

class_name GrassField
extends Node3D
## Dichtes Grasfeld um die Kamera (wie in modernen Open-World-Spielen): 8-m-Kacheln mit
## GPU-Instancing, die mit dem Spieler mitwandern. Nah ~10 Büschel/m² mit fein gebogenen Halmen,
## mittlere Entfernung ausgedünnt, dahinter übernimmt der Boden. Höhe und Wegmaske kommen aus dem
## Gelände-Mesh (Ground, tools/pipeline/loc_kit.py), auf Bauwerken/Felsen wächst nichts (Strahltest).

const CHUNK := 8.0
const NEAR := 20.0              ## volle Dichte
const FAR := 54.0               ## ausgedünnt bis hier
const DENSITY := 10.0           ## Büschel je m² (nah)
const FLOWERS := 0.35           ## Blumen je m²
const BUILD_PER_FRAME := 2

var _h: PackedFloat32Array      ## Höhe je Gitterpunkt
var _m: PackedFloat32Array      ## Wegmaske je Gitterpunkt
var _n := 0
var _x0 := 0.0
var _z0 := 0.0
var _step := 1.0
var _chunks: Dictionary = {}    ## Vector2i → {near: MultiMeshInstance3D, flowers: …}
var _queue: Array[Vector2i] = []
var _mesh_near: Mesh
var _mesh_mid: Mesh
var _mesh_flower: Mesh
var _space: PhysicsDirectSpaceState3D
var _ground_rids: Dictionary = {}
var _last_center := Vector2i(99999, 99999)
var density_scale := 1.0
var _build_us := 0
var _built := 0


## Baut ein Grasfeld für das Gelände `ground`; null, wenn kein passendes Gelände.
static func create(ground: MeshInstance3D, tint: Dictionary = {}) -> GrassField:
	var g := GrassField.new()
	g.name = "Grasfeld"
	if not g._sample(ground):
		g.free()
		return null
	g.density_scale = (1.0 if Settings.particles else 0.45) * float(tint.get("density", 1.0))
	tint = tint.duplicate()
	tint.erase("density")
	g._mesh_near = GrassBlades.tuft(24, 3, 0.32, tint)
	g._mesh_mid = GrassBlades.tuft(12, 2, 0.36, tint)
	g._mesh_flower = GrassBlades.flowers(tint)
	return g


func _sample(ground: MeshInstance3D) -> bool:
	var mesh := ground.mesh
	if mesh == null:
		return false
	var xf := ground.global_transform
	var verts: Array[Vector3] = []
	var cols: Array[float] = []
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cs: Variant = arr[Mesh.ARRAY_COLOR]
		for i in vs.size():
			verts.append(xf * vs[i])
			cols.append((cs as PackedColorArray)[i].r if cs is PackedColorArray and (cs as PackedColorArray).size() == vs.size() else 0.0)
	if verts.size() < 100:
		return false
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for v in verts:
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.z))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.z))
	# Gitterweite: kleinster Abstand zweier verschiedener x-Werte (glTF teilt Punkte je Material auf)
	var xs := {}
	for v in verts:
		xs[snappedf(v.x, 0.001)] = true
	var sx: Array = xs.keys()
	sx.sort()
	var dmin := INF
	for i in range(1, sx.size()):
		var dd: float = sx[i] - sx[i - 1]
		if dd > 0.02:
			dmin = minf(dmin, dd)
	if dmin == INF:
		return false
	_n = roundi((mx.x - mn.x) / dmin) + 1
	if _n < 8 or _n > 4096:
		return false
	_step = (mx.x - mn.x) / float(_n - 1)
	_x0 = mn.x
	_z0 = mn.y
	_h.resize(_n * _n)
	_m.resize(_n * _n)
	_h.fill(-9999.0)
	for i in verts.size():
		var v := verts[i]
		var gx := clampi(roundi((v.x - _x0) / _step), 0, _n - 1)
		var gz := clampi(roundi((v.z - _z0) / _step), 0, _n - 1)
		_h[gz * _n + gx] = v.y
		_m[gz * _n + gx] = maxf(_m[gz * _n + gx], cols[i])
	return true


func _ready() -> void:
	_space = get_world_3d().direct_space_state
	for n in get_parent().find_children("Ground*", "MeshInstance3D", true, false):
		for b in n.find_children("*", "StaticBody3D", true, false):
			_ground_rids[(b as StaticBody3D).get_rid()] = true


func _height(x: float, z: float) -> Vector2:
	var fx := (x - _x0) / _step
	var fz := (z - _z0) / _step
	var ix := clampi(floori(fx), 0, _n - 2)
	var iz := clampi(floori(fz), 0, _n - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var i00 := iz * _n + ix
	if _h[i00] < -9000.0 or _h[i00 + 1] < -9000.0 or _h[i00 + _n] < -9000.0 or _h[i00 + _n + 1] < -9000.0:
		return Vector2(-9999.0, 1.0)
	var h := lerpf(lerpf(_h[i00], _h[i00 + 1], tx), lerpf(_h[i00 + _n], _h[i00 + _n + 1], tx), tz)
	var m := lerpf(lerpf(_m[i00], _m[i00 + 1], tx), lerpf(_m[i00 + _n], _m[i00 + _n + 1], tx), tz)
	return Vector2(h, m)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var center := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if center != _last_center:
		_last_center = center
		var r := int(ceil(FAR / CHUNK))
		var want := {}
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var k := center + Vector2i(dx, dz)
				var cpos := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
				if cpos.distance_to(Vector2(p.x, p.z)) > FAR + CHUNK * 0.7:
					continue
				want[k] = true
				if not _chunks.has(k) and not k in _queue:
					_queue.append(k)
		for k in _chunks.keys():
			if not want.has(k):
				for node in _chunks[k].values():
					if node is Node and is_instance_valid(node):
						(node as Node).queue_free()
				_chunks.erase(k)
		_queue = _queue.filter(func(k): return want.has(k))
		_queue.sort_custom(func(a, b): return Vector2(a - center).length() < Vector2(b - center).length())
	for i in BUILD_PER_FRAME:
		if _queue.is_empty():
			break
		var t0 := Time.get_ticks_usec()
		_build(_queue.pop_front())
		_build_us += Time.get_ticks_usec() - t0
		_built += 1
		if _built % 40 == 0 and OS.get_environment("GRASS_DEBUG") != "":
			print("GRAS: %d Kacheln, Ø %.1f ms je Kachel" % [_built, _build_us / 1000.0 / _built])
	# Detailstufe je Kachel
	for k in _chunks:
		var c: Dictionary = _chunks[k]
		var d := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK).distance_to(Vector2(p.x, p.z))
		var mmi: MultiMeshInstance3D = c.grass
		var near := d < NEAR
		if near != bool(c.get("near", false)) or not c.has("near"):
			c["near"] = near
			mmi.multimesh.mesh = _mesh_near if near else _mesh_mid
			mmi.multimesh.visible_instance_count = -1 if near else int(mmi.multimesh.instance_count * 0.28)


func _build(k: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	# Strahltest auf 1-m-Raster: nur dort Gras, wo das Gelände selbst oben liegt
	var cells := int(CHUNK)
	var open := PackedByteArray()
	open.resize(cells * cells)
	for cz in cells:
		for cx in cells:
			var x := k.x * CHUNK + cx + 0.5
			var z := k.y * CHUNK + cz + 0.5
			var hm := _height(x, z)
			if hm.x < -9000.0 or hm.y > 0.6:
				continue
			var rq := PhysicsRayQueryParameters3D.create(Vector3(x, hm.x + 25.0, z), Vector3(x, hm.x - 0.5, z))
			var r := _space.intersect_ray(rq)
			if r.is_empty() or _ground_rids.has(r.rid) or absf(r.position.y - hm.x) < 0.15:
				open[cz * cells + cx] = 1
	var count := int(CHUNK * CHUNK * DENSITY * density_scale)
	var xforms: Array[Transform3D] = []
	var fl: Array[Transform3D] = []
	for i in count + int(CHUNK * CHUNK * FLOWERS * density_scale):
		var lx := rng.randf() * CHUNK
		var lz := rng.randf() * CHUNK
		if open[mini(int(lz), cells - 1) * cells + mini(int(lx), cells - 1)] == 0:
			continue
		var x := k.x * CHUNK + lx
		var z := k.y * CHUNK + lz
		var hm := _height(x, z)
		# am Wegrand dünner und kürzer
		if rng.randf() < smoothstep(0.15, 0.55, hm.y):
			continue
		var s := rng.randf_range(0.75, 1.3) * (1.0 - smoothstep(0.1, 0.5, hm.y) * 0.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.25), s))
		var t := Transform3D(b, Vector3(x, hm.x - 0.02, z))
		if i >= count:
			fl.append(t)
		else:
			xforms.append(t)
	var c := {}
	c["grass"] = _mmi(_mesh_near, xforms)
	if not fl.is_empty():
		c["flowers"] = _mmi(_mesh_flower, fl, 30.0)
	_chunks[k] = c


func _mmi(mesh: Mesh, xforms: Array[Transform3D], end: float = FAR) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	var buf := PackedFloat32Array()
	buf.resize(xforms.size() * 12)
	for i in xforms.size():
		var t := xforms[i]
		var o := i * 12
		buf[o] = t.basis.x.x; buf[o + 1] = t.basis.y.x; buf[o + 2] = t.basis.z.x; buf[o + 3] = t.origin.x
		buf[o + 4] = t.basis.x.y; buf[o + 5] = t.basis.y.y; buf[o + 6] = t.basis.z.y; buf[o + 7] = t.origin.y
		buf[o + 8] = t.basis.x.z; buf[o + 9] = t.basis.y.z; buf[o + 10] = t.basis.z.z; buf[o + 11] = t.origin.z
	if xforms.size() > 0:
		mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = end
	mmi.visibility_range_end_margin = 6.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	return mmi

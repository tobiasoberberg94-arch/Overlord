class_name DetailField
extends Node3D
## Bodendetails aus Fotoscans um den Spieler (wie Farne/Totholz in großen Open-World-Spielen):
## 24-m-Kacheln mit GPU-Instancing, die mit der Kamera wandern. Je Ortsart eine Tabelle aus
## [Modelle, Dichte je m², Größe min/max, Sichtweite]. Platziert wird nur auf freiem Gelände
## (Strahl trifft das Gelände selbst, nicht steil, nicht auf Wegen).

const CHUNK := 24.0
const FAR := 110.0
const BUILD_PER_FRAME := 1

## Ortsart → [[modelle], dichte/m², [min, max], sichtweite]
const TABLES := {
	"forest": [
		[["fern_02"], 0.16, [0.9, 1.7], 50.0],
		[["shrub_03", "shrub_04", "weed_plant_02"], 0.05, [1.0, 1.8], 40.0],
		[["dry_branches_medium_01"], 0.02, [0.8, 1.4], 35.0],
		[["tree_stump_01", "tree_stump_02"], 0.0025, [0.8, 1.3], 80.0],
		[["dead_tree_trunk", "dead_tree_trunk_02"], 0.0018, [0.9, 1.5], 90.0],
		[["rock_moss_set_01", "rock_moss_set_02"], 0.004, [0.6, 1.4], 100.0],
		[["rock_07", "stone_01"], 0.02, [2.0, 5.0], 30.0],
	],
	"jungle": [
		[["fern_02"], 0.22, [1.2, 2.2], 50.0],
		[["shrub_02", "shrub_03"], 0.03, [1.0, 1.6], 45.0],
		[["root_cluster_01"], 0.0015, [0.8, 1.2], 70.0],
		[["dead_tree_trunk_02"], 0.0015, [1.0, 1.5], 80.0],
		[["rock_moss_set_01", "rock_moss_set_02"], 0.003, [0.6, 1.2], 90.0],
	],
	"swamp": [
		[["fern_02"], 0.08, [1.0, 1.8], 45.0],
		[["shrub_03", "weed_plant_02"], 0.04, [1.0, 1.6], 40.0],
		[["root_cluster_01"], 0.002, [0.7, 1.1], 70.0],
		[["dead_tree_trunk", "dead_tree_trunk_02"], 0.003, [0.8, 1.4], 80.0],
	],
	"grassland": [
		[["grass_medium_01"], 0.45, [1.1, 1.7], 30.0],
		[["celandine_01", "flower_empodium", "dandelion_01", "flower_ursinia", "periwinkle_plant"], 0.07, [1.0, 1.4], 35.0],
		[["nettle_plant", "weed_plant_02"], 0.02, [1.0, 1.6], 35.0],
		[["shrub_04", "shrub_03"], 0.012, [1.0, 1.8], 45.0],
		[["rock_07", "stone_01"], 0.012, [2.0, 5.0], 30.0],
		[["boulder_01", "namaqualand_boulder_02", "namaqualand_boulder_05"], 0.0012, [0.6, 1.4], 120.0],
	],
	"village": [
		[["grass_medium_01"], 0.35, [1.1, 1.6], 30.0],
		[["celandine_01", "flower_empodium", "dandelion_01", "periwinkle_plant"], 0.05, [1.0, 1.4], 35.0],
		[["nettle_plant", "weed_plant_02"], 0.015, [1.0, 1.5], 35.0],
		[["rock_07", "stone_01"], 0.01, [2.0, 4.0], 30.0],
		[["boulder_01", "namaqualand_boulder_05"], 0.0008, [0.6, 1.2], 110.0],
	],
	"cemetery": [
		[["weed_plant_02", "nettle_plant"], 0.03, [1.0, 1.6], 35.0],
		[["dry_branches_medium_01"], 0.012, [0.8, 1.3], 35.0],
		[["rock_07", "stone_01"], 0.02, [2.0, 4.0], 30.0],
		[["dead_tree_trunk"], 0.0008, [0.8, 1.2], 80.0],
	],
	"battlefield": [
		[["dry_branches_medium_01"], 0.012, [0.8, 1.4], 35.0],
		[["rock_07", "stone_01"], 0.03, [2.0, 5.0], 30.0],
		[["boulder_01", "namaqualand_boulder_02"], 0.0015, [0.6, 1.4], 120.0],
		[["dead_tree_trunk", "dead_tree_trunk_02"], 0.001, [0.9, 1.4], 90.0],
	],
	"mountain": [
		[["rock_07", "stone_01"], 0.05, [2.0, 6.0], 35.0],
		[["boulder_01", "namaqualand_boulder_02", "namaqualand_boulder_05"], 0.005, [0.7, 2.0], 130.0],
		[["rock_moss_set_01", "rock_moss_set_02"], 0.002, [0.8, 1.6], 120.0],
		[["shrub_04", "weed_plant_02"], 0.012, [1.0, 1.5], 35.0],
	],
	"peaks": [
		[["rock_07", "stone_01"], 0.05, [2.0, 6.0], 35.0],
		[["boulder_01", "namaqualand_boulder_02"], 0.004, [0.8, 2.2], 130.0],
		[["dry_branches_medium_01"], 0.006, [0.8, 1.3], 35.0],
	],
	"city": [
		[["grass_medium_01"], 0.25, [1.0, 1.5], 28.0],
		[["dandelion_01", "celandine_01", "weed_plant_02"], 0.04, [1.0, 1.3], 30.0],
		[["nettle_plant", "weed_plant_02"], 0.012, [1.0, 1.5], 30.0],
	],
	"palace": [
		[["grass_medium_01"], 0.2, [1.0, 1.4], 28.0],
		[["celandine_01", "flower_empodium"], 0.03, [1.0, 1.3], 30.0],
	],
	"cathedral": [
		[["grass_medium_01"], 0.2, [1.0, 1.4], 28.0],
		[["celandine_01", "flower_empodium", "periwinkle_plant"], 0.03, [1.0, 1.3], 30.0],
	],
	"wall": [
		[["grass_medium_01"], 0.3, [1.1, 1.6], 30.0],
		[["nettle_plant", "weed_plant_02"], 0.015, [1.0, 1.5], 35.0],
		[["rock_07", "stone_01"], 0.012, [2.0, 4.0], 30.0],
		[["boulder_01", "namaqualand_boulder_05"], 0.001, [0.6, 1.3], 110.0],
	],
}

var grass: GrassField                 ## für Wegmaske/Höhe (falls vorhanden)
var _entries: Array = []              ## [{variants, density, smin, smax, range}]
var _chunks: Dictionary = {}
var _queue: Array[Vector2i] = []
var _last := Vector2i(99999, 99999)
var _space: PhysicsDirectSpaceState3D
var _ground_rids: Dictionary = {}


static func create(kind: String, gf: GrassField) -> DetailField:
	if not TABLES.has(kind):
		return null
	var d := DetailField.new()
	d.name = "Bodendetails"
	d.grass = gf
	var dens := 1.0 if Settings.particles else 0.5
	for e in TABLES[kind]:
		var v := PhProps.pool(e[0])
		if v.is_empty():
			continue
		d._entries.append({"variants": v, "density": float(e[1]) * dens, "smin": float(e[2][0]), "smax": float(e[2][1]), "range": float(e[3])})
	if d._entries.is_empty():
		d.free()
		return null
	return d


func _ready() -> void:
	_space = get_world_3d().direct_space_state
	for n in get_parent().find_children("Ground*", "MeshInstance3D", true, false):
		for b in n.find_children("*", "StaticBody3D", true, false):
			_ground_rids[(b as StaticBody3D).get_rid()] = true


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var center := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if center != _last:
		_last = center
		var r := int(ceil(FAR / CHUNK))
		var want := {}
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var k := center + Vector2i(dx, dz)
				if Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK).distance_to(Vector2(p.x, p.z)) > FAR + CHUNK * 0.7:
					continue
				want[k] = true
				if not _chunks.has(k) and not k in _queue:
					_queue.append(k)
		for k in _chunks.keys():
			if not want.has(k):
				for node in _chunks[k]:
					if is_instance_valid(node):
						(node as Node).queue_free()
				_chunks.erase(k)
		_queue = _queue.filter(func(k): return want.has(k))
		_queue.sort_custom(func(a, b): return Vector2(a - center).length() < Vector2(b - center).length())
	for i in BUILD_PER_FRAME:
		if _queue.is_empty():
			break
		_build(_queue.pop_front())


func _build(k: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k) ^ 0x5eed
	var nodes: Array = []
	for e in _entries:
		var n := int(CHUNK * CHUNK * float(e.density))
		if rng.randf() < fmod(CHUNK * CHUNK * float(e.density), 1.0):
			n += 1
		if n <= 0:
			continue
		var per: Dictionary = {}          # Variante → [Transform3D]
		for i in n:
			var x := k.x * CHUNK + rng.randf() * CHUNK
			var z := k.y * CHUNK + rng.randf() * CHUNK
			if grass:
				var hm := grass._height(x, z)
				if hm.x < -9000.0 or hm.y > 0.35:
					continue
			var rq := PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -200.0, z))
			var r := _space.intersect_ray(rq)
			if r.is_empty() or r.normal.y < 0.82:
				continue
			if not _ground_rids.is_empty() and not _ground_rids.has(r.rid):
				continue
			var vi := rng.randi() % (e.variants as Array).size()
			var v: Dictionary = e.variants[vi]
			var s := rng.randf_range(float(e.smin), float(e.smax))
			# leicht zum Hang geneigt, zufällig gedreht, etwas eingesunken
			var up: Vector3 = (Vector3.UP.lerp(r.normal, 0.6)).normalized()
			var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
			var t := Transform3D(b.scaled(Vector3(s, s, s)), (r.position as Vector3) - up * 0.04 * s) * (v.xf as Transform3D)
			if not per.has(vi):
				per[vi] = []
			per[vi].append(t)
		for vi in per:
			var v: Dictionary = e.variants[vi]
			nodes.append(_mmi(v.mesh, per[vi], float(e.range)))
	_chunks[k] = nodes


func _mmi(mesh: Mesh, xforms: Array, end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = end
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if end > 60.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

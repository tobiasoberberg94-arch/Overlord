class_name PhProps
## Fotoscan-Modelle (Poly Haven, CC0) aus assets/models/props/ph/<name>/<name>.gltf.
## Viele Dateien enthalten mehrere Varianten nebeneinander (z. B. vier Farne, sechs Felsen) – jede
## MeshInstance3D wird als eigene Variante geführt: Mesh + Transform, der sie mittig auf den Boden stellt.
##   variants("fern_02") → [{mesh, xf, size}]

const DIR := "res://assets/models/props/ph/"
static var _cache: Dictionary = {}


static func variants(name: String) -> Array:
	if _cache.has(name):
		return _cache[name]
	var out: Array = []
	var path := DIR + "%s/%s.gltf" % [name, name]
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		var root: Node3D = ps.instantiate()
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var nx := _xf_in(mi, root)
			var a := nx * mi.get_aabb()
			var c := a.get_center()
			# Basis bleibt, Ursprung: Mitte der Grundfläche
			var xf := Transform3D(Basis(), Vector3(-c.x, -a.position.y, -c.z)) * nx
			out.append({"mesh": mi.mesh, "xf": xf, "size": a.size})
		root.free()
	_cache[name] = out
	return out


static func _xf_in(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D()
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Alle Varianten mehrerer Dateien.
static func pool(names: Array) -> Array:
	var out: Array = []
	for n in names:
		out += variants(n)
	return out


# ------------------------------------------------------------------ Felstausch

const ROCK_SMALL := ["boulder_01", "namaqualand_boulder_02", "namaqualand_boulder_05", "rock_moss_set_01", "rock_moss_set_02"]
const ROCK_MOSSY := ["rock_moss_set_01", "rock_moss_set_02", "boulder_01"]
const ROCK_BIG := ["rock_face_01", "rock_face_02", "mountainside"]
const DRY_KINDS := ["battlefield", "peaks", "mountain", "cemetery", "wall"]


static func _is_rock(nm: String) -> bool:
	var l := nm.to_lower()
	if l.begins_with("ice_") or l.begins_with("frost_") or l.begins_with("nocol_"):
		return false
	return l.begins_with("sm_rock") or l.begins_with("sm_ground_rock") or l.begins_with("fv_rock") or l.begins_with("mw_rock") \
		or l.begins_with("sm_stonedan") or l.begins_with("sm_rockplane") or l.begins_with("sm_mossyground") or l.begins_with("sm_prop_stone")


## Ersetzt die stilisierten Felsen eines Ortsmodells durch Fotoscans gleicher Größe. Die Kollision des
## Originals bleibt (StaticBody-Kind), nur die Darstellung wird getauscht.
static func swap_rocks(scene: Node3D, kind: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var small := pool(ROCK_SMALL if not kind in ["forest", "jungle", "swamp"] else ROCK_MOSSY)
	var big := pool(ROCK_BIG)
	if small.is_empty():
		return 0
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not _is_rock(String(mi.name)):
			continue
		var a := mi.get_aabb()
		if a.size.length() < 0.05:
			continue
		if a.size.y < maxf(a.size.x, a.size.z) * 0.28:
			continue            # flache Bodenplatten bleiben (als Felsbrocken sähen sie wie Fladen aus)
		var ws := mi.global_transform.basis.get_scale() * a.size
		var list: Array = big if maxf(ws.x, maxf(ws.y, ws.z)) > 7.0 and not big.is_empty() else small
		var v: Dictionary = list[rng.randi() % list.size()]
		var vs: Vector3 = v.size
		# im lokalen Raum des Originals einpassen (gleiche Grundfläche/Höhe wie die Kollision)
		var sc := Vector3(a.size.x / maxf(vs.x, 0.01), a.size.y / maxf(vs.y, 0.01), a.size.z / maxf(vs.z, 0.01))
		var m := (sc.x + sc.z) * 0.5
		sc = Vector3(lerpf(sc.x, m, 0.5), sc.y, lerpf(sc.z, m, 0.5))
		var vis := MeshInstance3D.new()
		vis.name = "foto"
		vis.mesh = v.mesh
		var base := Vector3(a.get_center().x, a.position.y, a.get_center().z)
		vis.transform = Transform3D(Basis().scaled(sc), base) * (v.xf as Transform3D)
		vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.mesh = null
		mi.add_child(vis)
		n += 1
	return n

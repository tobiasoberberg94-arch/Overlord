class_name FoliageLod
extends Node3D
## Bäume und schwere Pflanzen mit Detailstufen je EINZELNER Instanz (nicht je Kachel):
## Jede Kachel hat drei MultiMeshes (lod0 = Original, lod1/lod2 = ausgedünnt). Bewegt sich die Kamera,
## werden die Instanzen naher Kacheln nach ihrer Entfernung neu auf die Stufen verteilt.
## Kacheln bleiben für das Frustum-Culling erhalten.

const UPDATE_EVERY := 0.25
const MOVE_EPS := 2.5

var _tiles: Array = []         ## {center, radius, items: Array[Transform3D], mm: [MultiMesh×3], ranges, level}
var _last := Vector3(INF, INF, INF)
var _t := 0.0


## meshes: [lod0, lod1, lod2]; ranges: [[0, a], [a, b], [b, c]]
func add_group(meshes: Array, tiles: Dictionary, ranges: Array, shadow: bool) -> void:
	for key in tiles:
		var list: Array = tiles[key]
		if list.is_empty():
			continue
		var c := Vector3.ZERO
		for t in list:
			c += (t as Transform3D).origin
		c /= list.size()
		var r := 0.0
		for t in list:
			r = maxf(r, c.distance_to((t as Transform3D).origin))
		var tile := {"center": c, "radius": r + 8.0, "items": list, "mm": [], "ranges": ranges, "level": -2}
		for lvl in 3:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[lvl]
			mm.instance_count = list.size()
			for i in list.size():          # alle Plätze mit Kachel-Transformationen füllen → AABB bleibt in der Kachel
				mm.set_instance_transform(i, list[i])
			mm.visible_instance_count = 0
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			# ferne Stufe ohne Schatten (liegt ohnehin hinter der Schattenreichweite)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow and lvl == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(mmi)
			tile.mm.append(mm)
		_tiles.append(tile)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = UPDATE_EVERY
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	if p.distance_to(_last) < MOVE_EPS:
		return
	_last = p
	for tile in _tiles:
		_update_tile(tile, p)


func _update_tile(tile: Dictionary, p: Vector3) -> void:
	var ranges: Array = tile.ranges
	var d0: float = p.distance_to(tile.center) - tile.radius
	var d1: float = p.distance_to(tile.center) + tile.radius
	# ganze Kachel in einer Stufe (oder außer Sicht) → ohne Einzelprüfung
	var whole := -1
	if d0 > ranges[2][1]:
		whole = 3
	elif d0 > ranges[1][1]:
		whole = 2
	elif d0 > ranges[0][1] and d1 < ranges[1][1]:
		whole = 1
	elif d1 < ranges[0][1]:
		whole = 0
	if whole >= 0 and tile.level == whole:
		return
	var items: Array = tile.items
	var mms: Array = tile.mm
	var n := [0, 0, 0]
	if whole >= 0:
		tile.level = whole
		for lvl in 3:
			(mms[lvl] as MultiMesh).visible_instance_count = 0
		if whole < 3:
			var mm := mms[whole] as MultiMesh
			for i in items.size():
				mm.set_instance_transform(i, items[i])
			mm.visible_instance_count = items.size()
		return
	tile.level = -1
	var lim0: float = ranges[0][1] * ranges[0][1]
	var lim1: float = ranges[1][1] * ranges[1][1]
	var lim2: float = ranges[2][1] * ranges[2][1]
	for t in items:
		var dd := p.distance_squared_to((t as Transform3D).origin)
		var lvl := 0 if dd < lim0 else (1 if dd < lim1 else (2 if dd < lim2 else 3))
		if lvl < 3:
			(mms[lvl] as MultiMesh).set_instance_transform(n[lvl], t)
			n[lvl] += 1
	for lvl in 3:
		(mms[lvl] as MultiMesh).visible_instance_count = n[lvl]

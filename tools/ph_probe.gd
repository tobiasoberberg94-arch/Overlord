extends SceneTree
## Maße der Poly-Haven-Modelle (assets/models/props/ph): Meshes, Begrenzung, Dreiecke, Detailstufen.

func _init() -> void:
	for d in DirAccess.get_directories_at("res://assets/models/props/ph/"):
		var ps: PackedScene = load("res://assets/models/props/ph/%s/%s.gltf" % [d, d])
		if ps == null:
			print("PH %-24s FEHLT" % d)
			continue
		var root: Node3D = ps.instantiate()
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		var aabb := AABB()
		var first := true
		var tris := 0
		var lods := 0
		for n in meshes:
			var mi := n as MeshInstance3D
			var a := _global_xf(mi) * mi.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
			for s in mi.mesh.get_surface_count():
				tris += int(RenderingServer.mesh_get_surface(mi.mesh.get_rid(), s).get("index_count", 0)) / 3
				lods = maxi(lods, (RenderingServer.mesh_get_surface(mi.mesh.get_rid(), s).get("lods", []) as Array).size())
		print("PH %-24s meshes %d  pos %s  size %s  tris %d  lods %d" % [d, meshes.size(), aabb.position.snapped(Vector3(0.01, 0.01, 0.01)),
			aabb.size.snapped(Vector3(0.01, 0.01, 0.01)), tris, lods])
		root.free()
	quit()


func _global_xf(n: Node) -> Transform3D:
	var t := Transform3D()
	var cur := n
	while cur != null and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

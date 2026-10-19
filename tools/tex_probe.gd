extends SceneTree
## Durchschnittsfarbe der Albedo-Texturen aller Pflanzen-Vorlagen eines Ortsmodells.
##   godot --headless --path . --script res://tools/tex_probe.gd -- elfen

func _init() -> void:
	var id: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "elfen"
	var ps: PackedScene = load("res://assets/models/locations/%s.glb" % id)
	var root := ps.instantiate()
	var seen := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if not (nm.contains("Tree") or nm.contains("tree") or nm.contains("Spruce") or nm.contains("Bush") or nm.contains("Foliage")):
			continue
		if not nm.begins_with("nocol_mm_lod0_") and not nm.begins_with("nocol_mm_"):
			continue
		var key := nm
		if seen.has(key) or mi.mesh == null:
			continue
		seen[key] = true
		var parts := PackedStringArray()
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m == null or m.albedo_texture == null:
				continue
			var img := m.albedo_texture.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			img.resize(16, 16)
			var acc := Color(0, 0, 0, 0)
			var cnt := 0
			for y in 16:
				for x in 16:
					var c := img.get_pixel(x, y)
					if c.a > 0.5:
						acc += c
						cnt += 1
			if cnt > 0:
				acc /= cnt
			parts.append("%s rgb(%.2f %.2f %.2f) tint(%.2f %.2f %.2f) alpha=%d" % [String(m.resource_name).substr(0, 22), acc.r, acc.g, acc.b,
				m.albedo_color.r, m.albedo_color.g, m.albedo_color.b, m.transparency])
		print("PROBE %-34s %s" % [nm.substr(0, 34), " | ".join(parts)])
	quit()

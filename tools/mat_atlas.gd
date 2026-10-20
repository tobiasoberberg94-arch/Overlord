extends SceneTree
## Material-Atlas der Ortsmodelle: je Material Vorschau der Albedo-Textur (Kachel 128 px), Durchschnittsfarbe,
## Anzahl Meshes und Fläche (grob). Ausgabe: tools/screenshots3d/atlas_<n>.png + Liste.
##   godot --headless --path . --script res://tools/mat_atlas.gd -- theokratie,baharuth,...

func _init() -> void:
	var locs: PackedStringArray = (OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "theokratie").split(",")
	var mats := {}            ## name → {tex, color, n, area, locs, meshes}
	for loc in locs:
		var ps: PackedScene = load("res://assets/models/locations/%s.glb" % loc)
		if ps == null:
			continue
		var root := ps.instantiate()
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var nm := String(mi.name)
			if nm.begins_with("nocol_mm") or nm.begins_with("Ground"):
				continue
			var aabb := mi.get_aabb()
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if m == null:
					continue
				var key := String(m.resource_name).get_slice(".", 0)
				if not mats.has(key):
					mats[key] = {"tex": m.albedo_texture, "color": m.albedo_color, "n": 0, "area": 0.0, "locs": {}, "meshes": {},
						"normal": m.normal_texture != null, "alpha": m.transparency}
				var e: Dictionary = mats[key]
				e.n += 1
				e.area += aabb.size.x * aabb.size.y + aabb.size.y * aabb.size.z + aabb.size.x * aabb.size.z
				e.locs[loc] = true
				e.meshes[nm.get_slice("_", 0) + "_" + nm.get_slice("_", 1)] = true
		root.free()
	var keys := mats.keys()
	keys.sort_custom(func(a, b): return mats[a].area > mats[b].area)
	var per_sheet := 48
	var cols := 8
	var sheet_i := 0
	var i := 0
	while i < keys.size():
		var img := Image.create(cols * 160, ceili(per_sheet / float(cols)) * 160, false, Image.FORMAT_RGB8)
		img.fill(Color(0.1, 0.1, 0.1))
		for k in per_sheet:
			if i + k >= keys.size():
				break
			var key: String = keys[i + k]
			var e: Dictionary = mats[key]
			var tile := Image.create(150, 150, false, Image.FORMAT_RGB8)
			tile.fill(e.color)
			if e.tex:
				var ti: Image = (e.tex as Texture2D).get_image()
				if ti:
					if ti.is_compressed():
						ti.decompress()
					ti.convert(Image.FORMAT_RGB8)
					ti.resize(150, 150)
					tile = ti
			img.blit_rect(tile, Rect2i(0, 0, 150, 150), Vector2i((k % cols) * 160 + 5, (k / cols) * 160 + 5))
			var avg := Color(0, 0, 0)
			var small := tile.duplicate() as Image
			small.resize(1, 1, Image.INTERPOLATE_BILINEAR)
			avg = small.get_pixel(0, 0)
			print("MAT %d/%02d %-34s n=%-4d fläche=%-8d tex=%s normal=%s alpha=%d farbe(%.2f %.2f %.2f) orte=%s meshes=%s" % [sheet_i, k, key, e.n, int(e.area),
				e.tex != null, e.normal, e.alpha, avg.r, avg.g, avg.b, ",".join(e.locs.keys()), ",".join(PackedStringArray(e.meshes.keys().slice(0, 5)))])
		img.save_png(ProjectSettings.globalize_path("res://tools/screenshots3d/atlas_%d.png" % sheet_i))
		i += per_sheet
		sheet_i += 1
	quit()

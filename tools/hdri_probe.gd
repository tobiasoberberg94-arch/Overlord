extends SceneTree
func _init() -> void:
	for f in DirAccess.get_files_at("res://assets/skies/"):
		if not f.ends_with(".hdr"):
			continue
		var n := f.trim_suffix("_4k.hdr")
		var a: Dictionary = HdriSky.analyze(n)
		if a.is_empty():
			print("HDRI ", n, " leer")
			continue
		var sd: Vector3 = a.sun_dir
		print("HDRI %-42s avg %.3f peak %.1f stärke %.2f sonne %.1f° farbe %s" % [n, a.avg, a.peak, a.strength, rad_to_deg(asin(sd.y)), a.sun_col])
	quit()

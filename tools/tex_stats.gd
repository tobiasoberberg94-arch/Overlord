extends SceneTree
## Mittlere Farbe aller 3D-Texturen (Orte, Fotomaterialien, Fotoscans) → data/tex_stats.json.
## Im Spiel braucht die Materialerkennung (Gebäude, Laub) so keine Texturen zu entpacken.
##   godot --headless --path . --script res://tools/tex_stats.gd
## Eintrag je Pfad: [r, g, b (sRGB-Mittel), lineare Helligkeit, deckender Anteil]

const DIRS := ["res://assets/models/locations/", "res://assets/textures/build/", "res://assets/textures/terrain/",
	"res://assets/models/props/ph/"]


var old := {}


func _init() -> void:
	var out := {}
	var f0 := FileAccess.open("res://data/tex_stats.json", FileAccess.READ)
	if f0:                                   # vorhandene Einträge übernehmen (nur neue Texturen berechnen)
		var d0: Variant = JSON.parse_string(f0.get_as_text())
		if d0 is Dictionary:
			old = d0
	for d in DIRS:
		_scan(d, out)
	var f := FileAccess.open("res://data/tex_stats.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("Texturen: ", out.size())
	quit()


func _scan(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir + sub + "/", out)
	for f in d.get_files():
		if not f.get_extension().to_lower() in ["jpg", "jpeg", "png", "webp"]:
			continue
		if old.has(dir + f) and FileAccess.get_modified_time(dir + f) < FileAccess.get_modified_time("res://data/tex_stats.json"):
			out[dir + f] = old[dir + f]
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + f))
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(32, 32, Image.INTERPOLATE_TRILINEAR)
		var s := Vector3.ZERO
		var sl := 0.0
		var n := 0
		for y in 32:
			for x in 32:
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				s += Vector3(c.r, c.g, c.b)
				var l := c.srgb_to_linear()
				sl += l.r * 0.2126 + l.g * 0.7152 + l.b * 0.0722
				n += 1
		if n == 0:
			out[dir + f] = [0.0, 0.0, 0.0, 0.0, 0.0]
			continue
		s /= float(n)
		out[dir + f] = [snappedf(s.x, 0.001), snappedf(s.y, 0.001), snappedf(s.z, 0.001), snappedf(sl / n, 0.0001), snappedf(n / 1024.0, 0.01)]

class_name TexStats
## Mittlere Farbe einer Textur aus data/tex_stats.json (tools/tex_stats.gd) – ohne die Textur zu entpacken.
## Unbekannte Texturen werden einmal berechnet und zwischengespeichert.

static var _db: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open("res://data/tex_stats.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_db = d


## [r, g, b (sRGB-Mittel), lineare Helligkeit, deckender Anteil]
static func of(t: Texture2D) -> Array:
	if t == null:
		return [0.5, 0.5, 0.5, 0.214, 1.0]
	_load()
	var key := t.resource_path
	if key != "" and _db.has(key):
		return _db[key]
	var img := t.get_image()
	var e: Array = [0.5, 0.5, 0.5, 0.214, 1.0]
	if img:
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(24, 24, Image.INTERPOLATE_BILINEAR)
		var s := Vector3.ZERO
		var sl := 0.0
		var n := 0
		for y in 24:
			for x in 24:
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					s += Vector3(c.r, c.g, c.b)
					var l := c.srgb_to_linear()
					sl += l.r * 0.2126 + l.g * 0.7152 + l.b * 0.0722
					n += 1
		if n > 0:
			s /= float(n)
			e = [s.x, s.y, s.z, sl / n, n / 576.0]
	if key != "":
		_db[key] = e
	return e


static func color(t: Texture2D) -> Color:
	var e := of(t)
	return Color(e[0], e[1], e[2], 1.0)

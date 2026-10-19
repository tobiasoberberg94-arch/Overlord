class_name HdriSky
## Fotografierte Himmel (assets/skies/*.hdr, Poly Haven CC0) für Außenorte. Findet die Sonne im Panorama,
## dreht das Panorama so, dass sie in der gewünschten Himmelsrichtung steht, übernimmt Höhe und Farbe der
## echten Sonne für das Spiel-Licht und normiert die Helligkeit. Analyse wird je Himmel zwischengespeichert.

const DIR := "res://assets/skies/"
static var _cache: Dictionary = {}     ## name → {tex, sun_dir, sun_col, avg, horizon}


static func analyze(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + "_4k.hdr"
	if not ResourceLoader.exists(path):
		return {}
	var tex: Texture2D = load(path)
	var img := tex.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBF)
	img.resize(512, 256, Image.INTERPOLATE_BILINEAR)
	# Sonne im unscharfen Bild suchen (kleine helle Punkte wie Lampen zählen nicht), dann im scharfen verfeinern
	var small := img.duplicate() as Image
	small.resize(64, 32, Image.INTERPOLATE_TRILINEAR)
	var sb := -1.0
	var sp := Vector2i(32, 8)
	var sum := Vector3.ZERO
	var n := 0
	var hz := Vector3.ZERO
	var hn := 0
	for y in 16:
		for x in 64:
			var c := small.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			if l > sb:
				sb = l
				sp = Vector2i(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
			if y >= 14:
				hz += Vector3(c.r, c.g, c.b)
				hn += 1
	var best := -1.0
	var best_uv := Vector2((sp.x + 0.5) / 64.0, (sp.y + 0.5) / 32.0)
	for y in range(maxi(0, sp.y * 8 - 10), mini(128, sp.y * 8 + 18)):
		for x in range(sp.x * 8 - 10, sp.x * 8 + 18):
			var c := img.get_pixel(posmod(x, 512), y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			if l > best:
				best = l
				best_uv = Vector2((posmod(x, 512) + 0.5) / 512.0, (y + 0.5) / 256.0)
	var phi := (best_uv.x - 0.5) * TAU
	var theta := best_uv.y * PI
	var sd := Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi))
	var sc := small.get_pixel(sp.x, sp.y)
	var m := maxf(sc.r, maxf(sc.g, sc.b))
	var sun_col := Color(sc.r / m, sc.g / m, sc.b / m) if m > 0.0 else Color.WHITE
	var avg := sum / maxf(1.0, n)
	var hor := hz / maxf(1.0, hn)
	var avg_l := avg.x * 0.2126 + avg.y * 0.7152 + avg.z * 0.0722
	# Sonnenstärke: wie stark die (unscharfe) Sonne über dem Himmelsmittel liegt – klar ≈ 1, bedeckt ≈ 0.3
	var strength := clampf(log(maxf(sb / maxf(avg_l, 0.001), 1.0)) / log(10.0) / 1.6, 0.3, 1.0)
	# nur die Messwerte zwischenspeichern – das Bild selbst (≈90 MB Grafikspeicher) gehört zum Ort und wird mit ihm frei
	var res := {"path": path, "sun_dir": sd.normalized(), "sun_col": sun_col, "peak": best, "strength": strength,
		"avg": avg_l, "horizon": Color(hor.x, hor.y, hor.z)}
	_cache[name] = res
	return res


## Himmel + Sonne einrichten. preset: hdri, hdri_energy, sun_rot (y = gewünschte Azimut-Richtung).
static func apply(env: Environment, sun: DirectionalLight3D, preset: Dictionary) -> bool:
	var a := analyze(String(preset.get("hdri", "")))
	if a.is_empty():
		return false
	var sd: Vector3 = a.sun_dir
	var elev := asin(clampf(sd.y, -1.0, 1.0))
	var az_h := atan2(sd.x, sd.z)
	var want_az := deg_to_rad(float((preset.get("sun_rot", Vector3(-40, 30, 0)) as Vector3).y))
	var night: bool = preset.get("night", false)
	var strength: float = float(a.get("strength", 1.0))
	var overcast: bool = strength < 0.55 and not night               # Sonne hinter Wolken
	var target := float(preset.get("hdri_energy", 0.8))
	var energy := target / maxf(0.02, float(a.avg))
	if night:
		energy = target / maxf(0.002, float(a.avg)) * 0.22
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/sky_hdri.gdshader")
	sm.set_shader_parameter("panorama", load(String(a.path)))
	sm.set_shader_parameter("yaw", want_az - az_h)
	sm.set_shader_parameter("energy", energy)
	var hc: Color = a.horizon
	sm.set_shader_parameter("horizon_col", Color(hc.r, hc.g, hc.b) * 1.0)
	sm.set_shader_parameter("radiance_scale", 0.55 if not overcast else 0.75)
	sm.set_shader_parameter("sun_boost", 0.0 if night else 1.0)
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.9 if not overcast else 1.15
	# Nebel in der (etwas gedämpften) Farbe des Horizonts – die Ferne verschmilzt mit dem Foto
	var fog_c := Color(hc.r, hc.g, hc.b) * energy * 0.75
	var mx := maxf(fog_c.r, maxf(fog_c.g, fog_c.b))
	if mx > 0.9:
		fog_c = fog_c * (0.9 / mx)
	env.fog_light_color = fog_c
	if env.volumetric_fog_enabled:
		env.volumetric_fog_albedo = Color(0.75, 0.78, 0.82).lerp(fog_c, 0.4)
	# Sonne wie im Foto: Höhe (mind. 7°), Farbe; tief stehend = wärmer und schwächer
	var e := maxf(elev, deg_to_rad(7.0))
	sun.rotation = Vector3(-e, want_az, 0.0)
	var sc: Color = a.sun_col
	sun.light_color = sc.lerp(Color(1.0, 0.97, 0.92), 0.35) if not night else Color(0.6, 0.7, 1.0)
	var deg := rad_to_deg(e)
	sun.light_energy = lerpf(1.6, 2.6, clampf(deg / 45.0, 0.0, 1.0)) * float(preset.get("sun_scale", 1.0)) * lerpf(0.4, 1.0, strength)
	sun.light_angular_distance = lerpf(4.0, 0.5, strength)     # bedeckt: weiche Schatten
	if night:
		sun.light_energy = 0.35
	return true

class_name DayCycle
extends Node
## Tag-Nacht-Wechsel im Freien. Ein voller Sonnenlauf dauert CYCLE_DAYS Spieltage (ein Spieltag = World3D.DAY_SECONDS):
## Phase 0 = Sonnenaufgang, 0,25 = Mittag, 0,5 = Sonnenuntergang, 0,75 = Mitternacht. Verändert werden Sonne
## (Höhe, Stärke, Farbe – nachts wird sie zum Mond), Himmelshelligkeit des HDRI-Shaders, Umgebungslicht, Nebelfarbe,
## die Helligkeit aller Lampen und Feuer (nachts heller) sowie Bewohner (nachts weniger, Händler schließen) und der
## Umgebungsklang (Nachtvariante). Innenräume und Nazarick bleiben unberührt; Orte mit Nacht-Himmel (Friedhof) auch.
## Einstellung: Settings.day_cycle. Testwerkzeug: `force` = feste Phase (TOD=0.8 → Nacht).

const CYCLE_DAYS := 8.0

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var lamps: Array = []
var folk: Array = []
var base := {}
var active := false
var phase := 0.0
var force := -1.0
var night := false
var _loc: Dictionary = {}
var _last := -10.0
## Wetter (scripts/world3d/weather.gd): Faktoren für Himmel, Sonne, Umgebungslicht, Nebel und eine Tönung der Sonne.
var weather: Dictionary = {}
var _flash := 0.0


## Wetterfaktoren setzen und sofort anwenden.
func set_weather(w: Dictionary) -> void:
	weather = w
	_last = -10.0
	if active and is_instance_valid(sun):
		_apply()


## Blitz: Sonne und Himmel für einen Augenblick grell (Gewitter).
func flash(secs: float = 0.12) -> void:
	if not active or not is_instance_valid(sun):
		return
	_flash = secs
	sun.light_energy = maxf(sun.light_energy, 1.0) * 5.0
	sun.light_color = Color(0.9, 0.92, 1.0)
	sky_mat.set_shader_parameter("energy", float(base.sky_energy) * 1.6)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_last = -10.0
			_apply()


## Nach dem Ortsaufbau aufrufen: sucht Himmel, Sonne, Lampen und Bewohner und merkt sich die Tageswerte.
func setup(level: Node3D, loc: Dictionary) -> void:
	active = false
	night = false
	env = null
	sun = null
	sky_mat = null
	base = {}
	lamps = []
	folk = []
	_loc = loc
	_last = -10.0
	if level == null or String(loc.get("group", "")) != "world":
		return
	for c in level.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D:
			sun = c
	if env == null or sun == null or env.sky == null or not (env.sky.sky_material is ShaderMaterial):
		return
	sky_mat = env.sky.sky_material
	if float(sky_mat.get_shader_parameter("sun_boost")) <= 0.0:
		return     # Nacht-Himmel (Friedhof): dort ist es immer Nacht
	base = {"sun_energy": sun.light_energy, "sun_color": sun.light_color, "sun_rot": sun.rotation,
		"ambient": env.ambient_light_energy, "sky_energy": float(sky_mat.get_shader_parameter("energy")),
		"sun_boost": float(sky_mat.get_shader_parameter("sun_boost")), "fog_light": env.fog_light_color,
		"vol_albedo": env.volumetric_fog_albedo, "shadow": sun.shadow_enabled,
		"fog_density": env.fog_density, "vol_density": env.volumetric_fog_density}
	for l in level.find_children("*", "OmniLight3D", true, false):
		if not l.has_meta("base_day"):
			l.set_meta("base_day", float(l.get_meta("base")) if l.has_meta("base") else (l as OmniLight3D).light_energy)
		lamps.append(l)
	folk = level.find_children("*", "Townsfolk", true, false)
	active = true


## Jeden Frame: `day_f` = Spieltag mit Bruchteil (Game.state.day + Tageszeit); wendet nur bei Änderung an.
func update(day_f: float) -> void:
	if not active or not is_instance_valid(sun) or not is_instance_valid(env):
		active = false
		return
	if not Settings.day_cycle:
		if _last != -1.0:
			_restore()
			_last = -1.0
		return
	phase = force if force >= 0.0 else fposmod(day_f / CYCLE_DAYS, 1.0)
	if absf(phase - _last) < 0.0015 and _last >= 0.0:
		return
	_last = phase
	_apply()


## Sonnenstand s = sin(Phase): > 0 Tag, < 0 Nacht; d = Tageslicht, n = Nacht, w = Dämmerung (Sonne am Horizont).
func _apply() -> void:
	var s := sin(phase * TAU)
	var d := clampf(s * 3.0, 0.0, 1.0)
	var n := clampf(-s * 3.0, 0.0, 1.0)
	var w := clampf(1.0 - absf(s) * 4.0, 0.0, 1.0)
	var rot: Vector3 = base.sun_rot
	var elev0 := -rot.x
	# Wetterfaktoren (bedeckt, Regen, Nebel, Schnee, Sand) dämpfen Himmel und Sonne und verdichten den Nebel
	var wk_sky := float(weather.get("sky", 1.0))
	var wk_sun := float(weather.get("sun", 1.0))
	var wk_amb := float(weather.get("ambient", 1.0))
	var wk_fog := float(weather.get("fog", 1.0))
	var tint: Color = weather.get("tint", Color.WHITE)
	var tint_amount := float(weather.get("tint_amount", 0.0))
	if s >= 0.0:
		# Tag: Sonne steigt von 3° bis über die Höhe des Fotos und sinkt wieder; tief stehend warm und schwach
		sun.rotation = Vector3(-lerpf(deg_to_rad(3.0), elev0 + deg_to_rad(12.0), s), rot.y, rot.z)
		sun.light_energy = float(base.sun_energy) * lerpf(0.12, 1.0, d) * wk_sun
		sun.light_color = (base.sun_color as Color).lerp(Color(1.0, 0.55, 0.3), w * 0.75).lerp(tint, tint_amount)
		sun.shadow_enabled = bool(base.shadow) and wk_sun > 0.45
	else:
		# Nacht: die Sonne wird zum Mond (blau, schwach, von der Gegenseite)
		sun.rotation = Vector3(-lerpf(deg_to_rad(3.0), deg_to_rad(38.0), n), rot.y + PI, rot.z)
		sun.light_energy = lerpf(0.14, 0.42, n) * float(base.sun_energy) / maxf(0.5, float(base.sun_energy)) * wk_sun
		sun.light_color = Color(0.62, 0.7, 1.0)
		sun.shadow_enabled = bool(base.shadow)
	sky_mat.set_shader_parameter("energy", float(base.sky_energy) * lerpf(0.06, 1.0, d) * wk_sky)
	sky_mat.set_shader_parameter("sun_boost", float(base.sun_boost) * d * wk_sun)
	# Nacht: Umgebungslicht kräftig anheben (Mond, Sterne); in Städten und Dörfern noch etwas mehr (Lichtschein)
	var town := String(_loc.get("kind", "")) in ["city", "village", "palace", "wall"]
	env.ambient_light_energy = float(base.ambient) * lerpf(1.0, 5.2 if town else 4.4, n) * wk_amb
	var fog_c := (base.fog_light as Color).lerp(Color(0.06, 0.08, 0.14), n * 0.85).lerp(Color(0.6, 0.35, 0.2), w * 0.35)
	if weather.has("fog_color"):
		fog_c = fog_c.lerp(weather.fog_color, 0.6)
	env.fog_light_color = fog_c
	env.fog_density = float(base.fog_density) * wk_fog
	if env.volumetric_fog_enabled:
		env.volumetric_fog_albedo = (base.vol_albedo as Color).lerp(Color(0.3, 0.35, 0.5), n)
		env.volumetric_fog_density = float(base.vol_density) * lerpf(1.0, wk_fog, 0.6)
	for l in lamps:
		if is_instance_valid(l):
			var bd: float = l.get_meta("base_day")
			var e := bd * lerpf(0.75, 1.35, n)
			if l.has_meta("flicker") or l.has_meta("base"):
				l.set_meta("base", e)
			else:
				(l as OmniLight3D).light_energy = e
	var is_night := n > 0.35
	if is_night != night:
		night = is_night
		for t in folk:
			if is_instance_valid(t):
				(t as Townsfolk).set_night(night)
		for g in get_tree().get_nodes_in_group("window_glow"):
			(g as OmniLight3D).light_energy = 1.3 if night else 0.0
		Audio.play_ambience_for(_loc, night)
		if get_parent() and get_parent().has_method("_night_changed"):
			get_parent()._night_changed(night)


func _restore() -> void:
	if base.is_empty() or not is_instance_valid(sun):
		return
	sun.rotation = base.sun_rot
	sun.light_energy = float(base.sun_energy)
	sun.light_color = base.sun_color
	sky_mat.set_shader_parameter("energy", float(base.sky_energy))
	sky_mat.set_shader_parameter("sun_boost", float(base.sun_boost))
	env.ambient_light_energy = float(base.ambient)
	env.fog_light_color = base.fog_light
	env.fog_density = float(base.fog_density)
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = float(base.vol_density)
	for l in lamps:
		if is_instance_valid(l):
			var bd: float = l.get_meta("base_day")
			if l.has_meta("flicker") or l.has_meta("base"):
				l.set_meta("base", bd)
			else:
				(l as OmniLight3D).light_energy = bd
	if night:
		night = false
		for t in folk:
			if is_instance_valid(t):
				(t as Townsfolk).set_night(false)
		Audio.play_ambience_for(_loc, false)


## Tageszeit als Text für Anzeigen (z. B. „Abend“).
func time_name() -> String:
	if not active:
		return ""
	var h := fposmod(6.0 + phase * 24.0, 24.0)
	if h >= 20.0 or h < 5.0:
		return "Nacht"
	if h < 8.0:
		return "Morgen"
	if h < 12.0:
		return "Vormittag"
	if h < 17.0:
		return "Nachmittag"
	if h < 20.0:
		return "Abend"
	return "Nacht"

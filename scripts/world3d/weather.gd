extends Node
## Wetter im Freien, je Spieltag und Gegend fest ausgewürfelt (gleicher Tag, gleiche Gegend = gleiches Wetter):
##   clear · overcast (bedeckt) · rain (Regen mit Gewitter) · fog (Nebelmorgen) · snow (Gebirge) · sand (Drachenlande)
## Wirkung: Faktoren für Himmel, Sonne, Umgebungslicht und Nebel über DayCycle.set_weather, Partikel um den Spieler
## (Tropfen, Flocken, Sand), eigene Klangschleife, bei Regen gelegentlich Blitz und Donner. Innenräume, Nazarick und
## der Friedhof (immer Nacht) bleiben unberührt. Testwerkzeug: WEATHER=rain erzwingt eine Art.

const LOOPS := {"rain": "rain", "sand": "storm", "snow": "snowwind"}
const NAMES := {"clear": "", "overcast": "Bedeckt", "rain": "Regen", "fog": "Nebel", "snow": "Schneefall", "sand": "Sandsturm"}

var kind := "clear"
var force := ""
var _world: Node
var _loc: Dictionary = {}
var _day := -1
var _particles: CPUParticles3D
var _audio := AudioStreamPlayer.new()
var _rng := RandomNumberGenerator.new()
var _thunder := 0.0


func _ready() -> void:
	_audio.volume_db = -80.0
	add_child(_audio)
	Settings.changed.connect(func(): if _audio.playing: _audio.volume_db = _volume_db())


## Nach dem Ortsaufbau: Wetter des Tages bestimmen und anwenden (nur wenn der Tag-Nacht-Wechsel aktiv ist).
func setup(world: Node, loc: Dictionary) -> void:
	_world = world
	_loc = loc
	_day = -1
	_clear_particles()
	_stop_audio()
	kind = "clear"
	refresh(int(Game.state.get("day", 1)), true)


## Neuer Tag → neues Wetter (sanft: Partikel und Klang wechseln sofort, Licht folgt über DayCycle).
func refresh(day: int, immediate: bool = false) -> void:
	if _world == null or not _world.day_cycle.active:
		return
	if day == _day and not immediate:
		return
	_day = day
	var k := force if force != "" else pick(day, _loc)
	if k == kind and not immediate:
		return
	kind = k
	_apply()


## Wetterart für Tag und Gegend – deterministisch, mit regionaler Eigenart.
func pick(day: int, loc: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [String(loc.get("region", loc.get("id", ""))), day])
	var r := rng.randf()
	match String(loc.get("kind", "")):
		"mountain":
			return "snow" if r < 0.3 else ("fog" if r < 0.45 else ("overcast" if r < 0.6 else "clear"))
		"peaks":
			return "sand" if r < 0.3 else ("overcast" if r < 0.5 else "clear")
		"swamp":
			return "fog" if r < 0.4 else ("rain" if r < 0.6 else ("overcast" if r < 0.75 else "clear"))
		"forest":
			return "fog" if r < 0.25 else ("rain" if r < 0.4 else ("overcast" if r < 0.55 else "clear"))
		"battlefield", "wall":
			return "overcast" if r < 0.3 else ("rain" if r < 0.45 else ("fog" if r < 0.55 else "clear"))
	return "rain" if r < 0.15 else ("fog" if r < 0.25 else ("overcast" if r < 0.45 else "clear"))


func _apply() -> void:
	var w := {}
	match kind:
		"overcast":
			w = {"sky": 0.72, "sun": 0.5, "ambient": 0.9, "fog": 1.4, "tint": Color(0.8, 0.82, 0.86), "tint_amount": 0.6}
		"rain":
			w = {"sky": 0.55, "sun": 0.3, "ambient": 0.8, "fog": 2.2, "tint": Color(0.7, 0.74, 0.8), "tint_amount": 0.8}
		"fog":
			w = {"sky": 0.8, "sun": 0.55, "ambient": 1.0, "fog": 3.5, "tint": Color(0.9, 0.9, 0.9), "tint_amount": 0.5}
		"snow":
			w = {"sky": 0.7, "sun": 0.45, "ambient": 1.05, "fog": 2.6, "tint": Color(0.85, 0.9, 1.0), "tint_amount": 0.7, "fog_color": Color(0.82, 0.86, 0.92)}
		"sand":
			w = {"sky": 0.75, "sun": 0.7, "ambient": 0.9, "fog": 3.0, "tint": Color(0.95, 0.8, 0.55), "tint_amount": 0.7, "fog_color": Color(0.75, 0.6, 0.4)}
	_world.day_cycle.set_weather(w)
	# Gebäude-Shader: bei Regen nasse Streifen an den Wänden (Global overlord_weather.z), sonst Normalwert
	RenderingServer.global_shader_parameter_set("overlord_weather", Vector4(0.3, 0.0, 0.95 if kind == "rain" else 0.5, 0.7))
	_clear_particles()
	if kind in ["rain", "snow", "sand"] and Settings.particles:
		_particles = CPUParticles3D.new()
		var qm := QuadMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.disable_receive_shadows = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		mat.billboard_keep_scale = true
		match kind:
			"rain":
				# Regen: weiche Schliere, bleibt senkrecht (dreht sich nur um die Hochachse zur Kamera)
				qm.size = Vector2(0.035, 0.6)
				mat.albedo_texture = B3.fx_tex("fx_streak")
				mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
				mat.albedo_color = Color(0.78, 0.84, 0.95, 0.38)
				_particles.amount = 1400
				_particles.lifetime = 1.1
				_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				_particles.emission_box_extents = Vector3(16, 1, 16)
				_particles.direction = Vector3(0.08, -1, 0)
				_particles.spread = 3.0
				_particles.initial_velocity_min = 14.0
				_particles.initial_velocity_max = 18.0
				_particles.gravity = Vector3.ZERO
			"snow":
				# Schnee: weiche runde Flocken in verschiedenen Größen
				qm.size = Vector2(0.09, 0.09)
				mat.albedo_texture = B3.fx_tex("fx_dot")
				mat.albedo_color = Color(1, 1, 1, 0.95)
				_particles.scale_amount_min = 0.55
				_particles.scale_amount_max = 1.5
				_particles.amount = 1400
				_particles.lifetime = 6.0
				_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				_particles.emission_box_extents = Vector3(18, 1, 18)
				_particles.direction = Vector3(0.2, -1, 0.1)
				_particles.spread = 25.0
				_particles.initial_velocity_min = 1.2
				_particles.initial_velocity_max = 2.2
				_particles.gravity = Vector3.ZERO
			"sand":
				qm.size = Vector2(0.1, 0.07)
				mat.albedo_texture = B3.fx_tex("fx_dot")
				mat.albedo_color = Color(0.85, 0.7, 0.45, 0.5)
				_particles.amount = 1100
				_particles.lifetime = 2.2
				_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				_particles.emission_box_extents = Vector3(4, 7, 18)
				_particles.direction = Vector3(1, -0.15, 0.2)
				_particles.spread = 12.0
				_particles.initial_velocity_min = 9.0
				_particles.initial_velocity_max = 14.0
				_particles.gravity = Vector3.ZERO
		qm.material = mat
		_particles.mesh = qm
		_world.level.add_child(_particles)
	# Klang: Regenrauschen, Sturm, Schneewind
	if LOOPS.has(kind):
		var stream: AudioStream = Audio._load(Audio.AMBIENCE_DIR + String(LOOPS[kind]) + ".ogg")
		if stream:
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			_audio.stream = stream
			_audio.volume_db = -80.0
			_audio.play(_rng.randf() * 20.0)
			create_tween().tween_property(_audio, "volume_db", _volume_db(), 3.0)
	else:
		_stop_audio()
	_thunder = _rng.randf_range(6.0, 20.0)


func _process(delta: float) -> void:
	if _particles and is_instance_valid(_particles) and _world and is_instance_valid(_world.player):
		var p: Vector3 = _world.player.global_position
		_particles.global_position = p + Vector3(0, 9.0 if kind != "sand" else 3.0, 0) + (Vector3(-14, 0, 0) if kind == "sand" else Vector3.ZERO)
	if kind == "rain" and _world and _world.day_cycle.active:
		_thunder -= delta
		if _thunder <= 0.0:
			_thunder = _rng.randf_range(12.0, 40.0)
			_world.day_cycle.flash(0.14)
			var t := get_tree().create_timer(_rng.randf_range(0.6, 2.2))
			t.timeout.connect(func(): Audio.sfx("thunder", 0.9))


func _volume_db() -> float:
	return linear_to_db(maxf(0.0001, Settings.ambience_volume * 0.8))


func _clear_particles() -> void:
	if _particles and is_instance_valid(_particles):
		_particles.queue_free()
	_particles = null


func _stop_audio() -> void:
	if _audio.playing:
		var tw := create_tween()
		tw.tween_property(_audio, "volume_db", -80.0, 1.5)
		tw.tween_callback(_audio.stop)


## Anzeigename („Regen“), leer bei klarem Himmel.
func label() -> String:
	return String(NAMES.get(kind, ""))

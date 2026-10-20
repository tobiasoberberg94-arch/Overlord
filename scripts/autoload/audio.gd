extends Node
## Audio – Musik (mit Überblendung) und Soundeffekte.
##
## Musik: res://assets/audio/music/<name>.ogg   (title, throne, tension)
## Effekte: res://assets/audio/sfx/<name>.ogg   (click, hover, page, dispatch, gong, order, love, rebuke)
## Alle Buttons im Spiel klicken automatisch (siehe _on_node_added).
## Die Stücke werden von tools/audio/compose.py erzeugt und können einfach ersetzt werden.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const FADE := 1.6
const SFX_VOICES := 6
const SFX3D_VOICES := 20
const COMBAT_DIR := "res://assets/audio/sfx/combat/"

var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx3d: Array[AudioStreamPlayer3D] = []
var _sfx3d_next := 0
var _variants := {}
var _reverb: AudioEffectReverb
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	# Kampfgeräusche: eigener Bus mit Hall (Stärke je Ort, siehe set_space)
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Kampf")
	AudioServer.set_bus_send(bus, "Master")
	_reverb = AudioEffectReverb.new()
	_reverb.predelay_msec = 40.0
	_reverb.hipass = 0.15
	AudioServer.add_bus_effect(bus, _reverb)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -10.0
	comp.ratio = 3.0
	comp.attack_us = 2000.0
	AudioServer.add_bus_effect(bus, comp)
	for i in SFX3D_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Kampf"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_distance = 70.0
		p.panning_strength = 0.85
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_sfx3d.append(p)
	get_tree().node_added.connect(_on_node_added)
	Settings.changed.connect(_apply_volume)


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Wechselt das Musikstück mit weicher Überblendung (gleicher Name = nichts tun).
func play_music(track: String) -> void:
	if track == _current:
		return
	var stream := _load(MUSIC_DIR + track + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_current = track
	var old := _music[_active]
	_active = 1 - _active
	var nxt := _music[_active]
	nxt.stream = stream
	nxt.volume_db = -80.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", _music_db(), FADE).set_trans(Tween.TRANS_SINE)
	tw.tween_property(old, "volume_db", -80.0, FADE).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(old.stop)


func stop_music() -> void:
	_current = ""
	for p in _music:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -80.0, FADE)
		tw.tween_callback(p.stop)


func sfx(name: String, volume: float = 1.0) -> void:
	if Settings.sfx_volume <= 0.001:
		return
	var stream := _load(SFX_DIR + name + ".ogg")
	if stream == null:
		return
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_VOICES
	p.stream = stream
	p.volume_db = linear_to_db(maxf(0.0001, Settings.sfx_volume * volume))
	p.play()


## Raumklang im Kampf: Geräusch an einer Weltposition (Abstand, Richtung, Hall des Ortes). Aus mehreren Varianten
## (<name>_1.ogg, <name>_2.ogg …) wird zufällig gewählt und die Tonhöhe leicht gestreut – nichts klingt zweimal gleich.
func sfx3d(name: String, pos: Vector3, volume: float = 1.0, pitch_var: float = 0.07, unit: float = 7.0) -> void:
	if Settings.sfx_volume <= 0.001:
		return
	var stream := _variant(name)
	if stream == null:
		return
	var p: AudioStreamPlayer3D = null
	# freie Stimme suchen, sonst die älteste (leiseste Kollision mit laufenden Klängen)
	for i in _sfx3d.size():
		var c: AudioStreamPlayer3D = _sfx3d[(_sfx3d_next + i) % _sfx3d.size()]
		if not c.playing:
			p = c
			_sfx3d_next = (_sfx3d_next + i + 1) % _sfx3d.size()
			break
	if p == null:
		p = _sfx3d[_sfx3d_next]
		_sfx3d_next = (_sfx3d_next + 1) % _sfx3d.size()
	p.stream = stream
	p.global_position = pos
	p.unit_size = unit
	p.volume_db = linear_to_db(maxf(0.0001, Settings.sfx_volume * volume))
	p.pitch_scale = clampf(1.0 + randf_range(-pitch_var, pitch_var), 0.5, 2.0) * Engine.time_scale ** 0.35
	p.play()


func _variant(name: String) -> AudioStream:
	if not _variants.has(name):
		var list: Array = []
		var single := _load(COMBAT_DIR + name + ".ogg")
		if single:
			list.append(single)
		for i in range(1, 9):
			var s := _load(COMBAT_DIR + "%s_%d.ogg" % [name, i])
			if s == null:
				break
			list.append(s)
		_variants[name] = list
	var l: Array = _variants[name]
	if l.is_empty():
		return null
	return l[randi() % l.size()]


## Hall je Ort: große Hallen und Grüfte klingen weit, Wälder und Ebenen trocken.
func set_space(kind: String) -> void:
	var room := 0.35
	var wet := 0.12
	match kind:
		"throne", "tombs", "library", "treasury", "royal", "cathedral", "lava":
			room = 0.85
			wet = 0.3
		"glacier", "mountain", "peaks", "cemetery":
			room = 0.6
			wet = 0.2
		"city", "palace", "wall", "village":
			room = 0.45
			wet = 0.14
		"forest", "jungle", "swamp":
			room = 0.3
			wet = 0.1
	if _reverb:
		_reverb.room_size = room
		_reverb.wet = wet
		_reverb.damping = 0.55 if room > 0.6 else 0.7


func _music_db() -> float:
	return linear_to_db(maxf(0.0001, Settings.music_volume * 0.8))


func _apply_volume() -> void:
	if _current != "":
		_music[_active].volume_db = _music_db()


## Jeder neu erzeugte Button bekommt Klick- und (leise) Hover-Geräusche.
func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b and not b.has_meta("silent"):
		b.pressed.connect(func(): if Settings.ui_sounds: sfx("click", 0.7))
		b.mouse_entered.connect(func(): if Settings.ui_sounds and not b.disabled: sfx("hover", 0.25))

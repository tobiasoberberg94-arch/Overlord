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

var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0
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

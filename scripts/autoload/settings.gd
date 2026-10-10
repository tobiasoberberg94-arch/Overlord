extends Node
## Settings – Benutzereinstellungen, gespeichert in user://settings.cfg
## (unabhängig von Spielständen). Änderungen werden sofort angewendet.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const WINDOW_MODES := ["Fenster", "Vollbild (randlos)", "Vollbild (exklusiv)"]
const FPS_LIMITS := [30, 60, 120, 0]
const TEXT_SPEEDS := ["Langsam", "Normal", "Schnell", "Sofort"]
const TEXT_SPEED_FACTORS := [0.55, 1.0, 1.8, 0.0]
const AUTOSAVE_OPTIONS := [0, 7, 30]

# Audio
var master_volume := 1.0
var music_volume := 0.7
var sfx_volume := 0.8
var ui_sounds := true
# Grafik
var window_mode := 0
var resolution := 1
var vsync := true
var max_fps := 1
var particles := true
var ui_scale := 1.0
# Spiel
var text_speed := 1
var auto_open := true
var autosave := 1
var tutorial_done := false

## Kompatibilität: alter Schalter
var fullscreen: bool:
	get: return window_mode != 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in _keys():
			var section: String = key[0]
			var prop: String = key[1]
			set(prop, cfg.get_value(section, prop, get(prop)))
		# alte Einstellungsdatei (v1)
		if cfg.has_section_key("audio", "music"):
			music_volume = cfg.get_value("audio", "music")
		if cfg.has_section_key("audio", "sfx"):
			sfx_volume = cfg.get_value("audio", "sfx")
		if cfg.has_section_key("game", "tutorial_done"):
			tutorial_done = cfg.get_value("game", "tutorial_done")
	apply_all()


func _keys() -> Array:
	return [
		["audio", "master_volume"], ["audio", "music_volume"], ["audio", "sfx_volume"], ["audio", "ui_sounds"],
		["video", "window_mode"], ["video", "resolution"], ["video", "vsync"], ["video", "max_fps"],
		["video", "particles"], ["video", "ui_scale"],
		["game", "text_speed"], ["game", "auto_open"], ["game", "autosave"], ["game", "tutorial_done"],
	]


func save() -> void:
	var cfg := ConfigFile.new()
	for key in _keys():
		cfg.set_value(key[0], key[1], get(key[1]))
	cfg.save(PATH)
	changed.emit()


## Setzt einen Wert, wendet ihn an und speichert.
func set_value(prop: String, value: Variant) -> void:
	set(prop, value)
	apply_all()
	save()


func apply_all() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master_volume)))
	Engine.max_fps = FPS_LIMITS[clampi(max_fps, 0, FPS_LIMITS.size() - 1)]
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res: Vector2i = RESOLUTIONS[clampi(resolution, 0, RESOLUTIONS.size() - 1)]
			var screen := DisplayServer.screen_get_usable_rect()
			res = Vector2i(mini(res.x, screen.size.x), mini(res.y, screen.size.y))
			if DisplayServer.window_get_size() != res:
				DisplayServer.window_set_size(res)
				DisplayServer.window_set_position(screen.position + (screen.size - res) / 2)
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_factor = ui_scale


## Faktor für den Schreibmaschinen-Effekt (0 = sofort).
func text_speed_factor() -> float:
	return TEXT_SPEED_FACTORS[clampi(text_speed, 0, TEXT_SPEED_FACTORS.size() - 1)]


func autosave_days() -> int:
	return AUTOSAVE_OPTIONS[clampi(autosave, 0, AUTOSAVE_OPTIONS.size() - 1)]


func set_fullscreen(on: bool) -> void:
	set_value("window_mode", 1 if on else 0)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F11:
		set_fullscreen(window_mode == 0)

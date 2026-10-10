extends Node
## Settings – Benutzereinstellungen (Lautstärke, Vollbild, Tutorial-Status).
## Gespeichert in user://settings.cfg, unabhängig von Spielständen.

signal changed

const PATH := "user://settings.cfg"

var music_volume := 0.7
var sfx_volume := 0.8
var fullscreen := false
var tutorial_done := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		tutorial_done = cfg.get_value("game", "tutorial_done", tutorial_done)
	_apply_window()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.save(PATH)
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	save()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F11:
		set_fullscreen(not fullscreen)

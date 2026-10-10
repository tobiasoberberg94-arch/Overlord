extends Node
## SaveSystem – Speichern & Laden von Spielständen als JSON in user://saves/.
##
## Gespeichert wird nur der veränderliche Zustand (Game.state). Statische Inhalte
## stammen immer aus res://data – neue Inhalte wirken so auch auf alte Spielstände.

const SAVE_DIR := "user://saves/"
const SLOTS := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func save_game(slot: int) -> bool:
	var payload := {
		"version": 1,
		"meta": {
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"day": Game.state.get("day", 1),
			"chapter": Game.state.get("chapter", 1),
			"lord_name": Game.state.get("lord_name", "Momonga"),
		},
		"state": Game.state,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: Speichern fehlgeschlagen (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if slot > 0:
		Game.log_msg("Die Chronik wurde in Siegel %d verwahrt." % slot, "info")
	return true


func load_game(slot: int) -> bool:
	if not FileAccess.file_exists(slot_path(slot)):
		return false
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("state"):
		push_error("SaveSystem: Spielstand %d ist beschädigt." % slot)
		return false
	Game.load_state(parsed["state"])
	return true


func slot_meta(slot: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(slot)):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"saved_at": "beschädigt", "day": 0, "chapter": 0, "lord_name": "?"}
	return parsed.get("meta", {})


## Siegel 0 ist das automatische Speichern.
func has_any_save() -> bool:
	for i in range(0, SLOTS + 1):
		if FileAccess.file_exists(slot_path(i)):
			return true
	return false

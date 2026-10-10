class_name SaveLoadDialog
extends Overlay
## Speichern / Laden in drei Siegel-Slots.

signal loaded

var save_mode := true


func _init(saving: bool) -> void:
	super._init(Vector2(760, 0))
	save_mode = saving
	content.add_child(make_header("Chronik versiegeln" if saving else "Chronik öffnen",
		"Wählt eines der drei Siegel." if saving else "Welche Geschichte soll fortgesetzt werden?"))
	content.add_child(HSeparator.new())
	for i in range(1, SaveSystem.SLOTS + 1):
		var meta := SaveSystem.slot_meta(i)
		var b := Button.new()
		b.theme_type_variation = "ButtonCard"
		b.custom_minimum_size = Vector2(0, 80)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if meta.is_empty():
			b.text = "Siegel %d\n— leer —" % i
			b.disabled = not saving
		else:
			var ch := Content.chapter(int(meta.get("chapter", 1)))
			b.text = "Siegel %d  ·  %s\nKapitel %s: %s  ·  Tag %d  ·  %s" % [i, meta.get("lord_name", "?"),
				ch.numeral, ch.title, int(meta.get("day", 0)), meta.get("saved_at", "")]
		b.pressed.connect(_on_slot.bind(i))
		content.add_child(b)
		UIFx.pop_in(b, 0.25, 0.05 * i)


func _on_slot(i: int) -> void:
	if save_mode:
		SaveSystem.save_game(i)
		close()
	elif SaveSystem.load_game(i):
		loaded.emit()
		close()

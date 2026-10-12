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
	for i in range(0 if not saving else 1, SaveSystem.SLOTS + 1):
		var meta := SaveSystem.slot_meta(i)
		if i == 0 and meta.is_empty():
			continue
		var b := Button.new()
		b.theme_type_variation = "ButtonCard"
		b.custom_minimum_size = Vector2(0, 80)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if meta.is_empty():
			b.text = "Siegel %d\n— leer —" % i
			b.disabled = not saving
		else:
			var ch := Content.chapter(int(meta.get("chapter", 1)))
			b.text = "%s  ·  %s\nKapitel %s: %s  ·  Tag %d  ·  %s" % ["Automatisch" if i == 0 else "Siegel %d" % i, meta.get("lord_name", "?"),
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

extends SceneTree
## Baut res://assets/ui/nazarick_theme.tres aus scripts/ui/nazarick_theme.gd.
## Aufruf:  godot --headless --path . --script res://tools/build_theme.gd

func _init() -> void:
	var theme: Theme = load("res://scripts/ui/nazarick_theme.gd").build()
	var err := ResourceSaver.save(theme, "res://assets/ui/nazarick_theme.tres")
	print("Theme gespeichert: ", error_string(err))
	quit(0 if err == OK else 1)

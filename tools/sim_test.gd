extends Node
## Automatischer Durchlauftest: spielt Nazarick headless mit zufälligen
## Entscheidungen und prüft, ob alle Kapitel erreichbar sind.
## Aufruf: godot --headless --path . res://tools/sim_test.tscn

func _ready() -> void:
	var runs := 6
	var reached: Array = []
	for r in runs:
		Game.rng.seed = 1000 + r
		Game.new_game()
		var steps := 0
		var kinds := {}
		while steps < 900 and Game.state.chapter < 8:
			steps += 1
			while not Game.pending().is_empty():
				var d: Dictionary = Game.pending()[0]
				kinds[d.kind] = kinds.get(d.kind, 0) + 1
				var opt: Dictionary = d.options[Game.rng.randi() % d.options.size()]
				Game.respond(d.uid, opt.key)
			# Aufträge verteilen
			for m in Game.available_missions():
				for cid in Game.unlocked_chars():
					if Game.can_assign(m, cid)[0]:
						var dirs := Content.directives.keys()
						Game.assign(m.id, cid, dirs[Game.rng.randi() % dirs.size()])
						break
			if Game.rng.randf() < 0.2:
				for cid in Game.unlocked_chars():
					if Game.is_available(cid) and Game.audiences_left() > 0:
						Game.audience(cid, ["talk", "gift", "rebuke"][Game.rng.randi() % 3])
						break
			Game.advance(7)
		reached.append(Game.state.chapter)
		print("Lauf %d: Kapitel %d an Tag %d | Rivalität %d | Gold %d | Depeschen %s | Flags %d" % [
			r, Game.state.chapter, Game.state.day, Game.state.rivalry, Game.state.resources.gold, kinds, Game.state.flags.size()])
		# Speichern/Laden-Rundlauf
		SaveSystem.save_game(3)
		var day: int = Game.state.day
		SaveSystem.load_game(3)
		assert(Game.state.day == day)
	print("ERGEBNIS: ", reached)
	get_tree().quit()

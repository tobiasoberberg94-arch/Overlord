extends Node
## Automatischer Durchlauftest: spielt Nazarick headless mit zufälligen
## Entscheidungen und prüft, ob alle Kapitel erreichbar sind.
## Aufruf: godot --headless --path . res://tools/sim_test.tscn

func _ready() -> void:
	var runs := 8
	var diffs := ["easy", "normal", "hard", "nightmare"]
	var reached: Array = []
	for r in runs:
		Game.rng.seed = 1000 + r
		Game.new_game(diffs[r % diffs.size()])
		var steps := 0
		var kinds := {}
		while steps < 3000 and not Game.has_flag("game_completed"):
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
						var partner := ""
						if Game.rng.randf() < 0.3:
							for p in Game.unlocked_chars():
								if p != cid and Game.is_available(p):
									partner = p
									break
						Game.assign(m.id, cid, dirs[Game.rng.randi() % dirs.size()], partner)
						break
			# Militär: Armee aufstellen, rekrutieren, Feldherr, Feldzug
			if Game.state.chapter >= 2 and Game.rng.randf() < 0.15:
				var a: Dictionary = Game.state.armies[0] if not Game.state.armies.is_empty() else Military.create_army()
				if a.location == "nazarick" and a.path.is_empty():
					var us := Military.available_units()
					for k in 2:
						Military.recruit(a.uid, us[Game.rng.randi() % us.size()].id)
					if a.commander == "":
						for cid in ["mare", "aura", "pandora", "demiurge"]:
							if Game.cs(cid).unlocked and Game.is_available(cid):
								Military.set_commander(a.uid, cid)
								break
					var targets: Array = Game.state.regions.keys().filter(func(id): return Military.can_conquer(id))
					if not targets.is_empty() and Military.strength(a) > 120:
						Military.order_move(a.uid, targets[Game.rng.randi() % targets.size()], true)
			# Diplomatie
			if Game.rng.randf() < 0.08:
				var kf := Diplomacy.known_factions()
				if not kf.is_empty():
					var f: Dictionary = kf[Game.rng.randi() % kf.size()]
					var acts: Array = Diplomacy.data.actions
					var act: Dictionary = acts[Game.rng.randi() % acts.size()]
					if act.id != "war" or Game.rng.randf() < 0.2:
						for cid in ["albedo", "demiurge", "sebas"]:
							if Game.is_available(cid):
								Diplomacy.start_action(f.id, act.id, cid)
								break
			# Erlasse gelegentlich wechseln
			if Game.rng.randf() < 0.05:
				var ds := World.available_decrees()
				if not ds.is_empty():
					World.toggle_decree(ds[Game.rng.randi() % ds.size()].id)
			if Game.rng.randf() < 0.2:
				for cid in Game.unlocked_chars():
					if Game.is_available(cid) and Game.audiences_left() > 0:
						Game.audience(cid, ["talk", "gift", "rebuke"][Game.rng.randi() % 3])
						break
			# Fortschritt: Ausbau, Ausrüstung, Albedos Truhe
			if Progress.ps().build.is_empty() and Game.state.resources.gold > 900:
				var fl: Array = Progress.floors.filter(func(f): return Progress.can_build(f.id)[0])
				if not fl.is_empty():
					Progress.start_build(fl[Game.rng.randi() % fl.size()].id)
			for cid in Game.unlocked_chars():
				Progress.auto_equip(cid)
			if Progress.can_claim_chest():
				Progress.claim_chest()
			Game.advance(7)
		reached.append(Game.state.chapter)
		var infl := {}
		for id in Game.state.regions:
			if Game.state.regions[id].discovered:
				infl[id] = Game.state.regions[id].influence
		var dip := {}
		for fid in Game.state.factions:
			var fst: Dictionary = Game.state.factions[fid]
			dip[fid] = "%d/%d%s" % [fst.relation, fst.fear, str(fst.treaties) if not fst.treaties.is_empty() else ""]
		var open_obj := Game.objectives().filter(func(o): return not o[1]).map(func(o): return o[0])
		if not open_obj.is_empty():
			print("   offen: ", open_obj)
		print("Lauf %d [%s]: Kapitel %d an Tag %d | Gold %d | Schlachten %d | Fraktionen %s" % [
			r, Game.state.difficulty, Game.state.chapter, Game.state.day, Game.state.resources.gold, kinds.get("battle", 0), dip])
		var ranks := {}
		for cid in Game.unlocked_chars():
			ranks[cid.substr(0, 3)] = Progress.rank(cid)
		var floors_lv := 0
		for f in Progress.floors:
			floors_lv += Progress.floor_level(f.id)
		print("   Ränge %s | Artefakte %d | Ausbau %d | Errungenschaften %d/%d | Wochen %d (Serie max %d)" % [
			ranks, Progress.inventory().size(), floors_lv, Progress.ps().achievements.size(), Progress.achievements.size(),
			Progress.stat("weeks_done"), Progress.stat("best_streak")])
		# Speichern/Laden-Rundlauf
		SaveSystem.save_game(3)
		var day: int = Game.state.day
		SaveSystem.load_game(3)
		assert(Game.state.day == day)
	print("ERGEBNIS: ", reached)
	get_tree().quit()

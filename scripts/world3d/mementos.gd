class_name Mementos
## Die 41 Erinnerungsstücke von Ainz Ooal Gown (data/mementos.json): je Ort versteckt (QuestWorld._spawn_mementos),
## gesammelt in Game.state.mementos, Fortschritt im Kodex des Questbuchs. Dazu der Entdeckungs-Fortschritt je Ort
## (Inschriften, Schreine, Verstecke, feste Entdeckungen und Erinnerungsstücke).

static var _data: Array = []
static var _disc: Dictionary = {}


static func all() -> Array:
	if _data.is_empty():
		var f := FileAccess.open("res://data/mementos.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = (parsed as Dictionary).get("mementos", [])
	return _data


static func by_loc(lid: String) -> Array:
	var out: Array = []
	for m in all():
		if String(m.get("loc", "")) == lid:
			out.append(m)
	return out


static func by_id(id: String) -> Dictionary:
	for m in all():
		if String(m.get("id", "")) == id:
			return m
	return {}


static func found() -> Array:
	return Game.state.get("mementos", [])


static func discoveries() -> Dictionary:
	if _disc.is_empty():
		var f := FileAccess.open("res://data/discoveries.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_disc = parsed
	return _disc


## Fortschritt eines Ortes: [gefunden, gesamt] über Inschriften, Schreine, Verstecke, feste Entdeckungen und
## Erinnerungsstücke. Schreine zählen als gefunden, sobald einmal gebetet wurde.
static func location_progress(lid: String) -> Array:
	var d: Dictionary = discoveries().get(lid, {})
	var picked: Dictionary = Game.state.get("picked", {})
	var total := 0
	var got := 0
	var lore: Array = d.get("lore", [])
	var n_random := lore.size() + int(d.get("shrines", 1 if not d.is_empty() and not d.has("placed") else 0)) + int(d.get("caches", 2 if not d.is_empty() and not d.has("placed") else 0))
	if d.is_empty():
		n_random = 0
	total += n_random
	for i in n_random:
		if picked.has("d:%s:%d" % [lid, i]):
			got += 1
	for e in d.get("placed", []):
		total += 1
		if picked.has("d:%s:%s" % [lid, String(e.get("id", e.get("title", "")))]):
			got += 1
	var fnd := found()
	for m in by_loc(lid):
		total += 1
		if String(m.get("id", "")) in fnd:
			got += 1
	return [got, total]

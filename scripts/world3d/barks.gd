class_name Barks
## Bemerkungen der Bewohner und Figuren (data/barks.json): kurze Sätze über den Köpfen, wenn der Spieler vorbeigeht.
## Die Gruppe hängt vom Stil des Bewohners (Townsfolk), vom Ort, von der Gestalt des Spielers (Ainz oder Momon),
## von Tageszeit und Geschichte ab (group_for). Figuren (Actor3D) haben eigene Zeilen je Id (for_char).

static var _data: Dictionary = {}
static var _last: Dictionary = {}
static var _rng := RandomNumberGenerator.new()


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/barks.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
		_rng.randomize()
	return _data


## Zufällige Zeile einer Gruppe, nie zweimal dieselbe hintereinander; "" wenn die Gruppe leer ist.
static func pick(group: String) -> String:
	var list: Array = data().get("folk", {}).get(group, [])
	return _choose(group, list)


## Zeile einer Figur (Einträge: Text oder {text, requires}); "" wenn nichts passt.
static func for_char(cid: String) -> String:
	var list: Array = []
	for e in data().get("chars", {}).get(cid, []):
		if e is Dictionary:
			if Game.check((e as Dictionary).get("requires", {})):
				list.append(String((e as Dictionary).get("text", "")))
		else:
			list.append(String(e))
	return _choose("char:" + cid, list)


static func _choose(key: String, list: Array) -> String:
	if list.is_empty():
		return ""
	if list.size() == 1:
		return String(list[0])
	var i := _rng.randi() % list.size()
	if i == int(_last.get(key, -1)):
		i = (i + 1) % list.size()
	_last[key] = i
	return String(list[i])


## Gruppe für einen Bewohner: style = Townsfolk-Stil ("" Passant), loc = Ort, player_style = "ainz" | "momon".
## "flee" in der Rückgabe bedeutet: die Gruppe erschrickt und weicht zurück.
static func group_for(style: String, loc: Dictionary, player_style: String, night: bool) -> String:
	var kind := String(loc.get("kind", ""))
	var lgroup := String(loc.get("group", ""))
	var region := String(loc.get("region", ""))
	var faction := String(loc.get("faction", ""))
	if lgroup == "interior":
		var parent: Dictionary = Content.location_by_id.get(String(loc.get("parent", "")), {})
		kind = String(parent.get("kind", kind))
		lgroup = String(parent.get("group", lgroup))
	var crowned := Game.has_flag("crowned")
	var human := kind in ["city", "palace", "cathedral", "village", "wall"]
	var friendly := player_style == "momon" or crowned or region == "carne"
	match style:
		"maid":
			return "nazarick_maid"
		"guard":
			if lgroup == "nazarick":
				return "nazarick_guard"
			if player_style == "ainz":
				return "guard_crowned" if crowned or region == "carne" else "guard_ainz"
			return "guard_momon"
		"merchant":
			return "merchant" if friendly else "ainz_human"
		"priest":
			return "priest" if friendly else "ainz_human"
		"mage":
			return "mage"
		"dwarf":
			return "dwarf"
		"smith":
			return "smith" if friendly else "ainz_human"
		"adventurer":
			return "adventurer" if friendly else "ainz_human"
		"noble":
			return "noble_empire" if faction == "empire" else "noble"
	if lgroup == "nazarick":
		return "nazarick_maid"
	if not human:
		return ""
	if player_style == "ainz":
		if region == "carne":
			return "ainz_carne"
		if not crowned:
			return "ainz_human"
	if night and _rng.randf() < 0.5:
		return "night"
	if Game.has_flag("katze_done") and region in ["re_capital", "e_rantel"] and _rng.randf() < 0.25:
		return "after_katze"
	if player_style == "ainz":
		return "ainz_crowned"
	return "momon_village" if kind == "village" else "momon_city"


## Erschrickt diese Gruppe (weicht zurück)?
static func flees(group: String) -> bool:
	return group == "ainz_human"

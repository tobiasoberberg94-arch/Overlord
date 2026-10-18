extends Node
## Abenteuer von Ainz/Momon (data/quests.json): Quests von NPCs und Anschlagtafeln, Beutel mit
## Materialien, Gegner-Beute und Sammelstellen. Zustand liegt in Game.state.quests / .bag.
##   Game.state.quests = {id: {"state": "active"|"done", "step": int, "n": int, "times": int}}
##   Game.state.bag    = {material_id: anzahl}
## Fortschritt kommt über die Haken on_kill / on_pickup / on_talk aus der 3D-Welt.

signal changed
signal step_done(quest_id: String, text: String)
signal completed(quest_id: String)

var data: Dictionary = {}
var by_id: Dictionary = {}
## im HUD verfolgte Quest (im Spielstand)
var tracked: String:
	get: return String(Game.state.get("quest_tracked", ""))
	set(v): Game.state["quest_tracked"] = v


func _ready() -> void:
	var f := FileAccess.open("res://data/quests.json", FileAccess.READ)
	if f:
		data = JSON.parse_string(f.get_as_text())
	for q in data.get("quests", []):
		by_id[q.id] = q


# ------------------------------------------------------------------ Zustand

func qs() -> Dictionary:
	if not Game.state.has("quests"):
		Game.state["quests"] = {}
	return Game.state.quests


func bag() -> Dictionary:
	if not Game.state.has("bag"):
		Game.state["bag"] = {}
	return Game.state.bag


func material(id: String) -> Dictionary:
	return data.get("materials", {}).get(id, {"name": id, "icon": "•", "value": 1})


func count(item: String) -> int:
	return int(bag().get(item, 0))


func add_item(item: String, n: int = 1) -> void:
	bag()[item] = count(item) + n
	_check_collect()
	changed.emit()


func take_item(item: String, n: int) -> bool:
	if count(item) < n:
		return false
	bag()[item] = count(item) - n
	if bag()[item] <= 0:
		bag().erase(item)
	changed.emit()
	return true


func state_of(id: String) -> String:
	return String(qs().get(id, {}).get("state", ""))


func is_active(id: String) -> bool:
	return state_of(id) == "active"


func active() -> Array:
	var out: Array = []
	for id in qs():
		if qs()[id].state == "active" and by_id.has(id):
			out.append(by_id[id])
	return out


func step(q: Dictionary) -> Dictionary:
	var st: Dictionary = qs().get(q.id, {})
	var i := int(st.get("step", 0))
	return q.steps[i] if i < q.steps.size() else {}


func step_progress(q: Dictionary) -> Array:
	var s := step(q)
	var st: Dictionary = qs().get(q.id, {})
	match String(s.get("type", "")):
		"kill":
			return [int(st.get("n", 0)), int(s.count)]
		"collect", "deliver":
			return [mini(count(s.item), int(s.count)), int(s.count)]
	return [0, 1]


## Text der aktuellen Aufgabe inkl. Fortschritt („Mondkraut 3/8“).
func step_text(q: Dictionary) -> String:
	var s := step(q)
	if s.is_empty():
		return ""
	var p := step_progress(q)
	if String(s.type) in ["kill", "collect", "deliver"]:
		return "%s  (%d/%d)" % [s.text, p[0], p[1]]
	return String(s.text)


# ------------------------------------------------------------------ Verfügbarkeit

func available(q: Dictionary) -> bool:
	var st := state_of(q.id)
	if st == "active":
		return false
	if st == "done" and not q.get("repeat", false):
		return false
	var req: Dictionary = q.get("requires", {})
	if req.has("chapter") and int(Game.state.get("chapter", 1)) < int(req.chapter):
		return false
	if req.has("quest") and state_of(req.quest) != "done":
		return false
	if req.has("flag") and not Game.has_flag(req.flag):
		return false
	return true


## Quests, die diese Figur anbietet (verfügbar) bzw. bei ihr abgegeben werden (aktiv, Schritt bei ihr).
func offers_of(npc: String) -> Array:
	return data.get("quests", []).filter(func(q): return q.get("giver", "") == npc and available(q))


func turnins_at(npc: String) -> Array:
	return active().filter(func(q): return String(step(q).get("npc", "")) == npc and _step_ready(q))


func board_quests(loc_id: String) -> Array:
	return data.get("quests", []).filter(func(q): return q.get("board", "") == loc_id and (available(q) or is_active(q.id)))


## Marker über dem Kopf: "!" neue Quest, "?" Abgabe möglich, "…" läuft.
func marker_for(npc: String) -> String:
	if not turnins_at(npc).is_empty():
		return "?"
	if not offers_of(npc).is_empty():
		return "!"
	for q in active():
		if String(step(q).get("npc", "")) == npc or q.get("giver", "") == npc:
			return "…"
	return ""


# ------------------------------------------------------------------ Ablauf

func accept(id: String) -> void:
	var prev: Dictionary = qs().get(id, {})
	qs()[id] = {"state": "active", "step": 0, "n": 0, "times": int(prev.get("times", 0))}
	if tracked == "" or not is_active(tracked):
		tracked = id
	Game.log_msg("Neuer Auftrag: %s" % by_id[id].title, "mission")
	Audio.sfx("page", 0.7)
	_check_collect()
	changed.emit()


func _step_ready(q: Dictionary) -> bool:
	var s := step(q)
	match String(s.get("type", "")):
		"deliver":
			return count(s.item) >= int(s.count)
		"talk":
			return true
	return false


func _advance(q: Dictionary) -> void:
	var st: Dictionary = qs()[q.id]
	var done_step := step(q)
	st.step = int(st.step) + 1
	st.n = 0
	if int(st.step) >= q.steps.size():
		_complete(q)
	else:
		step_done.emit(q.id, String(done_step.get("text", "")))
		_check_collect()
	changed.emit()


func _complete(q: Dictionary) -> void:
	var st: Dictionary = qs()[q.id]
	st.state = "done"
	st.times = int(st.get("times", 0)) + 1
	var r: Dictionary = q.get("rewards", {})
	var eff := {}
	if r.has("gold"):
		eff["res"] = {"gold": int(r.gold)}
	if r.has("res"):
		if not eff.has("res"):
			eff["res"] = {}
		for k in r.res:
			eff.res[k] = int(eff.res.get(k, 0)) + int(r.res[k])
	if r.has("chars"):
		eff["chars"] = r.chars
	if r.has("rivalry"):
		eff["rivalry"] = r.rivalry
	if q.has("on_done"):
		for k in q.on_done:
			eff[k] = q.on_done[k]
	if not eff.is_empty():
		Game.apply_effects(eff)
	for cid in r.get("xp", {}):
		Progress.add_xp(cid, int(r.xp[cid]))
	for m in r.get("bag", {}):
		bag()[m] = count(m) + int(r.bag[m])
	var it: String = String(r.get("item", ""))
	if it.begins_with("roll:"):
		Progress.grant_item(Progress.roll_item(it.substr(5)), "Belohnung: " + q.title)
	elif it != "":
		Progress.grant_item(it, "Belohnung: " + q.title)
	if tracked == q.id:
		tracked = ""
		for a in active():
			tracked = a.id
			break
	Game.log_msg("Auftrag erfüllt: %s" % q.title, "mission")
	Progress.bump("quests_done")
	completed.emit(q.id)


# ------------------------------------------------------------------ Haken aus der Welt

func on_kill(enemy: String, loc_id: String) -> void:
	for q in active():
		var s := step(q)
		if String(s.get("type", "")) == "kill" and s.enemy == enemy and (not s.has("loc") or s.loc == loc_id):
			var st: Dictionary = qs()[q.id]
			st.n = int(st.n) + 1
			if int(st.n) >= int(s.count):
				_advance(q)
			else:
				changed.emit()


func on_pickup(item: String, n: int = 1) -> void:
	add_item(item, n)


## Gesammelt genug? → nächster Schritt (bei Sammel-Kopfgeldern ohne Abgabe: Ware abliefern).
func _check_collect() -> void:
	for q in active():
		var s := step(q)
		if String(s.get("type", "")) == "collect" and count(s.item) >= int(s.count):
			if qs()[q.id].step == q.steps.size() - 1:
				take_item(s.item, int(s.count))
			_advance(q)


## Gespräch mit einer Figur: erledigt talk-Schritte; deliver-Schritte übergibt der Dialog (hand_in).
func on_talk(npc: String) -> void:
	for q in active():
		var s := step(q)
		if String(s.get("type", "")) == "talk" and s.npc == npc:
			_advance(q)


func hand_in(id: String) -> bool:
	var q: Dictionary = by_id.get(id, {})
	if q.is_empty() or not is_active(id):
		return false
	var s := step(q)
	if String(s.get("type", "")) == "deliver":
		if not take_item(s.item, int(s.count)):
			return false
	_advance(q)
	return true


## Gegner-Beute nach data/quests.json → loot: [[material, chance, min, max] | ["gold", …] | ["item", chance, rarity]]
func roll_loot(enemy: String) -> Array:
	var out: Array = []
	for e in data.get("loot", {}).get(enemy, []):
		if randf() > float(e[1]):
			continue
		if e[0] == "item":
			out.append(["item", Progress.roll_item(String(e[2])), 1])
		else:
			out.append([e[0], "", randi_range(int(e[2]), int(e[3]))])
	return out


## Verkauf aller Materialien (ohne Quest-Gegenstände) → Gold.
func sell_all() -> int:
	var total := 0
	for m in bag().keys():
		var d := material(m)
		if d.get("unique", false):
			continue
		var needed := 0
		for q in active():
			var s := step(q)
			if s.get("item", "") == m:
				needed = maxi(needed, int(s.count))
		var n := count(m) - needed
		if n <= 0:
			continue
		total += n * int(d.get("value", 1))
		bag()[m] = count(m) - n
		if bag()[m] <= 0:
			bag().erase(m)
	if total > 0:
		Game.apply_effects({"res": {"gold": total}})
	changed.emit()
	return total

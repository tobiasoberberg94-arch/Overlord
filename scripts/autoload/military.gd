extends Node
## Military – Armeen, Feldzüge und Schlachten auf der Weltkarte (Autoload).
##
## * Legionen werden in Nazarick rekrutiert (Gold) und kosten täglichen Unterhalt.
## * Ein Wächter kann eine Armee als Feldherr führen (Bonus) – er steht dann für
##   Aufträge nicht zur Verfügung.
## * Armeen ziehen entlang des Wegenetzes (data/regions.json → links) von Region zu Region.
## * Befehle: „Marschieren/Verteidigen“ oder „Erobern“ (Angriff auf die Garnison am Ziel).
## * Feindliche Mächte schicken Heere gegen Regionen unter Nazaricks Einfluss.
## * Treffen eigene und feindliche Armee aufeinander, kommt es zur Schlacht:
##   Der Spieler wählt eine Taktik, das Ergebnis wird berechnet und berichtet.
##
## Zustand in Game.state: armies, enemy_armies, battles.

const STATUS_CAMPAIGN := "feldzug"

var last_result: Dictionary = {}   ## Ergebnis der zuletzt ausgetragenen Schlacht (für die UI)
var _adj: Dictionary = {}


func _ready() -> void:
	_build_graph()


func _build_graph() -> void:
	_adj.clear()
	for l in Content.region_links:
		_adj.get_or_add(l[0], []).append([l[1], int(l[2])])
		_adj.get_or_add(l[1], []).append([l[0], int(l[2])])


func init_state(state: Dictionary) -> void:
	state["armies"] = []
	state["enemy_armies"] = []
	state["battles"] = {}


func normalize(state: Dictionary) -> void:
	if not state.has("armies"):
		init_state(state)
	for a in state.armies + state.enemy_armies:
		a.next_day = int(a.get("next_day", 0))
		for k in a.get("units", {}):
			a.units[k] = int(a.units[k])
		if a.has("strength"):
			a.strength = int(a.strength)


# =====================================================================
#  Wegenetz
# =====================================================================

func neighbors(id: String) -> Array:
	return _adj.get(id, [])


func link_days(a: String, b: String) -> int:
	for n in neighbors(a):
		if n[0] == b:
			return int(n[1])
	return 99


## Kürzester Weg (Dijkstra). Liefert die Regionen nach dem Start, inklusive Ziel.
func path(from: String, to: String) -> Array:
	if from == to:
		return []
	var dist := {from: 0}
	var prev := {}
	var open: Array = [from]
	while not open.is_empty():
		open.sort_custom(func(a, b): return dist[a] < dist[b])
		var cur: String = open.pop_front()
		if cur == to:
			break
		for n in neighbors(cur):
			var nd: int = dist[cur] + int(n[1])
			if not dist.has(n[0]) or nd < dist[n[0]]:
				dist[n[0]] = nd
				prev[n[0]] = cur
				if not n[0] in open:
					open.append(n[0])
	if not prev.has(to):
		return []
	var out: Array = [to]
	while prev[out[0]] != from:
		out.push_front(prev[out[0]])
	return out


func path_days(from: String, p: Array) -> int:
	var total := 0
	var cur := from
	for n in p:
		total += link_days(cur, n)
		cur = n
	return total


# =====================================================================
#  Einheiten & Armeen
# =====================================================================

func unit(id: String) -> Dictionary:
	for u in Content.systems.units:
		if u.id == id:
			return u
	return {}


func available_units() -> Array:
	return Content.systems.units.filter(func(u): return Game.check(u.get("requires")))


func army(uid: String) -> Dictionary:
	for a in Game.state.armies:
		if a.uid == uid:
			return a
	return {}


func enemy(uid: String) -> Dictionary:
	for e in Game.state.enemy_armies:
		if e.uid == uid:
			return e
	return {}


func base_strength(a: Dictionary) -> int:
	var s := 0
	for k in a.get("units", {}):
		s += int(unit(k).get("strength", 0)) * int(a.units[k])
	return s


func commander_bonus(cid: String) -> float:
	var b := Progress.floor_value("army")
	if cid == "":
		return b
	# Rang des Feldherrn und Artefakte stärken die Legion
	b += (Progress.rank(cid) - 1) * 0.015 + Progress.item_effect(cid, "army")
	return b + float(Content.systems.commanders.get(cid, {}).get("bonus", 0.1))


## Marschfortschritt auf dem aktuellen Wegstück (0…1), plus Bruchteil für Animationen.
func leg_progress(a: Dictionary, frac: float = 0.0) -> float:
	if a.get("path", []).is_empty():
		return 0.0
	var start := int(a.get("depart_day", Game.state.day))
	var total := maxi(1, int(a.next_day) - start)
	return clampf((Game.state.day - start + frac) / total, 0.0, 1.0)


## Effektive Stärke inkl. Feldherr (ohne Zufall/Taktik) – für die Anzeige.
func strength(a: Dictionary) -> int:
	return roundi(base_strength(a) * (1.0 + commander_bonus(a.get("commander", ""))))


func total_upkeep() -> int:
	var u := 0
	for a in Game.state.armies:
		for k in a.units:
			u += int(unit(k).get("upkeep", 0)) * int(a.units[k])
	return u


func can_create_army() -> bool:
	return Game.state.armies.size() < int(Content.systems.military.max_armies)


func create_army() -> Dictionary:
	if not can_create_army():
		return {}
	var n := 1
	var names: Array = Game.state.armies.map(func(a): return a.name)
	while "%d. Legion von Nazarick" % n in names:
		n += 1
	var a := {
		"uid": Game.next_uid("a"), "name": "%d. Legion von Nazarick" % n, "units": {},
		"location": "nazarick", "path": [], "next_day": 0, "order": "hold", "commander": "",
	}
	Game.state.armies.append(a)
	Game.log_msg("%s wurde aufgestellt." % a.name, "mission")
	Game.state_changed.emit()
	return a


## Rekrutiert eine Einheit in eine Armee, die in Nazarick steht.
func recruit(army_uid: String, unit_id: String) -> Dictionary:
	var a := army(army_uid)
	var u := unit(unit_id)
	if a.is_empty() or u.is_empty():
		return {"ok": false, "text": "Unbekannte Armee oder Einheit."}
	if a.location != "nazarick" or not a.path.is_empty():
		return {"ok": false, "text": "Rekrutieren ist nur im Großen Grab möglich."}
	var cost := int(u.cost)
	if Game.state.resources.gold < cost:
		return {"ok": false, "text": "Nicht genug Gold in der Schatzkammer."}
	Game.state.resources.gold -= cost
	a.units[unit_id] = int(a.units.get(unit_id, 0)) + 1
	Game.state_changed.emit()
	return {"ok": true, "text": "%s verstärkt die %s." % [u.name, a.name]}


func set_commander(army_uid: String, cid: String) -> bool:
	var a := army(army_uid)
	if a.is_empty():
		return false
	var old: String = a.commander
	if old != "" and Game.state.chars.has(old):
		var oc := Game.cs(old)
		if oc.status == STATUS_CAMPAIGN:
			oc.status = Game.STATUS_READY
	a.commander = ""
	if cid != "":
		if not Game.is_available(cid):
			Game.state_changed.emit()
			return false
		Game.cs(cid).status = STATUS_CAMPAIGN
		a.commander = cid
		Game.log_msg("%s übernimmt den Befehl über die %s." % [Game.char_name(cid), a.name], "mission")
	Game.state_changed.emit()
	return true


func disband(army_uid: String) -> void:
	var a := army(army_uid)
	if a.is_empty():
		return
	set_commander(army_uid, "")
	Game.state.armies.erase(a)
	Game.log_msg("%s wurde aufgelöst." % a.name, "info")
	Game.state_changed.emit()


## Marschbefehl. conquer = am Ziel die Garnison angreifen.
func order_move(army_uid: String, target: String, conquer: bool = false) -> Dictionary:
	var a := army(army_uid)
	if a.is_empty():
		return {"ok": false, "text": ""}
	if base_strength(a) <= 0:
		return {"ok": false, "text": "Die Armee hat keine Truppen."}
	var p := path(a.location, target)
	if p.is_empty() and a.location != target:
		return {"ok": false, "text": "Kein Weg dorthin."}
	a.path = p
	a.order = "conquer" if conquer else "move"
	if not p.is_empty():
		a.next_day = Game.state.day + link_days(a.location, p[0])
		a["depart_day"] = Game.state.day
	var days := path_days(a.location, p)
	var rname: String = World.region(target).get("short", target)
	Game.log_msg("%s marschiert nach %s (%d Tage)%s." % [a.name, rname, days, " – Eroberungsbefehl" if conquer else ""], "mission")
	if p.is_empty() and conquer:
		_arrive(a)
	Game.state_changed.emit()
	return {"ok": true, "text": "Ankunft in %d Tagen." % days}


func can_conquer(region_id: String) -> bool:
	var r := World.region(region_id)
	if r.is_empty() or r.get("home", false):
		return false
	var st := World.rs(region_id)
	return st.discovered and st.influence < 80 and int(st.get("garrison_left", r.get("garrison", 0))) > 0


func garrison(region_id: String) -> int:
	var r := World.region(region_id)
	return int(World.rs(region_id).get("garrison_left", r.get("garrison", 0)))


# =====================================================================
#  Tageslauf
# =====================================================================

func tick_day() -> void:
	var s := Game.state
	for a in s.armies:
		_advance_army(a, false)
	for e in s.enemy_armies.duplicate():
		_advance_army(e, true)
	_check_encounters()
	_maybe_spawn_invasion()


func _advance_army(a: Dictionary, hostile: bool) -> void:
	if a.path.is_empty() or Game.state.day < int(a.next_day):
		return
	a.location = a.path.pop_front()
	if a.path.is_empty():
		if hostile:
			_enemy_arrives(a)
		else:
			_arrive(a)
	else:
		a.next_day = Game.state.day + link_days(a.location, a.path[0])
		a["depart_day"] = Game.state.day


func _arrive(a: Dictionary) -> void:
	var rname: String = World.region(a.location).get("short", a.location)
	if a.order == "conquer" and can_conquer(a.location):
		var r := World.region(a.location)
		_create_battle(a, {"name": r.get("defenders", "Garnison"), "strength": garrison(a.location), "kind": "garrison"}, "conquest")
	else:
		Game.log_msg("%s ist in %s eingetroffen." % [a.name, rname], "mission")
	a.order = "hold"


func _check_encounters() -> void:
	for e in Game.state.enemy_armies.duplicate():
		for a in Game.state.armies:
			if a.location == e.location and base_strength(a) > 0 and not _battle_pending(a.uid):
				_create_battle(a, e, "defense")
				break


func _battle_pending(army_uid: String) -> bool:
	for b in Game.state.battles.values():
		if b.army == army_uid:
			return true
	return false


# =====================================================================
#  Feindliche Feldzüge
# =====================================================================

func _maybe_spawn_invasion() -> void:
	var s := Game.state
	if not s.enemy_armies.is_empty():
		return
	var chance := float(Content.systems.economy.invasion_chance) * Game.diff("threat")
	if Game.rng.randf() >= chance:
		return
	var options: Array = []
	for inv in Content.systems.invasions:
		if not Game.check(inv.get("trigger")):
			continue
		if World.rs(inv.origin).influence > int(inv.get("origin_max_influence", 100)):
			continue
		var w := Diplomacy.invasion_weight(inv.get("faction_id", ""), inv.get("war_only", false)) * float(inv.get("weight", 1))
		if w <= 0.0:
			continue
		var target := _invasion_target(inv.origin)
		if target != "":
			options.append([inv, target, w])
	if options.is_empty():
		return
	var total := 0.0
	for o in options:
		total += float(o[2])
	var roll := Game.rng.randf() * total
	for o in options:
		roll -= float(o[2])
		if roll <= 0.0:
			_spawn_enemy(o[0], o[1])
			return


func _invasion_target(origin: String) -> String:
	var best := ""
	var best_days := 999
	for id in Game.state.regions:
		var st := World.rs(id)
		if id == origin or not st.discovered:
			continue
		var home: bool = World.region(id).get("home", false)
		if st.influence < 30 or (home and Game.state.resources.attention < 70):
			continue
		var p := path(origin, id)
		if p.is_empty():
			continue
		var d := path_days(origin, p)
		if d < best_days:
			best_days = d
			best = id
	return best


func _spawn_enemy(inv: Dictionary, target: String) -> void:
	var lo := int(inv.strength[0])
	var hi := int(inv.strength[1])
	var str := roundi(Game.rng.randi_range(lo, hi) * Game.diff("enemy") * (1.0 + Game.state.chapter * 0.05))
	var p := path(inv.origin, target)
	var e := {
		"uid": Game.next_uid("e"), "name": inv.faction, "strength": str, "location": inv.origin,
		"target": target, "path": p, "next_day": Game.state.day + link_days(inv.origin, p[0]), "invasion": inv.id,
		"depart_day": Game.state.day,
	}
	Game.state.enemy_armies.append(e)
	var days := path_days(inv.origin, p)
	var tname: String = World.region(target).name
	Game.log_msg("⚔ %s marschiert auf %s (Ankunft in %d Tagen)!" % [inv.faction, tname, days], "warning")
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "threat", "char_id": "cocytus", "day": Game.state.day,
		"title": "⚔ Feindliches Heer im Anmarsch",
		"body": "Ainz-sama. Ein. Heer. Nähert. Sich.\n\n[b]%s[/b] (geschätzte Stärke [color=#ff4a5a]%d[/color]) ist aus %s aufgebrochen und marschiert auf [b]%s[/b]. Ankunft in [color=#ff4a5a][b]%d Tagen[/b][/color].\n\nStellt eine Armee in den Weg – auf der [b]Weltkarte [K][/b] – oder nehmt die Verwüstung hin. Erreicht der Feind sein Ziel ungehindert, verlieren wir dort Einfluss und Gold.\n\n[color=#8ee6ff][i]»Ich. Bitte. Darum. Sie. Persönlich. Empfangen. Zu. Dürfen.«[/i][/color]" % [inv.faction, str, World.region(inv.origin).name, tname, days],
		"options": [{"key": "ok", "label": "Die Legionen sammeln", "effects": {}, "reaction": "", "variant": "danger"}],
		"context": {"subtitle": tname, "location": tname, "image": World.region(target).get("image", "")},
	})


func _enemy_arrives(e: Dictionary) -> void:
	# Steht dort eine eigene Armee, regelt das _check_encounters (Schlacht). Sonst: Verwüstung.
	for a in Game.state.armies:
		if a.location == e.location and base_strength(a) > 0:
			return
	Game.state.enemy_armies.erase(e)
	var rid: String = e.target
	var home: bool = World.region(rid).get("home", false)
	var summary: Array = []
	if home:
		summary += Game.apply_effects({"res": {"gold": -250, "morale": -15, "power": -6}})
	else:
		summary += World.apply_region_effects({rid: {"influence": -40, "unrest": 30}})
		summary += Game.apply_effects({"res": {"gold": -60, "morale": -6, "reputation": -3}})
	Game.log_msg("%s hat %s verwüstet." % [e.name, World.region(rid).name], "warning")
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "event", "char_id": "albedo", "day": Game.state.day,
		"title": "Verwüstung in " + World.region(rid).short,
		"body": "%s hat %s erreicht – und niemand stand ihm im Weg. Unsere Kontaktleute sind tot oder geflohen, die Bevölkerung verflucht unseren Namen.\n\n[color=#f1e6ff][i]»Eine Demütigung, {lord}. Gebt mir eine Armee, und ich sorge dafür, dass sie sich nie wiederholt.«[/i][/color]" % [e.name, World.region(rid).name],
		"options": [{"key": "ok", "label": "Das wird gesühnt.", "effects": {}, "reaction": "", "variant": "danger"}],
		"context": {"summary": summary, "location": World.region(rid).name, "image": World.region(rid).get("image", "")},
	})


# =====================================================================
#  Schlachten
# =====================================================================

func _create_battle(a: Dictionary, foe: Dictionary, kind: String) -> void:
	var uid := Game.next_uid("b")
	Game.state.battles[uid] = {
		"uid": uid, "army": a.uid, "kind": kind, "region": a.location,
		"enemy_uid": foe.get("uid", ""), "enemy_name": foe.name, "enemy_strength": int(foe.strength),
	}
	var rname: String = World.region(a.location).name
	var cid: String = a.commander
	var options: Array = []
	for t in Content.systems.tactics:
		options.append({"key": "t_" + t.id, "label": "%s %s" % [t.icon, t.name], "variant": "danger" if t.id == "terror" else ("primary" if t.id == "assault" else "default"),
			"effects": {"battle": {"uid": uid, "tactic": t.id}}, "reaction": ""})
	var intro: String = {
		"conquest": "Die %s steht vor %s. Die Verteidiger – [b]%s[/b] – haben sich verschanzt." % [a.name, rname, foe.name],
		"defense": "Die %s trifft in %s auf [b]%s[/b]. Die Schlacht ist unausweichlich." % [a.name, rname, foe.name],
	}[kind]
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "battle", "char_id": cid if cid != "" else "cocytus", "day": Game.state.day,
		"title": "Schlacht um " + World.region(a.location).short,
		"body": "%s\n\nUnsere Stärke: [color=#6fdc8c][b]%d[/b][/color]   ·   Feindliche Stärke: [color=#ff4a5a][b]~%d[/b][/color]%s\n\nWählt die Taktik, {lord}." % [
			intro, strength(a), roundi(float(foe.strength) * Game.diff("enemy") if foe.get("kind", "") == "garrison" else float(foe.strength)),
			("\nFeldherr: [b]%s[/b] – %s" % [Game.char_name(cid), Content.systems.commanders.get(cid, {}).get("text", "")]) if cid != "" else "\n[color=#ff9a3c]Kein Feldherr – die Truppen kämpfen ohne Führung.[/color]"],
		"options": options,
		"context": {"subtitle": rname, "location": rname, "image": World.region(a.location).get("image", ""), "battle": uid},
	})


## Effekt "battle": trägt die Schlacht mit der gewählten Taktik aus.
func resolve_battle(uid: String, tactic_id: String) -> Array:
	var b: Dictionary = Game.state.battles.get(uid, {})
	if b.is_empty():
		return []
	Game.state.battles.erase(uid)
	var a := army(b.army)
	if a.is_empty():
		return []
	var tactic: Dictionary = {}
	for t in Content.systems.tactics:
		if t.id == tactic_id:
			tactic = t
	var cid: String = a.commander
	var cmd: Dictionary = Content.systems.commanders.get(cid, {})
	var mult := 1.0 + commander_bonus(cid) + float(tactic.get("str", 0))
	if tactic.get("int_bonus", false) and cid != "":
		mult += (float(Content.char_data(cid).stats.intellekt) - 50.0) / 160.0
	if b.kind == "defense" and World.rs(b.region).influence >= 30:
		mult += float(Content.systems.military.defense_bonus)
	if b.kind == "defense":
		mult += Progress.floor_value("defense") + (Progress.item_effect(cid, "defense") if cid != "" else 0.0)
	var ours := base_strength(a) * mult * Game.rng.randf_range(0.85, 1.15)
	var foe_mult := 1.0 - float(cmd.get("enemy_morale", 0)) - float(tactic.get("enemy_morale", 0))
	var foe_base := float(b.enemy_strength) * (Game.diff("enemy") if b.kind == "conquest" else 1.0)
	var theirs := foe_base * foe_mult * Game.rng.randf_range(0.85, 1.15)
	var won := ours > theirs
	var ratio := theirs / maxf(ours, 1.0)
	var loss := clampf(ratio * 0.35, 0.05, 0.8) if won else clampf(0.45 + ratio * 0.15, 0.4, 0.95)
	loss *= float(tactic.get("loss", 1.0)) * float(cmd.get("loss_mult", 1.0))
	loss = clampf(loss, 0.03, 0.95)
	var lost := _apply_losses(a, loss)

	var summary: Array = []
	var rid: String = b.region
	var rname: String = World.region(rid).short
	var lines := PackedStringArray()
	if won:
		Game.state["battles_won"] = int(Game.state.get("battles_won", 0)) + 1
		Progress.bump("battles_won")
		if b.kind == "conquest":
			Progress.bump("conquests")
		if cid != "":
			Progress.add_xp(cid, 70 if b.kind == "conquest" else 55)
		Progress.roll_loot("battle", "Schlachtfeld von " + rname, cid)
		summary += Game.apply_effects({"res": {"power": 3, "morale": 4}})
		if b.kind == "conquest":
			var mil: Dictionary = Content.systems.military
			World.rs(rid)["garrison_left"] = 0
			var unrest := int(mil.conquest_unrest) + int(cmd.get("unrest", 0)) + int(tactic.get("unrest", 0))
			summary += World.apply_region_effects({rid: {"influence": int(mil.conquest_influence), "unrest": unrest}})
			summary += Diplomacy.on_region_conquered(rid)
			summary += Game.apply_effects({"res": {"attention": int(mil.conquest_attention) + int(tactic.get("attention", 0))}})
			lines.append("[color=#f5d77a][b]%s ist gefallen.[/b][/color] Die Banner von Ainz Ooal Gown wehen über der Region." % rname)
		else:
			var e := enemy(b.enemy_uid)
			if not e.is_empty():
				Game.state.enemy_armies.erase(e)
			summary += Game.apply_effects({"res": {"reputation": 3, "attention": int(tactic.get("attention", 0))}})
			if int(tactic.get("unrest", 0)) != 0:
				summary += World.apply_region_effects({rid: {"unrest": int(tactic.unrest)}})
			lines.append("[color=#f5d77a][b]Der Feind ist vernichtet.[/b][/color] %s wird nie wieder einen Feldzug gegen Nazarick führen." % b.enemy_name)
		if cid != "":
			summary += Game.apply_effects({"chars": {cid: {"favor": 6, "mood": 8, "fatigue": 15}}})
	else:
		summary += Game.apply_effects({"res": {"morale": -7, "power": -3}})
		lines.append("[color=#ff4a5a][b]Niederlage.[/b][/color] Die Reste der %s ziehen sich zurück." % a.name)
		if b.kind == "conquest":
			World.rs(rid)["garrison_left"] = maxi(0, garrison(rid) - roundi(ours * 0.4))
		if cid != "":
			summary += Game.apply_effects({"chars": {cid: {"mood": -12, "fatigue": 25}}})
		_retreat(a)
	var lost_txt := PackedStringArray()
	for k in lost:
		lost_txt.append("%d× %s" % [lost[k], unit(k).name])
	lines.append("Eigene Verluste: %s." % (", ".join(lost_txt) if not lost_txt.is_empty() else "keine nennenswerten"))
	if cid != "":
		lines.append("[color=%s][i]%s[/i][/color]" % [Content.char_data(cid).color, _commander_line(cid, won)])
	last_result = {"won": won, "ours": roundi(ours), "theirs": roundi(theirs), "tactic": tactic.get("name", ""),
		"text": "\n\n".join(lines), "lost": lost, "region": rid}
	Game.log_msg("Schlacht um %s: %s (%d gegen %d)." % [rname, "Sieg" if won else "Niederlage", roundi(ours), roundi(theirs)], "mission" if won else "warning")
	if base_strength(a) <= 0:
		set_commander(a.uid, "")
		Game.state.armies.erase(a)
		Game.log_msg("%s wurde vollständig aufgerieben." % a.name, "warning")
	return summary


func _apply_losses(a: Dictionary, frac: float) -> Dictionary:
	var lost := {}
	for k in a.units.keys():
		var n: int = a.units[k]
		var l := int(floor(n * frac))
		if Game.rng.randf() < n * frac - l:
			l += 1
		l = mini(l, n)
		if l > 0:
			lost[k] = l
			a.units[k] = n - l
			if a.units[k] <= 0:
				a.units.erase(k)
	return lost


func _retreat(a: Dictionary) -> void:
	if a.location == "nazarick":
		return
	var p := path(a.location, "nazarick")
	a.path = p
	a.order = "move"
	if not p.is_empty():
		a.next_day = Game.state.day + link_days(a.location, p[0])
		a["depart_day"] = Game.state.day


func _commander_line(cid: String, won: bool) -> String:
	var lines := {
		"cocytus": ["Ein. Ehrenvoller. Sieg. Die. Feinde. Kämpften. Tapfer.", "Ich. Habe. Versagt. Ich. Werde. Hundert. Tage. Trainieren."],
		"shalltear": ["Habt Ihr das gesehen, Eure Herrlichkeit? Ein Meer aus Blut – nur für Euch, ~arinsu!", "Uuuh … sie waren mehr, als ich zählen konnte. Bestraft mich, aber nicht vor Albedo!"],
		"demiurge": ["Wie vorhergesehen. Der Feind hat genau die Fehler begangen, die Ihr ihm zugedacht hattet.", "Eine Variable, die ich übersah. Ich werde sie … entfernen."],
		"albedo": ["Für Euch, mein Geliebter, halte ich jede Linie. Jede.", "Verzeiht mir. Ich habe Eure Soldaten nicht schützen können."],
		"aura": ["Hehe! Fenrir hat den Anführer gefressen! Na ja, fast!", "Die waren zu viele … aber ich hab's versucht!"],
		"mare": ["I-ich habe die Erde gebeten, sich zu öffnen … und sie hat es getan …", "E-es tut mir so leid …"],
		"sebas": ["Der Sieg ist unser. Ich habe dafür gesorgt, dass die Gefangenen anständig behandelt werden.", "Ich übernehme die volle Verantwortung."],
		"narberal": ["Die Kakerlaken sind gegrillt.", "Unverzeihlich."],
		"pandora": ["Ein Triumph auf der Bühne des Krieges! Bravo!", "Tragödie! Der dritte Akt ging daneben!"],
	}
	var pair: Array = lines.get(cid, ["Sieg.", "Niederlage."])
	return Game.fmt(pair[0] if won else pair[1])

extends Node
## World – die strategische Ebene von Nazarick (Autoload).
##
## * Regionen: Einfluss (0–100), Unruhe (0–100), entdeckt ja/nein, tägliche Einkünfte
## * Wirtschaft: Einkünfte aus Regionen gegen Unterhalt des Grabes und der Einsätze
## * Bedrohungen: Mächte der Welt reagieren auf Aufmerksamkeit/Unruhe – mit Frist
## * Komplikationen: Lageberichte mitten im Auftrag mit echten Abwägungen
## * Teams: Synergien und Konflikte zwischen zwei Untertanen
##
## Der Zustand liegt in Game.state (regions, income_acc, threats, dynamic_missions),
## damit Speichern/Laden unverändert funktioniert. Inhalte: data/regions.json, data/systems.json.

const CONTROL_STAGES := [
	[0, "Unbeachtet"], [10, "Beobachtet"], [30, "Infiltriert"], [55, "Unter Einfluss"], [80, "Beherrscht"],
]


# =====================================================================
#  Zustand
# =====================================================================

func init_state(state: Dictionary) -> void:
	state["regions"] = {}
	for r in Content.regions:
		state.regions[r.id] = {
			"influence": int(r.get("start_influence", 0)), "unrest": 0,
			"discovered": r.get("discovered", false),
		}
	state["income_acc"] = {"gold": 0.0, "info": 0.0}
	state["threats"] = []
	state["dynamic_missions"] = {}
	state["decrees"] = []
	state["decree_acc"] = {}


func normalize(state: Dictionary) -> void:
	if not state.has("regions"):
		init_state(state)
	if not state.has("decrees"):
		state["decrees"] = []
		state["decree_acc"] = {}
	for r in Content.regions:
		if not state.regions.has(r.id):
			state.regions[r.id] = {"influence": int(r.get("start_influence", 0)), "unrest": 0, "discovered": r.get("discovered", false)}
		var rs: Dictionary = state.regions[r.id]
		rs.influence = int(rs.influence)
		rs.unrest = int(rs.unrest)
	for t in state.threats:
		t.deadline_day = int(t.deadline_day)
	for k in state.dynamic_missions:
		var m: Dictionary = state.dynamic_missions[k]
		m.days = int(m.days)
		m.difficulty = int(m.difficulty)


func region(id: String) -> Dictionary:
	return Content.region_by_id.get(id, {})


func rs(id: String) -> Dictionary:
	return Game.state.regions.get(id, {"influence": 0, "unrest": 0, "discovered": false})


func control_label(influence: int) -> String:
	var label := "Unbeachtet"
	for st in CONTROL_STAGES:
		if influence >= st[0]:
			label = st[1]
	return label


# =====================================================================
#  Bedingungen & Effekte (von Game.check / Game.apply_effects aufgerufen)
# =====================================================================

func check(c: Dictionary) -> bool:
	for id in c.get("region_min", {}):
		if rs(id).influence < int(c.region_min[id]):
			return false
	for id in c.get("region_unrest_min", {}):
		if rs(id).unrest < int(c.region_unrest_min[id]):
			return false
	for id in c.get("region_discovered", []):
		if not rs(id).discovered:
			return false
	if c.has("region_undiscovered") and rs(c.region_undiscovered).discovered:
		return false
	if c.has("region_influence_below"):
		for id in c.region_influence_below:
			if rs(id).influence >= int(c.region_influence_below[id]):
				return false
	return true


## {"carne": {"influence": 20, "unrest": -10, "discover": true, "unrest_set": 30}}
func apply_region_effects(eff: Dictionary) -> Array:
	var summary: Array = []
	for id in eff:
		if not Game.state.regions.has(id):
			continue
		var r := rs(id)
		var e: Dictionary = eff[id]
		var name: String = region(id).get("short", id)
		if e.get("discover", false) and not r.discovered:
			r.discovered = true
			Game.log_msg("Neue Region entdeckt: %s" % region(id).name, "story")
			summary.append(["Entdeckt: " + name, 1])
		if e.has("influence"):
			var old: int = r.influence
			r.influence = clampi(old + int(e.influence), 0, 100)
			if r.influence != old:
				summary.append(["Einfluss " + name, r.influence - old])
				if r.influence > old:
					Progress.bump("influence_gained", r.influence - old)
		if e.has("unrest"):
			var old: int = r.unrest
			r.unrest = clampi(old + int(e.unrest), 0, 100)
			if r.unrest != old:
				summary.append(["Unruhe " + name, r.unrest - old])
		if e.has("unrest_set"):
			r.unrest = int(e.unrest_set)
	return summary


# =====================================================================
#  Erlasse (dauerhafte Regierungsentscheidungen)
# =====================================================================

func decree(id: String) -> Dictionary:
	for d in Content.systems.decrees:
		if d.id == id:
			return d
	return {}


func decree_active(id: String) -> bool:
	return id in Game.state.decrees


func decree_slots() -> int:
	var slots := 2
	var table: Dictionary = Content.systems.decree_slots
	for k in table:
		if Game.state.chapter >= int(k):
			slots = maxi(slots, int(table[k]))
	return slots


func available_decrees() -> Array:
	return Content.systems.decrees.filter(func(d): return Game.check(d.get("requires")))


## Erlässt oder widerruft einen Erlass. Liefert {"ok", "text", "summary"}.
func toggle_decree(id: String) -> Dictionary:
	var d := decree(id)
	if d.is_empty():
		return {"ok": false, "text": ""}
	var opinions: Dictionary = d.get("opinions", {})
	var eff := {"chars": {}}
	var sign := 1
	if decree_active(id):
		Game.state.decrees.erase(id)
		sign = -1
		Game.log_msg("Erlass widerrufen: %s" % d.name, "info")
	else:
		if Game.state.decrees.size() >= decree_slots():
			return {"ok": false, "text": "Alle Erlass-Plätze sind belegt. Widerruft zuerst einen anderen Erlass."}
		Game.state.decrees.append(id)
		Game.log_msg("Erlass verkündet: %s" % d.name, "story")
	# Die Wächter haben Meinungen zu Erlassen – Zustimmung hebt Gunst, Ablehnung drückt die Stimmung
	var voices := PackedStringArray()
	for cid in opinions:
		if not Game.state.chars.has(cid) or not Game.cs(cid).unlocked:
			continue
		var v := int(opinions[cid]) * sign
		eff.chars[cid] = {"favor": v, "mood": v}
		var nm: String = Game.char_name(cid).split(" ")[0]
		voices.append(("[color=#6fdc8c]%s ist erfreut[/color]" if v > 0 else "[color=#ff7a7a]%s ist unzufrieden[/color]") % nm)
	var summary := Game.apply_effects(eff)
	Game.state_changed.emit()
	return {"ok": true, "text": " · ".join(voices), "summary": summary}


func _tick_decrees() -> void:
	var s := Game.state
	var acc: Dictionary = s.decree_acc
	for id in s.decrees:
		var d := decree(id)
		for k in d.get("daily", {}):
			acc[k] = float(acc.get(k, 0.0)) + float(d.daily[k])
		if d.has("region_influence"):
			acc["_region"] = float(acc.get("_region", 0.0)) + float(d.region_influence)
		if d.has("fatigue_bonus"):
			for cid in Game.unlocked_chars():
				var c := Game.cs(cid)
				if c.status in [Game.STATUS_READY, Game.STATUS_RECOVER]:
					c.fatigue = maxi(0, c.fatigue - int(d.fatigue_bonus))
		if d.has("unrest_decay"):
			for rid in s.regions:
				s.regions[rid].unrest = maxi(0, s.regions[rid].unrest - int(d.unrest_decay))
	# ganze Punkte auszahlen
	var res := {}
	for k in acc.keys():
		if k == "_region":
			continue
		var whole := int(acc[k])
		if whole != 0:
			acc[k] = float(acc[k]) - whole
			res[k] = whole
	if not res.is_empty():
		Game.apply_effects({"res": res})
	if float(acc.get("_region", 0.0)) >= 1.0:
		acc["_region"] = float(acc["_region"]) - 1.0
		for rid in s.regions:
			var r: Dictionary = s.regions[rid]
			if r.discovered and r.influence > 0 and not region(rid).get("home", false):
				r.influence = mini(100, r.influence + 1)


func _income_mult() -> float:
	var m := 1.0
	for id in Game.state.decrees:
		m *= float(decree(id).get("income_mult", 1.0))
	return m


func _decree_upkeep() -> int:
	var u := 0
	for id in Game.state.decrees:
		u += int(decree(id).get("upkeep", 0))
	return u


## Tägliche Netto-Wirkung der Erlasse (für die Anzeige).
func decree_daily_gold() -> float:
	var g := 0.0
	for id in Game.state.decrees:
		g += float(decree(id).get("daily", {}).get("gold", 0))
	return g


# =====================================================================
#  Wirtschaft
# =====================================================================

func daily_income() -> Dictionary:
	var g := 0.0
	var inf := 0.0
	for r in Content.regions:
		var st := rs(r.id)
		if not st.discovered:
			continue
		var factor: float = st.influence / 100.0 * (1.0 - st.unrest / 150.0)
		g += float(r.income.get("gold", 0)) * factor
		inf += float(r.income.get("info", 0)) * factor
	var mult := _income_mult() * Game.diff("income")
	return {"gold": g * mult + Progress.daily_gold(), "info": inf * mult}


func daily_upkeep() -> int:
	var eco: Dictionary = Content.systems.economy
	var agents := 0
	for am in Game.state.active:
		agents += 2 if am.get("partner", "") != "" else 1
	var army_upkeep := roundi(Military.total_upkeep() * (1.0 - Progress.floor_value("upkeep")))
	var base := int(eco.upkeep_base) + agents * int(eco.upkeep_per_agent) + _decree_upkeep() + army_upkeep
	return roundi(base * Game.diff("upkeep"))


func tick_day() -> void:
	var s := Game.state
	# Einkünfte (Bruchteile werden angesammelt)
	var inc := daily_income()
	s.income_acc.gold = float(s.income_acc.gold) + inc.gold - daily_upkeep()
	s.income_acc.info = float(s.income_acc.info) + inc.info
	var whole_gold := int(s.income_acc.gold)
	if whole_gold != 0:
		s.income_acc.gold = float(s.income_acc.gold) - whole_gold
		if s.resources.gold + whole_gold < 0:
			s.resources.gold = 0
			s.resources.morale = clampi(s.resources.morale - 2, 0, 100)
			if s.day % 5 == 0:
				Game.log_msg("Die Schatzkammer ist leer – der Unterhalt Nazaricks kann nicht bezahlt werden!", "warning")
		else:
			s.resources.gold += whole_gold
	if float(s.income_acc.info) >= 1.0:
		s.income_acc.info = float(s.income_acc.info) - 1.0
		s.resources.info = clampi(s.resources.info + 1, 0, 100)
	# Unruhe klingt ab; hohe Unruhe frisst Einfluss
	for id in s.regions:
		var r: Dictionary = s.regions[id]
		if r.unrest > 0:
			r.unrest = maxi(0, r.unrest - int(Content.systems.economy.unrest_decay))
		if r.unrest > 70 and r.influence > 0:
			r.influence -= 1
	_tick_decrees()
	_tick_complications()
	_tick_threats()


# =====================================================================
#  Einfluss durch Aufträge
# =====================================================================

## Wird bei der Auflösung eines Auftrags aufgerufen; liefert Effekt-Zusammenfassung.
func mission_region_effects(m: Dictionary, am: Dictionary, tier: String, directive: String, cid: String) -> Array:
	var rid: String = m.get("region", "")
	if rid == "" or region(rid).get("home", false):
		return []
	var eco: Dictionary = Content.systems.economy
	var base := float(m.get("influence", 0))
	if base == 0.0:
		base = float(eco.influence_main if m.get("main", false) else (eco.influence_proposal if m.get("proposal", false) else eco.influence_side))
	var mult: float = {"triumph": 1.4, "success": 1.0, "partial": 0.5, "failure": 0.0}[tier]
	var dir_mult: float = {"gnadenlos": 1.25, "schnell": 0.75}.get(directive, 1.0)
	var unrest: int = {"gnadenlos": 12, "diplomatisch": -6, "schnell": 3}.get(directive, 0)
	if directive == "freie_hand" and cid == "shalltear":
		unrest += 10
	var mods: Dictionary = am.get("mods", {})
	# Abnehmender Ertrag: Die letzten Prozent Kontrolle sind die schwersten
	var current: int = rs(rid).influence
	var diminish := clampf(1.0 - current / 125.0, 0.25, 1.0)
	var gain := roundi(base * mult * dir_mult * float(mods.get("influence_mult", 1.0)) * diminish * Game.diff("influence"))
	if tier == "failure":
		gain = -5
		unrest += 6
	var eff := {rid: {"influence": gain, "unrest": unrest, "discover": tier != "failure"}}
	return apply_region_effects(eff)


# =====================================================================
#  Teams
# =====================================================================

func synergy(a: String, b: String) -> Dictionary:
	if a == "" or b == "":
		return {}
	for s in Content.systems.synergies:
		if a in s.pair and b in s.pair:
			return s
	return {}


## Beitrag eines Unterstützers zum Erfolgswert.
func partner_bonus(m: Dictionary, main: String, partner: String) -> float:
	if partner == "":
		return 0.0
	var cd := Content.char_data(partner)
	var weights: Dictionary = m.get("weights", {"kampf": 1})
	var total := 0.0
	var score := 0.0
	for k in weights:
		total += float(weights[k])
		score += float(cd.stats[k]) * float(weights[k])
	score /= maxf(total, 1.0)
	return (score - 50.0) / 5.0 + float(synergy(main, partner).get("bonus", 0))


# =====================================================================
#  Komplikationen
# =====================================================================

func _tick_complications() -> void:
	for am in Game.state.active:
		if am.get("comp_done", false) or am.has("threat"):
			continue
		var length: int = am.end_day - am.start_day
		if length < 2 or Game.state.day < am.start_day + int(ceil(length / 2.0)):
			continue
		am["comp_done"] = true
		var m := Game.mission(am.mission_id)
		var chance := 1.0 if m.get("main", false) else 0.6
		if Game.rng.randf() >= chance:
			continue
		_create_complication(am, m)


func _create_complication(am: Dictionary, m: Dictionary) -> void:
	var cat: String = m.get("category", "")
	var pool: Array = []
	for c in Content.systems.complications:
		if cat in c.categories or c.categories.is_empty():
			if c.get("rare", false) and Game.rng.randf() > 0.15:
				continue
			pool.append(c)
	if pool.is_empty():
		pool = Content.systems.complications.filter(func(c): return not c.get("rare", false))
	var c: Dictionary = pool[Game.rng.randi() % pool.size()]
	var cid: String = am.char_id
	var nm: String = Game.char_name(cid).split(" ")[0]
	var options: Array = []
	var i := 0
	for o in c.options:
		var mod: Dictionary = o.mod.duplicate()
		mod["uid"] = am.uid
		options.append({"key": "c%d" % i, "label": o.label, "variant": o.get("variant", "default"),
			"effects": {"mission_mod": mod}, "reaction": Game.fmt(o.get("reaction", ""))})
		i += 1
	var style: Dictionary = Content.systems.free_hand_styles.get(cid, {})
	if not style.is_empty():
		var mod: Dictionary = style.mod.duplicate()
		mod["uid"] = am.uid
		options.append({"key": "free", "label": "%s freie Hand lassen" % nm, "variant": "warning",
			"effects": {"mission_mod": mod}, "reaction": "[i]" + Game.fmt(style.text) + "[/i]"})
	var partner_line := ""
	if am.get("partner", "") != "":
		partner_line = "\n\n[color=#8f86a3]%s ist an %ss Seite.[/color]" % [Game.char_name(am.partner).split(" ")[0], nm]
	Game.log_msg("Lagebericht: %s meldet eine Komplikation bei »%s«." % [nm, m.title], "initiative")
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "complication", "char_id": cid, "day": Game.state.day,
		"title": "Lagebericht · " + c.title,
		"body": "[color=#c79bff]Auftrag: »%s«[/color]\n\n%s%s\n\nWie lautet Euer Befehl, {lord}?" % [m.title, c.text.replace("{char}", nm), partner_line],
		"options": options,
		"context": {"subtitle": m.get("location", ""), "location": m.get("location", ""), "mission": m.id},
	})


## Effekt "mission_mod": verändert einen laufenden Auftrag.
func apply_mission_mod(mod: Dictionary) -> Array:
	var am := {}
	for a in Game.state.active:
		if a.uid == mod.get("uid", ""):
			am = a
	if am.is_empty():
		return []
	var mods: Dictionary = am.get("mods", {})
	mods["score"] = float(mods.get("score", 0)) + float(mod.get("score", 0))
	mods["influence_mult"] = float(mods.get("influence_mult", 1.0)) * float(mod.get("influence_mult", 1.0))
	am["mods"] = mods
	var summary: Array = []
	if int(mod.get("days", 0)) != 0:
		am.end_day += int(mod.days)
		summary.append(["Dauer (Tage)", int(mod.days)])
	var res := {}
	for k in ["gold", "info", "power", "reputation", "attention", "morale"]:
		if mod.has(k):
			res[k] = int(mod[k])
	summary += Game.apply_effects({"res": res})
	var rid: String = Game.mission(am.mission_id).get("region", "")
	if mod.has("unrest") and rid != "" and not region(rid).get("home", false):
		summary += apply_region_effects({rid: {"unrest": int(mod.unrest)}})
	if float(mod.get("score", 0)) != 0:
		summary.append(["Erfolgsaussicht", int(mod.score)])
	return summary


# =====================================================================
#  Bedrohungen
# =====================================================================

func active_threats() -> Array:
	return Game.state.threats


func _tick_threats() -> void:
	var s := Game.state
	# Fristen prüfen
	for t in s.threats.duplicate():
		if s.day >= t.deadline_day and not Game.is_mission_active(t.mission_id):
			_threat_failed(t, true)
	# Neue Bedrohung?
	if s.threats.size() >= 2 or Game.rng.randf() >= float(Content.systems.economy.threat_check_chance) * Game.diff("threat"):
		return
	var candidates: Array = []
	for th in Content.systems.threats:
		if not Game.check(th.get("trigger")):
			continue
		for rid in _threat_regions(th):
			candidates.append([th, rid])
	if candidates.is_empty():
		return
	var weights: Array = candidates.map(func(c): return float(c[0].get("weight", 1)))
	var total := 0.0
	for w in weights:
		total += w
	var roll := Game.rng.randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			_spawn_threat(candidates[i][0], candidates[i][1])
			return


func _threat_regions(th: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = [th.region] if th.has("region") else Game.state.regions.keys()
	for rid in ids:
		var r := rs(rid)
		if not r.discovered or rid in th.get("exclude_regions", []):
			continue
		if r.influence < int(th.get("region_min_influence", 0)) or r.unrest < int(th.get("region_min_unrest", 0)):
			continue
		if Game.state.threats.any(func(t): return t.region == rid):
			continue
		out.append(rid)
	return out


func _spawn_threat(th: Dictionary, rid: String) -> void:
	var s := Game.state
	var uid := Game.next_uid("t")
	var rname: String = region(rid).name
	var mid := "threat_" + uid
	var att_bonus := int(s.resources.attention / 5)
	s.dynamic_missions[mid] = {
		"id": mid, "title": "Abwehr: " + th.title.replace("{region}", region(rid).short),
		"category": "Verteidigung", "location": rname, "region": rid, "threat": uid,
		"description": th.text.replace("{region}", rname),
		"days": 3, "difficulty": int(th.difficulty) + att_bonus, "weights": th.weights,
		"rewards": {}, "repeatable": false,
		"outcomes": {
			"triumph": "Die Bedrohung wurde vollständig zerschlagen – ohne dass jemand begreift, was geschehen ist.",
			"success": "Die Bedrohung ist abgewendet.",
			"partial": "Die Bedrohung ist abgewendet, doch es gab Zeugen.",
			"failure": "Die Abwehr ist gescheitert. Der Feind hat sein Ziel erreicht.",
		},
	}
	var t := {"uid": uid, "threat_id": th.id, "region": rid, "deadline_day": s.day + int(th.deadline), "mission_id": mid}
	s.threats.append(t)
	Game.log_msg("⚠ Bedrohung: %s (Frist %d Tage)" % [th.title.replace("{region}", region(rid).short), int(th.deadline)], "warning")
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "threat", "char_id": "albedo", "day": s.day,
		"title": "⚠ " + th.title.replace("{region}", region(rid).short),
		"body": "%s\n\n[color=#ff4a5a][b]Frist: %d Tage.[/b][/color] Entsendet einen Untertanen über die Auftragstafel (Auftrag »Abwehr«), bevor die Frist verstreicht.\n\n[color=#f1e6ff][i]»Ein Wort von Euch, {lord}, und ich kümmere mich persönlich darum.«[/i][/color]" % [th.text.replace("{region}", rname), int(th.deadline)],
		"options": [{"key": "ok", "label": "Verstanden", "effects": {}, "reaction": "", "variant": "danger"}],
		"context": {"subtitle": rname, "location": rname, "image": region(rid).get("image", "")},
	})


func threat_def(threat_id: String) -> Dictionary:
	for th in Content.systems.threats:
		if th.id == threat_id:
			return th
	return {}


func threat_for_mission(mid: String) -> Dictionary:
	for t in Game.state.threats:
		if t.mission_id == mid:
			return t
	return {}


## Ergebnis eines Abwehr-Auftrags.
func resolve_threat_mission(mid: String, success: bool) -> Array:
	var t := threat_for_mission(mid)
	if t.is_empty():
		return []
	if success:
		var th := threat_def(t.threat_id)
		Game.state.threats.erase(t)
		var eff: Dictionary = th.get("success", {})
		var summary := Game.apply_effects({"res": eff.get("res", {})})
		if eff.has("unrest"):
			summary += apply_region_effects({t.region: {"unrest": int(eff.unrest)}})
		Game.log_msg("Bedrohung abgewehrt: %s" % th.title.replace("{region}", region(t.region).short), "mission")
		Progress.bump("threats_resolved")
		Progress.roll_loot("threat", th.title.replace("{region}", region(t.region).short))
		return summary
	return _threat_failed(t, false)


func _threat_failed(t: Dictionary, deadline: bool) -> Array:
	var th := threat_def(t.threat_id)
	Game.state.threats.erase(t)
	Game.state.dynamic_missions.erase(t.mission_id)
	var fail: Dictionary = th.get("fail", {})
	var summary := Game.apply_effects({"res": fail.get("res", {})})
	var reff := {}
	if fail.has("influence"):
		reff["influence"] = int(fail.influence)
	if fail.has("unrest_set"):
		reff["unrest_set"] = int(fail.unrest_set)
	if not reff.is_empty():
		summary += apply_region_effects({t.region: reff})
	var title: String = th.title.replace("{region}", region(t.region).short)
	Game.log_msg("Bedrohung eingetreten: %s" % title, "warning")
	if deadline:
		Game.push_dispatch({
			"uid": Game.next_uid("d"), "kind": "event", "char_id": "albedo", "day": Game.state.day,
			"title": "Frist verstrichen · " + title,
			"body": "Niemand wurde entsandt, {lord}. Der Feind hat ungestört gehandelt – und Nazarick zahlt den Preis.\n\n[color=#f1e6ff][i]»Ich hätte es Euch abnehmen können. Ihr hättet nur fragen müssen.«[/i][/color]",
			"options": [{"key": "ok", "label": "Bitter. Weiter.", "effects": {}, "reaction": "", "variant": "danger"}],
			"context": {"summary": summary, "location": region(t.region).name, "image": region(t.region).get("image", "")},
		})
	return summary


func threat_days_left(t: Dictionary) -> int:
	return maxi(0, int(t.deadline_day) - Game.state.day)

extends Node
## Diplomacy – Fraktionen der Neuen Welt, ihre Haltung zu Nazarick und Verträge (Autoload).
##
## Jede Fraktion hat:
##   relation (−100…100)  Wohlwollen gegenüber Nazarick
##   fear     (0…100)     wie sehr sie Nazarick fürchtet
##   treaties             trade · nonaggression · alliance · vassal · war
## Diplomatische Aktionen werden von einem Wächter als Gesandtschaft ausgeführt –
## technisch ein dynamischer Auftrag mit Bericht, Lagebericht und Erfolgsstufe.
## Fraktionen reagieren täglich auf Nazaricks Ruf, Macht und Aufmerksamkeit,
## erklären bei tiefem Hass den Krieg und schicken selbst Gesandte.

var data: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://data/factions.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())


func factions() -> Array:
	return data.get("factions", [])


func faction(id: String) -> Dictionary:
	for f in factions():
		if f.id == id:
			return f
	return {}


func action(id: String) -> Dictionary:
	for a in data.get("actions", []):
		if a.id == id:
			return a
	return {}


# =====================================================================
#  Zustand
# =====================================================================

func init_state(state: Dictionary) -> void:
	state["factions"] = {}
	for f in factions():
		state.factions[f.id] = {"relation": int(f.get("start_relation", 0)), "fear": 0, "treaties": [], "acc": 0.0}


func normalize(state: Dictionary) -> void:
	if not state.has("factions"):
		init_state(state)
	for f in factions():
		if not state.factions.has(f.id):
			state.factions[f.id] = {"relation": int(f.get("start_relation", 0)), "fear": 0, "treaties": [], "acc": 0.0}
		var fs: Dictionary = state.factions[f.id]
		fs.relation = int(fs.relation)
		fs.fear = int(fs.fear)


## Bedingungen: faction_relation_min, faction_fear_min, faction_treaty ({id: [treaties]}).
func check(c: Dictionary) -> bool:
	for id in c.get("faction_relation_min", {}):
		if fs(id).relation < int(c.faction_relation_min[id]) and not has_treaty(id, "vassal"):
			return false
	for id in c.get("faction_fear_min", {}):
		if fs(id).fear < int(c.faction_fear_min[id]):
			return false
	for id in c.get("faction_treaty", {}):
		var ok := false
		for t in c.faction_treaty[id]:
			ok = ok or has_treaty(id, t)
		if not ok:
			return false
	return true


func fs(id: String) -> Dictionary:
	return Game.state.factions.get(id, {"relation": 0, "fear": 0, "treaties": [], "acc": 0.0})


func has_treaty(id: String, t: String) -> bool:
	return t in fs(id).treaties


func at_war(id: String) -> bool:
	return has_treaty(id, "war")


func is_known(id: String) -> bool:
	var f := faction(id)
	if not Game.check(f.get("known_requires")):
		return false
	for rid in f.get("regions", []):
		if World.rs(rid).discovered:
			return true
	return false


func known_factions() -> Array:
	return factions().filter(func(f): return is_known(f.id))


func stance(id: String) -> Array:
	if at_war(id):
		return ["Krieg", "#ff4a5a"]
	if has_treaty(id, "vassal"):
		return ["Vasall", "#f5d77a"]
	var rel: int = fs(id).relation
	var out: Array = ["Neutral", "#c9c2d8"]
	for s in data.stances:
		if rel >= int(s[0]):
			out = [s[1], s[2]]
	return out


func treaty_label(t: String) -> String:
	return {"trade": "Handel", "nonaggression": "Nichtangriff", "alliance": "Bündnis", "vassal": "Vasall", "war": "Krieg"}.get(t, t)


## Fraktion, der eine Region gehört (sofern nicht Vasall/erobert).
func region_faction(rid: String) -> String:
	return World.region(rid).get("faction", "")


# =====================================================================
#  Effekte
# =====================================================================

## {"empire": {"relation": 10, "fear": 5, "treaty_add": "trade", "treaty_remove": "war"}}
func apply_faction_effects(eff: Dictionary) -> Array:
	var summary: Array = []
	for id in eff:
		if not Game.state.factions.has(id):
			continue
		var f := fs(id)
		var e: Dictionary = eff[id]
		var nm: String = faction(id).short
		if e.has("relation"):
			var old: int = f.relation
			f.relation = clampi(old + int(e.relation), -100, 100)
			if f.relation != old:
				summary.append(["Beziehung " + nm, f.relation - old])
		if e.has("fear"):
			var old: int = f.fear
			f.fear = clampi(old + int(e.fear), 0, 100)
			if f.fear != old:
				summary.append(["Furcht " + nm, f.fear - old])
		if e.has("treaty_add"):
			_add_treaty(id, e.treaty_add)
		if e.has("treaty_remove"):
			f.treaties.erase(e.treaty_remove)
	return summary


func _add_treaty(id: String, t: String) -> void:
	var f := fs(id)
	if t in f.treaties:
		return
	if t == "war":
		f.treaties.clear()
	else:
		f.treaties.erase("war")
	f.treaties.append(t)
	var nm: String = faction(id).name
	match t:
		"war": Game.log_msg("⚔ Krieg mit %s!" % nm, "warning")
		"vassal":
			Game.log_msg("⚜ %s unterwirft sich als Vasall Nazaricks!" % nm, "story")
			for rid in faction(id).regions:
				World.apply_region_effects({rid: {"discover": true, "influence": 30}})
		_: Game.log_msg("Vertrag mit %s: %s" % [nm, treaty_label(t)], "story")


# =====================================================================
#  Gesandtschaften
# =====================================================================

## Prüft, ob eine Aktion gegenüber einer Fraktion möglich ist. [ok, Grund]
func can_do(fid: String, aid: String) -> Array:
	var a := action(aid)
	var f := fs(fid)
	var r: Dictionary = a.get("requires", {})
	if r.get("not_war", false) and at_war(fid):
		return [false, "Im Krieg nicht möglich"]
	if r.get("war", false) and not at_war(fid):
		return [false, "Kein Krieg"]
	if r.has("relation_min") and f.relation < int(r.relation_min):
		return [false, "Beziehung mind. %d" % int(r.relation_min)]
	if r.has("fear_min") and f.fear < int(r.fear_min):
		return [false, "Furcht mind. %d" % int(r.fear_min)]
	if r.has("power_min") and Game.state.resources.power < int(r.power_min):
		return [false, "Macht mind. %d" % int(r.power_min)]
	if r.has("no_treaty") and has_treaty(fid, r.no_treaty):
		return [false, "Besteht bereits"]
	if r.has("not_treaty") and has_treaty(fid, r.not_treaty):
		return [false, "Nicht möglich"]
	if Game.state.resources.gold < int(a.get("cost", 0)):
		return [false, "Zu wenig Gold"]
	for am in Game.state.active:
		var m := Game.mission(am.mission_id)
		if m.get("diplomacy", {}).get("faction", "") == fid:
			return [false, "Gesandtschaft unterwegs"]
	return [true, ""]


## Startet eine diplomatische Aktion. Sofort-Aktionen (Krieg) wirken direkt,
## alle anderen werden als Gesandtschaft des gewählten Wächters ausgeführt.
func start_action(fid: String, aid: String, envoy: String) -> Dictionary:
	var ok: Array = can_do(fid, aid)
	if not ok[0]:
		return {"ok": false, "text": ok[1]}
	var a := action(aid)
	var f := faction(fid)
	if a.get("instant", false):
		_add_treaty(fid, "war")
		fs(fid).relation = mini(fs(fid).relation, -70)
		Game.apply_effects({"res": {"attention": 8}, "chars": {"shalltear": {"mood": 10}, "cocytus": {"mood": 6}, "sebas": {"mood": -6}}})
		Game.state_changed.emit()
		return {"ok": true, "text": "Krieg gegen %s erklärt." % f.name}
	if envoy == "" or not Game.is_available(envoy):
		return {"ok": false, "text": "Wählt einen verfügbaren Gesandten."}
	Game.state.resources.gold -= int(a.get("cost", 0))
	var mid := "dip_" + Game.next_uid("x")
	var diff := 35 + int(f.power) / 4
	if aid in ["vassal", "tribute"]:
		diff += 15
	if aid == "peace":
		diff += 10
	Game.state.dynamic_missions[mid] = {
		"id": mid, "title": "%s: %s" % [a.name, f.short], "category": "Diplomatie",
		"location": f.name, "region": f.regions[0] if not f.regions.is_empty() else "",
		"description": a.desc, "days": int(a.days), "difficulty": diff,
		"weights": {"diplomatie": 3, "intellekt": 1} if aid != "intimidate" else {"kampf": 1, "grausamkeit": 2},
		"rewards": {}, "diplomacy": {"faction": fid, "action": aid},
		"outcomes": {
			"triumph": "Die Gesandtschaft zu %s war ein vollkommener Erfolg." % f.name,
			"success": "Die Gesandtschaft zu %s hat ihr Ziel erreicht." % f.name,
			"partial": "%s hat nur teilweise eingewilligt." % f.ruler,
			"failure": "%s hat das Ansinnen zurückgewiesen." % f.ruler,
		},
	}
	Game.assign(mid, envoy, "diplomatisch")
	return {"ok": true, "text": "%s bricht als Gesandter nach %s auf." % [Game.char_name(envoy).split(" ")[0], f.short]}


## Wird bei Abschluss einer Gesandtschaft aufgerufen.
func resolve_envoy(m: Dictionary, tier: String, envoy: String) -> Array:
	var d: Dictionary = m.diplomacy
	var fid: String = d.faction
	var a := action(d.action)
	var f := faction(fid)
	var res: Dictionary = a.get("result", {})
	var mult: float = {"triumph": 1.4, "success": 1.0, "partial": 0.5, "failure": 0.0}[tier]
	var eff := {}
	var summary: Array = []
	var ok := tier in ["triumph", "success"] or (tier == "partial" and not res.has("treaty"))
	if res.has("relation"):
		eff["relation"] = roundi(float(res.relation) * mult) if tier != "failure" else -5
	if res.has("fear"):
		eff["fear"] = roundi(float(res.fear) * maxf(mult, 0.3))
	if ok and res.has("treaty"):
		eff["treaty_add"] = res.treaty
	if ok and res.get("end_war", false):
		eff["treaty_remove"] = "war"
		fs(fid).relation = maxi(fs(fid).relation, -30)
		Game.log_msg("Frieden mit %s." % f.name, "story")
	summary += apply_faction_effects({fid: eff})
	if ok and res.get("tribute", false):
		summary += Game.apply_effects({"res": {"gold": roundi(float(f.tribute) * mult)}})
	if res.has("attention"):
		summary += Game.apply_effects({"res": {"attention": int(res.attention)}})
	# Albedo und Demiurge sind geborene Diplomaten – Shalltear und Narberal eher nicht
	if tier == "failure" and envoy in ["shalltear", "narberal"]:
		summary += apply_faction_effects({fid: {"relation": -10, "fear": 10}})
	if ok:
		Progress.bump("envoys")
	return summary


# =====================================================================
#  Tageslauf: Stimmungen, Handel, Kriegserklärungen, Gesandte der Fraktionen
# =====================================================================

func tick_day() -> void:
	var s := Game.state
	var trade_income := 0.0
	for f in factions():
		var st := fs(f.id)
		if not is_known(f.id):
			continue
		# Langsame Drift nach Ruf, Macht und Aufmerksamkeit Nazaricks
		var drift := 0.0
		for k in f.get("likes", {}):
			drift += float(f.likes[k]) * (s.resources.get(k, 0) - 40)
		for k in f.get("dislikes", {}):
			drift += float(f.dislikes[k]) * s.resources.get(k, 0)
		if has_treaty(f.id, "trade"):
			drift += 0.08
			trade_income += float(f.trade)
		if has_treaty(f.id, "vassal"):
			trade_income += float(f.tribute) / 30.0
			drift += 0.05
		st.acc = float(st.get("acc", 0.0)) + drift
		if absf(st.acc) >= 1.0:
			var whole := int(st.acc)
			st.acc -= whole
			st.relation = clampi(st.relation + whole, -100, 100)
		if s.day % 3 == 0 and st.fear > 0:
			st.fear -= 1
		# Hass schlägt in Krieg um
		if st.relation <= -60 and not at_war(f.id) and not has_treaty(f.id, "vassal") and not has_treaty(f.id, "nonaggression"):
			_declare_war_on_us(f)
		elif Game.rng.randf() < 0.012:
			_faction_envoy(f)
	if trade_income > 0:
		s.income_acc.gold = float(s.income_acc.gold) + trade_income * 0.1 * Game.diff("income")


func _declare_war_on_us(f: Dictionary) -> void:
	_add_treaty(f.id, "war")
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "threat", "char_id": "demiurge", "day": Game.state.day,
		"title": "⚔ %s erklärt den Krieg" % f.name,
		"body": "%s hat Nazarick den Krieg erklärt. Herolde verkünden in allen Städten, dass ›das Übel im Westen‹ ausgelöscht werden muss.\n\n[color=#ff8c1a][i]»Wie Ihr es zweifellos geplant habt, {lord}. Ein Feind, der offen angreift, ist ein Feind, den man offen vernichten darf. Ich bereite alles vor.«[/i][/color]\n\nErwartet Heere auf der Weltkarte [K]. Frieden lässt sich über die Diplomatie [P] anbieten." % f.ruler,
		"options": [{"key": "ok", "label": "So sei es.", "effects": {}, "reaction": "", "variant": "danger"}],
		"context": {"subtitle": f.name, "image": f.get("image", "")},
	})


## Fraktionen ergreifen selbst die Initiative – mit Angeboten oder Forderungen.
func _faction_envoy(f: Dictionary) -> void:
	var st := fs(f.id)
	var opts: Array = []
	var body := ""
	var title := ""
	if at_war(f.id):
		return
	if st.relation >= 25 and not has_treaty(f.id, "trade"):
		title = "%s bietet Handel an" % f.short
		body = "Ein Gesandter von %s überbringt ein Angebot: ein Handelsabkommen zwischen ihrem Reich und ›dem Herrscher von Nazarick‹." % f.ruler
		opts = [
			{"key": "yes", "label": "Annehmen", "variant": "success", "effects": {"factions": {f.id: {"treaty_add": "trade", "relation": 5}}}, "reaction": "Das Abkommen ist besiegelt. Gold wird fließen – und Informationen."},
			{"key": "no", "label": "Ablehnen", "variant": "default", "effects": {"factions": {f.id: {"relation": -6}}}, "reaction": "Der Gesandte verneigt sich steif und reist ab."},
		]
	elif st.fear >= 45 and not has_treaty(f.id, "nonaggression"):
		title = "%s bittet um Frieden" % f.short
		body = "Zitternd überbringt ein Bote von %s ein Schreiben: Man bitte ›untertänigst‹ um einen Nichtangriffspakt und biete Gold als Zeichen guten Willens." % f.ruler
		opts = [
			{"key": "yes", "label": "Gewähren (+%d Gold)" % (int(f.tribute) / 2), "variant": "success", "effects": {"factions": {f.id: {"treaty_add": "nonaggression", "relation": 10}}, "res": {"gold": int(f.tribute) / 2}}, "reaction": "Der Bote weint vor Erleichterung. Demiurge notiert sich die Schwächen seines Herrn."},
			{"key": "no", "label": "Ihre Angst genießen", "variant": "danger", "effects": {"factions": {f.id: {"fear": 10, "relation": -8}}}, "reaction": "Der Bote flieht. Shalltear findet das sehr amüsant."},
		]
	elif st.relation <= -30:
		title = "Drohung aus %s" % f.short
		body = "%s lässt verkünden: Sollte Nazarick seine ›unheiligen Umtriebe‹ nicht einstellen, werde man mit aller Härte antworten. Man verlangt eine Entschädigung." % f.ruler
		opts = [
			{"key": "pay", "label": "Zahlen (−120 Gold)", "variant": "warning", "requires_gold": 120, "effects": {"res": {"gold": -120}, "factions": {f.id: {"relation": 15}}}, "reaction": "Das Gold besänftigt sie – vorerst. Albedo hält das für Verschwendung."},
			{"key": "mock", "label": "Den Boten verspotten", "variant": "danger", "effects": {"factions": {f.id: {"relation": -15, "fear": 5}}}, "reaction": "Der Bote kehrt ohne Antwort zurück – und mit grauen Haaren."},
			{"key": "ignore", "label": "Ignorieren", "variant": "default", "effects": {"factions": {f.id: {"relation": -5}}}, "reaction": "Schweigen ist auch eine Antwort."},
		]
	else:
		return
	Game.log_msg("Gesandter aus %s: %s" % [f.short, title], "initiative")
	Game.push_dispatch({
		"uid": Game.next_uid("d"), "kind": "event", "char_id": "albedo", "day": Game.state.day,
		"title": title, "body": body + "\n\n[color=#f1e6ff][i]»Wie lautet Eure Antwort, {lord}?«[/i][/color]",
		"options": opts.filter(func(o): return Game.state.resources.gold >= int(o.get("requires_gold", 0))),
		"context": {"subtitle": f.name, "image": f.get("image", "")},
	})


## Eroberung einer Region: Die Fraktion reagiert.
func on_region_conquered(rid: String) -> Array:
	var fid := region_faction(rid)
	if fid == "" or has_treaty(fid, "vassal"):
		return []
	var summary: Array = []
	if at_war(fid):
		summary += apply_faction_effects({fid: {"fear": 20}})
	else:
		summary += apply_faction_effects({fid: {"relation": -45, "fear": 15}})
		summary += Game.apply_effects({"res": {"reputation": -6}})
	return summary


## Gewichtung feindlicher Feldzüge je Fraktion (0 = nie).
func invasion_weight(fid: String, war_only: bool) -> float:
	if fid == "":
		return 1.0
	if has_treaty(fid, "nonaggression") or has_treaty(fid, "vassal") or has_treaty(fid, "alliance"):
		return 0.0
	if at_war(fid):
		return 3.0
	if war_only:
		return 0.0
	var rel: int = fs(fid).relation
	return 1.5 if rel <= -30 else (0.5 if rel < 20 else 0.0)

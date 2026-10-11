extends Node
## Game – zentraler Spielzustand und Spiellogik von Nazarick (Autoload).
##
## Die UI liest ausschließlich aus [member state] und ruft öffentliche Methoden
## auf (assign, advance, respond, audience …). Änderungen werden über Signale
## gemeldet. Der gesamte Zustand ist ein JSON-kompatibles Dictionary und kann
## daher direkt gespeichert werden (siehe SaveSystem).
##
## Ablauf eines Tages ([method _tick_day]):
##   1. Laufende Aufträge prüfen → Berichte erzeugen
##   2. Erholung, Emotionen & Rivalität fortschreiben
##   3. Story-Ereignisse und Kapitelfortschritt prüfen
##   4. Eigeninitiative der Untertanen würfeln
##   5. Zufallsereignisse würfeln
##
## Jede Spielerentscheidung läuft über eine „Depesche“ (Dispatch): ein Bericht,
## Ereignis oder Vorschlag mit Antwortoptionen. Jede Option trägt ihre Effekte
## mit sich (siehe [method apply_effects]) – so lassen sich Inhalte rein über
## JSON erweitern.

signal state_changed
signal log_added(entry: Dictionary)
signal dispatches_arrived(count: int)
signal chapter_changed(number: int)

const STATUS_READY := "bereit"
const STATUS_MISSION := "im_einsatz"
const STATUS_RECOVER := "erholung"
const STATUS_CONTROLLED := "kontrolliert"
const STATUS_LOCKED := "gesperrt"

const STATUS_LABELS := {
	"bereit": "Im Thronsaal",
	"im_einsatz": "Im Einsatz",
	"erholung": "Erholt sich",
	"kontrolliert": "GEDANKENKONTROLLE",
	"gesperrt": "Unbekannt",
	"feldzug": "Führt eine Armee",
}

const RESOURCE_KEYS := ["power", "info", "reputation", "morale", "gold", "attention"]
const RESOURCE_LABELS := {
	"power": "Macht", "info": "Wissen", "reputation": "Ruf",
	"morale": "Stimmung", "gold": "Gold", "attention": "Aufmerksamkeit",
}
const BOUNDED := ["power", "info", "reputation", "morale", "attention"]

const CHAR_STAT_LABELS := {"favor": "Gunst", "mood": "Stimmung", "jealousy": "Eifersucht", "fatigue": "Erschöpfung"}
const STAT_LABELS := {
	"kampf": "Kampfkraft", "intellekt": "Intellekt", "diskretion": "Diskretion",
	"diplomatie": "Diplomatie", "grausamkeit": "Grausamkeit", "initiative": "Initiative",
}
const TIER_LABELS := {"triumph": "Triumph", "success": "Erfolg", "partial": "Teilerfolg", "failure": "Fehlschlag"}
const TIER_MULT := {"triumph": 1.5, "success": 1.0, "partial": 0.5, "failure": 0.0}
const MONTHS := ["Frostmond", "Eismond", "Saatmond", "Blütenmond", "Sonnenmond", "Glutmond",
	"Erntemond", "Nebelmond", "Rauchmond", "Sturmmond", "Schattenmond", "Totenmond"]

const AUDIENCES_PER_DAY := 2
const RANDOM_EVENT_CHANCE := 0.11
const INITIATIVE_BASE := 0.045

var state: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# =====================================================================
#  Spielstart / Laden
# =====================================================================

## Wert des gewählten Schwierigkeitsgrads (gold, income, upkeep, mission, threat, enemy, influence).
func diff(key: String) -> float:
	var d := Content.difficulty(state.get("difficulty", "normal"))
	return float(d.get(key, 0.0 if key == "mission" else 1.0))


func new_game(difficulty: String = "normal") -> void:
	state = {
		"day": 1, "chapter": 1, "chapter_start_day": 1,
		"lord_name": "Momonga", "rivalry": 25,
		"audiences_day": 0, "audiences_used": 0, "uid": 0,
		"resources": {}, "chars": {}, "flags": [], "unlocked_missions": [],
		"completed": {}, "completed_day": {}, "failed": {}, "active": [], "dispatches": [], "log": [], "fired": {},
	}
	state["difficulty"] = difficulty
	for k in Content.lord.get("start_resources", {}):
		state.resources[k] = int(Content.lord.start_resources[k])
	state.resources.gold = int(diff("gold"))
	for cid in Content.character_order:
		state.chars[cid] = _new_char_state(cid)
	World.init_state(state)
	Military.init_state(state)
	Diplomacy.init_state(state)
	Progress.init_state(state)
	log_msg("Das Große Grab von Nazarick erwacht in einer fremden Welt.", "story")
	_enter_chapter(1)
	state_changed.emit()


func load_state(data: Dictionary) -> void:
	state = data
	_normalize()
	state_changed.emit()


func _new_char_state(cid: String) -> Dictionary:
	var cd := Content.char_data(cid)
	var init: Dictionary = cd.get("initial", {})
	var unlocked: bool = cd.get("unlocked", true)
	return {
		"favor": int(init.get("favor", 50)), "mood": int(init.get("mood", 70)),
		"jealousy": int(init.get("jealousy", 0)), "fatigue": 0,
		"status": STATUS_READY if unlocked else STATUS_LOCKED,
		"mission_uid": "", "unlocked": unlocked, "recover_until": 0, "deeds": [],
	}


## JSON kennt nur Floats – nach dem Laden alle Zahlen wieder zu int machen
## und neu hinzugekommene Charaktere ergänzen.
func _normalize() -> void:
	for k in ["day", "chapter", "chapter_start_day", "rivalry", "audiences_day", "audiences_used", "uid"]:
		state[k] = int(state.get(k, 0))
	for k in state.resources:
		state.resources[k] = int(state.resources[k])
	for cid in Content.character_order:
		if not state.chars.has(cid):
			state.chars[cid] = _new_char_state(cid)
		var cs: Dictionary = state.chars[cid]
		for k in ["favor", "mood", "jealousy", "fatigue", "recover_until"]:
			cs[k] = int(cs.get(k, 0))
	for k in state.completed:
		state.completed[k] = int(state.completed[k])
	# Ältere Spielstände kennen diese Felder noch nicht
	if not state.has("completed_day"):
		state["completed_day"] = {}
		for k in state.completed:
			state.completed_day[k] = state.day
	if not state.has("failed"):
		state["failed"] = {}
	for k in state.completed_day:
		state.completed_day[k] = int(state.completed_day[k])
	for k in state.failed:
		state.failed[k] = int(state.failed[k])
	World.normalize(state)
	Military.normalize(state)
	Diplomacy.normalize(state)
	Progress.normalize(state)
	if not state.has("difficulty"):
		state["difficulty"] = "normal"
	for k in state.fired:
		state.fired[k] = int(state.fired[k])
	for am in state.active:
		am.start_day = int(am.start_day)
		am.end_day = int(am.end_day)
	for e in state.log:
		e.day = int(e.day)


# =====================================================================
#  Hilfsfunktionen
# =====================================================================

## Anrede des Overlords, wie die Untertanen sie benutzen.
func lord() -> String:
	return "Momonga-sama" if state.get("lord_name", "Momonga") == "Momonga" else "Ainz-sama"


## Ersetzt Platzhalter in Texten aus den JSON-Daten.
func fmt(text: String) -> String:
	return text.replace("{lord}", lord()).replace("{lord_full}", state.get("lord_name", "Momonga"))


func pick(options: Variant) -> String:
	if options == null:
		return ""
	if options is String:
		return fmt(options)
	if options is Array and not options.is_empty():
		return fmt(options[rng.randi() % options.size()])
	return ""


func log_msg(text: String, cat: String = "info") -> void:
	if state.is_empty():
		return
	var entry := {"day": state.day, "text": fmt(text), "cat": cat}
	state.log.append(entry)
	if state.log.size() > 600:
		state.log = state.log.slice(100)
	log_added.emit(entry)


func format_date(day: int) -> String:
	var d := day - 1
	return "%d. %s · Jahr %d" % [d % 30 + 1, MONTHS[(d % 360) / 30], d / 360 + 1]


func cs(cid: String) -> Dictionary:
	return state.chars[cid]


func char_name(cid: String) -> String:
	return Content.char_data(cid).get("name", cid)


func is_available(cid: String) -> bool:
	var c := cs(cid)
	return c.unlocked and c.status == STATUS_READY


func unlocked_chars() -> Array[String]:
	var out: Array[String] = []
	for cid in Content.character_order:
		if cs(cid).unlocked:
			out.append(cid)
	return out


func has_flag(flag: String) -> bool:
	return flag in state.flags


func set_flag(flag: String) -> void:
	if not has_flag(flag):
		state.flags.append(flag)


func day_in_chapter() -> int:
	return state.day - state.chapter_start_day


func next_uid(prefix: String) -> String:
	state.uid += 1
	return "%s%d" % [prefix, state.uid]


## Effizienz der Guardians: Mittel aus Stimmung, Gunst und (fehlender) Erschöpfung.
func efficiency() -> int:
	var vals: Array[float] = []
	for cid in unlocked_chars():
		var c := cs(cid)
		if c.status == STATUS_CONTROLLED:
			vals.append(0.0)
		else:
			vals.append(c.mood * 0.5 + c.favor * 0.2 + (100 - c.fatigue) * 0.3)
	if vals.is_empty():
		return 0
	var total := 0.0
	for v in vals:
		total += v
	return clampi(roundi(total / vals.size()), 0, 100)


func audiences_left() -> int:
	if state.audiences_day != state.day:
		return audiences_per_day()
	return maxi(0, audiences_per_day() - state.audiences_used)


func audiences_per_day() -> int:
	return AUDIENCES_PER_DAY + roundi(Progress.floor_value("audience"))


# =====================================================================
#  Bedingungen (gemeinsames Schema für alle JSON-Inhalte)
# =====================================================================

func check(cond: Variant) -> bool:
	if cond == null or not (cond is Dictionary) or cond.is_empty():
		return true
	var c: Dictionary = cond
	if c.has("chapter") and state.chapter != int(c.chapter):
		return false
	if state.chapter < int(c.get("chapter_min", 0)) or state.chapter > int(c.get("chapter_max", 999)):
		return false
	if day_in_chapter() < int(c.get("day_in_chapter_min", 0)):
		return false
	for f in c.get("flags_all", []):
		if not has_flag(f):
			return false
	for f in c.get("flags_none", []):
		if has_flag(f):
			return false
	if c.has("flags_any"):
		var any := false
		for f in c.flags_any:
			any = any or has_flag(f)
		if not any:
			return false
	if state.rivalry < int(c.get("rivalry_min", -1)) or state.rivalry > int(c.get("rivalry_max", 101)):
		return false
	for k in c.get("res_min", {}):
		if state.resources.get(k, 0) < int(c.res_min[k]):
			return false
	for k in c.get("res_max", {}):
		if state.resources.get(k, 0) > int(c.res_max[k]):
			return false
	for cid in c.get("jealousy_min", {}):
		if cs(cid).jealousy < int(c.jealousy_min[cid]):
			return false
	for cid in c.get("favor_min", {}):
		if cs(cid).favor < int(c.favor_min[cid]):
			return false
	for cid in c.get("favor_max", {}):
		if cs(cid).favor > int(c.favor_max[cid]):
			return false
	for cid in c.get("idle", []):
		if not is_available(cid):
			return false
	for cid in c.get("unlocked", []):
		if not cs(cid).unlocked:
			return false
	for mid in c.get("missions_done", []):
		if not state.completed.has(mid):
			return false
	if state.has("regions") and not World.check(c):
		return false
	if state.has("factions") and not Diplomacy.check(c):
		return false
	return true


# =====================================================================
#  Effekte
# =====================================================================

## Wendet ein Effekt-Dictionary an und liefert eine Zusammenfassung
## als Array von [Label, Delta] für die Anzeige.
##
## Unterstützte Schlüssel: res, chars, rivalry, set_flags, clear_flags,
## unlock_missions, unlock_chars, status, lord_name, log, log_cat, queue_events
func apply_effects(eff: Variant) -> Array:
	var summary: Array = []
	if eff == null or not (eff is Dictionary):
		return summary
	for k in eff.get("res", {}):
		var delta := int(eff.res[k])
		if delta == 0:
			continue
		var old: int = state.resources.get(k, 0)
		var nv := old + delta
		nv = clampi(nv, 0, 100) if k in BOUNDED else maxi(0, nv)
		state.resources[k] = nv
		if k == "gold" and nv > old:
			Progress.bump("gold_earned", nv - old)
		if nv != old:
			summary.append([RESOURCE_LABELS.get(k, k), nv - old])
	for cid in eff.get("chars", {}):
		if not state.chars.has(cid):
			continue
		var c := cs(cid)
		for attr in eff.chars[cid]:
			var old: int = c.get(attr, 0)
			var nv := clampi(old + int(eff.chars[cid][attr]), 0, 100)
			c[attr] = nv
			if nv != old and c.unlocked:
				summary.append(["%s: %s" % [char_name(cid), CHAR_STAT_LABELS.get(attr, attr)], nv - old])
	if int(eff.get("rivalry", 0)) != 0:
		var old: int = state.rivalry
		state.rivalry = clampi(old + int(eff.rivalry), 0, 100)
		if state.rivalry != old:
			summary.append(["Rivalität Albedo ⚔ Shalltear", state.rivalry - old])
	for f in eff.get("set_flags", []):
		set_flag(f)
	for f in eff.get("clear_flags", []):
		state.flags.erase(f)
	for mid in eff.get("unlock_missions", []):
		if not mid in state.unlocked_missions:
			state.unlocked_missions.append(mid)
			if Content.missions.has(mid):
				log_msg("Neuer Auftrag verfügbar: %s" % Content.missions[mid].title, "mission")
	for cid in eff.get("unlock_chars", []):
		var c := cs(cid)
		if not c.unlocked:
			c.unlocked = true
			c.status = STATUS_READY
			log_msg("%s steht Euch nun zu Diensten." % char_name(cid), "story")
	for cid in eff.get("status", {}):
		cs(cid).status = eff.status[cid]
		if eff.status[cid] == STATUS_READY:
			cs(cid).mission_uid = ""
	if eff.has("lord_name"):
		state.lord_name = eff.lord_name
	if eff.has("log"):
		log_msg(eff.log, eff.get("log_cat", "story"))
	if eff.has("regions"):
		summary += World.apply_region_effects(eff.regions)
	if eff.has("mission_mod"):
		summary += World.apply_mission_mod(eff.mission_mod)
	if eff.has("factions"):
		summary += Diplomacy.apply_faction_effects(eff.factions)
	if eff.has("battle"):
		summary += Military.resolve_battle(eff.battle.uid, eff.battle.tactic)
	for ev_id in eff.get("queue_events", []):
		queue_event(ev_id)
	return summary


func _add_deed(cid: String, text: String) -> void:
	var deeds: Array = cs(cid).deeds
	deeds.append("Tag %d · %s" % [state.day, fmt(text)])
	if deeds.size() > 14:
		cs(cid).deeds = deeds.slice(deeds.size() - 14)


# =====================================================================
#  Kapitel
# =====================================================================

func _enter_chapter(number: int) -> void:
	state.chapter = number
	state.chapter_start_day = state.day
	var ch := Content.chapter(number)
	apply_effects(ch.get("on_enter"))
	log_msg("══ Kapitel %s: %s ══" % [ch.numeral, ch.title], "story")
	_push({
		"uid": next_uid("d"), "kind": "story", "char_id": "", "day": state.day,
		"title": "Kapitel %s · %s" % [ch.numeral, ch.title],
		"body": fmt(ch.intro),
		"options": [{"key": "go", "label": "Die Geschicke Nazaricks lenken", "effects": {}, "reaction": "", "variant": "primary"}],
		"context": {"subtitle": ch.get("subtitle", ""), "chapter": number, "image": ch.get("image", "")},
	})
	chapter_changed.emit(number)


## Liste der Kapitelziele als [Text, erledigt]-Paare.
## Ziele sind entweder Story-Flags ("flag") oder Bedingungen ("cond", z. B. Einfluss/Ressourcen);
## dazu kommt eine Mindestdauer je Kapitel ("min_days"), damit sich die Herrschaft entfalten kann.
func objectives() -> Array:
	var out: Array = []
	var ch := Content.chapter(state.chapter)
	for o in ch.get("objectives", []):
		out.append([fmt(o.text) + _objective_progress(o), _objective_done(o)])
	if ch.has("min_days") and not ch.get("objectives", []).is_empty():
		var need := int(ch.min_days)
		out.append(["Die Herrschaft festigen (%d/%d Tage)" % [mini(day_in_chapter(), need), need], day_in_chapter() >= need])
	return out


func _objective_done(o: Dictionary) -> bool:
	if o.has("flag"):
		return has_flag(o.flag)
	return check(o.get("cond"))


## Fortschrittsanzeige wie „(12/30)“ für Einfluss- und Ressourcenziele.
func _objective_progress(o: Dictionary) -> String:
	var c: Dictionary = o.get("cond", {})
	if c.has("region_min") and c.region_min.size() == 1:
		var id: String = c.region_min.keys()[0]
		return " (%d/%d)" % [World.rs(id).influence, int(c.region_min[id])]
	if c.has("res_min") and c.res_min.size() == 1:
		var k: String = c.res_min.keys()[0]
		return " (%d/%d)" % [state.resources.get(k, 0), int(c.res_min[k])]
	return ""


func _check_chapter_progress() -> void:
	var ch := Content.chapter(state.chapter)
	var objs: Array = ch.get("objectives", [])
	if objs.is_empty() or state.chapter >= Content.chapters.size():
		return
	for o in objs:
		if not _objective_done(o):
			return
	if day_in_chapter() < int(ch.get("min_days", 0)):
		return
	apply_effects(ch.get("on_complete"))
	_enter_chapter(state.chapter + 1)


# =====================================================================
#  Depeschen
# =====================================================================

func _push(d: Dictionary) -> void:
	state.dispatches.append(d)


## Öffentlich für andere Systeme (World).
func push_dispatch(d: Dictionary) -> void:
	d["body"] = fmt(d.get("body", ""))
	_push(d)


func pending() -> Array:
	return state.dispatches


func get_dispatch(uid: String) -> Dictionary:
	for d in state.dispatches:
		if d.uid == uid:
			return d
	return {}


## Erzeugt eine Depesche aus einem Ereignis der events.json.
func queue_event(ev_id: String) -> void:
	if not Content.events.has(ev_id):
		push_warning("Unbekanntes Ereignis: %s" % ev_id)
		return
	var ev: Dictionary = Content.events[ev_id]
	state.fired[ev_id] = state.day
	apply_effects(ev.get("on_trigger"))
	var options: Array = []
	var i := 0
	for ch in ev.get("choices", []):
		if check(ch.get("requires")):
			options.append({
				"key": "c%d" % i, "label": fmt(ch.label), "effects": ch.get("effects", {}),
				"reaction": fmt(ch.get("reaction", "")), "variant": ch.get("variant", "default"),
			})
		i += 1
	if options.is_empty():
		options.append({"key": "ok", "label": "Fortfahren", "effects": {}, "reaction": "", "variant": "primary"})
	if ev.get("special", "") == "ending":
		ev = ev.duplicate()
		ev["body"] = build_ending()
		options = [{"key": "ok", "label": "Die Herrschaft geht weiter …", "effects": {"set_flags": ["game_completed"]}, "reaction": "", "variant": "primary"}]
	_push({
		"uid": next_uid("d"), "kind": ev.get("kind", "event"), "char_id": ev.get("char", ""),
		"day": state.day, "title": fmt(ev.title), "body": fmt(ev.body), "options": options,
		"context": {"event_id": ev_id, "subtitle": fmt(ev.get("subtitle", "")), "type": ev.get("type", ""), "image": ev.get("image", "")},
	})


## Wendet die gewählte Antwort an. Liefert {"reaction": String, "summary": Array}.
func respond(uid: String, key: String) -> Dictionary:
	var d := get_dispatch(uid)
	if d.is_empty():
		return {"reaction": "", "summary": []}
	var opt: Dictionary = d.options[0]
	for o in d.options:
		if o.key == key:
			opt = o
	state.dispatches.erase(d)
	var summary := apply_effects(opt.get("effects"))
	if d.kind == "report" and d.char_id != "":
		if key in ["praise", "reward"]:
			Progress.bump("praises")
		elif key == "rebuke":
			Progress.bump("rebukes")
		var verbs := {"praise": "lobt", "reward": "belohnt", "rebuke": "tadelt", "silence": "nickt schweigend zu:"}
		if verbs.has(key):
			log_msg("%s %s %s." % [state.lord_name, verbs[key], char_name(d.char_id)], "emotion")
	var before: int = state.chapter
	_check_chapter_progress()
	state_changed.emit()
	if state.chapter != before:
		dispatches_arrived.emit(state.dispatches.size())
	var reaction: String = opt.get("reaction", "")
	if opt.get("effects", {}).has("battle"):
		reaction = Military.last_result.get("text", "")
	return {"reaction": reaction, "summary": summary}


# =====================================================================
#  Aufträge
# =====================================================================

func mission(mid: String) -> Dictionary:
	if Content.missions.has(mid):
		return Content.missions[mid]
	return state.get("dynamic_missions", {}).get(mid, {})


func is_mission_active(mid: String) -> bool:
	for am in state.active:
		if am.mission_id == mid:
			return true
	return false


func mission_kind(m: Dictionary) -> String:
	if m.has("threat"):
		return "threat"
	if m.get("main", false):
		return "main"
	if m.get("proposal", false):
		return "proposal"
	return "side"


## Standard-Abklingzeit wiederholbarer Aufträge (Tage); pro Auftrag per "repeat_cooldown" änderbar.
const REPEAT_COOLDOWN := 12


func mission_available(m: Dictionary) -> bool:
	if is_mission_active(m.id):
		return false
	if state.completed.has(m.id):
		# Abgeschlossene Aufträge verschwinden – wiederholbare kehren erst nach ihrer Abklingzeit zurück.
		if not m.get("repeatable", false):
			return false
		if repeat_days_left(m) > 0:
			return false
	if m.has("threat"):
		return true
	if m.id in state.unlocked_missions:
		var req: Dictionary = m.get("requires", {})
		return check({"flags_all": req.get("flags_all", []), "flags_none": req.get("flags_none", []),
			"region_discovered": req.get("region_discovered", [])})
	if m.get("proposal", false) or m.get("locked", false):
		return false
	return check(m.get("requires"))


## Tage, bis ein wiederholbarer Auftrag erneut angeboten wird.
func repeat_days_left(m: Dictionary) -> int:
	if not state.completed_day.has(m.id):
		return 0
	var cd := int(m.get("repeat_cooldown", REPEAT_COOLDOWN))
	return maxi(0, int(state.completed_day[m.id]) + cd - state.day)


## Status-Kennzeichen für die Auftragsliste: "" (neu), "repeat" (wiederholt), "retry" (zuvor gescheitert).
func mission_badge(m: Dictionary) -> String:
	if state.failed.has(m.id) and not state.completed.has(m.id):
		return "retry"
	if state.completed.has(m.id):
		return "repeat"
	return ""


func available_missions() -> Array:
	var order := {"threat": -1, "main": 0, "proposal": 1, "side": 2}
	var out: Array = []
	for m in Content.missions.values():
		if mission_available(m):
			out.append(m)
	for m in state.get("dynamic_missions", {}).values():
		if mission_available(m):
			out.append(m)
	out.sort_custom(func(a, b):
		var ka: int = order[mission_kind(a)]
		var kb: int = order[mission_kind(b)]
		if ka != kb:
			return ka < kb
		return int(a.difficulty) < int(b.difficulty))
	return out


## Liefert [darf_zugewiesen_werden: bool, Grund: String].
func can_assign(m: Dictionary, cid: String) -> Array:
	var c := cs(cid)
	if not c.unlocked:
		return [false, "Unbekannt"]
	var req: String = m.get("required_char", "")
	if req != "" and req != cid:
		return [false, "Nur " + char_name(req).split(" ")[0]]
	if c.status != STATUS_READY:
		return [false, STATUS_LABELS.get(c.status, "Nicht verfügbar")]
	return [true, ""]


func mission_days(m: Dictionary, directive: String) -> int:
	return maxi(1, roundi(float(m.days) * float(Content.directives[directive].get("days", 1.0))))


## Erfolgswert eines Untertanen für einen Auftrag (Marge gegenüber der Schwierigkeit).
func _score(m: Dictionary, cid: String, directive: String, roll: bool = true, partner: String = "", extra: float = 0.0) -> float:
	var cd := Content.char_data(cid)
	var c := cs(cid)
	var dmod: Dictionary = Content.directives[directive]
	var weights: Dictionary = m.get("weights", {"kampf": 1}).duplicate()
	for k in dmod.get("stat_bonus", {}):
		weights[k] = float(weights.get(k, 0)) + float(dmod.stat_bonus[k])
	var total := 0.0
	var score := 0.0
	for k in weights:
		total += float(weights[k])
		score += (float(cd.stats[k]) + Progress.stat_bonus(cid, k)) * float(weights[k])
	score /= maxf(total, 1.0)
	score += (c.mood - 60) / 5.0 - c.fatigue / 6.0
	score += float(dmod.get("score", 0))
	if directive == "freie_hand":
		score += float(cd.get("style", {}).get("score", 0))
	if cid in m.get("recommended", []):
		score += 6.0
	# Schwierigkeitsgrad: Hauptaufträge nur halber Aufschlag; aus Fehlschlägen lernt man (bis −15)
	var diff_pen := diff("mission") * (0.5 if m.get("main", false) else 1.0)
	var learned := minf(15.0, int(state.get("failed", {}).get(m.get("id", ""), 0)) * 5.0)
	score += World.partner_bonus(m, cid, partner) + extra - diff_pen + learned
	# Ausbau (Bibliothek) und Artefakte mit Planungsbonus
	score += Progress.floor_value("score") + Progress.item_effect(cid, "score")
	if roll:
		var v := float(dmod.get("variance", 15)) + float(World.synergy(cid, partner).get("variance", 0))
		score += rng.randf_range(-v, v)
	return score - float(m.get("difficulty", 50))


## Grobe Erfolgsaussicht für die Auftragsvergabe: [Label, Farbe als Hex].
func estimate(m: Dictionary, cid: String, directive: String, partner: String = "") -> Array:
	var margin := _score(m, cid, directive, false, partner)
	if margin >= 22: return ["Triumph gewiss", "#7dffa0"]
	if margin >= 8: return ["Sehr gut", "#9be36a"]
	if margin >= -4: return ["Solide", "#f2d15c"]
	if margin >= -14: return ["Riskant", "#ff9a3c"]
	return ["Gefährlich", "#ff4a5a"]


func assign(mid: String, cid: String, directive: String, partner: String = "") -> bool:
	var m := mission(mid)
	if m.is_empty() or not can_assign(m, cid)[0]:
		return false
	if partner == cid or (partner != "" and not is_available(partner)):
		partner = ""
	var days := mission_days(m, directive)
	var am := {
		"uid": next_uid("m"), "mission_id": mid, "char_id": cid, "directive": directive,
		"start_day": state.day, "end_day": state.day + days, "partner": partner, "mods": {},
	}
	if m.has("threat"):
		am["threat"] = m.threat
	state.active.append(am)
	var c := cs(cid)
	c.status = STATUS_MISSION
	c.mission_uid = am.uid
	if partner != "":
		cs(partner).status = STATUS_MISSION
		cs(partner).mission_uid = am.uid
	var team := "" if partner == "" else " mit %s" % char_name(partner).split(" ")[0]
	log_msg("%s bricht%s auf: »%s« (%s, %d Tage)." % [char_name(cid), team, m.title, Content.directives[directive].name, days], "mission")
	# Wer mit Aufgaben betraut wird, gewinnt an Gunst – die Rivalin wird eifersüchtig.
	var boost := 4 if m.get("main", false) else 2
	var eff := {"chars": {cid: {"favor": boost}}}
	var rival: String = Content.char_data(cid).get("rival", "")
	if rival != "" and cs(rival).unlocked and rival != partner:
		eff.chars[rival] = {"jealousy": boost + 2}
	if partner != "":
		eff.chars[partner] = {"favor": 1}
		eff["rivalry"] = int(World.synergy(cid, partner).get("rivalry", 0))
	apply_effects(eff)
	state_changed.emit()
	return true


func mission_progress(am: Dictionary) -> float:
	var total := maxi(1, am.end_day - am.start_day)
	return clampf(float(state.day - am.start_day) / total, 0.0, 1.0)


func _resolve_mission(am: Dictionary) -> void:
	var m := mission(am.mission_id)
	var cid: String = am.char_id
	var cd := Content.char_data(cid)
	var c := cs(cid)
	state.active.erase(am)
	c.mission_uid = ""
	var partner: String = am.get("partner", "")
	var mods: Dictionary = am.get("mods", {})

	# 1) Interpretiert der Untertan den Befehl eigenwillig?
	var directive: String = am.directive
	var deviation_text := ""
	var dev: Dictionary = cd.get("deviations", {}).get(directive, {})
	if not dev.is_empty() and rng.randf() < float(dev.chance):
		directive = dev.to
		deviation_text = pick(dev.text)

	# 2) Ergebnis bestimmen
	var margin := _score(m, cid, directive, true, partner, float(mods.get("score", 0)))
	var tier := "failure"
	if margin >= 22: tier = "triumph"
	elif margin >= 4: tier = "success"
	elif margin >= -12: tier = "partial"
	tier = m.get("forced_tier", tier)

	# 3) Ressourceneffekte: Missionsbelohnung × Stufe + Stil des Vorgehens
	var res := {}
	for k in m.get("rewards", {}):
		var v := float(m.rewards[k])
		res[k] = int(res.get(k, 0)) + (int(v) if k == "attention" else roundi(v * TIER_MULT[tier]))
	if tier == "failure":
		var fail: Dictionary = m.get("failure", {"morale": -4, "attention": 4})
		for k in fail:
			res[k] = int(res.get(k, 0)) + int(fail[k])
	var dres: Dictionary = cd.get("style", {}).get("res", {}) if directive == "freie_hand" else Content.directives[directive].get("res", {})
	for k in dres:
		res[k] = int(res.get(k, 0)) + int(dres[k])
	var mood_delta: int = {"triumph": 10, "success": 5, "partial": -3, "failure": -15}[tier]
	var fatigue := int(float(m.days) * 2 + float(m.get("difficulty", 50)) / 6.0)
	var char_eff := {cid: {"mood": mood_delta, "fatigue": fatigue}}
	if partner != "":
		char_eff[partner] = {"mood": mood_delta / 2, "fatigue": fatigue - 4}
	var summary := apply_effects({"res": res, "chars": char_eff})
	summary += World.mission_region_effects(m, am, tier, directive, cid)
	if m.has("threat"):
		summary += World.resolve_threat_mission(m.id, tier != "failure")

	for who in ([cid, partner] if partner != "" else [cid]):
		var wc := cs(who)
		wc.mission_uid = ""
		if wc.fatigue >= 75:
			wc.status = STATUS_RECOVER
			wc.recover_until = state.day + 3
		elif wc.status == STATUS_MISSION:
			wc.status = STATUS_READY
	if partner != "":
		_add_deed(partner, "Unterstützung: %s – %s" % [m.title, TIER_LABELS[tier]])

	# Erfahrung, Beute und Zähler für Wochenziele/Errungenschaften
	var gained_xp := Progress.mission_xp(tier, m)
	Progress.add_xp(cid, gained_xp)
	summary.append(["Erfahrung " + cd.name.split(" ")[0], gained_xp])
	if partner != "":
		Progress.add_xp(partner, gained_xp / 2)
	if tier == "failure":
		Progress.bump("failures")
	else:
		Progress.bump("missions_done")
		if tier == "triumph":
			Progress.bump("triumphs")
	var loot_uid := Progress.roll_loot(tier, m.title, cid)
	var loot_id: String = Progress.inv_entry(loot_uid).get("id", "") if loot_uid != "" else ""

	_add_deed(cid, "%s – %s" % [m.title, TIER_LABELS[tier]])
	log_msg("%s kehrt zurück: »%s« – %s." % [cd.name, m.title, TIER_LABELS[tier]], "warning" if tier == "failure" else "mission")
	if m.has("diplomacy"):
		summary += Diplomacy.resolve_envoy(m, tier, cid)
	if m.has("threat") or m.has("diplomacy"):
		state.dynamic_missions.erase(m.id)
	if tier != "failure":
		state.completed[m.id] = int(state.completed.get(m.id, 0)) + 1
		state.completed_day[m.id] = state.day
		state.failed.erase(m.id)
		summary += apply_effects(m.get("on_success"))
	else:
		state.failed[m.id] = int(state.failed.get(m.id, 0)) + 1

	# Spezialfall: Bericht wird durch ein Ereignis ersetzt (z. B. Shalltear-Zwischenfall)
	if m.has("replace_report_with_event"):
		queue_event(m.replace_report_with_event)
		return

	var effective_name: String = cd.get("style", {}).get("name", "Freie Hand") if directive == "freie_hand" else Content.directives[directive].name
	_push({
		"uid": next_uid("d"), "kind": "report", "char_id": cid, "day": state.day,
		"title": "Bericht · " + m.title,
		"body": _compose_report(m, cid, directive, am.directive, tier, deviation_text) + _partner_note(cid, partner),
		"options": _report_options(cid, tier),
		"context": {
			"tier": tier, "mission": m.id, "summary": summary,
			"directive": Content.directives[am.directive].name, "effective": effective_name,
			"deviated": directive != am.directive, "location": m.get("location", ""),
			"partner": partner, "loot": loot_id,
		},
	})
	if tier != "failure" and m.has("followup_event"):
		queue_event(m.followup_event)
	_maybe_proposal(cid, am.directive)


## Epilog: fasst die Partie anhand von Entscheidungen und Zuständen zusammen.
func build_ending() -> String:
	var p := PackedStringArray()
	var held := 0
	for id in state.regions:
		if state.regions[id].influence >= 55 and not World.region(id).get("home", false):
			held += 1
	var vassals := PackedStringArray()
	var wars := PackedStringArray()
	var fear_sum := 0
	for f in Diplomacy.factions():
		if Diplomacy.has_treaty(f.id, "vassal"):
			vassals.append(f.short)
		if Diplomacy.at_war(f.id):
			wars.append(f.short)
		fear_sum += Diplomacy.fs(f.id).fear
	var rep: int = state.resources.reputation
	p.append("[b][color=#f5d77a]Das Zauberkönigreich von %s[/color][/b]" % state.lord_name)
	if has_flag("ending_peace"):
		p.append("Der Platin-Drache zog sich zurück, und mit ihm wich die Angst vor einem neuen Zeitalter der Gierkönige. Unter dem Banner des Zauberkönigs entstand etwas, das die Neue Welt nicht kannte: ein Reich, in dem Menschen, Zwerge, Elfen, Echsenmenschen und Untote nebeneinander lebten – beschützt von einem Herrscher, der niemals schlief.")
	elif has_flag("ending_power"):
		p.append("Der Tag, an dem die Platinrüstung zerbrach, wurde zum Feiertag – in Nazarick. Überall sonst wurde er zum Tag der Trauer. Keine Macht der Welt wagte es mehr, sich dem Zauberkönig zu widersetzen. Die Welt war nicht erobert. Sie hatte schlicht aufgegeben.")
	elif has_flag("ending_conquest"):
		p.append("Der Krieg gegen die alten Mächte der Welt begann in jener Nacht auf der Katze-Ebene. Demiurge hatte ihn längst geplant. Nazarick marschierte – und die Chroniken der Neuen Welt füllten sich mit einem einzigen Namen.")
	else:
		p.append("Das Zauberkönigreich steht. Was aus ihm werden wird, liegt allein in Euren knöchernen Händen.")
	if rep >= 60:
		p.append("Die Völker nennen Euch den [i]Gerechten König[/i]. In den Tempeln des Südens predigt eine junge Frau mit scharfen Augen, der Zauberkönig sei die Gerechtigkeit selbst.")
	elif fear_sum > 200 or rep < 20:
		p.append("Die Völker flüstern Euren Namen nur hinter verschlossenen Türen. Mütter erschrecken ihre Kinder mit dem ›König aus Knochen‹. Furcht ist ein verlässliches Fundament.")
	p.append("[color=#d4af37]Bilanz:[/color] %d Tage · %d Regionen unter Kontrolle · %d gewonnene Schlachten · %d Gold · Vasallen: %s%s" % [
		state.day, held, int(state.get("battles_won", 0)), state.resources.gold,
		", ".join(vassals) if not vassals.is_empty() else "keine", (" · Im Krieg mit: " + ", ".join(wars)) if not wars.is_empty() else ""])
	# Herzensangelegenheiten
	var a := cs("albedo")
	var sh := cs("shalltear")
	if has_flag("harem_pact") or (state.rivalry < 25 and a.favor >= 70 and sh.favor >= 70):
		p.append("[color=#ff7aa8]♥ Albedo und Shalltear haben ihren Pakt erneuert: Wer auch immer die Erste wird, die andere wird die Zweite. Sie streiten trotzdem täglich über die Reihenfolge – aber leiser.[/color]")
	elif a.favor >= sh.favor + 10:
		p.append("[color=#f1e6ff]♥ Albedo trägt seit der Krönung einen Ring am Ringfinger. Niemand weiß genau, ob Ihr ihn ihr geschenkt habt – Ihr selbst am allerwenigsten. Sie lächelt jeden Morgen, als hätte sie gewonnen. Vielleicht hat sie das.[/color]")
	elif sh.favor >= a.favor + 10:
		p.append("[color=#ff2a4f]♥ Shalltear hat ihren Sarg in die Gemächer neben Euren verlegen lassen. ›Zur Sicherheit‹, ~arinsu. Albedo hat die Verbindungstür dreimal zumauern lassen. Shalltear hat sie dreimal eingerissen.[/color]")
	else:
		p.append("[color=#ff7aa8]♥ Der Herzenskrieg ist nicht entschieden. Albedo und Shalltear stehen jeden Morgen gleichzeitig rechts neben dem Thron. Ihr habt aufgehört, es zu kommentieren.[/color]")
	if has_flag("world_conquest") or has_flag("ending_conquest"):
		p.append("[color=#ff8c1a]Demiurge hat seinen Zehnjahresplan zur Welteroberung auf sieben Jahre verkürzt. Er schreibt bereits an einem Hundertjahresplan.[/color]")
	if has_flag("tuare_saved"):
		p.append("[color=#dcdcdc]Sebas und Tuare spazieren abends durch die Gärten der Sechsten Ebene. Er hat sie nie um Erlaubnis gebeten. Ihr habt sie ihm nie verweigert.[/color]")
	if has_flag("lizard_mercy"):
		p.append("[color=#8ee6ff]Cocytus regiert die Sümpfe mit Ehre. Die Echsenmenschen nennen ihn ›Großvater‹. Er hat sie nie korrigiert.[/color]")
	if has_flag("elves_freed"):
		p.append("[color=#ffb52e]Aura und Mare besuchen den Ewigen Wald jeden Monat. Die Elfen dort verbeugen sich vor ihnen wie vor Prinzen. Mare stottert dabei immer noch.[/color]")
	if cs("pandora").unlocked:
		p.append("[color=#ffd23f]Pandora's Actor führt in der Schatzkammer jeden Abend ein Theaterstück über Eure Taten auf. Ihr habt es nie besucht. Er spielt trotzdem für Euch.[/color]")
	p.append("[i]Und irgendwo in Euch, unter all der Macht, erinnert sich ein Angestellter aus einer anderen Welt daran, dass er nur nicht allein sein wollte. Ihr seid es nicht mehr.[/i]")
	p.append("[color=#8f86a3]— ENDE der Hauptgeschichte. Ihr könnt weiterherrschen, so lange Ihr wollt. —[/color]")
	return "\n\n".join(p)


## Zusatz im Bericht, wenn ein Team unterwegs war.
func _partner_note(cid: String, partner: String) -> String:
	if partner == "":
		return ""
	var syn := World.synergy(cid, partner)
	var nm: String = char_name(partner).split(" ")[0]
	var line := "\n\n[color=#8fb8ff]⚔ Unterstützt von %s.[/color]" % nm
	if not syn.is_empty():
		line += " [color=#8f86a3]%s[/color]" % syn.text
	if "albedo" in [cid, partner] and "shalltear" in [cid, partner]:
		line += "\n[color=#ff7aa8][i]Auf dem Rückweg haben sich beide dreimal gestritten, wer von ihnen mehr geleistet hat.[/i][/color]"
	return line


## Baut den Berichtstext (BBCode) im Stil des Charakters zusammen.
func _compose_report(m: Dictionary, cid: String, directive: String, ordered: String, tier: String, deviation: String) -> String:
	var cd := Content.char_data(cid)
	var c := cs(cid)
	var voice: Dictionary = cd.voice
	var col: String = cd.get("color", "#ffffff")
	var parts := PackedStringArray()
	parts.append("[i]" + pick(voice.opening) + "[/i]")
	if deviation != "":
		parts.append("[color=#c79bff][b]✧ Eigenmächtige Auslegung:[/b][/color] " + deviation)
	elif ordered == "freie_hand":
		var style: Dictionary = cd.get("style", {})
		parts.append("[color=#c79bff][b]✧ %s:[/b][/color] %s" % [style.get("name", "Freie Hand"), pick(style.get("text"))])
	var outcome: String = m.get("char_outcomes", {}).get(cid, {}).get(tier, m.get("outcomes", {}).get(tier, ""))
	if outcome != "":
		parts.append(fmt(outcome))
	parts.append(pick(voice.get("tier", {}).get(tier)))

	# Emotionale Bemerkung – das Herzstück von Albedo & Shalltear
	var emo: Dictionary = cd.get("emotion", {})
	var rival: String = cd.get("rival", "")
	if not emo.is_empty():
		var line := ""
		if rival != "" and c.jealousy >= 55 and cs(rival).unlocked:
			line = pick(emo.get("jealous"))
		elif c.favor < 35:
			line = pick(emo.get("neglected"))
		elif rng.randf() < 0.85:
			line = pick(emo.get("love"))
		if line != "":
			parts.append("[color=%s]♥ %s[/color]" % [col, line])
	elif cd.has("personal") and rng.randf() < 0.5:
		parts.append("[color=%s]%s[/color]" % [col, pick(cd.personal)])

	# Ainz' innerer Monolog – der Running Gag der Serie
	var mono: Dictionary = Content.lord.get("inner_monologue", {})
	var key := "%s_%s" % [cid, "good" if tier in ["success", "triumph"] else "bad"]
	var pool: Variant = mono.get(key)
	if pool == null and rng.randf() < 0.3:
		pool = mono.get("generic")
	if pool != null and rng.randf() < 0.7:
		parts.append("[color=#8f86a3][i](%s denkt: %s)[/i][/color]" % [state.lord_name, pick(pool)])
	var clean := PackedStringArray()
	for p in parts:
		if p.strip_edges() != "" and p != "[i][/i]":
			clean.append(p)
	return "\n\n".join(clean)


func _report_options(cid: String, tier: String) -> Array:
	var cd := Content.char_data(cid)
	var reactions: Dictionary = cd.reactions
	var rival: String = cd.get("rival", "")
	var has_rival: bool = rival != "" and cs(rival).unlocked
	var rival_line := ""
	if has_rival:
		rival_line = "\n\n[color=#8f86a3]" + pick(Content.char_data(rival).emotion.get("watching")) + "[/color]"
	var failed := tier == "failure"

	var praise := {"chars": {cid: {"favor": 8, "mood": 4 if failed else 8}}}
	var reward := {"res": {"gold": -40}, "chars": {cid: {"favor": 15, "mood": 12}}}
	if has_rival:
		praise.chars[rival] = {"jealousy": 8}
		praise["rivalry"] = 2
		reward.chars[rival] = {"jealousy": 13}
		reward["rivalry"] = 3
	var silence := {}
	if cd.has("emotion"):
		silence = {"chars": {cid: {"favor": -3, "mood": -3}}}
	elif cid == "demiurge":
		silence = {"res": {"info": 1}}
	return [
		{"key": "praise", "label": "Lob aussprechen", "effects": praise,
			"reaction": pick(reactions.praise) + rival_line, "variant": "success"},
		{"key": "reward", "label": "Belohnen (−40 Gold)", "effects": reward,
			"reaction": pick(reactions.reward) + rival_line, "variant": "warning"},
		{"key": "rebuke", "label": "Tadeln", "variant": "danger",
			"effects": {"res": {"morale": 2 if failed else -2}, "chars": {cid: {"favor": -7, "mood": -8 if failed else -12}}},
			"reaction": pick(reactions.rebuke)},
		{"key": "silence", "label": "Schweigend nicken", "effects": silence,
			"reaction": pick(reactions.silence), "variant": "default"},
	]


func _maybe_proposal(cid: String, directive: String) -> void:
	var cd := Content.char_data(cid)
	var candidates: Array = []
	for mid in cd.get("proposals", []):
		if Content.missions.has(mid) and not mid in state.unlocked_missions \
				and not state.completed.has(mid) and check(Content.missions[mid].get("proposal_requires")):
			candidates.append(mid)
	if candidates.is_empty():
		return
	var chance := 0.22 + float(cd.stats.initiative) / 400.0 + (0.25 if directive == "freie_hand" else 0.0)
	if rng.randf() < chance:
		create_proposal(cid, candidates[rng.randi() % candidates.size()])


## Ein Untertan unterbreitet einen eigenen Plan (Vorschlags-Mission).
func create_proposal(cid: String, mid: String) -> void:
	var m := mission(mid)
	var reactions: Dictionary = Content.char_data(cid).reactions
	log_msg("%s unterbreitet einen eigenen Plan: »%s«." % [char_name(cid), m.title], "initiative")
	_push({
		"uid": next_uid("d"), "kind": "proposal", "char_id": cid, "day": state.day,
		"title": "Vorschlag · " + m.title,
		"body": fmt(m.get("proposal_text", m.description)),
		"options": [
			{"key": "approve", "label": "Genehmigen", "variant": "success",
				"effects": {"unlock_missions": [mid], "chars": {cid: {"favor": 6, "mood": 6}}},
				"reaction": pick(reactions.get("approve", reactions.praise))},
			{"key": "deny", "label": "Ablehnen", "variant": "danger",
				"effects": {"chars": {cid: {"favor": -4, "mood": -6}}},
				"reaction": pick(reactions.get("deny", reactions.rebuke))},
		],
		"context": {"mission": mid, "location": m.get("location", "")},
	})


# =====================================================================
#  Audienzen (persönliche Interaktion im Thronsaal)
# =====================================================================

## kind: "talk" | "gift" | "rebuke". Liefert {"ok", "text", "summary"}.
func audience(cid: String, kind: String) -> Dictionary:
	if audiences_left() <= 0:
		return {"ok": false, "text": "Für heute habt Ihr genug Audienzen gewährt."}
	if not is_available(cid):
		return {"ok": false, "text": "%s ist nicht im Thronsaal." % char_name(cid)}
	if kind == "gift" and state.resources.gold < 60:
		return {"ok": false, "text": "Die Schatzkammer gibt dafür nicht genug her."}
	if state.audiences_day != state.day:
		state.audiences_day = state.day
		state.audiences_used = 0
	state.audiences_used += 1
	var cd := Content.char_data(cid)
	var c := cs(cid)
	var rival: String = cd.get("rival", "")
	var has_rival: bool = rival != "" and cs(rival).unlocked
	var aud: Dictionary = cd.audience
	var text := ""
	var eff := {}
	match kind:
		"talk":
			text = pick(aud.jealous if (c.jealousy >= 60 and aud.has("jealous")) else aud.talk)
			eff = {"chars": {cid: {"favor": 6, "mood": 6, "jealousy": -6}}}
			if has_rival:
				eff.chars[rival] = {"jealousy": 6}
				eff["rivalry"] = 2
		"gift":
			text = pick(aud.gift)
			eff = {"res": {"gold": -60}, "chars": {cid: {"favor": 14, "mood": 10, "jealousy": -10}}}
			if has_rival:
				eff.chars[rival] = {"jealousy": 12}
				eff["rivalry"] = 4
			elif cd.get("female", false) and cid != "albedo":
				# Albedo registriert jede Gunst, die anderen Frauen zuteilwird.
				eff.chars["albedo"] = {"jealousy": 3}
		_:
			text = pick(aud.rebuke)
			eff = {"chars": {cid: {"favor": -8, "mood": -10}}}
	if has_rival and kind != "rebuke":
		text += "\n\n[color=#8f86a3]" + pick(Content.char_data(rival).emotion.get("watching")) + "[/color]"
	var summary := apply_effects(eff)
	Progress.bump("audiences")
	if kind == "gift":
		Progress.bump("gifts")
	if kind != "rebuke":
		Progress.add_xp(cid, 5)
	var labels := {"talk": "gewährt %s eine Audienz.", "gift": "überreicht %s ein Geschenk.", "rebuke": "weist %s zurecht."}
	log_msg(state.lord_name + " " + (labels[kind] % cd.name), "emotion")
	state_changed.emit()
	return {"ok": true, "text": text, "summary": summary}


# =====================================================================
#  Zeitfluss
# =====================================================================

## Lässt bis zu [param days] Tage vergehen. Stoppt, sobald Depeschen eintreffen.
func advance(days: int) -> Dictionary:
	if not state.dispatches.is_empty():
		return {"days": 0, "blocked": true}
	var passed := 0
	for i in days:
		_tick_day()
		passed += 1
		if not state.dispatches.is_empty():
			break
	state_changed.emit()
	if not state.dispatches.is_empty():
		dispatches_arrived.emit(state.dispatches.size())
	return {"days": passed, "blocked": false, "interrupted": passed < days}


func _tick_day() -> void:
	state.day += 1
	var due: Array = []
	for am in state.active:
		if am.end_day <= state.day:
			due.append(am)
	for am in due:
		_resolve_mission(am)
	_drift_emotions()
	World.tick_day()
	Military.tick_day()
	Diplomacy.tick_day()
	Progress.tick_day()
	var story_fired := _fire_story_events()
	_check_chapter_progress()
	if not story_fired:
		_roll_initiative()
		if rng.randf() < RANDOM_EVENT_CHANCE:
			_roll_random_event()


## Langsame Veränderung von Stimmung, Gunst, Eifersucht und Rivalität.
func _drift_emotions() -> void:
	for cid in unlocked_chars():
		var c := cs(cid)
		var cd := Content.char_data(cid)
		if c.status == STATUS_RECOVER and c.recover_until <= state.day:
			c.status = STATUS_READY
		if c.status in [STATUS_READY, STATUS_RECOVER]:
			c.fatigue = clampi(c.fatigue - (6 if c.status == STATUS_RECOVER else 4), 0, 100)
		var target: float = 35.0 + c.favor * 0.5 - c.fatigue * 0.2
		if c.mood < target - 1:
			c.mood = clampi(c.mood + 1, 0, 100)
		elif c.mood > target + 1:
			c.mood = clampi(c.mood - 1, 0, 100)
		# Albedo und Shalltear sehnen sich nach Aufmerksamkeit – ihre Gunst sinkt schneller.
		var decay_every := 3 if cd.has("emotion") else 8
		if state.day % decay_every == 0 and c.favor > 40:
			c.favor -= 1
		var rival: String = cd.get("rival", "")
		if rival != "" and cs(rival).unlocked:
			if cs(rival).favor > c.favor + 8:
				c.jealousy = clampi(c.jealousy + 2, 0, 100)
			else:
				c.jealousy = clampi(c.jealousy - 1, 0, 100)
	if state.chars.has("albedo") and state.chars.has("shalltear"):
		var total: int = cs("albedo").jealousy + cs("shalltear").jealousy
		if total > 110 and state.day % 2 == 0:
			state.rivalry = clampi(state.rivalry + 1, 0, 100)
		elif total < 70:
			state.rivalry = clampi(state.rivalry - 1, 0, 100)
	if state.day % 2 == 0:
		state.resources.attention = clampi(state.resources.attention - 1, 0, 100)
	var eff := efficiency()
	if state.resources.morale < eff - 3:
		state.resources.morale += 1
	elif state.resources.morale > eff + 8 and state.day % 2 == 0:
		state.resources.morale -= 1


func _fire_story_events() -> bool:
	var fired := false
	for ev in Content.events.values():
		if ev.get("type", "") != "story" or state.fired.has(ev.id):
			continue
		if check(ev.get("trigger")):
			queue_event(ev.id)
			fired = true
	return fired


func _on_cooldown(ev: Dictionary) -> bool:
	if not state.fired.has(ev.id):
		return false
	if ev.get("once", false):
		return true
	return state.day - int(state.fired[ev.id]) < int(ev.get("cooldown", 30))


func _weighted(pool: Array) -> Dictionary:
	var total := 0.0
	for e in pool:
		total += float(e.get("weight", 1))
	var r := rng.randf() * total
	for e in pool:
		r -= float(e.get("weight", 1))
		if r <= 0.0:
			return e
	return pool.back()


## Untätige Untertanen handeln auf eigene Faust – Vernachlässigte und Eifersüchtige häufiger.
func _roll_initiative() -> void:
	var idle: Array = []
	for cid in unlocked_chars():
		if is_available(cid):
			idle.append(cid)
	idle.shuffle()
	for cid in idle:
		var cd := Content.char_data(cid)
		var c := cs(cid)
		var p := float(cd.stats.initiative) / 100.0 * INITIATIVE_BASE
		if c.favor < 35 or c.jealousy > 60:
			p *= 1.8
		if rng.randf() >= p:
			continue
		var pool: Array = []
		for ini in Content.initiatives.values():
			if ini["char"] == cid and not _on_cooldown(ini) and check(ini.get("trigger")):
				pool.append(ini)
		if pool.is_empty():
			continue
		_fire_initiative(_weighted(pool))
		return


func _fire_initiative(ini: Dictionary) -> void:
	var cid: String = ini["char"]
	state.fired[ini.id] = state.day
	var summary := apply_effects(ini.get("effects"))
	log_msg("Eigeninitiative: %s – %s" % [char_name(cid), fmt(ini.title)], "initiative")
	var reactions: Dictionary = Content.char_data(cid).reactions
	var options: Array = []
	if ini.has("choices"):
		var i := 0
		for ch in ini.choices:
			options.append({"key": "c%d" % i, "label": fmt(ch.label), "effects": ch.get("effects", {}),
				"reaction": fmt(ch.get("reaction", "")), "variant": ch.get("variant", "default")})
			i += 1
	else:
		options = [
			{"key": "approve", "label": "Gutheißen", "variant": "success",
				"effects": {"chars": {cid: {"favor": 5, "mood": 5}}},
				"reaction": pick(reactions.get("approve", reactions.praise))},
			{"key": "deny", "label": "Missbilligen", "variant": "danger",
				"effects": {"chars": {cid: {"favor": -5, "mood": -8}}, "res": {"attention": -2}},
				"reaction": pick(reactions.get("deny", reactions.rebuke))},
			{"key": "ok", "label": "Zur Kenntnis nehmen", "variant": "default",
				"effects": {}, "reaction": pick(reactions.silence)},
		]
	_push({
		"uid": next_uid("d"), "kind": "initiative", "char_id": cid, "day": state.day,
		"title": "Eigeninitiative · " + fmt(ini.title), "body": fmt(ini.body), "options": options,
		"context": {"summary": summary, "event_id": ini.id},
	})
	if ini.has("unlock_proposal") and not ini.unlock_proposal in state.unlocked_missions:
		create_proposal(cid, ini.unlock_proposal)


func _roll_random_event() -> void:
	var pool: Array = []
	for ev in Content.events.values():
		if ev.get("type", "") in ["random", "rivalry"] and not _on_cooldown(ev) and check(ev.get("trigger")):
			pool.append(ev)
	if not pool.is_empty():
		queue_event(_weighted(pool).id)

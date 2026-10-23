extends Node
## Fortschrittssysteme, die zum Weiterspielen verleiten:
##  • Wächter-Ränge (Erfahrung → Rang I–X → Wertebonus)
##  • Artefakte mit Seltenheiten, Schatzkammer und Ausrüstung
##  • Ausbau der Ebenen Nazaricks (Bauschlange mit Dauer und Kosten)
##  • Albedos Wochenziele (drei wechselnde Ziele + Truhe + Serie)
##  • Errungenschaften mit Belohnungen
## Alle Daten liegen in data/progression.json, der Zustand in Game.state.progress.

## Feier-Popup im Thronsaal. kind: levelup | loot | achievement | build | weekly
signal celebrate(data: Dictionary)

const SLOTS := ["waffe", "ruestung", "schmuck"]
const SLOT_LABELS := {"waffe": "Waffe", "ruestung": "Rüstung", "schmuck": "Kleinod"}
const RARITY_ORDER := ["common", "rare", "epic", "legendary", "world"]
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

var data: Dictionary = {}
var items: Dictionary = {}
var rarities: Dictionary = {}
var floors: Array = []
var achievements: Array = []
## Während Simulationen/Ladevorgängen keine Popups.
var quiet := false


func _ready() -> void:
	var f := FileAccess.open("res://data/progression.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	for it in data.items:
		items[it.id] = it
	for r in data.rarities:
		rarities[r.id] = r
	floors = data.floors
	achievements = data.achievements


# =====================================================================
#  Zustand
# =====================================================================

func init_state(s: Dictionary) -> void:
	var xp := {}
	for cid in Content.character_order:
		xp[cid] = 0
	s["progress"] = {
		"xp": xp, "inventory": [], "equip": {}, "floors": {}, "build": {},
		"stats": {}, "week_start": {}, "week": -1, "goals": [], "streak": 0,
		"chest_claimed": false, "achievements": {}, "acc": {"info": 0.0},
	}
	_roll_week(s)


func normalize(s: Dictionary) -> void:
	if not s.has("progress"):
		init_state(s)
	var p: Dictionary = s.progress
	for cid in Content.character_order:
		p.xp[cid] = int(p.xp.get(cid, 0))
	for k in p.stats:
		p.stats[k] = int(p.stats[k])
	for k in p.week_start:
		p.week_start[k] = int(p.week_start[k])
	for k in p.floors:
		p.floors[k] = int(p.floors[k])
	for k in p.achievements:
		p.achievements[k] = int(p.achievements[k])
	for g in p.goals:
		g.target = int(g.target)
	p.week = int(p.week)
	p.streak = int(p.streak)
	if not p.build.is_empty():
		p.build.level = int(p.build.level)
		p.build.done_day = int(p.build.done_day)
		p.build.start_day = int(p.build.start_day)


func ps() -> Dictionary:
	return Game.state.progress


func stat(k: String) -> int:
	return int(ps().stats.get(k, 0))


## Zähler erhöhen – Grundlage für Wochenziele und Errungenschaften.
func bump(k: String, n: int = 1) -> void:
	if n <= 0 or not Game.state.has("progress"):
		return
	ps().stats[k] = stat(k) + n
	_check_achievements()


func set_max(k: String, v: int) -> void:
	if v > stat(k):
		ps().stats[k] = v
		_check_achievements()


func _emit(d: Dictionary) -> void:
	if not quiet:
		celebrate.emit(d)


# =====================================================================
#  Ränge & Erfahrung
# =====================================================================

func xp(cid: String) -> int:
	return int(ps().xp.get(cid, 0))


func rank(cid: String) -> int:
	var x := xp(cid)
	var r := 1
	var th: Array = data.ranks.xp
	for i in th.size():
		if x >= int(th[i]):
			r = i + 1
	return r


func rank_title(cid: String) -> String:
	var r := rank(cid)
	return "Rang %s · %s" % [ROMAN[r - 1], data.ranks.titles[r - 1]]


## [aktuelles XP im Rang, benötigt für nächsten Rang] – benötigt 0 = Höchstrang.
func rank_progress(cid: String) -> Array:
	var r := rank(cid)
	var th: Array = data.ranks.xp
	if r >= th.size():
		return [1, 0]
	var lo := int(th[r - 1])
	return [xp(cid) - lo, int(th[r]) - lo]


func add_xp(cid: String, amount: int) -> void:
	if amount <= 0 or not Game.state.chars.has(cid):
		return
	amount = roundi(amount * (1.0 + floor_value("xp") + item_effect(cid, "xp")))
	var before := rank(cid)
	ps().xp[cid] = xp(cid) + amount
	bump("xp_earned", amount)
	var after := rank(cid)
	if after > before:
		bump("levelups", after - before)
		set_max("max_rank", after)
		Game.apply_effects({"chars": {cid: {"favor": 4, "mood": 8}}})
		Game.log_msg("%s steigt auf: %s!" % [Game.char_name(cid), rank_title(cid)], "story")
		_emit({"kind": "levelup", "char": cid, "title": "RANGAUFSTIEG",
			"text": "%s\n%s" % [Game.char_name(cid), rank_title(cid)],
			"sub": "Alle Werte +%s" % _fmt_num(stat_rank_bonus(after) - stat_rank_bonus(before)),
			"color": Palette.GOLD_BRIGHT})


func stat_rank_bonus(r: int) -> float:
	return float(data.ranks.stat_per_rank) * (r - 1)


## Wertebonus durch Rang und Ausrüstung.
func stat_bonus(cid: String, k: String) -> float:
	if not Game.state.has("progress"):
		return 0.0
	var b := stat_rank_bonus(rank(cid))
	for it in equipped_items(cid):
		b += float(it.stats.get(k, 0))
		if it.get("fav", "") == cid:
			b += float(it.stats.get(k, 0)) * 0.5
	return b


func eff_stat(cid: String, k: String) -> int:
	return roundi(float(Content.char_data(cid).stats.get(k, 0)) + stat_bonus(cid, k))


func mission_xp(tier: String, m: Dictionary) -> int:
	var base := float(data.ranks.xp_mission.get(tier, 10))
	var mult := 0.6 + float(m.get("difficulty", 50)) / 100.0
	if m.get("main", false):
		mult += 0.4
	return roundi(base * mult)


# =====================================================================
#  Artefakte & Schatzkammer
# =====================================================================

func item_def(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func rarity(rid: String) -> Dictionary:
	return rarities.get(rid, rarities.common)


func rarity_color(rid: String) -> Color:
	return Color(rarity(rid).color)


func inventory() -> Array:
	return ps().inventory


func inv_entry(uid: String) -> Dictionary:
	for e in inventory():
		if e.uid == uid:
			return e
	return {}


func equipped_items(cid: String) -> Array:
	var res: Array = []
	var eq: Dictionary = ps().equip.get(cid, {})
	for slot in eq:
		var e := inv_entry(eq[slot])
		if not e.is_empty():
			res.append(item_def(e.id))
	return res


func item_effect(cid: String, k: String) -> float:
	var v := 0.0
	for it in equipped_items(cid):
		v += float(it.get("effects", {}).get(k, 0))
	return v


func owner_of(uid: String) -> String:
	for cid in ps().equip:
		for slot in ps().equip[cid]:
			if ps().equip[cid][slot] == uid:
				return cid
	return ""


## Zieht eine Seltenheit (mindestens min_rarity) und ein passendes Artefakt.
func roll_item(min_rarity: String = "common", bonus: float = 0.0) -> String:
	var min_i := RARITY_ORDER.find(min_rarity)
	var pool: Array = []
	var total := 0.0
	for r in data.rarities:
		var i := RARITY_ORDER.find(r.id)
		if i < min_i:
			continue
		# Bonus verschiebt Gewicht zu seltenen Stufen
		var w := float(r.weight) * (1.0 + bonus * i * 2.0)
		pool.append([r.id, w])
		total += w
	var roll := Game.rng.randf() * total
	var rid: String = pool[0][0]
	for p in pool:
		roll -= p[1]
		if roll <= 0:
			rid = p[0]
			break
	var cands: Array = []
	for it in data.items:
		if it.rarity == rid and Game.check(it.get("requires", {})):
			cands.append(it.id)
	if cands.is_empty():
		for it in data.items:
			if it.rarity == rid:
				cands.append(it.id)
	return cands[Game.rng.randi() % cands.size()]


## Fügt ein Artefakt hinzu, feiert den Fund. Liefert die Inventar-UID.
func grant_item(item_id: String, source: String = "") -> String:
	var it := item_def(item_id)
	if it.is_empty():
		return ""
	var uid := Game.next_uid("it")
	inventory().append({"uid": uid, "id": item_id, "day": Game.state.day, "source": source})
	bump("items_found")
	if it.rarity == "legendary":
		bump("legendary_found")
	elif it.rarity == "world":
		bump("world_found")
	var r := rarity(it.rarity)
	Game.log_msg("Fund für die Schatzkammer: %s (%s)%s." % [it.name, r.name, "" if source == "" else " – " + source], "mission")
	_emit({"kind": "loot", "item": item_id, "title": r.name.to_upper() + "ER FUND" if it.rarity != "world" else "WELTGEGENSTAND!",
		"text": it.name, "sub": source, "color": Color(r.color), "rarity": it.rarity})
	return uid


## Beute-Wurf nach Ergebnis (triumph/success/partial/battle/threat).
func roll_loot(kind: String, source: String = "", cid: String = "") -> String:
	var chance := float(data.loot_chance.get(kind, 0.0))
	if chance <= 0.0:
		return ""
	var bonus := floor_value("loot") + (item_effect(cid, "loot") if cid != "" else 0.0)
	if Game.rng.randf() < chance + bonus:
		return grant_item(roll_item("common", bonus + (0.15 if kind == "triumph" else 0.0)), source)
	return ""


func equip(cid: String, uid: String) -> void:
	var e := inv_entry(uid)
	if e.is_empty():
		return
	var slot: String = item_def(e.id).slot
	var prev := owner_of(uid)
	if prev != "":
		ps().equip[prev].erase(slot)
	if not ps().equip.has(cid):
		ps().equip[cid] = {}
	ps().equip[cid][slot] = uid
	if ps().equip[cid].size() >= 3:
		set_max("full_equip", 1)
	var fav: bool = item_def(e.id).get("fav", "") == cid
	Game.apply_effects({"chars": {cid: {"mood": 4 if fav else 2, "favor": 3 if fav else 1}}})
	Game.state_changed.emit()


func unequip(cid: String, slot: String) -> void:
	if ps().equip.has(cid):
		ps().equip[cid].erase(slot)
	Game.state_changed.emit()


## Einschmelzen: Artefakt gegen Gold.
func sell(uid: String) -> int:
	var e := inv_entry(uid)
	if e.is_empty():
		return 0
	var o := owner_of(uid)
	if o != "":
		unequip(o, item_def(e.id).slot)
	inventory().erase(e)
	var g := int(rarity(item_def(e.id).rarity).sell)
	Game.apply_effects({"res": {"gold": g}})
	Game.state_changed.emit()
	return g


## Bestes freies Artefakt für einen Platz automatisch anlegen.
func auto_equip(cid: String) -> void:
	for slot in SLOTS:
		var best := ""
		var best_v := -1.0
		var cur: String = ps().equip.get(cid, {}).get(slot, "")
		if cur != "":
			best_v = _item_value(item_def(inv_entry(cur).id), cid)
			best = cur
		for e in inventory():
			var it := item_def(e.id)
			if it.slot != slot or (owner_of(e.uid) != "" and e.uid != cur):
				continue
			var v := _item_value(it, cid)
			if v > best_v:
				best_v = v
				best = e.uid
		if best != "" and best != cur:
			equip(cid, best)


func _item_value(it: Dictionary, cid: String) -> float:
	var v := 0.0
	var st: Dictionary = Content.char_data(cid).stats
	for k in it.stats:
		v += float(it.stats[k]) * (0.5 + float(st.get(k, 50)) / 100.0)
	if it.get("fav", "") == cid:
		v *= 1.5
	return v + RARITY_ORDER.find(it.rarity) * 2


# =====================================================================
#  Ausbau Nazaricks
# =====================================================================

func floor_def(fid: String) -> Dictionary:
	for f in floors:
		if f.id == fid:
			return f
	return {}


func floor_level(fid: String) -> int:
	return int(ps().floors.get(fid, 0))


## Summe der Wirkungen aller Ebenen für einen Effekt (upkeep, army, xp …).
func floor_value(effect: String) -> float:
	if not Game.state.has("progress"):
		return 0.0
	var v := 0.0
	for f in floors:
		if f.effect == effect:
			v += float(f.per_level) * floor_level(f.id)
	return v


func floor_label(f: Dictionary, level: int) -> String:
	var v := float(f.per_level) * level
	if f.effect in ["upkeep", "defense", "army", "xp", "loot"]:
		return f.label % roundi(v * 100)
	if f.effect == "info":
		return f.label % v
	return f.label % roundi(v)


func can_build(fid: String) -> Array:
	var f := floor_def(fid)
	var lvl := floor_level(fid)
	if lvl >= f.costs.size():
		return [false, "Höchste Stufe erreicht"]
	if not ps().build.is_empty():
		return [false, "Die Baumeister sind beschäftigt"]
	if not Game.check(f.get("requires", {})):
		return [false, "Noch nicht verfügbar (Kapitel %d)" % int(f.requires.get("chapter_min", 1))]
	var cost := build_cost(fid)
	if Game.state.resources.gold < cost:
		return [false, "Zu wenig Gold (%d)" % cost]
	return [true, ""]


func build_cost(fid: String) -> int:
	var f := floor_def(fid)
	var lvl := floor_level(fid)
	if lvl >= f.costs.size():
		return 0
	return roundi(float(f.costs[lvl]) * Game.diff("upkeep"))


func build_days(fid: String) -> int:
	var f := floor_def(fid)
	return int(f.days[mini(floor_level(fid), f.days.size() - 1)])


func start_build(fid: String) -> Dictionary:
	var ok := can_build(fid)
	if not ok[0]:
		return {"ok": false, "text": ok[1]}
	var f := floor_def(fid)
	var cost := build_cost(fid)
	var days := build_days(fid)
	Game.apply_effects({"res": {"gold": -cost}})
	ps().build = {"id": fid, "level": floor_level(fid) + 1, "start_day": Game.state.day, "done_day": Game.state.day + days}
	Game.log_msg("Ausbau begonnen: %s, Stufe %d (%d Tage)." % [f.name, floor_level(fid) + 1, days], "mission")
	Game.state_changed.emit()
	return {"ok": true, "text": "Die Arbeiten an %s beginnen. Fertig in %d Tagen." % [f.name, days]}


func build_progress() -> float:
	var b: Dictionary = ps().build
	if b.is_empty():
		return 0.0
	return clampf(float(Game.state.day - b.start_day) / maxf(1.0, b.done_day - b.start_day), 0.0, 1.0)


func _finish_build() -> void:
	var b: Dictionary = ps().build
	var f := floor_def(b.id)
	ps().floors[b.id] = int(b.level)
	ps().build = {}
	bump("builds_done")
	if int(b.level) >= f.costs.size():
		set_max("floor_max", 1)
	var keeper: String = f.get("keeper", "")
	if keeper != "" and Game.state.chars.has(keeper) and Game.cs(keeper).unlocked:
		Game.apply_effects({"chars": {keeper: {"mood": 8, "favor": 5}}})
	Game.log_msg("Ausbau vollendet: %s erreicht Stufe %d. %s." % [f.name, int(b.level), floor_label(f, int(b.level))], "story")
	_emit({"kind": "build", "title": "AUSBAU VOLLENDET", "text": "%s · Stufe %d" % [f.name, int(b.level)],
		"sub": floor_label(f, int(b.level)), "color": Palette.VIOLET_GLOW})


# =====================================================================
#  Albedos Wochenziele
# =====================================================================

func week_index() -> int:
	return (int(Game.state.day) - 1) / 7


func week_days_left() -> int:
	return 7 - (int(Game.state.day) - 1) % 7


func _roll_week(s: Dictionary) -> void:
	var p: Dictionary = s.progress
	var templates: Array = []
	for t in data.weekly:
		if _check_on(s, t.get("requires", {})):
			templates.append(t)
	templates.shuffle()
	var goals: Array = []
	var scale := 1.0 + mini(int(s.chapter), 10) * 0.08
	for t in templates.slice(0, 3):
		var step := int(t.get("step", 1))
		var lo := int(t.min)
		var hi := int(t.max)
		var target := lo + (Game.rng.randi() % ((hi - lo) / step + 1)) * step
		if step > 1:
			target = roundi(target * scale / step) * step
		goals.append({"id": t.id, "stat": t.stat, "target": target, "text": t.text % target, "reward": t.reward, "claimed": false})
	p.goals = goals
	p.week = (int(s.day) - 1) / 7
	p.week_start = p.stats.duplicate()
	p.chest_claimed = false


func _check_on(s: Dictionary, req: Dictionary) -> bool:
	return int(s.get("chapter", 1)) >= int(req.get("chapter_min", 1))


func goal_value(g: Dictionary) -> int:
	return stat(g.stat) - int(ps().week_start.get(g.stat, 0))


func goal_done(g: Dictionary) -> bool:
	return goal_value(g) >= int(g.target)


func goals_all_done() -> bool:
	for g in ps().goals:
		if not goal_done(g):
			return false
	return not ps().goals.is_empty()


## Belohnung eines erfüllten Wochenziels einfordern.
func claim_goal(i: int) -> Array:
	var g: Dictionary = ps().goals[i]
	if g.claimed or not goal_done(g):
		return []
	g.claimed = true
	var summary := Game.apply_effects({"res": g.reward})
	Game.state_changed.emit()
	return summary


func can_claim_chest() -> bool:
	return goals_all_done() and not ps().chest_claimed


## Albedos Truhe: Gold (+ Serienbonus) und ein garantiert seltenes Artefakt.
func claim_chest() -> Dictionary:
	if not can_claim_chest():
		return {}
	for i in ps().goals.size():
		claim_goal(i)
	ps().chest_claimed = true
	var cfg: Dictionary = data.weekly_chest
	ps().streak = int(ps().streak) + 1
	set_max("best_streak", ps().streak)
	bump("weeks_done")
	var streak_mult := 1.0 + float(cfg.streak_bonus) * mini(ps().streak - 1, int(cfg.streak_max))
	var gold := roundi(float(cfg.gold) * streak_mult * (1.0 + Game.state.chapter * 0.1))
	Game.apply_effects({"res": {"gold": gold}, "chars": {"albedo": {"favor": 3, "mood": 5}}})
	var min_r: String = "epic" if ps().streak >= 4 else cfg.min_rarity
	var uid := grant_item(roll_item(min_r, 0.05 * ps().streak), "Albedos Truhe")
	Game.state_changed.emit()
	return {"gold": gold, "item": inv_entry(uid).get("id", ""), "streak": ps().streak}


func _tick_week() -> void:
	if week_index() == int(ps().week):
		return
	# Nicht eingeforderte, aber erfüllte Ziele werden gutgeschrieben – eine Serie aber nur mit Truhe.
	if goals_all_done() and not ps().chest_claimed:
		quiet = true
		claim_chest()
		quiet = false
	elif not ps().chest_claimed:
		for i in ps().goals.size():
			claim_goal(i)
		ps().streak = 0
	_roll_week(Game.state)
	if not quiet:
		Game.log_msg("Albedo legt Euch die Ziele der neuen Woche vor.", "initiative")


# =====================================================================
#  Errungenschaften
# =====================================================================

func achievement_done(aid: String) -> bool:
	return ps().achievements.has(aid)


func achievement_progress(a: Dictionary) -> Array:
	if a.has("stat"):
		return [mini(stat(a.stat), int(a.target)), int(a.target)]
	return [1 if achievement_done(a.id) else 0, 1]


func _ach_met(a: Dictionary) -> bool:
	if a.has("stat"):
		return stat(a.stat) >= int(a.target)
	var c: Dictionary = a.get("cond", {})
	if c.has("chapter_min") and int(Game.state.chapter) < int(c.chapter_min):
		return false
	if c.has("day_min") and int(Game.state.day) < int(c.day_min):
		return false
	for cid in c.get("favor_min", {}):
		if Game.cs(cid).favor < int(c.favor_min[cid]):
			return false
	for f in c.get("flags", []):
		if not Game.has_flag(f):
			return false
	return true


func _check_achievements() -> void:
	if not Game.state.has("progress"):
		return
	for a in achievements:
		if achievement_done(a.id) or not _ach_met(a):
			continue
		ps().achievements[a.id] = int(Game.state.day)
		var rw: Dictionary = a.get("reward", {})
		var res := rw.duplicate()
		res.erase("item")
		if not res.is_empty():
			Game.apply_effects({"res": res})
		Game.log_msg("Errungenschaft: %s" % a.name, "story")
		_emit({"kind": "achievement", "title": "ERRUNGENSCHAFT", "text": a.name, "sub": a.desc,
			"color": tier_color(a.get("tier", "bronze")), "icon": a.icon})
		if rw.has("item"):
			grant_item(roll_item(rw.item), "Errungenschaft »%s«" % a.name)


func tier_color(t: String) -> Color:
	return {"bronze": Color("d08a4a"), "silver": Color("d8dce8"), "gold": Palette.GOLD_BRIGHT, "platinum": Color("b8f0ff")}.get(t, Palette.GOLD)


func reward_text(rw: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in rw:
		if k == "item":
			parts.append("%s Artefakt" % rarity(rw.item).name)
		else:
			parts.append("%+d %s" % [int(rw[k]), Game.RESOURCE_LABELS.get(k, k)])
	return ", ".join(parts)


# =====================================================================
#  Tageslauf
# =====================================================================

func tick_day() -> void:
	var p := ps()
	if not p.build.is_empty() and Game.state.day >= int(p.build.done_day):
		_finish_build()
	var info := floor_value("info")
	if info > 0.0:
		p.acc.info = float(p.acc.get("info", 0.0)) + info
		var whole := int(p.acc.info)
		if whole > 0:
			p.acc.info = float(p.acc.info) - whole
			Game.apply_effects({"res": {"info": whole}})
	var att := roundi(floor_value("attention"))
	if att > 0 and Game.state.day % 4 == 0:
		Game.apply_effects({"res": {"attention": -att}})
	if floor_level("royal") > 0 and Game.state.day % 3 == 0:
		var eff := {}
		for cid in Game.unlocked_chars():
			eff[cid] = {"mood": floor_level("royal")}
		Game.apply_effects({"chars": eff})
	_tick_week()
	_check_achievements()


## Gold pro Tag aus der Golemschmiede.
func daily_gold() -> float:
	return floor_value("gold")


# =====================================================================
#  Hilfen für die Anzeige
# =====================================================================

## Kurze Liste für die Thronsaal-Hinweiszeile: was steht als Nächstes an?
func upcoming() -> PackedStringArray:
	var out := PackedStringArray()
	var b: Dictionary = ps().build
	if not b.is_empty():
		out.append("⚒ %s in %d T." % [floor_def(b.id).name, maxi(0, int(b.done_day) - Game.state.day)])
	var done := 0
	for g in ps().goals:
		if goal_done(g):
			done += 1
	out.append("❤ Wochenziele %d/%d · noch %d T." % [done, ps().goals.size(), week_days_left()])
	return out


func _fmt_num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


# =====================================================================
#  Ainz im Kampf: Seelen, Zauberbuch, Ringe (data/grimoire.json)
# =====================================================================

signal souls_changed(total: int, gained: int)
signal grimoire_changed

var grimoire: Dictionary = {}
var ring_defs: Dictionary = {}


## Einstellungen des Zauberbuchs (data/grimoire.json).
func gcfg() -> Dictionary:
	_load_grimoire()
	return grimoire


func _load_grimoire() -> void:
	if not grimoire.is_empty():
		return
	var f := FileAccess.open("res://data/grimoire.json", FileAccess.READ)
	if f:
		grimoire = JSON.parse_string(f.get_as_text())
	for r in grimoire.get("rings", []):
		ring_defs[r.id] = r


## Zustand des Zauberbuchs (wird bei alten Spielständen ergänzt).
func gs() -> Dictionary:
	_load_grimoire()
	var p := ps()
	if not p.has("grimoire"):
		p["grimoire"] = {"souls": 0, "souls_total": 0, "ranks": {}, "unlocked": [], "loadout": {}, "rings": [], "ring_slots": ["", "", ""], "story_rewards": []}
	var g: Dictionary = p.grimoire
	g.souls = int(g.souls)
	g.souls_total = int(g.souls_total)
	for k in g.ranks:
		g.ranks[k] = int(g.ranks[k])
	while (g.ring_slots as Array).size() < 3:
		g.ring_slots.append("")
	return g


func souls() -> int:
	return int(gs().souls) if Game.state.has("progress") else 0


## Seelen eines besiegten Gegners (nach Stärke; Beschworene geben wenig).
func souls_for(e_data: Dictionary, summoned: bool = false) -> int:
	_load_grimoire()
	var c: Dictionary = grimoire.get("souls", {})
	var n := float(e_data.get("hp", 50)) * float(c.get("per_hp", 0.04))
	if e_data.get("boss", false):
		n = n * float(c.get("boss_mult", 1.5)) + float(c.get("boss_bonus", 40))
	elif e_data.get("elite", false):
		n = n * float(c.get("elite_mult", 2.0)) + float(c.get("elite_bonus", 8))
	if summoned:
		n *= float(c.get("summoned_mult", 0.25))
	return maxi(int(c.get("min", 1)), roundi(n * (1.0 + ring_effect("souls"))))


func add_souls(n: int) -> void:
	if n <= 0 or not Game.state.has("progress"):
		return
	var g := gs()
	g.souls = int(g.souls) + n
	g.souls_total = int(g.souls_total) + n
	set_max("souls_total", int(g.souls_total))
	souls_changed.emit(int(g.souls), n)


func spend_souls(n: int) -> bool:
	var g := gs()
	if int(g.souls) < n:
		return false
	g.souls = int(g.souls) - n
	souls_changed.emit(int(g.souls), -n)
	return true


# ------------------------------------------------------------------ Zauber

## Alle Zauber eines Kampfstils im Zauberbuch (bekannte und erlernbare).
func style_spells(style: String) -> Array:
	_load_grimoire()
	return grimoire.get("styles", {}).get(style, [])


func spell_entry(id: String) -> Dictionary:
	_load_grimoire()
	return grimoire.get("spells", {}).get(id, {})


func spell_known(id: String) -> bool:
	return int(spell_entry(id).get("unlock", 0)) <= 0 or id in gs().unlocked


func spell_rank(id: String) -> int:
	return clampi(int(gs().ranks.get(id, 1)), 1, 3)


func upgrade_cost(id: String) -> int:
	var r := spell_rank(id)
	return int(grimoire.get("rank_cost", {}).get(str(r + 1), 0)) if r < 3 else 0


## Erlernen: [möglich, Grund]
func can_unlock(id: String) -> Array:
	var e := spell_entry(id)
	if spell_known(id):
		return [false, "bereits bekannt"]
	if not Game.check(e.get("requires", {})):
		return [false, "ab Kapitel %d" % int(e.get("requires", {}).get("chapter_min", 1))]
	if souls() < int(e.get("unlock", 0)):
		return [false, "%d Seelen nötig" % int(e.get("unlock", 0))]
	return [true, ""]


func unlock_spell(id: String) -> bool:
	if not can_unlock(id)[0] or not spend_souls(int(spell_entry(id).get("unlock", 0))):
		return false
	gs().unlocked.append(id)
	bump("spells_learned")
	var sp: Dictionary = Content.combat.spells.get(id, {})
	_emit({"kind": "achievement", "title": "NEUER ZAUBER", "text": String(sp.get("name", id)), "sub": "Im Zauberbuch erlernt", "icon": String(sp.get("icon", "✦")), "color": Color(sp.get("color", "#c37bff"))})
	grimoire_changed.emit()
	Game.state_changed.emit()
	return true


func upgrade_spell(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost <= 0 or not spell_known(id) or not spend_souls(cost):
		return false
	var r := spell_rank(id) + 1
	gs().ranks[id] = r
	if r >= 3:
		bump("spells_mastered")
	var sp: Dictionary = Content.combat.spells.get(id, {})
	_emit({"kind": "achievement", "title": "ZAUBER AUFGEWERTET", "text": "%s – Rang %s" % [String(sp.get("name", id)), ROMAN[r - 1]],
		"sub": String(spell_entry(id).get("ranks", {}).get(str(r), {}).get("text", "")), "icon": String(sp.get("icon", "✦")), "color": Color(sp.get("color", "#c37bff"))})
	grimoire_changed.emit()
	Game.state_changed.emit()
	return true


## Zauberleiste eines Stils (6 Tasten: 1–5, R). Ohne eigene Belegung: die Grundzauber des Stils.
func loadout(style: String, base: Array) -> Array:
	var lo: Array = gs().loadout.get(style, [])
	if lo.is_empty():
		lo = base.duplicate()
	var out: Array = []
	for i in 6:
		var id: String = String(lo[i]) if i < lo.size() else ""
		out.append(id if id != "" and Content.combat.spells.has(id) and spell_known(id) else "")
	return out


func set_loadout(style: String, base: Array, slot: int, id: String) -> void:
	var lo := loadout(style, base)
	var old := lo.find(id)
	if old >= 0 and id != "":
		lo[old] = lo[slot]                 # Tausch, wenn der Zauber schon auf einer anderen Taste liegt
	lo[slot] = id
	gs().loadout[style] = lo
	grimoire_changed.emit()


## Wirksame Werte eines Zaubers: Rang (Schaden, Abklingzeit, Kosten, Sonderwirkung) und Ringe.
func effective_spell(id: String) -> Dictionary:
	var sp: Dictionary = Content.combat.spells.get(id, {}).duplicate(true)
	if sp.is_empty():
		return sp
	if not Game.state.has("progress"):
		sp["rank"] = 1
		return sp
	var r := spell_rank(id)
	var m: Dictionary = grimoire.get("rank_mult", {})
	if sp.has("damage"):
		sp.damage = float(sp.damage) * float(m.get("damage", [1, 1, 1])[r - 1])
	sp.cooldown = float(sp.get("cooldown", 1.0)) * float(m.get("cooldown", [1, 1, 1])[r - 1])
	sp.cost = float(sp.get("cost", 0)) * float(m.get("cost", [1, 1, 1])[r - 1])
	for k in range(2, r + 1):
		var ov: Dictionary = spell_entry(id).get("ranks", {}).get(str(k), {})
		for key in ov:
			if key != "text":
				sp[key] = ov[key]
	# Ringe: Schaden je Art, Abklingzeiten
	if sp.has("damage"):
		var t := String(sp.get("type", "physical"))
		sp.damage = float(sp.damage) * (1.0 + ring_effect("dmg_all") + ring_effect("dmg_" + t) + (ring_effect("dmg_melee") if sp.get("cost_type", "") == "stamina" else 0.0))
	sp.cooldown = float(sp.cooldown) * (1.0 - clampf(ring_effect("cdr"), 0.0, 0.5))
	sp["rank"] = r
	return sp


# ------------------------------------------------------------------ Ringe

func ring_def(rid: String) -> Dictionary:
	_load_grimoire()
	return ring_defs.get(rid, {})


func rings() -> Array:
	return gs().rings


func ring_entry(uid: String) -> Dictionary:
	for e in rings():
		if e.uid == uid:
			return e
	return {}


func owns_ring(rid: String) -> bool:
	for e in rings():
		if e.id == rid:
			return true
	return false


func grant_ring(rid: String, source: String = "") -> String:
	var d := ring_def(rid)
	if d.is_empty() or (d.get("unique", false) and owns_ring(rid)):
		return ""
	var uid := Game.next_uid("rg")
	rings().append({"uid": uid, "id": rid, "day": Game.state.day, "source": source})
	bump("rings_found")
	var r := rarity(String(d.rarity))
	Game.log_msg("Ring für Ainz: %s (%s)%s." % [d.name, r.name, "" if source == "" else " – " + source], "mission")
	_emit({"kind": "ring", "title": ("EINZIGARTIGER RING" if d.get("unique", false) else String(r.name).to_upper() + "ER RING"), "unique": d.get("unique", false),
		"text": String(d.name), "sub": ring_text(d), "color": Color(r.color), "rarity": String(d.rarity), "icon": String(d.get("icon", "◍"))})
	# Freier Platz? Dann gleich anstecken.
	var slots: Array = gs().ring_slots
	var free := slots.find("")
	if free >= 0:
		slots[free] = uid
	grimoire_changed.emit()
	return uid


## Zufallsring (Gewichtung wie Artefakte), keine einzigartigen.
func roll_ring() -> String:
	_load_grimoire()
	var pool: Array = []
	var total := 0.0
	for d in grimoire.get("rings", []):
		if d.get("unique", false):
			continue
		var w := float(rarity(String(d.rarity)).get("weight", 10))
		pool.append([d.id, w])
		total += w
	var roll := Game.rng.randf() * total
	for p in pool:
		roll -= p[1]
		if roll <= 0:
			return p[0]
	return pool[0][0] if not pool.is_empty() else ""


func equip_ring(uid: String, slot: int) -> void:
	var slots: Array = gs().ring_slots
	var old := slots.find(uid)
	if old >= 0:
		slots[old] = slots[slot]
	slots[slot] = uid
	grimoire_changed.emit()


func unequip_ring(slot: int) -> void:
	gs().ring_slots[slot] = ""
	grimoire_changed.emit()


## Ring einschmelzen (nicht angesteckt, nicht einzigartig) → Seelen.
func melt_ring(uid: String) -> int:
	var e := ring_entry(uid)
	var d := ring_def(String(e.get("id", "")))
	if e.is_empty() or d.get("unique", false) or uid in gs().ring_slots:
		return 0
	rings().erase(e)
	var n := int(grimoire.get("ring_melt", {}).get(String(d.rarity), 20))
	add_souls(n)
	grimoire_changed.emit()
	return n


## Summe einer Ringwirkung über die angesteckten Ringe.
func ring_effect(k: String) -> float:
	if not Game.state.has("progress"):
		return 0.0
	var v := 0.0
	for uid in gs().ring_slots:
		if String(uid) == "":
			continue
		v += float(ring_def(String(ring_entry(String(uid)).get("id", ""))).get("effects", {}).get(k, 0.0))
	return v


func ring_text(d: Dictionary) -> String:
	_load_grimoire()
	var labels: Dictionary = grimoire.get("ring_effects", {})
	var parts := PackedStringArray()
	for k in d.get("effects", {}):
		var v := float(d.effects[k])
		var shown := roundi(v * 100.0) if absf(v) < 1.0 else roundi(v)
		parts.append(String(labels.get(k, k + " %+d")) % shown)
	return " · ".join(parts)


## Belohnung eines Story-Einsatzes: Seelen und der einzigartige Ring (nur beim ersten Mal).
func story_reward(mid: String) -> void:
	_load_grimoire()
	var g := gs()
	if mid in g.story_rewards:
		return
	g.story_rewards.append(mid)
	add_souls(int(grimoire.get("souls", {}).get("story_reward", 150)))
	var rid := String(grimoire.get("story_rings", {}).get(mid, ""))
	if rid != "":
		grant_ring(rid, "Kapitel-Moment")

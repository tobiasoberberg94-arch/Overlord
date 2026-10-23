class_name QuestWorld
extends Node
## Bindet das Questsystem (Quests-Autoload) an die 3D-Welt: Questgeber-NPCs und ihre Markierungen,
## Sammelstellen, Truhen und Einzigartiges, Gegner-Beute, Gespräche, Anschlagtafeln.
## Gehört zu world_3d.gd (w); wird je Ort neu befüllt.

const RESPAWN_DAYS := {"chest": 7}
const MATERIAL_RESPAWN := 3
## Feste Fundorte einzigartiger Gegenstände (Godot-Koordinaten), sonst Zufallsplatz
const UNIQUE_POS := {"goblin_horn": Vector3(-31.0, 0.0, -21.0)}

var w: Node
var pickups: Array[Pickup] = []


func _init(world: Node) -> void:
	w = world
	name = "QuestWorld"


func _ready() -> void:
	Quests.completed.connect(_on_completed)
	Quests.step_done.connect(_on_step_done)
	Quests.changed.connect(refresh_marks)


func clear() -> void:
	pickups.clear()


# ------------------------------------------------------------------ Aufbau je Ort

## Questgeber, die hier stehen (nach data/quests.json → givers).
func spawn_givers(slots: Array) -> void:
	for gid in Quests.data.get("givers", {}):
		var g: Dictionary = Quests.data.givers[gid]
		if g.get("loc", "") != w.loc.id or g.get("keeper", false):
			continue
		var pos: Vector3
		var si := int(g.get("slot", 0))
		if si < slots.size():
			pos = slots[si]
		else:
			pos = w.anchors.spawn + Vector3(randf_range(-6, 6), 0, randf_range(-12, -4))
		var a := Actor3D.character(gid, "", 2.25)
		a.prompt = "Sprechen"
		a.wander_radius = 0.0 if w.loc.get("group", "") == "interior" else 2.0
		w._add_actor(a, pos)
	refresh_marks()


## Sammelstellen/Truhen auf festen (je Ort gleichen) Plätzen, sobald die Kollision bereitsteht.
func spawn_pickups() -> void:
	await w.get_tree().physics_frame
	await w.get_tree().physics_frame
	if not is_instance_valid(w.level):
		return
	var lid: String = w.loc.id
	var list: Array = Quests.data.get("pickups", {}).get(lid, [])
	var total := 0
	for e in list:
		total += int(e[1])
	var picked: Dictionary = _picked()
	var day := int(Game.state.day)
	var spots := _spots(total + 6, hash(lid))
	var idx := 0
	for e in list:
		for i in int(e[1]):
			if idx >= spots.size():
				break
			var key := "%s:%d" % [lid, idx]
			var pos: Vector3 = spots[idx]
			idx += 1
			var wait := int(RESPAWN_DAYS.get(e[0], MATERIAL_RESPAWN))
			if picked.has(key) and day - int(picked[key]) < wait:
				continue
			var p := Pickup.chest() if e[0] == "chest" else Pickup.material_pickup(e[0], 1)
			p.key = key
			_place(p, pos)
	# Einzigartiges für laufende Quests
	for item in Quests.data.get("uniques", {}):
		var u: Dictionary = Quests.data.uniques[item]
		var locs: Array = u.get("locs", [u.get("loc", "")])
		if not lid in locs or not Quests.is_active(u.quest):
			continue
		var key := "u:%s:%s" % [item, lid]
		if picked.has(key):
			continue
		var pos: Vector3
		if UNIQUE_POS.has(item) and lid == u.get("loc", ""):
			pos = _ground_at(UNIQUE_POS[item])
		elif u.get("near", "") != "" and w.anchors.has(u.near):
			pos = _ground_at(w.anchors[u.near] + Vector3(1.2, 0, 1.2))
		elif idx < spots.size():
			pos = spots[idx]
			idx += 1
		else:
			continue
		var p := Pickup.material_pickup(item, 1)
		p.key = key
		p.radius = 2.0
		_place(p, pos)


## Entdeckungen des Ortes (data/discoveries.json): an festen Zufallsplätzen abseits der Wege.
func spawn_discoveries() -> void:
	await w.get_tree().physics_frame
	await w.get_tree().physics_frame
	if not is_instance_valid(w.level):
		return
	if _disc.is_empty():
		var f := FileAccess.open("res://data/discoveries.json", FileAccess.READ)
		if f:
			_disc = JSON.parse_string(f.get_as_text())
	var lid: String = w.loc.id
	if w.loc.group == "nazarick" and not _disc.has(lid):
		return
	var d: Dictionary = _disc.get(lid, _disc.get("_default", {}))
	var lore: Array = d.get("lore", [])
	var n := lore.size() + int(d.get("shrines", 1)) + int(d.get("caches", 2))
	var picked := _picked()
	# Von Hand gesetzte Entdeckungen: {"id", "kind", "title", "text", "at": [x, y, z], "yaw": Grad}
	for e in d.get("placed", []):
		var kind := String(e.get("kind", "lore"))
		var key := "d:%s:%s" % [lid, String(e.get("id", e.get("title", "")))]
		if kind == "cache" and picked.has(key):
			continue
		var p := Pickup.discovery(kind, String(e.get("title", "")), String(e.get("text", "")))
		p.key = key
		p.set_meta("done", picked.has(key) and (kind != "shrine" or int(Game.state.day) - int(picked[key]) < 1))
		var at: Array = e.at
		_place(p, Vector3(float(at[0]), float(at[1]), float(at[2])))
		if e.has("yaw"):
			p.rotation.y = deg_to_rad(float(e.yaw))
	if n == 0:
		return
	var spots := _spots(n + 4, hash(lid + "entdeckung"))
	var i := 0
	var shrine_names := ["Schrein der Sechs Götter", "Altar des Kriegers", "Quelle des Lebens"]
	for e in lore:
		if i >= spots.size():
			return
		var p := Pickup.discovery("lore", e[0], e[1])
		p.key = "d:%s:%d" % [lid, i]
		p.set_meta("done", picked.has(p.key))
		_place(p, spots[i])
		i += 1
	for k in int(d.get("shrines", 1)):
		if i >= spots.size():
			return
		var p := Pickup.discovery("shrine", shrine_names[k % shrine_names.size()], "")
		p.key = "d:%s:%d" % [lid, i]
		p.set_meta("done", picked.has(p.key) and int(Game.state.day) - int(picked[p.key]) < 1)
		_place(p, spots[i])
		i += 1
	for k in int(d.get("caches", 2)):
		if i >= spots.size():
			return
		var key := "d:%s:%d" % [lid, i]
		if not picked.has(key):
			var p := Pickup.discovery("cache", "Versteckter Schatz", "")
			p.key = key
			_place(p, spots[i])
		i += 1


var _disc: Dictionary = {}


## Inschrift lesen / am Schrein beten. Gibt true zurück, wenn die Entdeckung behandelt wurde.
func _discover(p: Pickup) -> bool:
	var first := not _picked().has(p.key)
	match p.kind:
		"lore", "lectern", "plaque", "note":
			w._open(LoreDialog.new(p.label, String(p.get_meta("text", ""))))
			if first:
				Game.apply_effects({"res": {"info": 1}})
				Progress.bump("discoveries")
				w.toast("Entdeckt: %s  (+1 Wissen)" % p.label, Color(0.55, 0.85, 1.0))
			_picked()[p.key] = int(Game.state.day)
			p.set_meta("done", true)
			return true
		"shrine":
			if bool(p.get_meta("done", false)):
				w.toast("Der Schrein schweigt. Kommt morgen wieder.", Palette.MUTED)
				return true
			var pl = w.player
			match p.label:
				"Altar des Kriegers":
					pl.shield_time = maxf(pl.shield_time, 90.0)
					w.toast("Segen des Kriegers: eine Barriere schützt Euch 90 s.", Color(1.0, 0.86, 0.5))
				"Quelle des Lebens":
					pl.mana = pl.max_mana
					pl.stamina = pl.max_stamina
					w.toast("Quelle des Lebens: Mana und Ausdauer erneuert.", Color(0.6, 0.9, 1.0))
				_:
					pl.hp = pl.max_hp
					pl.mana = pl.max_mana
					w.toast("Segen der Sechs Götter: vollständig geheilt. (Wie ironisch.)", Color(1.0, 0.86, 0.5))
			if first:
				Progress.bump("discoveries")
			_picked()[p.key] = int(Game.state.day)
			p.set_meta("done", true)
			Audio.sfx("levelup", 0.5)
			return true
		"cache":
			Progress.bump("discoveries")
			w._show_banner("Versteckter Schatz", "Unter den Steinen lag etwas verborgen …")
	return false


func _place(p: Pickup, pos: Vector3) -> void:
	p.position = pos
	p.rotation.y = randf() * TAU
	w.level.add_child(p)
	pickups.append(p)


func _picked() -> Dictionary:
	if not Game.state.has("picked"):
		Game.state["picked"] = {}
	return Game.state.picked


## Begehbare Plätze: Strahl nach unten trifft flachen Boden, frei nach oben (draußen) bzw. unter der
## Decke (Nazarick), Sichtlinie zu einem Anker, Abstand zueinander und zum Spawn.
func _spots(n: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var space: PhysicsDirectSpaceState3D = w.player.get_world_3d().direct_space_state
	var seeds: Array = [w.anchors.spawn]
	seeds += w.anchors.get("slots", [])
	if w.anchors.has("keeper"):
		seeds.append(w.anchors.keeper)
	var indoor: bool = w.loc.group == "nazarick" or w.loc.get("kind", "") in ["city", "palace", "cathedral"]
	var reach := 18.0 if indoor else 48.0
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < n * 40:
		tries += 1
		var s: Vector3 = seeds[rng.randi() % seeds.size()]
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, reach)
		var x := s.x + cos(a) * r
		var z := s.z + sin(a) * r
		var top := Vector3(x, s.y + (2.4 if indoor else 40.0), z)
		var rq := PhysicsRayQueryParameters3D.create(top, Vector3(x, s.y - 8.0, z))
		var hit := space.intersect_ray(rq)
		if hit.is_empty() or hit.normal.y < 0.85:
			continue
		var p: Vector3 = hit.position
		if absf(p.y - s.y) > (2.5 if indoor else 12.0):
			continue
		var los := PhysicsRayQueryParameters3D.create(s + Vector3(0, 1.0, 0), p + Vector3(0, 1.0, 0))
		if not space.intersect_ray(los).is_empty():
			continue
		if p.distance_to(w.anchors.spawn) < 5.0:
			continue
		var ok := true
		for o in out:
			if (o as Vector3).distance_to(p) < 4.0:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func _ground_at(p: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = w.player.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 30, 0), p + Vector3(0, -30, 0)))
	return hit.position if not hit.is_empty() else p


# ------------------------------------------------------------------ Wächter-Einsätze

## Beim Betreten eines Ortes: läuft hier ein Einsatz („as“), übernimmt der Spieler den Wächter und die
## Gegner des Schritts erscheinen. Sonst zurück zu Ainz, falls noch ein Wächter gespielt wird.
func apply_story() -> void:
	var s := _story_step()
	if not s.is_empty():
		_become(String(s.as), s.q)
		_spawn_wave(s.step)
	elif String(w.player.style).begins_with("g_"):
		_restore()


func _story_step() -> Dictionary:
	for q in Quests.active():
		var st := Quests.step(q)
		if st.has("as") and String(st.get("loc", "")) == w.loc.id:
			return {"q": q, "step": st, "as": st["as"]}
	return {}


func _become(cid: String, q: Dictionary) -> void:
	var style := "g_" + cid
	if w.player.style == style or not Content.combat.player.styles.has(style):
		return
	if not Game.state.has("world3d"):
		Game.state["world3d"] = {}
	if not String(w.player.style).begins_with("g_"):
		Game.state.world3d["prev_style"] = w.player.style
	w.player.set_style(style, true)
	w._show_banner(Content.char_data(cid).get("name", cid), q.title + " – Ihr kämpft als " + String(Content.char_data(cid).get("name", cid)) + ".")


func _restore() -> void:
	var prev: String = String(Game.state.get("world3d", {}).get("prev_style", "ainz"))
	w.player.set_style(prev if not prev.begins_with("g_") else "ainz", true)
	w.toast("Ihr seid wieder Ainz Ooal Gown.", Palette.VIOLET_GLOW)


func _spawn_wave(st: Dictionary) -> void:
	var base: Vector3 = w.anchors.spawn
	var fwd := Vector3(sin(float(w.anchors.get("yaw", 0.0))), 0, cos(float(w.anchors.get("yaw", 0.0)))) * -1.0
	var slots: Array = w.anchors.get("slots", [])
	var i := 0
	for e in st.get("spawn", []):
		for k in int(e[1]):
			var p: Vector3
			if i < slots.size():
				p = slots[i]
			else:
				p = base + fwd * randf_range(12.0, 20.0) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			i += 1
			w.spawn_enemy(String(e[0]), _ground_at(p) + Vector3(0, 0.2, 0))


func _on_step_done(qid: String, text: String) -> void:
	w.toast("✔ " + text, Palette.SUCCESS)
	var q: Dictionary = Quests.by_id[qid]
	var st := Quests.step(q)
	if st.has("as") and String(st.get("loc", "")) == w.loc.id:
		await w.get_tree().create_timer(1.6).timeout
		if is_instance_valid(w.level):
			w._show_banner(String(st.text).get_slice(":", 1).strip_edges() if ":" in String(st.text) else String(st.text), q.title)
			_spawn_wave(st)
	elif String(w.player.style).begins_with("g_"):
		await w.get_tree().create_timer(2.0).timeout
		_restore()


# ------------------------------------------------------------------ Laufzeit

## Nächstes Aufhebbares in Reichweite (für den Interaktionshinweis); Beutel werden im Vorbeigehen eingesammelt.
func nearest(pos: Vector3) -> Pickup:
	var best: Pickup = null
	var bd := INF
	for p in pickups.duplicate():
		if not is_instance_valid(p):
			pickups.erase(p)
			continue
		var d := Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		if p.auto and d < 1.3:
			collect(p)
			continue
		if d < p.radius and d < bd:
			best = p
			bd = d
	return best


func collect(p: Pickup) -> void:
	if p.kind in ["lore", "shrine", "cache"] and _discover(p):
		return
	var lines := PackedStringArray()
	for e in p.entries:
		match String(e[0]):
			"gold":
				Game.apply_effects({"res": {"gold": int(e[2])}})
				lines.append("+%d Gold" % int(e[2]))
			"item":
				if String(e[1]) != "":
					Progress.grant_item(String(e[1]), "Fund: " + p.label)
			_:
				Quests.on_pickup(String(e[0]), int(e[2]))
				var d: Dictionary = Quests.material(String(e[0]))
				lines.append("+%d %s" % [int(e[2]), d.get("name", e[0])])
	if p.key != "":
		_picked()[p.key] = int(Game.state.day)
	Audio.sfx("loot", 0.6)
	if not lines.is_empty():
		w.toast("  ".join(lines), p.color.lerp(Palette.GOLD_BRIGHT, 0.4))
	pickups.erase(p)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)
	w._refresh_hud()


## Gegner besiegt: Quest-Fortschritt + Beutebeutel.
func on_enemy_defeated(e: Enemy3D) -> void:
	Quests.on_kill(e.type_id, w.loc.id)
	var loot := Quests.roll_loot(e.type_id)
	if loot.is_empty():
		return
	var bag := Pickup.loot_bag(loot)
	bag.position = e.global_position + Vector3(randf_range(-0.4, 0.4), 0.02, randf_range(-0.4, 0.4))
	w.level.add_child(bag)
	pickups.append(bag)


# ------------------------------------------------------------------ Gespräche

const MERCHANTS := ["lizzie", "guild_clerk", "enri"]


## Gespräch mit einer Figur. Gibt true zurück, wenn ein Quest-Dialog geöffnet wurde.
func talk(a: Actor3D) -> bool:
	var before := {}
	for q in Quests.active():
		before[q.id] = true
	Quests.on_talk(a.id)
	# Abgabe
	for q in Quests.turnins_at(a.id):
		var qid: String = q.id
		_dialog(a, q.get("progress", "…") + "\n\n[color=#d4af37]Ihr habt alles beisammen.[/color]", [
			{"text": "⚜  Übergeben", "action": func(): _hand_in(a, qid)}])
		return true
	# soeben per Gespräch abgeschlossen?
	for qid in before:
		if Quests.state_of(qid) == "done":
			_dialog(a, Quests.by_id[qid].get("done", "Gut gemacht."), [])
			return true
	# Angebot
	var offers := Quests.offers_of(a.id)
	if not offers.is_empty():
		var q: Dictionary = offers[0]
		var qid: String = q.id
		var acts := [{"text": "✦  Auftrag annehmen: " + q.title, "action": func(): Quests.accept(qid); w.toast("Neuer Auftrag: " + Quests.by_id[qid].title, Palette.GOLD_BRIGHT)}]
		if a.kind == "char":
			acts.append({"text": "Audienz", "action": func(): w._open(CharacterView.new(a.id))})
		_dialog(a, q.offer, acts)
		return true
	# laufende Quest dieser Figur: Erinnerung
	for q in Quests.active():
		if q.get("giver", "") == a.id or String(Quests.step(q).get("npc", "")) == a.id:
			var acts2 := []
			if a.kind == "char":
				acts2.append({"text": "Audienz", "action": func(): w._open(CharacterView.new(a.id))})
			_merchant_action(a, acts2)
			_dialog(a, String(q.get("progress", "")) + "\n\n[color=#8f86a3]" + Quests.step_text(q) + "[/color]", acts2)
			return true
	if a.id in MERCHANTS and a.kind == "npc":
		var acts3 := []
		_merchant_action(a, acts3)
		_dialog(a, a.line if a.line != "" else "Womit kann ich dienen, Herr Momon?", acts3)
		return true
	return false


func _merchant_action(a: Actor3D, acts: Array) -> void:
	if not a.id in MERCHANTS:
		return
	var value := 0
	for m in Quests.bag():
		var d := Quests.material(m)
		if not d.get("unique", false):
			value += Quests.count(m) * int(d.get("value", 1))
	if value > 0:
		acts.append({"text": "◈  Materialien verkaufen (~%d Gold)" % value, "action": func():
			var g := Quests.sell_all()
			w.toast("Verkauft: +%d Gold" % g, Palette.GOLD_BRIGHT)})


func _hand_in(a: Actor3D, qid: String) -> void:
	if Quests.hand_in(qid) and Quests.state_of(qid) == "done":
		_dialog(a, Quests.by_id[qid].get("done", "Danke."), [])


func _dialog(a: Actor3D, text: String, actions: Array) -> void:
	w._open(TalkDialog.new(a.id, text, actions))


func _on_completed(qid: String) -> void:
	var q: Dictionary = Quests.by_id[qid]
	var r: Dictionary = q.get("rewards", {})
	var parts := PackedStringArray()
	if r.has("gold"):
		parts.append("+%d Gold" % int(r.gold))
	for k in r.get("res", {}):
		parts.append("%s +%d" % [Game.RESOURCE_LABELS.get(k, k), int(r.res[k])])
	if String(r.get("item", "")) != "":
		parts.append("Gegenstand")
	Progress.celebrate.emit({"kind": "achievement", "title": "Auftrag erfüllt", "text": q.title, "sub": " · ".join(parts),
		"icon": "⚜", "color": Palette.GOLD_BRIGHT})
	refresh_marks()


## "!"/"?" über den Köpfen der Questgeber.
func refresh_marks() -> void:
	if not is_instance_valid(w) or w.actors.is_empty():
		return
	for a in w.actors:
		if is_instance_valid(a) and a.kind != "object":
			a.set_quest_mark(Quests.marker_for(a.id))


## Anschlagtafel: Kopfgelder des Ortes.
func board_menu() -> bool:
	var qs := Quests.board_quests(w.board_loc())
	if qs.is_empty():
		return false
	var entries: Array = []
	for q in qs:
		var qid: String = q.id
		if Quests.is_active(qid):
			entries.append({"text": "…  %s" % q.title, "sub": Quests.step_text(q), "disabled": true, "action": func(): pass})
		else:
			var r: Dictionary = q.get("rewards", {})
			entries.append({"text": "✦  %s" % q.title, "sub": "%s  · Lohn: %d Gold" % [q.offer, int(r.get("gold", 0))], "style": "ButtonPrimary",
				"action": func(): Quests.accept(qid); w.toast("Kopfgeld angenommen: " + Quests.by_id[qid].title, Palette.GOLD_BRIGHT)})
	entries.append({"text": "⚑  Lage der Region", "action": func(): w._region_menu_info()})
	w._open(ChoiceMenu.new("Anschlagtafel", "Aushänge und Kopfgelder", entries, 860))
	return true

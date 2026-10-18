extends Node3D
## Third-Person-Welt: Ainz bewegt sich frei durch Nazarick und die Neue Welt.
##
## • Orte aus data/locations.json, gebaut vom LocationBuilder
## • Wächter stehen dort, wo sie gerade sind (Thronsaal, eigene Ebene, Einsatzort, Feldzug)
## • Interaktion [E]: Gespräch/Audienz, Thron (Zeit), Kriegstisch (Aufträge, Karte, Diplomatie),
##   Albedos Pult (Verwaltung, Nazarick), Gate (Reisen), Lagetafel (regionale Aufträge)
## • Die Zeit läuft in Echtzeit weiter (ein Tag je DAY_SECONDS), Depeschen öffnen sich als Fenster
## Alle Systeme (Game, World, Military, Diplomacy, Progress) laufen direkt in dieser 3D-Welt.

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const DAY_SECONDS := 45.0

var player := Player3D.new()
var level: Node3D
var loc: Dictionary = {}
var actors: Array[Actor3D] = []
var anchors: Dictionary = {}

var ui := CanvasLayer.new()
var ui_root := Control.new()
var overlay_layer := Control.new()
var celebrations := CelebrationLayer.new()
var hud := WorldHud.new()
var quest_world := QuestWorld.new(self)
var _pickup_focus: Pickup
var hud_feedback := Label.new()
var hud_vignette := ColorRect.new()
var enemies: Array[Enemy3D] = []
var _spell_slots: Array = []
var _focus: Actor3D
var _day_timer := 0.0
var _time_running := true
var _busy := false
var _last_autosave := 0
var _spinners: Array = []
var _flickers: Array = []


func _ready() -> void:
	if Game.state.is_empty():
		Game.new_game()
	add_child(player)
	add_child(quest_world)
	Actor3D.player = player
	_build_ui()
	player.feedback.connect(_on_feedback)
	player.style_changed.connect(func(_s): _rebuild_spell_bar())
	player.damaged.connect(_on_player_damaged)
	player.died.connect(func(_f): _on_player_died())
	_rebuild_spell_bar()
	Game.state_changed.connect(_refresh_hud)
	Game.dispatches_arrived.connect(func(_n): Audio.sfx("dispatch", 0.8))
	var w3: Dictionary = Game.state.get("world3d", {})
	var start: String = w3.get("loc", "throne")
	load_location(start if Content.location_by_id.has(start) else "throne")
	_refresh_hud()
	await get_tree().create_timer(0.8).timeout
	_open_next_dispatch()
	if not Settings.tutorial_done:
		while overlay_layer.get_child_count() > 0:
			await get_tree().create_timer(0.5).timeout
		start_tutorial()


# =====================================================================
#  Orte laden
# =====================================================================

func load_location(id: String, fade: bool = false) -> void:
	if fade:
		await _fade(1.0, 0.35)
	actors.clear()
	enemies.clear()
	_focus = null
	player.lock = null
	quest_world.clear()
	if level:
		# alten Ort erst vollständig freigeben, dann den neuen bauen (halbiert den Speicher-Spitzenwert)
		remove_child(level)
		level.queue_free()
		level = null
		await get_tree().process_frame
		await get_tree().process_frame
	loc = Content.location_by_id[id]
	level = Node3D.new()
	level.name = "Level_" + id
	add_child(level)
	LocationBuilder.environment(level, loc, LocationBuilder.preset(loc.kind))
	anchors = LocationBuilder.build(loc, level)
	_spinners = level.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.has_meta("spin"))
	_flickers = level.find_children("*", "OmniLight3D", true, false).filter(func(n): return n.has_meta("flicker"))
	_place_actors()
	_spawn_encounters()
	quest_world.apply_story()
	quest_world.spawn_pickups()
	player.global_position = anchors.spawn
	player.velocity = Vector3.ZERO
	player.face(anchors.get("yaw", 0.0))
	if not Game.state.has("world3d"):
		Game.state["world3d"] = {}
	Game.state.world3d["loc"] = id
	Audio.play_music(loc.get("music", "throne"))
	hud.set_location(loc.name)
	_show_banner(loc.name, loc.get("desc", ""))
	if fade:
		await _fade(0.0, 0.5)


func _place_actors() -> void:
	var slots: Array = anchors.get("slots", []).duplicate()
	var region: String = loc.get("region", "nazarick" if loc.group == "nazarick" else "")
	var placed: Array = []
	# Wächter: jeder ist an seinem Platz – im Thronsaal nur Albedo und wer gerade Aufmerksamkeit sucht
	var guests := _throne_guests()
	for cid in Game.unlocked_chars():
		var c := Game.cs(cid)
		var where := _char_whereabouts(cid)
		var here := false
		var variant := ""
		if where == "nazarick":
			here = (loc.id == "throne" and cid in guests) or (loc.id != "throne" and HOME.get(cid, "") == loc.id)
		elif loc.group == "world" and where == region:
			here = true
			variant = "battle" if c.status == "feldzug" else ""
		if not here:
			continue
		if variant == "":
			variant = "angry" if c.jealousy >= 60 else ("love" if c.favor >= 80 else ("sad" if c.favor < 30 else ""))
		var pos: Vector3
		if loc.get("keeper", "") == cid and anchors.has("keeper"):
			pos = anchors.keeper
		elif not slots.is_empty():
			pos = slots.pop_front()
		else:
			pos = Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		var a := Actor3D.character(cid, variant)
		a.prompt = "Audienz"
		_add_actor(a, pos)
		placed.append(cid)
	# Story-Figuren und Diener
	for n in loc.get("npcs", []):
		if not Game.check(n.get("requires", {})):
			continue
		var pos: Vector3 = slots.pop_front() if not slots.is_empty() else Vector3(randf_range(-6, 6), 0, randf_range(-8, 0))
		var a := Actor3D.character(n.id, "", 2.6 if n.id in ["death_knight", "platinum_dragon"] else 2.3)
		a.line = n.get("line", "")
		_add_actor(a, pos)
	quest_world.spawn_givers(slots)
	# Objekte
	if anchors.has("throne"):
		_add_actor(Actor3D.object("throne", "Thron von Nazarick", "Zeit vergehen lassen", Palette.GOLD_BRIGHT, 3.2), anchors.throne)
	if anchors.has("table"):
		_add_actor(Actor3D.object("table", "Kriegsrat", "Aufträge, Karte & Diplomatie", Palette.GOLD, 3.2), anchors.table)
	if anchors.has("desk"):
		_add_actor(Actor3D.object("desk", "Albedos Pult", "Verwaltung, Ausbau & Wochenziele", Palette.VIOLET_GLOW, 3.0), anchors.desk)
	if anchors.has("board"):
		var rname: String = World.region(region).get("name", loc.name) if region != "" else loc.name
		var a := Actor3D.object("board", "Lage: " + rname, "Lage & Aufträge der Region", Palette.GOLD, 2.8)
		_add_actor(a, anchors.board)
		B3.box(level, Vector3(1.6, 1.2, 0.12), anchors.board + Vector3(0, 1.3, 0), B3.mat(Color(0.3, 0.2, 0.1), 0.8))
		B3.cyl(level, 0.06, 0.06, 1.8, anchors.board + Vector3(0, 0.9, -0.1), B3.mat(Color(0.2, 0.14, 0.08)), true, 6)
	_add_actor(Actor3D.object("gate", "Gate", "Reisen", Color(0.75, 0.5, 1.0), 3.0), anchors.gate)


## Heimat in Nazarick (Ebene/Raum). Wer hier fehlt, hält sich im Thronsaal bereit.
const HOME := {
	"albedo": "throne", "shalltear": "tombs", "cocytus": "glacier", "aura": "jungle", "mare": "jungle",
	"demiurge": "lava", "sebas": "royal", "pandora": "treasury", "narberal": "royal", "yuri": "royal",
	"lupusregina": "royal", "solution": "royal", "entoma": "royal", "cz": "royal", "victim": "lava", "neuronist": "lava",
}


## Wer im Thronsaal wartet: Albedo, wer Ainz sprechen will (verliebt, eifersüchtig, unzufrieden),
## dazu reihum ein Wächter für die tägliche Audienz.
func _throne_guests() -> Array:
	var out := ["albedo"]
	var pool: Array = []
	for cid in Game.unlocked_chars():
		var c := Game.cs(cid)
		if cid == "albedo" or _char_whereabouts(cid) != "nazarick":
			continue
		if not HOME.has(cid) or c.jealousy >= 60 or c.favor >= 85 or c.favor < 25:
			out.append(cid)
		elif HOME.get(cid, "") != "royal":
			pool.append(cid)
	if not pool.is_empty():
		pool.sort()
		out.append(pool[int(Game.state.day) % pool.size()])
	return out.slice(0, 5)


## Wo hält sich ein Wächter auf? "nazarick" oder eine Regions-ID.
func _char_whereabouts(cid: String) -> String:
	var c := Game.cs(cid)
	if c.status == Game.STATUS_MISSION:
		for am in Game.state.active:
			if am.char_id == cid or am.get("partner", "") == cid:
				var r: String = Game.mission(am.mission_id).get("region", "")
				return r if r != "" else "unterwegs"
		return "unterwegs"
	if c.status == "feldzug":
		for a in Game.state.armies:
			if a.commander == cid:
				return a.location
	return "nazarick"


func _add_actor(a: Actor3D, pos: Vector3) -> void:
	a.position = pos
	level.add_child(a)
	actors.append(a)
	# Figuren schauen zur Raummitte/zum Spieler-Startpunkt
	if a.kind != "object":
		var look: Vector3 = anchors.get("spawn", Vector3.ZERO)
		a.rotation.y = atan2(look.x - pos.x, look.z - pos.z)


# =====================================================================
#  Ablauf
# =====================================================================

func _process(delta: float) -> void:
	var blocked := overlay_layer.get_child_count() > 0 or _busy
	player.input_enabled = not blocked
	# Während ein Fenster offen ist, steht der Kampf still
	for e in enemies:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED if blocked else Node.PROCESS_MODE_INHERIT
	if blocked:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_focus()
	_animate(delta)
	_update_combat_hud(blocked)
	# Echtzeit: Tage vergehen, solange niemand wartet
	if not blocked and _time_running and Game.pending().is_empty():
		_day_timer += delta
		if _day_timer >= DAY_SECONDS:
			_day_timer = 0.0
			_advance(1, false)
	hud.day_line.set_values(_day_timer, DAY_SECONDS)


func _animate(delta: float) -> void:
	if level == null:
		return
	for n in _spinners:
		if is_instance_valid(n):
			n.rotate_object_local(Vector3.UP, float(n.get_meta("spin")) * delta)
	for l in _flickers:
		if is_instance_valid(l):
			l.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.013 + l.position.x) * 0.25 + randf() * 0.2


func _update_focus() -> void:
	var best: Actor3D = null
	var best_d := INF
	for a in actors:
		if not is_instance_valid(a):
			continue
		var d := Vector2(a.global_position.x - player.global_position.x, a.global_position.z - player.global_position.z).length()
		if d < a.radius and d < best_d:
			best = a
			best_d = d
	if best != _focus:
		if _focus and is_instance_valid(_focus):
			_focus.set_highlight(false)
		_focus = best
		if _focus:
			_focus.set_highlight(true)
	_pickup_focus = quest_world.nearest(player.global_position) if overlay_layer.get_child_count() == 0 else null
	if _pickup_focus and (_focus == null or player.global_position.distance_to(_pickup_focus.global_position) < player.global_position.distance_to(_focus.global_position)):
		hud.set_prompt("%s  ·  %s" % [_pickup_focus.prompt(), _pickup_focus.label])
	elif _focus and overlay_layer.get_child_count() == 0:
		hud.set_prompt("%s  ·  %s" % [_focus.prompt, _focus.label])
	else:
		hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if overlay_layer.get_child_count() > 0 or _busy:
		return
	if event.is_action_pressed("interact") and _pickup_focus and is_instance_valid(_pickup_focus) and 			(_focus == null or player.global_position.distance_to(_pickup_focus.global_position) < player.global_position.distance_to(_focus.global_position)):
		quest_world.collect(_pickup_focus)
		_pickup_focus = null
		return
	if event.is_action_pressed("interact") and _focus:
		_interact(_focus)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE: _pause_menu()
		KEY_J: _open(QuestJournal.new())
		KEY_K: _open(MissionBoard.new(loc.get("region", "")))
		KEY_M: _open_map()
		KEY_P: _open(DiplomacyView.new())
		KEY_V: _open(AdministrationView.new())
		KEY_N: _open(NazarickView.new())
		KEY_U: _open(CharacterView.new("albedo"))
		KEY_C: _open(ChronicleView.new())
		KEY_G: _gate_menu()
		KEY_T: _time_menu()
		KEY_H, KEY_F1: hud.toggle_help()
		KEY_TAB: hud.toggle_goals()
		KEY_ENTER, KEY_KP_ENTER: _open_next_dispatch(true)
		KEY_F5:
			SaveSystem.save_game(1)
			toast("Gespeichert in Chronik 1.")


func _interact(a: Actor3D) -> void:
	match a.kind:
		"char":
			if quest_world.talk(a):
				return
			var cv := CharacterView.new(a.id)
			cv.closed.connect(_refresh_actors_soft)
			_open(cv)
		"npc":
			if quest_world.talk(a):
				return
			_open(TalkDialog.new(a.id, a.line if a.line != "" else "…"))
		"object":
			match a.id:
				"throne": _time_menu()
				"table": _war_table()
				"desk": _desk_menu()
				"gate": _gate_menu()
				"board":
					if not quest_world.board_menu():
						_region_menu()


func _refresh_actors_soft() -> void:
	_refresh_hud()


# =====================================================================
#  Menüs
# =====================================================================

func _open(o: Control) -> Control:
	overlay_layer.add_child(o)
	return o


func _open_map() -> void:
	var m := WorldMapView.new(loc.get("region", "nazarick"))
	m.open_missions.connect(func(rid): await get_tree().create_timer(0.3).timeout; _open(MissionBoard.new(rid)))
	_open(m)


func _time_menu() -> void:
	var pend := not Game.pending().is_empty()
	_open(ChoiceMenu.new("Der Thron von Nazarick", "Tag %d · %s" % [Game.state.day, Game.format_date(Game.state.day)], [
		{"text": "◷  Einen Tag vergehen lassen", "action": func(): _advance(1), "disabled": pend},
		{"text": "◷  Eine Woche vergehen lassen", "action": func(): _advance(7), "disabled": pend},
		{"text": "◷  Einen Monat vergehen lassen", "action": func(): _advance(30), "disabled": pend},
		{"text": ("⏸  Zeitfluss anhalten" if _time_running else "▶  Zeitfluss fortsetzen"), "sub": "Ohne Eingriff vergeht alle %d Sekunden ein Tag." % int(DAY_SECONDS),
			"action": func(): _time_running = not _time_running; toast("Die Zeit %s." % ("fließt wieder" if _time_running else "steht still"))},
		{"text": "❤  Wochenziele & Nazarick", "sub": "Albedos Truhe, Ausbau, Schatzkammer [N]", "action": func(): _open(NazarickView.new(2))},
	], 700, "ainz"))


func _war_table() -> void:
	_open(ChoiceMenu.new("Kriegsrat", "Die Weltkarte liegt vor Euch ausgebreitet.", [
		{"text": "✦  Auftragstafel", "sub": "Wächter entsenden [J]", "action": func(): _open(MissionBoard.new()), "style": "ButtonPrimary"},
		{"text": "⚑  Weltkarte & Legionen", "sub": "Regionen, Heere, Feldzüge [M]", "action": _open_map},
		{"text": "⚖  Diplomatie", "sub": "Fraktionen & Gesandtschaften [P]", "action": func(): _open(DiplomacyView.new())},
		{"text": "☰  Chronik", "sub": "Alle Ereignisse [C]", "action": func(): _open(ChronicleView.new())},
	], 700, "demiurge"))


func _desk_menu() -> void:
	_open(ChoiceMenu.new("Albedos Pult", "»Alles ist vorbereitet, %s.«" % Game.lord(), [
		{"text": "❤  Wochenziele & Truhe", "action": func(): _open(NazarickView.new(2)), "style": "ButtonPrimary" if Progress.can_claim_chest() else "Button"},
		{"text": "⚒  Ausbau der Ebenen", "action": func(): _open(NazarickView.new(0))},
		{"text": "◈  Schatzkammer & Ausrüstung", "action": func(): _open(NazarickView.new(1))},
		{"text": "★  Errungenschaften", "action": func(): _open(NazarickView.new(3))},
		{"text": "⚙  Reichsverwaltung & Erlasse", "sub": "[V]", "action": func(): _open(AdministrationView.new())},
	], 700, "albedo"))


func _gate_menu() -> void:
	var entries: Array = []
	for l in Content.locations:
		var ok := true
		var why := ""
		if l.group == "world":
			var r: String = l.get("region", "")
			ok = r == "" or World.rs(r).get("discovered", false)
			why = "Noch nicht erkundet – entsendet einen Wächter zur Erkundung."
		var here: bool = l.id == loc.id
		entries.append({"text": ("☗  " if l.group == "nazarick" else "✧  ") + l.name + ("   (hier)" if here else ""),
			"sub": _short(l.get("desc", "")), "disabled": not ok or here, "tip": why if not ok else "",
			"action": func(): _travel(l.id)})
	_open(ChoiceMenu.new("Gate", "Wohin soll das Tor sich öffnen?", entries, 980))


## Kurzbeschreibung: erster Satz, sonst an einer Wortgrenze gekürzt.
func _short(t: String, n: int = 110) -> String:
	var dot := t.find(". ")
	if dot > 0 and dot < n:
		return t.substr(0, dot + 1)
	if t.length() <= n:
		return t
	var cut := t.substr(0, n)
	return cut.substr(0, cut.rfind(" ")) + " …"


func _region_menu_info() -> void:
	_region_menu()


func _region_menu() -> void:
	var rid: String = loc.get("region", "")
	var r := World.region(rid)
	var st := World.rs(rid)
	var txt := "Einfluss %d %% · Unruhe %d · %s" % [int(st.get("influence", 0)), int(st.get("unrest", 0)), World.control_label(int(st.get("influence", 0)))]
	_open(ChoiceMenu.new(r.get("name", loc.name), txt, [
		{"text": "✦  Aufträge in dieser Region", "action": func(): _open(MissionBoard.new(rid)), "style": "ButtonPrimary"},
		{"text": "⚑  Auf der Weltkarte zeigen", "action": func(): _open(WorldMapView.new(rid))},
	], 700))


func _pause_menu() -> void:
	_open(ChoiceMenu.new("Pause", "%s · Tag %d" % [Game.state.lord_name, Game.state.day], [
		{"text": "▶  Weiter", "action": func(): pass, "style": "ButtonPrimary"},
		{"text": "✎  Speichern", "action": func(): _open(SaveLoadDialog.new(true))},
		{"text": "☰  Laden", "action": _load_menu},
		{"text": "⚙  Einstellungen", "action": _settings},
		{"text": "?  Einführung erneut zeigen", "action": start_tutorial},
		{"text": "✕  Zum Titelbildschirm", "action": func(): get_tree().change_scene_to_file(TITLE_SCENE)},
	], 620))


func _settings() -> void:
	var dlg := SettingsDialog.new(true)
	dlg.tutorial_requested.connect(func(): await get_tree().create_timer(0.3).timeout; start_tutorial())
	_open(dlg)


func _load_menu() -> void:
	var dlg := SaveLoadDialog.new(false)
	dlg.loaded.connect(func(): get_tree().reload_current_scene())
	_open(dlg)


func _travel(id: String) -> void:
	Audio.sfx("gong", 0.6)
	await load_location(id, true)


# =====================================================================
#  Zeit & Depeschen
# =====================================================================

func _advance(days: int, show_veil: bool = true) -> void:
	if _busy:
		return
	if not Game.pending().is_empty():
		_open_next_dispatch(true)
		return
	_busy = true
	if show_veil:
		Audio.sfx("gong", 0.5)
		await _fade(0.6, 0.3)
	var res := Game.advance(days)
	_autosave()
	if show_veil:
		_show_banner("%d %s vergangen" % [res.days, "Tag" if res.days == 1 else "Tage"], Game.format_date(Game.state.day))
		await _fade(0.0, 0.4)
	_busy = false
	_refresh_hud()
	_open_next_dispatch()


func _open_next_dispatch(force: bool = false) -> void:
	if overlay_layer.get_child_count() > 0:
		return
	var pending := Game.pending()
	if pending.is_empty():
		return
	if in_combat() and not force:
		toast("Eine Depesche wartet – erst der Kampf. [Enter] öffnet sie.", Palette.GOLD_BRIGHT)
		return
	if not Settings.auto_open and not force:
		toast("Eine Depesche ist eingetroffen – [Enter] zum Öffnen.", Palette.GOLD_BRIGHT)
		return
	var d: Dictionary = pending[0]
	var battle_uid: String = d.get("context", {}).get("battle", "") if d.kind == "battle" else ""
	if battle_uid != "" and Game.state.battles.has(battle_uid) and not _has_option(d, "lead"):
		# Ainz kann jede Schlacht persönlich anführen – sie wird dann in 3D ausgetragen
		d.options.push_front({"key": "lead", "label": "⚔ Persönlich in die Schlacht ziehen (3D-Kampf)", "variant": "primary", "effects": {}, "reaction": "Ihr erhebt Euch vom Thron. Das Gate öffnet sich zum Schlachtfeld …"})
	var dlg: Overlay = DispatchDialog.new(d)
	dlg.closed.connect(func():
		await get_tree().create_timer(0.15).timeout
		if battle_uid != "" and Game.state.battles.has(battle_uid):
			_lead_battle(battle_uid)
			return
		_open_next_dispatch(true)
		_refresh_hud())
	_open(dlg)


func _autosave() -> void:
	var every := Settings.autosave_days()
	if every > 0 and Game.state.day - _last_autosave >= every:
		_last_autosave = Game.state.day
		SaveSystem.save_game(0)


# =====================================================================
#  HUD
# =====================================================================

func _build_ui() -> void:
	add_child(ui)
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = load("res://assets/ui/nazarick_theme.tres")
	ui.add_child(ui_root)
	hud_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_vignette.color = Color(0.6, 0.0, 0.05, 0.0)
	hud_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_vignette)
	ui_root.add_child(hud)
	hud.setup(self)
	hud_feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_feedback.offset_top = 60
	hud_feedback.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_feedback.theme_type_variation = "GoldLabel"
	hud_feedback.add_theme_font_size_override("font_size", 28)
	hud_feedback.add_theme_constant_override("outline_size", 8)
	hud_feedback.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_feedback.modulate.a = 0.0
	ui_root.add_child(hud_feedback)
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(overlay_layer)
	ui_root.add_child(hud.toast_box)
	ui_root.add_child(celebrations)


func _refresh_hud() -> void:
	if is_inside_tree():
		hud.refresh()


func toast(text: String, color: Color = Palette.GOLD_BRIGHT) -> void:
	hud.toast(text, color)


var _banner: Control


func _show_banner(title: String, sub: String) -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	var vb := VBoxContainer.new()
	_banner = vb
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_top = -280
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.text = title.to_upper()
	t.theme_type_variation = "TitleLabel"
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02, 0.9))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var orn := Label.new()
	orn.text = "━━━━━━━━  ◆  ━━━━━━━━"
	orn.add_theme_color_override("font_color", Color(Palette.GOLD, 0.8))
	orn.add_theme_font_size_override("font_size", 14)
	orn.add_theme_constant_override("outline_size", 4)
	orn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(orn)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_override("font", NazarickTheme.italic_font(600))
	s.add_theme_font_size_override("font_size", 21)
	s.add_theme_color_override("font_color", Palette.PARCHMENT)
	s.add_theme_constant_override("outline_size", 7)
	s.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 860
	vb.add_child(s)
	hud.add_child(vb)
	vb.modulate.a = 0.0
	t.pivot_offset = Vector2(430, 28)
	t.scale = Vector2(1.06, 1.06)
	var tw := vb.create_tween()
	tw.tween_property(vb, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(t, "scale", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.2)
	tw.tween_property(vb, "modulate:a", 0.0, 0.9)
	tw.tween_callback(vb.queue_free)


var _veil: ColorRect


func _fade(to: float, t: float) -> void:
	if _veil == null:
		_veil = ColorRect.new()
		_veil.color = Color(0.02, 0.0, 0.04, 0.0)
		_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(_veil)
		ui_root.move_child(_veil, overlay_layer.get_index())
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", to, t)
	await tw.finished


# =====================================================================
#  Kampf
# =====================================================================

func _spawn_encounters() -> void:
	for enc in loc.get("encounters", []):
		if not Game.check(enc.get("requires", {})):
			continue
		var at: Array = enc.get("at", [0, 0])
		var center := Vector3(float(at[0]), 0.2, float(at[1]))
		for i in int(enc.get("count", 1)):
			var off := Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)) if i > 0 else Vector3.ZERO
			spawn_enemy(enc.enemy, center + off)


func spawn_enemy(id: String, pos: Vector3) -> Enemy3D:
	var e := Enemy3D.create(id)
	e.position = pos
	e.target = player
	level.add_child(e)
	e.add_to_group("enemies")
	enemies.append(e)
	e.damaged.connect(_on_enemy_damaged)
	e.defeated.connect(_on_enemy_defeated)
	return e


func _on_enemy_damaged(f: Fighter, amount: int, kind: String) -> void:
	var col: Color = {"fire": Color(1, 0.6, 0.2), "negative": Color(0.75, 0.4, 1.0), "holy": Color(1, 0.95, 0.6)}.get(kind, Color(1, 1, 1))
	var crit := amount >= 40
	_float_text(f.global_position + Vector3(randf_range(-0.4, 0.4), 2.4, 0), str(amount) + ("!" if crit else ""),
		col.lerp(Palette.GOLD_BRIGHT, 0.35) if crit else col, 60 if crit else 44)


func _on_player_damaged(_f: Fighter, amount: int, _kind: String) -> void:
	_float_text(player.global_position + Vector3(0, 2.4, 0), "−%d" % amount, Color(1, 0.3, 0.3), 40)
	hud_vignette.color.a = clampf(0.15 + amount / 120.0, 0.0, 0.5)


func _on_enemy_defeated(e: Enemy3D) -> void:
	enemies.erase(e)
	quest_world.on_enemy_defeated(e)
	var gold := int(e.data.get("gold", 0))
	if gold > 0:
		Game.apply_effects({"res": {"gold": gold}})
		_float_text(e.global_position + Vector3(0, 3.0, 0), "+%d Gold" % gold, Palette.GOLD_BRIGHT, 40)
	Progress.bump("enemies_slain")
	if e.data.get("elite", false):
		Progress.roll_loot("battle", "Bezwungen: " + e.display_name)
		Game.log_msg("%s bezwingt %s." % [Game.state.lord_name, e.display_name], "mission")
	if e.data.get("respawn", false):
		var id := e.type_id
		var home := e.home
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(level) and loc.get("encounters", []).size() > 0:
				spawn_enemy(id, home))
	_check_battle_end.call_deferred()
	if enemies.is_empty() and not e.data.get("respawn", false):
		toast("Die Gegend ist gesäubert.", Palette.SUCCESS)
	_refresh_hud()


func _on_player_died() -> void:
	_busy = true
	if not _battle.is_empty():
		Military.resolve_battle(_battle.uid, "overlord_fallen")
		_battle = {}
	await get_tree().create_timer(1.8).timeout
	_show_banner("Ainz zieht sich zurück", "Ein Overlord stirbt nicht – doch die Niederlage schmerzt Nazarick.")
	Game.apply_effects({"res": {"morale": -4}})
	Game.log_msg("Ainz musste sich aus %s nach Nazarick zurückziehen." % loc.name, "warning")
	await _fade(1.0, 0.6)
	player.revive()
	_busy = false
	await load_location("throne")
	await _fade(0.0, 0.6)


func _on_feedback(text: String, color: Color) -> void:
	hud_feedback.text = text
	hud_feedback.add_theme_color_override("font_color", color)
	hud_feedback.modulate.a = 1.0
	var tw := hud_feedback.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(hud_feedback, "modulate:a", 0.0, 0.5)


func _float_text(at: Vector3, text: String, col: Color, size: int) -> void:
	# Schadenszahl: springt groß auf, schrumpft auf Normalgröße und steigt in leichtem Bogen davon
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = NazarickTheme.display_font(800)
	l.font_size = size
	l.outline_size = 12
	l.modulate = col
	l.outline_modulate = Color(col.darkened(0.85), 0.9)
	l.pixel_size = 0.006
	l.no_depth_test = true
	l.render_priority = 10
	level.add_child(l)
	l.global_position = at
	var big := size >= 50
	l.scale = Vector3.ONE * (1.9 if big else 1.4)
	var side := Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", at + Vector3(0, 1.4, 0) + side, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.55)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)


func _rebuild_spell_bar() -> void:
	hud.rebuild_spells(player)


func _update_combat_hud(blocked: bool = false) -> void:
	hud.tick(get_process_delta_time(), blocked or _busy)
	if hud_vignette.color.a > 0.0:
		hud_vignette.color.a = maxf(0.0, hud_vignette.color.a - get_process_delta_time() * 0.8)


## Kampf läuft, wenn ein lebender Gegner Ainz bemerkt hat.
func in_combat() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD and e.global_position.distance_to(player.global_position) < e.aggro * 1.3:
			return true
	return false


func _has_option(d: Dictionary, key: String) -> bool:
	for o in d.get("options", []):
		if o.get("key", "") == key:
			return true
	return false


# =====================================================================
#  Schlachten persönlich anführen
# =====================================================================

var _battle: Dictionary = {}


## Teleportiert Ainz zum Schlachtfeld der Region und lässt die feindliche Armee als Welle antreten.
func _lead_battle(uid: String) -> void:
	var b: Dictionary = Game.state.battles[uid]
	var target := "katze"
	for l in Content.locations:
		if l.get("region", "") == b.region:
			target = l.id
	_battle = {"uid": uid, "enemies": [], "left": 0}
	await load_location(target, true)
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	var strength := int(b.enemy_strength)
	var n := clampi(strength / 40, 3, 9)
	var kinds := _battle_roster(b)
	var center: Vector3 = anchors.spawn + Vector3(0, 0, -16)
	for i in n:
		var kind: String = kinds[mini(i, kinds.size() - 1)] if i < 2 else kinds[i % kinds.size()]
		var e := spawn_enemy(kind, center + Vector3((i % 3 - 1) * 3.0, 0, -(i / 3) * 3.0))
		e.aggro = 60.0
		_battle.enemies.append(e)
	_battle.left = n
	_show_banner("Schlacht um " + World.region(b.region).get("short", ""), "%s – %d Gegner. Besiegt sie alle!" % [b.enemy_name, n])
	Audio.play_music("battle")


func _battle_roster(b: Dictionary) -> Array:
	var name := String(b.enemy_name).to_lower()
	if "engel" in name or "theokratie" in name or "schrift" in name:
		return ["angel", "soldier", "soldier"]
	if "elf" in name:
		return ["elf"]
	if "untot" in name or "katze" in name:
		return ["death_knight", "skeleton", "skeleton"]
	if "quagoa" in name or "frost" in name:
		return ["quagoa"]
	return ["soldier", "soldier", "death_knight"]


func _check_battle_end() -> void:
	if _battle.is_empty():
		return
	var alive := 0
	for e in _battle.enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD:
			alive += 1
	if alive > 0:
		return
	var uid: String = _battle.uid
	_battle = {}
	var summary := Military.resolve_battle(uid, "personal")
	Game.state_changed.emit()
	_show_banner("Sieg!", Military.last_result.get("text", "Der Feind ist vernichtet.").substr(0, 160))
	toast("Schlacht gewonnen – %d Auswirkungen." % summary.size(), Palette.SUCCESS)
	Audio.play_music(loc.get("music", "throne"))


# =====================================================================
#  Einführung (3D)
# =====================================================================

func start_tutorial() -> void:
	var steps := [
		["albedo", "Willkommen in Eurem Thronsaal, {lord}. Ihr bewegt Euch mit [b]WASD[/b], die Maus lenkt den Blick. Tretet an uns Wächter heran und drückt [b]E[/b], um eine Audienz zu gewähren."],
		["demiurge", "Am [b]Kriegsrat[/b] (links) liegen die Auftragstafel, die Karte des Kriegstisches und die Diplomatie. Befehle an uns Wächter erteilt Ihr dort – oder jederzeit mit [b]J[/b]."],
		["albedo", "Mein [b]Pult[/b] (rechts) birgt Verwaltung, Ausbau, Schatzkammer und meine Wochenziele für Euch. Der [b]Thron[/b] lässt die Zeit verstreichen – sie fließt aber auch von selbst."],
		["cocytus", "Das [b]Gate[/b] am Ende der Halle führt in jede erkundete Region. Dort lauern Feinde: [b]linke Maustaste[/b] leichter Schlag, [b]rechte[/b] schwerer, [b]Leertaste[/b] ausweichen, [b]F[/b] blocken – im rechten Moment pariert. [b]Q[/b] fixiert ein Ziel."],
		["shalltear", "Und Zauber, ~arinsu! [b]1–4[/b] und [b]R[/b] wirken Eure Magie, mit [b]X[/b] werdet Ihr zu Momon mit zwei Großschwertern. Und wenn Ihr mich lobt statt diese gehörnte Kuh – umso besser!"],
	]
	_tutorial_step(steps, 0)


func _tutorial_step(steps: Array, i: int) -> void:
	if i >= steps.size():
		Settings.set_value("tutorial_done", true)
		toast("Die Einführung ist beendet. Ihr findet sie im Menü (Esc).")
		return
	var dlg := TalkDialog.new(steps[i][0], steps[i][1])
	dlg.closed.connect(func(): await get_tree().create_timer(0.2).timeout; _tutorial_step(steps, i + 1))
	_open(dlg)

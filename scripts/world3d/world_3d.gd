extends Node3D
## Third-Person-Welt: Ainz bewegt sich frei durch Nazarick und die Neue Welt.
##
## • Orte aus data/locations.json, gebaut vom LocationBuilder
## • Wächter stehen dort, wo sie gerade sind (Thronsaal, eigene Ebene, Einsatzort, Feldzug)
## • Interaktion [E]: Gespräch/Audienz, Thron (Zeit), Kriegstisch (Aufträge, Karte, Diplomatie),
##   Albedos Pult (Verwaltung, Nazarick), Gate (Reisen), Lagetafel (regionale Aufträge)
## • Die Zeit läuft in Echtzeit weiter (ein Tag je DAY_SECONDS), Depeschen öffnen sich als Fenster
## Alle Systeme (Game, World, Military, Diplomacy, Progress) sind dieselben wie im klassischen Thronsaal.

const CLASSIC_SCENE := "res://scenes/throne_room.tscn"
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
var toast_box := VBoxContainer.new()
var celebrations := CelebrationLayer.new()
var hud_loc := Label.new()
var hud_date := Label.new()
var hud_res := RichTextLabel.new()
var hud_prompt := Label.new()
var hud_ticker := RichTextLabel.new()
var hud_weekly := RichTextLabel.new()
var hud_help := RichTextLabel.new()
var day_bar := ProgressBar.new()

var hud_bars: Dictionary = {}           ## hp/stamina/mana → [ProgressBar, Label]
var hud_style := Label.new()
var hud_spells := HBoxContainer.new()
var hud_feedback := Label.new()
var hud_vignette := ColorRect.new()
var enemies: Array[Enemy3D] = []
var _spell_slots: Array = []
var _focus: Actor3D
var _day_timer := 0.0
var _time_running := true
var _busy := false
var _last_autosave := 0


func _ready() -> void:
	if Game.state.is_empty():
		Game.new_game()
	add_child(player)
	_build_ui()
	_build_combat_hud()
	player.feedback.connect(_on_feedback)
	player.style_changed.connect(func(_s): _rebuild_spell_bar())
	player.damaged.connect(_on_player_damaged)
	player.died.connect(func(_f): _on_player_died())
	_rebuild_spell_bar()
	Game.state_changed.connect(_refresh_hud)
	Game.log_added.connect(func(_e): _refresh_ticker())
	Game.dispatches_arrived.connect(func(_n): Audio.sfx("dispatch", 0.8))
	var w3: Dictionary = Game.state.get("world3d", {})
	var start: String = w3.get("loc", "throne")
	load_location(start if Content.location_by_id.has(start) else "throne")
	_refresh_hud()
	await get_tree().create_timer(0.8).timeout
	_open_next_dispatch()


# =====================================================================
#  Orte laden
# =====================================================================

func load_location(id: String, fade: bool = false) -> void:
	if fade:
		await _fade(1.0, 0.35)
	if level:
		level.queue_free()
	actors.clear()
	enemies.clear()
	_focus = null
	loc = Content.location_by_id[id]
	level = Node3D.new()
	level.name = "Level_" + id
	add_child(level)
	LocationBuilder.environment(level, loc, LocationBuilder.preset(loc.kind))
	anchors = LocationBuilder.build(loc, level)
	_place_actors()
	_spawn_encounters()
	player.global_position = anchors.spawn
	player.velocity = Vector3.ZERO
	player.face(anchors.get("yaw", 0.0))
	if not Game.state.has("world3d"):
		Game.state["world3d"] = {}
	Game.state.world3d["loc"] = id
	Audio.play_music(loc.get("music", "throne"))
	hud_loc.text = loc.name
	_show_banner(loc.name, loc.get("desc", ""))
	if fade:
		await _fade(0.0, 0.5)


func _place_actors() -> void:
	var slots: Array = anchors.get("slots", []).duplicate()
	var region: String = loc.get("region", "nazarick" if loc.group == "nazarick" else "")
	var placed: Array = []
	# Wächter
	for cid in Game.unlocked_chars():
		var c := Game.cs(cid)
		var where := _char_whereabouts(cid)
		var here := false
		var variant := ""
		if loc.id == "throne" and where == "nazarick":
			here = true
		elif loc.get("keeper", "") == cid and where == "nazarick":
			here = true
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
	_update_combat_hud()
	# Echtzeit: Tage vergehen, solange niemand wartet
	if not blocked and _time_running and Game.pending().is_empty():
		_day_timer += delta
		if _day_timer >= DAY_SECONDS:
			_day_timer = 0.0
			_advance(1, false)
	day_bar.value = _day_timer / DAY_SECONDS * 100.0


func _animate(delta: float) -> void:
	if level == null:
		return
	for n in level.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("spin"):
			n.rotate_object_local(Vector3.UP, float(n.get_meta("spin")) * delta)
	for l in level.find_children("*", "OmniLight3D", true, false):
		if l.has_meta("flicker"):
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
	if _focus and overlay_layer.get_child_count() == 0:
		hud_prompt.text = "[E]  %s  ·  %s" % [_focus.prompt, _focus.label]
		hud_prompt.visible = true
	else:
		hud_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if overlay_layer.get_child_count() > 0 or _busy:
		return
	if event.is_action_pressed("interact") and _focus:
		_interact(_focus)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE: _pause_menu()
		KEY_J: _open(MissionBoard.new(loc.get("region", "")))
		KEY_M: _open_map()
		KEY_P: _open(DiplomacyView.new())
		KEY_V: _open(AdministrationView.new())
		KEY_N: _open(NazarickView.new())
		KEY_U: _open(CharacterView.new("albedo"))
		KEY_C: _open(ChronicleView.new())
		KEY_G: _gate_menu()
		KEY_T: _time_menu()
		KEY_H: hud_help.visible = not hud_help.visible
		KEY_TAB: _to_classic()
		KEY_ENTER, KEY_KP_ENTER: _open_next_dispatch(true)
		KEY_F5:
			SaveSystem.save_game(1)
			toast("Gespeichert in Chronik 1.")


func _interact(a: Actor3D) -> void:
	match a.kind:
		"char":
			var cv := CharacterView.new(a.id)
			cv.closed.connect(_refresh_actors_soft)
			_open(cv)
		"npc":
			_open(TalkDialog.new(a.id, a.line if a.line != "" else "…"))
		"object":
			match a.id:
				"throne": _time_menu()
				"table": _war_table()
				"desk": _desk_menu()
				"gate": _gate_menu()
				"board": _region_menu()


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
		{"text": "♛  Klassische Thronsaal-Übersicht", "sub": "Alle Systeme auf einen Blick (Tab)", "action": _to_classic},
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
			"sub": l.get("desc", "").substr(0, 90), "disabled": not ok or here, "tip": why if not ok else "",
			"action": func(): _travel(l.id)})
	_open(ChoiceMenu.new("Gate", "Wohin soll das Tor sich öffnen?", entries, 980))


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
		{"text": "⚙  Einstellungen", "action": func(): _open(SettingsDialog.new(true))},
		{"text": "♛  Klassische Thronsaal-Übersicht", "action": _to_classic},
		{"text": "✕  Zum Titelbildschirm", "action": func(): get_tree().change_scene_to_file(TITLE_SCENE)},
	], 620))


func _load_menu() -> void:
	var dlg := SaveLoadDialog.new(false)
	dlg.loaded.connect(func(): get_tree().reload_current_scene())
	_open(dlg)


func _travel(id: String) -> void:
	Audio.sfx("gong", 0.6)
	await load_location(id, true)


func _to_classic() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(CLASSIC_SCENE)


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
	var dlg: Overlay = BattleView.new(d) if d.kind == "battle" and Game.state.battles.has(d.get("context", {}).get("battle", "")) else DispatchDialog.new(d)
	dlg.closed.connect(func():
		await get_tree().create_timer(0.15).timeout
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
	# Kopfzeile
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.VOID, 0.72), Color(Palette.GOLD_DARK, 0.8), 1, 10, Color.TRANSPARENT, 0, 10))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	top.add_child(hb)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", -2)
	hud_loc.theme_type_variation = "GoldLabel"
	hud_loc.add_theme_font_size_override("font_size", 22)
	hud_date.theme_type_variation = "MutedLabel"
	lv.add_child(hud_loc)
	lv.add_child(hud_date)
	day_bar.show_percentage = false
	day_bar.custom_minimum_size = Vector2(220, 4)
	day_bar.add_theme_stylebox_override("fill", NazarickTheme.box(Palette.GOLD, Color.TRANSPARENT, 0, 2))
	day_bar.tooltip_text = "Fortschritt des aktuellen Tages"
	lv.add_child(day_bar)
	hb.add_child(lv)
	hud_res.bbcode_enabled = true
	hud_res.fit_content = true
	hud_res.scroll_active = false
	hud_res.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_res.add_theme_font_size_override("normal_font_size", 18)
	hud_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(hud_res)
	# Wochenziele & Hinweise rechts
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.VOID, 0.6), Color(Palette.VIOLET, 0.5), 1, 10, Color.TRANSPARENT, 0, 10))
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -400
	right.offset_right = -14
	right.offset_top = 92
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_weekly.bbcode_enabled = true
	hud_weekly.fit_content = true
	hud_weekly.scroll_active = false
	hud_weekly.add_theme_font_size_override("normal_font_size", 14)
	hud_weekly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(hud_weekly)
	ui_root.add_child(right)
	# Ticker unten links
	hud_ticker.bbcode_enabled = true
	hud_ticker.fit_content = true
	hud_ticker.scroll_active = false
	hud_ticker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud_ticker.offset_top = 96
	hud_ticker.offset_right = 620
	hud_ticker.offset_left = 18
	hud_ticker.offset_bottom = 200
	hud_ticker.add_theme_font_size_override("normal_font_size", 15)
	hud_ticker.add_theme_constant_override("outline_size", 6)
	hud_ticker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_ticker)
	# Interaktionshinweis
	hud_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.offset_top = -170
	hud_prompt.offset_bottom = -130
	hud_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_prompt.theme_type_variation = "GoldLabel"
	hud_prompt.add_theme_font_size_override("font_size", 24)
	hud_prompt.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.VOID, 0.8), Palette.GOLD, 1, 10, Color(Palette.GOLD, 0.3), 10, 10))
	hud_prompt.visible = false
	ui_root.add_child(hud_prompt)
	# Steuerungshilfe
	hud_help.bbcode_enabled = true
	hud_help.fit_content = true
	hud_help.scroll_active = false
	hud_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_help.offset_left = -360
	hud_help.offset_top = -330
	hud_help.offset_right = -18
	hud_help.offset_bottom = -14
	hud_help.add_theme_font_size_override("normal_font_size", 14)
	hud_help.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.VOID, 0.65), Color(Palette.GOLD_DARK, 0.6), 1, 10, Color.TRANSPARENT, 0, 10))
	hud_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_help.text = "[color=#d4af37][b]Steuerung[/b][/color]  [color=#8f86a3](H ausblenden)[/color]\n" + \
		"WASD gehen · Shift rennen · Maus Kamera · Rad Zoom\n" + \
		"[color=#ff9a8a]LMB[/color] leichte · [color=#ff9a8a]RMB[/color] schwere Attacke\n[b]Leertaste[/b] Rolle · [b]F[/b] Block/Parade · [b]Q[/b] Lock-on\n" + \
		"[b]1–4, R[/b] Zauber · [b]X[/b] Ainz ↔ Momon\n" + \
		"[b]E[/b] sprechen / benutzen · [b]G[/b] Gate · [b]T[/b] Zeit\n[b]J[/b] Aufträge · [b]M[/b] Karte · [b]P[/b] Diplomatie\n" + \
		"[b]V[/b] Verwaltung · [b]N[/b] Nazarick · [b]U[/b] Wächter\n[b]Tab[/b] klassische Übersicht · [b]Esc[/b] Menü"
	ui_root.add_child(hud_help)
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(overlay_layer)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.position.y = 100
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(toast_box)
	ui_root.add_child(celebrations)


func _refresh_hud() -> void:
	if not is_inside_tree():
		return
	var s := Game.state
	hud_date.text = "Tag %d · %s · Kapitel %s" % [s.day, Game.format_date(s.day), Content.chapter(s.chapter).numeral]
	var parts := PackedStringArray()
	for k in Game.RESOURCE_KEYS:
		parts.append("[color=%s]%s %d[/color]" % [Palette.hex(Palette.RESOURCE_COLORS[k]), Palette.RESOURCE_ICONS[k], int(s.resources.get(k, 0))])
	var pend := Game.pending().size()
	hud_res.text = "[right]%s%s[/right]" % ["   ".join(parts), "    [color=#ff4a5a][b]✉ %d Depesche%s [Enter][/b][/color]" % [pend, "n" if pend != 1 else ""] if pend > 0 else ""]
	var p := Progress.ps()
	var lines := PackedStringArray()
	lines.append("[color=#d4af37][b]❤ Wochenziele[/b][/color] [color=#8f86a3]noch %d T.[/color]" % Progress.week_days_left())
	for g in p.goals:
		var done := Progress.goal_done(g)
		lines.append("[color=%s]%s %s (%d/%d)[/color]" % ["#6fdc8c" if done else "#ebe2cc", "✔" if done else "◇", g.text, mini(Progress.goal_value(g), int(g.target)), int(g.target)])
	for o in Game.objectives():
		if not o[1]:
			lines.append("[color=#c79bff]⚜ %s[/color]" % o[0])
			break
	for t in s.get("threats", []):
		lines.append("[color=#ff4a5a]⚠ %s – %d T.[/color]" % [Game.mission(t.mission_id).get("title", "Bedrohung"), World.threat_days_left(t)])
	hud_weekly.text = "\n".join(lines)
	_refresh_ticker()


func _refresh_ticker() -> void:
	var lines := PackedStringArray()
	var entries: Array = Game.state.get("log", [])
	for e in entries.slice(maxi(0, entries.size() - 4)):
		lines.append("[color=#7a6f8f]T%d[/color]  [color=%s]%s[/color]" % [e.day, Palette.LOG_COLORS.get(e.cat, "#b7aecb"), e.text])
	hud_ticker.text = "\n".join(lines)


func toast(text: String, color: Color = Palette.GOLD_BRIGHT) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.ABYSS, 0.95), color, 1, 10, Color(color, 0.4), 12, 10))
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	toast_box.add_child(p)
	UIFx.pop_in(p, 0.25)
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _show_banner(title: String, sub: String) -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_top = -180
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "TitleLabel"
	t.add_theme_font_size_override("font_size", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_override("font", NazarickTheme.italic_font(600))
	s.add_theme_font_size_override("font_size", 20)
	s.add_theme_color_override("font_color", Palette.PARCHMENT)
	s.add_theme_constant_override("outline_size", 6)
	s.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 900
	vb.add_child(s)
	ui_root.add_child(vb)
	vb.modulate.a = 0.0
	var tw := vb.create_tween()
	tw.tween_property(vb, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(vb, "modulate:a", 0.0, 0.8)
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
	_float_text(f.global_position + Vector3(randf_range(-0.4, 0.4), 2.4, 0), str(amount), col, 56 if amount >= 40 else 44)


func _on_player_damaged(_f: Fighter, amount: int, _kind: String) -> void:
	_float_text(player.global_position + Vector3(0, 2.4, 0), "−%d" % amount, Color(1, 0.3, 0.3), 40)
	hud_vignette.color.a = clampf(0.15 + amount / 120.0, 0.0, 0.5)


func _on_enemy_defeated(e: Enemy3D) -> void:
	enemies.erase(e)
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
	if enemies.is_empty() and not e.data.get("respawn", false):
		toast("Die Gegend ist gesäubert.", Palette.SUCCESS)
	_refresh_hud()


func _on_player_died() -> void:
	_busy = true
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
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = NazarickTheme.display_font(800)
	l.font_size = size
	l.outline_size = 10
	l.modulate = col
	l.pixel_size = 0.006
	l.no_depth_test = true
	level.add_child(l)
	l.global_position = at
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", at + Vector3(0, 1.2, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _build_combat_hud() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 18
	box.offset_top = -170
	box.offset_bottom = -16
	box.offset_right = 420
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(box)
	hud_style.theme_type_variation = "GoldLabel"
	hud_style.add_theme_constant_override("outline_size", 6)
	hud_style.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	box.add_child(hud_style)
	for spec in [["hp", "Leben", Color(0.85, 0.12, 0.2)], ["stamina", "Ausdauer", Color(0.95, 0.78, 0.3)], ["mana", "Mana", Color(0.35, 0.55, 1.0)]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(320, 14 if spec[0] == "hp" else 9)
		bar.add_theme_stylebox_override("fill", NazarickTheme.box(spec[2], Color.TRANSPARENT, 0, 4, Color(spec[2], 0.5), 6, 0))
		bar.add_theme_stylebox_override("background", NazarickTheme.box(Color(0, 0, 0, 0.6), Color(spec[2], 0.4), 1, 4))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		row.add_child(l)
		box.add_child(row)
		hud_bars[spec[0]] = [bar, l]
	hud_spells.add_theme_constant_override("separation", 6)
	hud_spells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hud_spells)
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
	hud_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_vignette.color = Color(0.6, 0.0, 0.05, 0.0)
	hud_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_vignette)
	ui_root.move_child(hud_vignette, 0)


func _rebuild_spell_bar() -> void:
	for c in hud_spells.get_children():
		c.queue_free()
	_spell_slots.clear()
	var keys := ["1", "2", "3", "4", "R"]
	var sp: Array = player.spells()
	for i in sp.size():
		var d: Dictionary = Content.combat.spells[sp[i]]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(58, 58)
		slot.tooltip_text = "%s [%s] – %s\nKosten: %d %s · Abklingzeit %.0f s" % [d.name, keys[i], d.desc, int(d.cost), "Mana" if d.cost_type == "mana" else "Ausdauer", float(d.cooldown)]
		slot.add_theme_stylebox_override("panel", NazarickTheme.box(Color(0, 0, 0, 0.7), Color(d.color), 2, 8, Color(Color(d.color), 0.3), 6, 2))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", -4)
		slot.add_child(vb)
		var ic := Label.new()
		ic.text = d.icon
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.add_theme_font_size_override("font_size", 24)
		ic.add_theme_color_override("font_color", Color(d.color))
		vb.add_child(ic)
		var k := Label.new()
		k.text = keys[i]
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.add_theme_font_size_override("font_size", 13)
		vb.add_child(k)
		hud_spells.add_child(slot)
		_spell_slots.append([sp[i], slot, k, keys[i]])


func _update_combat_hud() -> void:
	if hud_bars.is_empty():
		return
	var vals := {"hp": [player.hp, player.max_hp], "stamina": [maxf(0.0, player.stamina), player.max_stamina], "mana": [player.mana, player.max_mana]}
	for k in vals:
		var bar: ProgressBar = hud_bars[k][0]
		bar.max_value = maxf(1.0, vals[k][1])
		bar.value = vals[k][0]
		(hud_bars[k][1] as Label).text = "%d / %d" % [int(vals[k][0]), int(vals[k][1])]
		bar.get_parent().visible = vals[k][1] > 0.0
	var st: String = Fighter.STATE_NAMES[player.state]
	var extra := ""
	if player.lock and is_instance_valid(player.lock):
		extra = "  ·  ◆ " + player.lock.display_name
	if player.shield_time > 0.0:
		extra += "  ·  ⛨ Barriere %.0fs" % player.shield_time
	hud_style.text = "%s  [%s]%s" % [player.display_name, st, extra]
	for s in _spell_slots:
		var cd := float(player.cooldowns.get(s[0], 0.0))
		var ready := player.spell_ready(s[0])
		(s[1] as Control).modulate = Color(1, 1, 1, 1) if ready else Color(0.5, 0.5, 0.55, 0.85)
		(s[2] as Label).text = ("%.0f" % ceilf(cd)) if cd > 0.0 else s[3]
	if hud_vignette.color.a > 0.0:
		hud_vignette.color.a = maxf(0.0, hud_vignette.color.a - get_process_delta_time() * 0.8)


## Kampf läuft, wenn ein lebender Gegner Ainz bemerkt hat.
func in_combat() -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD and e.global_position.distance_to(player.global_position) < e.aggro * 1.3:
			return true
	return false

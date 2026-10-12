class_name WorldMapView
extends Overlay
## Weltkarte: Regionen, Einfluss, Bedrohungen, Legionen und feindliche Heere.
## Rechts: Details der gewählten Region bzw. Verwaltung der Legionen
## (rekrutieren, Feldherr bestimmen, Marsch- und Eroberungsbefehle).

signal open_missions(region_id: String)

var canvas := MapTable3D.new()
var tabs := TabContainer.new()
var region_box := VBoxContainer.new()
var army_box := VBoxContainer.new()
var status_label := RichTextLabel.new()
var day_label := Label.new()
var stop_button := Button.new()
var time_buttons: Array[Button] = []
var _playing := false
var _stop := false
var _region := "nazarick"
var _army := ""


func _init(start_region: String = "nazarick") -> void:
	super._init(Vector2(1540, 840))
	_region = start_region
	content.add_child(make_header("Die Neue Welt", "Einflussgebiete, Wege und Heere – Klickt eine Region oder eine Legion an."))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.region_clicked.connect(_on_region)
	canvas.army_clicked.connect(_on_army)
	left.add_child(canvas)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	left.add_child(bottom)
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("normal_font_size", 16)
	bottom.add_child(status_label)
	# Zeitsteuerung direkt auf der Karte: Heere marschieren sichtbar Tag für Tag
	day_label.theme_type_variation = "GoldLabel"
	bottom.add_child(day_label)
	for spec in [["▶ 1 Tag", 1], ["▶▶ 1 Woche", 7]]:
		var b := Button.new()
		b.text = spec[0]
		b.theme_type_variation = "ButtonWarning"
		b.pressed.connect(_play.bind(spec[1]))
		bottom.add_child(b)
		time_buttons.append(b)
	stop_button.text = "■"
	stop_button.tooltip_text = "Anhalten"
	stop_button.disabled = true
	stop_button.pressed.connect(func(): _stop = true)
	bottom.add_child(stop_button)

	tabs.custom_minimum_size.x = 430
	row.add_child(tabs)
	for pair in [[region_box, "Region"], [army_box, "Legionen"]]:
		var sc := ScrollContainer.new()
		sc.name = pair[1]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pair[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pair[0].add_theme_constant_override("separation", 8)
		sc.add_child(pair[0])
		tabs.add_child(sc)
	if not Game.state.armies.is_empty():
		_army = Game.state.armies[0].uid
	Game.state_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if Game.state_changed.is_connected(_refresh):
		Game.state_changed.disconnect(_refresh)


func _on_region(id: String) -> void:
	_region = id
	tabs.current_tab = 0
	Audio.sfx("click", 0.6)
	_refresh()


func _on_army(uid: String) -> void:
	_army = uid
	tabs.current_tab = 1
	Audio.sfx("click", 0.6)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() and not is_node_ready():
		pass
	if Military.army(_army).is_empty():
		_army = Game.state.armies[0].uid if not Game.state.armies.is_empty() else ""
	canvas.selected_region = _region
	canvas.selected_army = _army
	_build_status()
	_build_region()
	_build_armies()


## Lässt Tage auf der Karte animiert verstreichen. Stoppt bei Depeschen.
func _play(days: int) -> void:
	if _playing:
		return
	if not Game.pending().is_empty():
		_toast("Erst müssen die Depeschen beantwortet werden – schließt die Karte.")
		return
	_playing = true
	_stop = false
	stop_button.disabled = false
	for b in time_buttons:
		b.disabled = true
	Audio.sfx("gong", 0.4)
	for i in days:
		if _stop or not is_inside_tree():
			break
		var tw := create_tween()
		tw.tween_property(canvas, "anim_frac", 1.0, 0.55).from(0.0)
		await tw.finished
		if not is_instance_valid(self) or _closing:
			return
		canvas.anim_frac = 0.0
		Game.advance(1)
		if not Game.pending().is_empty():
			_toast("Eine Depesche ist eingetroffen.")
			break
	_playing = false
	if is_inside_tree():
		stop_button.disabled = true
		for b in time_buttons:
			b.disabled = false
		_refresh()
	if not Game.pending().is_empty() and is_inside_tree():
		await get_tree().create_timer(0.6).timeout
		close()


func _build_status() -> void:
	day_label.text = "Tag %d" % Game.state.day
	var inc := World.daily_income()
	var up := World.daily_upkeep()
	var t := "[color=#d4af37]Tagesbilanz:[/color] [color=#6fdc8c]+%d Gold[/color] Einkünfte · [color=#ff7a7a]−%d Gold[/color] Unterhalt (davon Armeen %d)" % [roundi(inc.gold + World.decree_daily_gold()), up, roundi(Military.total_upkeep() * Game.diff("upkeep"))]
	if not Game.state.enemy_armies.is_empty():
		for e in Game.state.enemy_armies:
			var eta := Military.path_days(e.location, e.path)
			t += "\n[color=#ff4a5a]⚔ %s (Stärke %d) → %s, Ankunft in ~%d T.[/color]" % [e.name, int(e.strength), World.region(e.target).short, eta]
	status_label.text = t


func _clear(box: Control) -> void:
	for c in box.get_children():
		c.queue_free()


func _label(text: String, variation: String = "", size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


func _rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", 17)
	return r


func _button(text: String, variation: String, cb: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.disabled = disabled
	b.pressed.connect(cb)
	return b


# ------------------------------------------------------------------ Region
func _build_region() -> void:
	_clear(region_box)
	var r := World.region(_region)
	var st := World.rs(_region)
	var tex: Texture2D = Content.find_image("backgrounds", r.get("image", ""))
	if tex and st.discovered:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size.y = 120
		tr.clip_contents = true
		region_box.add_child(tr)
	region_box.add_child(_label(r.name if st.discovered else "Unerforschtes Gebiet", "HeaderLabel"))
	if not st.discovered:
		region_box.add_child(_rich("[color=#8f86a3]Über dieses Gebiet ist nichts bekannt. Schickt einen Kundschafter (Auftrag »Erkundung«), sobald die Lage es erlaubt.[/color]"))
		var m: Dictionary = Content.missions.get("x_" + _region, {})
		if not m.is_empty() and Game.mission_available(m):
			region_box.add_child(_button("⚑ Erkundung beauftragen", "ButtonPrimary", func(): open_missions.emit(_region); close()))
		return
	var hostile: bool = r.get("hostile", false)
	region_box.add_child(_label("%s%s" % [World.control_label(st.influence), "  ·  feindliches Gebiet" if hostile else ""], "GoldLabel", 16))
	region_box.add_child(_rich("[color=#b7aecb]%s[/color]" % r.desc))
	var fid: String = r.get("faction", "")
	if fid != "" and Diplomacy.is_known(fid):
		var stn := Diplomacy.stance(fid)
		region_box.add_child(_rich("[color=#d4af37]Herrschaft:[/color] %s – [color=%s]%s[/color]%s" % [Diplomacy.faction(fid).name, stn[1], stn[0],
			"  [color=#ff9a3c](Eroberung im Frieden: Beziehung −45, Ruf −6)[/color]" if not Diplomacy.at_war(fid) and Military.can_conquer(_region) else ""]))
	var ib := StatBar.new("Einfluss", Palette.GOLD, "", 90)
	ib.set_value(st.influence)
	region_box.add_child(ib)
	var ub := StatBar.new("Unruhe", Palette.CRIMSON, "", 90)
	ub.set_value(st.unrest)
	region_box.add_child(ub)
	var factor: float = st.influence / 100.0 * (1.0 - st.unrest / 150.0)
	var g := float(r.income.get("gold", 0)) * factor * Game.diff("income")
	region_box.add_child(_rich("[color=#d4af37]Ertrag:[/color] %.1f Gold/Tag  ·  [color=#d4af37]bei voller Kontrolle:[/color] %d Gold" % [g, int(r.income.get("gold", 0))]))
	if Military.can_conquer(_region):
		region_box.add_child(_rich("[color=#ff9a3c]Garnison:[/color] %s – Stärke ~%d" % [r.get("defenders", "Verteidiger"), roundi(Military.garrison(_region) * Game.diff("enemy"))]))
	for t in Game.state.threats:
		if t.region == _region:
			region_box.add_child(_rich("[color=#ff4a5a]⚠ %s – noch %d Tage[/color]" % [Game.mission(t.mission_id).get("title", "Bedrohung"), World.threat_days_left(t)]))
	var n := Game.available_missions().filter(func(m): return m.get("region", "") == _region).size()
	region_box.add_child(_button("Aufträge in dieser Region (%d)" % n, "ButtonPrimary", func(): open_missions.emit(_region); close(), n == 0))
	# Armee-Befehle
	var a := Military.army(_army)
	if not a.is_empty():
		region_box.add_child(HSeparator.new())
		region_box.add_child(_label("Befehl an: " + a.name, "SubHeaderLabel"))
		var p := Military.path(a.location, _region)
		var days := Military.path_days(a.location, p)
		var here: bool = a.location == _region
		region_box.add_child(_button("⚔ Hierher marschieren (%d Tage)" % days if not here else "⚔ Die Legion steht hier", "Button",
			func(): _order(a.uid, false), here or Military.base_strength(a) <= 0))
		if Military.can_conquer(_region):
			region_box.add_child(_button("☠ Region erobern (%d Tage)" % days, "ButtonDanger", func(): _order(a.uid, true), Military.base_strength(a) <= 0))


func _order(army_uid: String, conquer: bool) -> void:
	var res := Military.order_move(army_uid, _region, conquer)
	Audio.sfx("order", 0.8)
	_toast(res.get("text", ""))
	_refresh()


func _toast(t: String) -> void:
	if t != "" and get_tree().current_scene.has_method("toast"):
		get_tree().current_scene.toast(t)


# ------------------------------------------------------------------ Legionen
func _build_armies() -> void:
	_clear(army_box)
	army_box.add_child(_rich("[color=#b7aecb]Legionen werden im Großen Grab ausgehoben. Ein Wächter als Feldherr verleiht große Stärke – steht aber für Aufträge nicht zur Verfügung. Jede Einheit kostet täglichen Unterhalt.[/color]"))
	for a in Game.state.armies:
		var where: String = World.region(a.location).short
		if not a.path.is_empty():
			where = "marschiert nach " + World.region(a.path.back()).short
		var cmd: String = Game.char_name(a.commander).split(" ")[0] if a.commander != "" else "ohne Feldherr"
		var b := _button("%s\nStärke %d · %s · %s" % [a.name, Military.strength(a), where, cmd], "ButtonCard", func(): _army = a.uid; _refresh())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = a.uid == _army
		army_box.add_child(b)
	army_box.add_child(_button("+ Neue Legion aufstellen", "Button", func():
		var a := Military.create_army()
		if not a.is_empty():
			_army = a.uid
		_refresh(), not Military.can_create_army()))
	var a := Military.army(_army)
	if a.is_empty():
		return
	army_box.add_child(HSeparator.new())
	army_box.add_child(_label(a.name, "HeaderLabel"))
	# Feldherr
	var row := HBoxContainer.new()
	var fl := Label.new()
	fl.text = "Feldherr:"
	fl.custom_minimum_size.x = 90
	row.add_child(fl)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_item("— keiner —")
	ob.set_item_metadata(0, "")
	var idx := 1
	for cid in Game.unlocked_chars():
		if cid == a.commander or Game.is_available(cid):
			var bonus := int(Military.commander_bonus(cid) * 100)
			ob.add_item("%s  (+%d %%)" % [Game.char_name(cid).split(" ")[0], bonus])
			ob.set_item_metadata(idx, cid)
			if cid == a.commander:
				ob.select(idx)
			idx += 1
	ob.item_selected.connect(func(i): Military.set_commander(a.uid, ob.get_item_metadata(i)); _refresh())
	row.add_child(ob)
	army_box.add_child(row)
	if a.commander != "":
		army_box.add_child(_rich("[color=#c79bff]%s[/color]" % Content.systems.commanders.get(a.commander, {}).get("text", "")))
	# Truppen
	var units := PackedStringArray()
	for k in a.units:
		var u := Military.unit(k)
		units.append("%s %d× %s (Stärke %d)" % [u.icon, a.units[k], u.name, int(u.strength) * int(a.units[k])])
	army_box.add_child(_rich("[color=#d4af37]Truppen:[/color]\n" + ("\n".join(units) if not units.is_empty() else "[color=#8f86a3]keine[/color]")))
	army_box.add_child(_rich("[color=#d4af37]Gesamtstärke:[/color] %d" % Military.strength(a)))
	# Rekrutierung
	if a.location == "nazarick" and a.path.is_empty():
		army_box.add_child(_label("Rekrutieren", "SubHeaderLabel"))
		for u in Military.available_units():
			var b := _button("%s %s  ·  %d Gold  ·  Stärke %d  ·  −%d/Tag" % [u.icon, u.name, int(u.cost), int(u.strength), int(u.upkeep)], "ButtonCard",
				func():
					var res := Military.recruit(a.uid, u.id)
					Audio.sfx("order" if res.ok else "rebuke", 0.6)
					if not res.ok:
						_toast(res.text)
					_refresh(), Game.state.resources.gold < int(u.cost))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = u.desc
			army_box.add_child(b)
	else:
		army_box.add_child(_rich("[color=#8f86a3]Verstärkungen können nur im Großen Grab ausgehoben werden.[/color]"))
		if a.location != "nazarick":
			army_box.add_child(_button("Nach Nazarick zurückkehren", "Button", func(): _region = "nazarick"; _order(a.uid, false)))
	army_box.add_child(_button("Legion auflösen", "ButtonGhost", func(): Military.disband(a.uid); _refresh()))

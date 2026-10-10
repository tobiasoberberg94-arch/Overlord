class_name MissionBoard
extends Overlay
## Auftragstafel: Auftrag wählen → Vollstrecker wählen → Befehlsart wählen → erteilen.
##
## Zeigt dabei Persönlichkeits-Hinweise: ob ein Untertan zu eigenmächtiger
## Auslegung neigt, welchen Stil er bei „Freier Hand“ wählt, und ob die
## Vergabe die Eifersucht einer Rivalin weckt.

signal mission_assigned

const KIND_BADGES := {"threat": ["⚠ BEDROHUNG", "#ff4a5a"], "main": ["★ HAUPTAUFTRAG", "#f5d77a"], "proposal": ["✧ VORSCHLAG", "#c79bff"], "side": ["◆ NEBENAUFTRAG", "#8fb8ff"]}

var list_box := VBoxContainer.new()
var detail := RichTextLabel.new()
var chars_box := GridContainer.new()
var directives_box := GridContainer.new()
var directive_desc := RichTextLabel.new()
var forecast := RichTextLabel.new()
var confirm := Button.new()
var partner_opt := OptionButton.new()
var region_filter := OptionButton.new()
var _partner := ""
var _region := ""

var _mission_id := ""
var _char_id := ""
var _directive := "freie_hand"
var _mission_group := ButtonGroup.new()
var _char_group := ButtonGroup.new()
var _dir_group := ButtonGroup.new()


func _init(region_id: String = "") -> void:
	super._init(Vector2(1480, 840))
	_region = region_id
	content.add_child(make_header("Auftragstafel von Nazarick", "Erteilt Euren Untertanen Befehle – sie werden sie auf ihre eigene Weise ausführen."))
	content.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)

	# ---------------- Spalte 1: Filter + Auftragsliste
	var lcol := VBoxContainer.new()
	lcol.custom_minimum_size = Vector2(420, 0)
	row.add_child(lcol)
	region_filter.item_selected.connect(func(i): _region = region_filter.get_item_metadata(i); _build_list())
	lcol.add_child(region_filter)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(420, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)
	lcol.add_child(scroll)

	# ---------------- Spalte 2: Details
	var mid := PanelContainer.new()
	mid.theme_type_variation = "PanelDim"
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(detail)
	row.add_child(mid)

	# ---------------- Spalte 3: Vollstrecker & Befehl
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(_section("Vollstrecker"))
	chars_box.columns = 3
	chars_box.add_theme_constant_override("h_separation", 6)
	chars_box.add_theme_constant_override("v_separation", 6)
	right.add_child(chars_box)
	var prow := HBoxContainer.new()
	var pl := Label.new()
	pl.text = "Unterstützung:"
	prow.add_child(pl)
	partner_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	partner_opt.item_selected.connect(func(i): _partner = partner_opt.get_item_metadata(i); _update_forecast())
	prow.add_child(partner_opt)
	right.add_child(prow)
	right.add_child(_section("Befehlsart"))
	directives_box.columns = 3
	directives_box.add_theme_constant_override("h_separation", 6)
	directives_box.add_theme_constant_override("v_separation", 6)
	right.add_child(directives_box)
	for key in Content.directives:
		var dd: Dictionary = Content.directives[key]
		var b := Button.new()
		b.text = "%s %s" % [dd.icon, dd.name]
		b.toggle_mode = true
		b.button_group = _dir_group
		b.theme_type_variation = "ButtonCard"
		b.add_theme_font_size_override("font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = key == _directive
		b.pressed.connect(func(): _directive = key; _update_forecast())
		directives_box.add_child(b)
	directive_desc.bbcode_enabled = true
	directive_desc.fit_content = true
	directive_desc.scroll_active = false
	directive_desc.add_theme_font_size_override("normal_font_size", 17)
	right.add_child(directive_desc)
	forecast.bbcode_enabled = true
	forecast.fit_content = true
	forecast.scroll_active = false
	forecast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forecast.add_theme_font_size_override("normal_font_size", 17)
	right.add_child(forecast)
	confirm.text = "⚜  Befehl erteilen  ⚜"
	confirm.theme_type_variation = "ButtonPrimary"
	confirm.custom_minimum_size = Vector2(0, 54)
	confirm.add_theme_font_size_override("font_size", 19)
	confirm.pressed.connect(_on_confirm)
	right.add_child(confirm)
	_build_list()


func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	l.theme_type_variation = "SubHeaderLabel"
	l.add_theme_color_override("font_color", Palette.GOLD)
	return l


func _build_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	_build_filter()
	var missions := Game.available_missions()
	if _region != "":
		missions = missions.filter(func(m): return m.get("region", "") == _region)
	if missions.is_empty():
		_add_cooldown_note()
		var l := Label.new()
		l.text = "Derzeit liegen keine Aufträge vor.\nLasst Zeit vergehen – Eure Untertanen werden neue Pläne schmieden."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(l)
		_select_mission("")
		return
	var i := 0
	for m in missions:
		var kind := Game.mission_kind(m)
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _mission_group
		b.theme_type_variation = "ButtonCard"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 86)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var diff := clampi(int(m.difficulty) / 17, 1, 5)
		var badge := ""
		match Game.mission_badge(m):
			"repeat": badge = "   ↻ WIEDERHOLT ×%d" % int(Game.state.completed[m.id])
			"retry": badge = "   ✗ ERNEUTER VERSUCH"
		if kind == "threat":
			var t := World.threat_for_mission(m.id)
			badge = "   · noch %d Tage!" % World.threat_days_left(t) if not t.is_empty() else ""
		b.text = "%s%s\n%s\n⚑ %s  ·  ◷ %d T.  ·  %s" % [KIND_BADGES[kind][0], badge, m.title, m.get("location", "?"), int(m.days),
			"◆".repeat(diff) + "◇".repeat(5 - diff)]
		b.add_theme_color_override("font_color", Color(KIND_BADGES[kind][1]).lerp(Palette.PARCHMENT, 0.45))
		b.pressed.connect(_select_mission.bind(m.id))
		list_box.add_child(b)
		UIFx.pop_in(b, 0.25, 0.03 * i)
		if i == 0:
			b.button_pressed = true
		i += 1
	_add_cooldown_note()
	_select_mission(missions[0].id)


## Regionsfilter (mit Anzahl verfügbarer Aufträge je Region).
func _build_filter() -> void:
	region_filter.clear()
	var all := Game.available_missions()
	region_filter.add_item("Alle Regionen (%d)" % all.size())
	region_filter.set_item_metadata(0, "")
	var idx := 1
	for r in Content.regions:
		var n := all.filter(func(m): return m.get("region", "") == r.id).size()
		if n == 0 and r.id != _region:
			continue
		region_filter.add_item("%s (%d)" % [r.short, n])
		region_filter.set_item_metadata(idx, r.id)
		if r.id == _region:
			region_filter.select(idx)
		idx += 1


## Hinweis auf erledigte, wiederholbare Aufträge, die sich gerade „abkühlen“.
func _add_cooldown_note() -> void:
	var waiting := PackedStringArray()
	for m in Content.missions.values():
		if m.get("repeatable", false) and Game.state.completed.has(m.id) and not Game.is_mission_active(m.id):
			var left := Game.repeat_days_left(m)
			if left > 0:
				waiting.append("%s (in %d T.)" % [m.title, left])
	if waiting.is_empty():
		return
	var l := Label.new()
	l.text = "↻ Wieder verfügbar: " + ", ".join(waiting)
	l.theme_type_variation = "MutedLabel"
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(l)


func _select_mission(mid: String) -> void:
	_mission_id = mid
	_char_id = ""
	for c in chars_box.get_children():
		c.queue_free()
	if mid == "":
		detail.text = ""
		_update_forecast()
		return
	var m := Game.mission(mid)
	var kind := Game.mission_kind(m)
	var t := "[font_size=28][color=#f5d77a]%s[/color][/font_size]\n" % m.title
	t += "[color=%s]%s[/color]   [color=#8f86a3]%s · %s[/color]\n\n" % [KIND_BADGES[kind][1], KIND_BADGES[kind][0], m.get("category", ""), m.get("location", "")]
	t += Game.fmt(m.description) + "\n\n"
	match Game.mission_badge(m):
		"repeat":
			t += "[color=#8fb8ff]↻ Wiederkehrender Auftrag – bereits %d× erledigt, zuletzt an Tag %d.[/color]\n" % [int(Game.state.completed[m.id]), int(Game.state.completed_day.get(m.id, 0))]
		"retry":
			t += "[color=#ff9a3c]✗ Dieser Auftrag ist bereits %d× gescheitert. Wählt einen geeigneteren Vollstrecker.[/color]\n" % int(Game.state.failed[m.id])
	t += "[color=#d4af37]Dauer:[/color] %d Tage    [color=#d4af37]Schwierigkeit:[/color] %d\n" % [int(m.days), int(m.difficulty)]
	var weights: Dictionary = m.get("weights", {})
	var wl := PackedStringArray()
	for k in weights:
		wl.append("%s ×%d" % [Game.STAT_LABELS.get(k, k), int(weights[k])])
	t += "[color=#d4af37]Gefragt:[/color] %s\n" % ", ".join(wl)
	if m.has("required_char"):
		t += "[color=#ff7aa8]Nur durchführbar von: %s[/color]\n" % Game.char_name(m.required_char)
		var rc := Game.cs(m.required_char)
		if rc.status == "feldzug":
			t += "[color=#ff9a3c]⚠ %s führt derzeit eine Armee – auf der Weltkarte [K] als Feldherr abberufen.[/color]\n" % Game.char_name(m.required_char).split(" ")[0]
		elif rc.status != Game.STATUS_READY:
			t += "[color=#ff9a3c]⚠ %s ist derzeit nicht verfügbar (%s).[/color]\n" % [Game.char_name(m.required_char).split(" ")[0], Game.STATUS_LABELS.get(rc.status, "")]
	elif m.has("recommended"):
		var rl := PackedStringArray()
		for r in m.recommended:
			rl.append(Game.char_name(r))
		t += "[color=#9be36a]Empfohlen: %s[/color]\n" % ", ".join(rl)
	var rid: String = m.get("region", "")
	if rid != "" and not World.region(rid).get("home", false):
		var st := World.rs(rid)
		t += "[color=#d4af37]Region:[/color] %s – %s, Einfluss %d, Unruhe %d\n" % [World.region(rid).name, World.control_label(st.influence), st.influence, st.unrest]
	var rewards: Dictionary = m.get("rewards", {})
	if not rewards.is_empty():
		var parts := PackedStringArray()
		for k in rewards:
			var v := int(rewards[k])
			parts.append("[color=%s]%s %s %s%d[/color]" % [Palette.hex(Palette.RESOURCE_COLORS.get(k, Palette.GOLD)), Palette.RESOURCE_ICONS.get(k, ""),
				Game.RESOURCE_LABELS.get(k, k), "+" if v > 0 else "", v])
		t += "\n[color=#d4af37]Erwarteter Ertrag:[/color]  " + "   ".join(parts)
	detail.text = t

	# Vollstrecker-Kacheln
	_partner = ""
	for cid in Game.unlocked_chars():
		var check: Array = Game.can_assign(m, cid)
		var nm: String = Content.char_data(cid).name.split(" ")[0]
		var est: Array = Game.estimate(m, cid, _directive) if check[0] else [check[1], "#8f86a3"]
		var b := PortraitButton.new(cid, nm, est[0], Vector2(36, 50))
		b.toggle_mode = true
		b.button_group = _char_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 130
		b.disabled = not check[0]
		b.line2.add_theme_color_override("font_color", Color(est[1]))
		b.set_meta("cid", cid)
		b.pressed.connect(func(): _char_id = cid; _build_partners(); _update_forecast())
		chars_box.add_child(b)
		if check[0] and _char_id == "":
			_char_id = cid
			b.button_pressed = true
	_build_partners()
	_update_forecast()


## Optionaler zweiter Untertan – mit Synergie-Hinweis.
func _build_partners() -> void:
	partner_opt.clear()
	partner_opt.add_item("— allein —")
	partner_opt.set_item_metadata(0, "")
	partner_opt.disabled = _mission_id == ""
	var idx := 1
	for cid in Game.unlocked_chars():
		if cid == _char_id or not Game.is_available(cid):
			continue
		var syn := World.synergy(_char_id, cid)
		var tag := ""
		if not syn.is_empty():
			tag = "  ▲" if int(syn.bonus) > 0 else "  ▼"
		partner_opt.add_item(Game.char_name(cid).split(" ")[0] + tag)
		partner_opt.set_item_metadata(idx, cid)
		if cid == _partner:
			partner_opt.select(idx)
		idx += 1
	if _partner != "" and partner_opt.selected == 0:
		_partner = ""


func _update_forecast() -> void:
	var dd: Dictionary = Content.directives[_directive]
	directive_desc.text = "[color=#c79bff]%s %s:[/color] %s" % [dd.icon, dd.name, dd.desc]
	confirm.disabled = _mission_id == "" or _char_id == ""
	if confirm.disabled:
		forecast.text = "[color=#8f86a3]Wählt einen Auftrag und einen verfügbaren Untertanen.[/color]"
		return
	var m := Game.mission(_mission_id)
	var cd := Content.char_data(_char_id)
	var est := Game.estimate(m, _char_id, _directive, _partner)
	var t := "[color=#d4af37]Aussicht:[/color] [color=%s][b]%s[/b][/color]     [color=#d4af37]Dauer:[/color] %d Tage     [color=#d4af37]Unterhalt:[/color] %d Gold/Tag\n" % [
		est[1], est[0], Game.mission_days(m, _directive), int(Content.systems.economy.upkeep_per_agent) * (2 if _partner != "" else 1)]
	if _partner != "":
		var syn := World.synergy(_char_id, _partner)
		var pb := World.partner_bonus(m, _char_id, _partner)
		t += "[color=#8fb8ff]⚔ Unterstützung durch %s: %+d Erfolg.[/color]" % [Game.char_name(_partner).split(" ")[0], roundi(pb)]
		if not syn.is_empty():
			t += " [color=%s]%s[/color]" % ["#6fdc8c" if int(syn.bonus) > 0 else "#ff9a3c", syn.text]
		t += "\n"
	# Persönlichkeitshinweise
	if _directive == "freie_hand" and cd.has("style"):
		t += "[color=#c79bff]✧ %s handelt im Stil »%s«.[/color]\n" % [cd.name.split(" ")[0], cd.style.name]
	var dev: Dictionary = cd.get("deviations", {}).get(_directive, {})
	if not dev.is_empty():
		var strength := "neigt stark dazu" if float(dev.chance) >= 0.35 else "könnte versucht sein"
		t += "[color=#ff9a3c]⚠ %s %s, diesen Befehl eigenmächtig auszulegen.[/color]\n" % [cd.name.split(" ")[0], strength]
	var rival: String = cd.get("rival", "")
	if rival != "" and Game.cs(rival).unlocked:
		t += "[color=#ff7aa8]♥ %s wird diese Gunst nicht entgehen …[/color]\n" % Game.char_name(rival).split(" ")[0]
	forecast.text = t
	# Schätzungen auf den Kacheln an die Befehlsart anpassen
	for b: PortraitButton in chars_box.get_children():
		var cid: String = b.get_meta("cid", "")
		if cid != "" and not b.disabled:
			var e := Game.estimate(m, cid, _directive, _partner if _partner != cid else "")
			b.set_lines(Content.char_data(cid).name.split(" ")[0], e[0], Color(e[1]))


func _on_confirm() -> void:
	if Game.assign(_mission_id, _char_id, _directive, _partner):
		Audio.sfx("order")
		mission_assigned.emit()
		_build_list()

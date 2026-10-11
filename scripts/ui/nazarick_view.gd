class_name NazarickView
extends Overlay
## Das Große Grab selbst: Ausbau der Ebenen, Schatzkammer mit Artefakten,
## Albedos Wochenziele und die Errungenschaften des Overlords.

const EFFECT_LABELS := {
	"army": "Legionsstärke +%d %%", "defense": "Verteidigung +%d %%", "xp": "Erfahrung +%d %%",
	"loot": "Beutechance +%d %%", "score": "Erfolgswert +%d",
}

var tabs := TabContainer.new()
var build_status := RichTextLabel.new()
var build_bar := ProgressBar.new()
var floors_grid := GridContainer.new()
var items_flow := HFlowContainer.new()
var item_detail := VBoxContainer.new()
var treasury_head := Label.new()
var weekly_box := VBoxContainer.new()
var ach_grid := GridContainer.new()
var ach_head := Label.new()
var feedback := Label.new()
var _slot_filter := ""
var _selected := ""
var _start_tab := 0


func _init(tab: int = 0) -> void:
	super._init(Vector2(1500, 840))
	content.add_child(make_header("Das Große Grab von Nazarick", "Ausbau · Schatzkammer · Albedos Wochenziele · Errungenschaften"))
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	tabs.add_child(_build_floors_tab())
	tabs.add_child(_build_treasury_tab())
	tabs.add_child(_build_weekly_tab())
	tabs.add_child(_build_achievements_tab())
	tabs.set_tab_title(0, "⚒ Ausbau")
	tabs.set_tab_title(1, "◈ Schatzkammer")
	tabs.set_tab_title(2, "❤ Wochenziele")
	tabs.set_tab_title(3, "★ Errungenschaften")
	_start_tab = tab
	feedback.theme_type_variation = "GoldLabel"
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(feedback)
	_refresh()


func _ready() -> void:
	tabs.current_tab = _start_tab
	super._ready()


func _refresh() -> void:
	_refresh_floors()
	_refresh_treasury()
	_refresh_weekly()
	_refresh_achievements()


func _say(text: String, color: Color = Palette.GOLD_BRIGHT) -> void:
	feedback.text = text
	feedback.add_theme_color_override("font_color", color)
	UIFx.flash(feedback)


func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 16)
	return r


func _scroll(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	return sc


# =====================================================================
#  Ausbau
# =====================================================================

func _build_floors_tab() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var status := PanelContainer.new()
	status.theme_type_variation = "PanelDim"
	var sv := VBoxContainer.new()
	status.add_child(sv)
	build_status.bbcode_enabled = true
	build_status.fit_content = true
	build_status.scroll_active = false
	sv.add_child(build_status)
	build_bar.show_percentage = false
	build_bar.custom_minimum_size.y = 10
	build_bar.add_theme_stylebox_override("fill", NazarickTheme.box(Palette.VIOLET_GLOW, Color.TRANSPARENT, 0, 5, Color(Palette.VIOLET_GLOW, 0.6), 6, 0))
	sv.add_child(build_bar)
	vb.add_child(status)
	floors_grid.columns = 2
	floors_grid.add_theme_constant_override("h_separation", 12)
	floors_grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(_scroll(floors_grid))
	return vb


func _refresh_floors() -> void:
	var b: Dictionary = Progress.ps().build
	if b.is_empty():
		build_status.text = "[color=#d4af37][b]Die Baumeister warten auf Euren Befehl.[/b][/color]  [color=#8f86a3]Immer nur ein Bauprojekt zugleich – wählt mit Bedacht. Gold: %d[/color]" % Game.state.resources.gold
		build_bar.visible = false
	else:
		var f := Progress.floor_def(b.id)
		build_status.text = "[color=#c79bff][b]⚒ Im Bau: %s – Stufe %d[/b][/color]   fertig in [b]%d[/b] Tagen  [color=#8f86a3]→ %s[/color]" % [
			f.name, int(b.level), maxi(0, int(b.done_day) - Game.state.day), Progress.floor_label(f, int(b.level))]
		build_bar.visible = true
		build_bar.value = Progress.build_progress() * 100.0
	for c in floors_grid.get_children():
		c.queue_free()
	for f in Progress.floors:
		floors_grid.add_child(_floor_card(f))


func _floor_card(f: Dictionary) -> Control:
	var lvl := Progress.floor_level(f.id)
	var maxl: int = f.costs.size()
	var building: bool = Progress.ps().build.get("id", "") == f.id
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := Palette.GOLD if lvl >= maxl else (Palette.VIOLET_GLOW if building else Color(Palette.VIOLET, 0.6))
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.NIGHT, 0.95), border, 2 if lvl > 0 else 1, 12, Color(border, 0.3), 8, 10))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	hb.add_child(_floor_image(f, lvl))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	var title := Label.new()
	title.text = "%s  %s" % [f.icon, f.name]
	title.theme_type_variation = "GoldLabel"
	vb.add_child(title)
	var pips := ""
	for i in maxl:
		pips += "◆" if i < lvl else "◇"
	var keeper: String = f.get("keeper", "")
	var sub := _rich()
	sub.add_theme_font_size_override("normal_font_size", 14)
	sub.text = "[color=#f5d77a]%s[/color]  [color=#8f86a3]%s%s[/color]" % [pips, f.floor, (" · Hüter: " + Game.char_name(keeper).split(" ")[0]) if keeper != "" else ""]
	vb.add_child(sub)
	var desc := _rich()
	desc.add_theme_font_size_override("normal_font_size", 14)
	var now := "[color=#6fdc8c]Aktuell: %s[/color]" % Progress.floor_label(f, lvl) if lvl > 0 else "[color=#8f86a3]Noch nicht ausgebaut[/color]"
	var nxt := "  ·  [color=#f5d77a]Nächste Stufe: %s[/color]" % Progress.floor_label(f, lvl + 1) if lvl < maxl else ""
	desc.text = "[color=#b7aecb]%s[/color]\n%s%s" % [f.desc, now, nxt]
	vb.add_child(desc)
	var btn := Button.new()
	var ok := Progress.can_build(f.id)
	if lvl >= maxl:
		btn.text = "✔ Vollendet"
		btn.disabled = true
	elif building:
		btn.text = "Im Bau …"
		btn.disabled = true
	else:
		btn.text = "Ausbauen · %d Gold · %d Tage" % [Progress.build_cost(f.id), Progress.build_days(f.id)]
		if not ok[0] and not Progress.ps().build.is_empty():
			btn.text += "  (Baumeister beschäftigt)"
		elif not ok[0]:
			btn.text = ok[1]
		btn.disabled = not ok[0]
		btn.tooltip_text = ok[1]
		btn.theme_type_variation = "ButtonPrimary"
	btn.pressed.connect(func():
		var res := Progress.start_build(f.id)
		Audio.sfx("order" if res.ok else "rebuke", 0.7)
		_say(res.text, Palette.GOLD_BRIGHT if res.ok else Palette.DANGER)
		_refresh())
	vb.add_child(btn)
	return p


func _floor_image(f: Dictionary, lvl: int) -> Control:
	var tex := Content.find_image("backgrounds", f.get("image", ""))
	var sz := Vector2(150, 132)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = sz
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate = Color.WHITE if lvl > 0 else Color(0.55, 0.5, 0.6)
		return tr
	var l := Label.new()
	l.text = f.icon
	l.custom_minimum_size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 64)
	var col := Palette.GOLD_BRIGHT if lvl > 0 else Palette.MUTED
	l.add_theme_color_override("font_color", col)
	l.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.VIOLET_DEEP, 0.5 + lvl * 0.15), Color(col, 0.4), 1, 8))
	return l


# =====================================================================
#  Schatzkammer
# =====================================================================

func _build_treasury_tab() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	var row := HBoxContainer.new()
	treasury_head.theme_type_variation = "GoldLabel"
	treasury_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(treasury_head)
	for spec in [["Alle", ""], ["Waffen", "waffe"], ["Rüstungen", "ruestung"], ["Kleinode", "schmuck"]]:
		var b := Button.new()
		b.text = spec[0]
		b.toggle_mode = true
		b.button_pressed = spec[1] == _slot_filter
		b.theme_type_variation = "ButtonGhost"
		b.pressed.connect(func(): _slot_filter = spec[1]; _refresh_treasury())
		row.add_child(b)
	left.add_child(row)
	items_flow.add_theme_constant_override("h_separation", 8)
	items_flow.add_theme_constant_override("v_separation", 8)
	left.add_child(_scroll(items_flow))
	var auto := Button.new()
	auto.text = "✦ Alle Wächter mit den besten freien Artefakten ausrüsten"
	auto.pressed.connect(func():
		for cid in Game.unlocked_chars():
			Progress.auto_equip(cid)
		Audio.sfx("order", 0.6)
		_say("Pandora's Actor verteilt die Schätze mit theatralischer Verbeugung.")
		_refresh_treasury())
	left.add_child(auto)

	var right := PanelContainer.new()
	right.theme_type_variation = "PanelDim"
	right.custom_minimum_size.x = 470
	item_detail.add_theme_constant_override("separation", 8)
	right.add_child(item_detail)
	hb.add_child(right)
	return hb


func _refresh_treasury() -> void:
	var inv: Array = Progress.inventory().duplicate()
	inv.sort_custom(func(a, b):
		var ra := Progress.RARITY_ORDER.find(Progress.item_def(a.id).rarity)
		var rb := Progress.RARITY_ORDER.find(Progress.item_def(b.id).rarity)
		return ra > rb if ra != rb else a.uid > b.uid)
	treasury_head.text = "Schatzkammer · %d Artefakte" % inv.size()
	for c in items_flow.get_children():
		c.queue_free()
	if inv.is_empty():
		var l := Label.new()
		l.text = "Die Schatzkammer ist leer. Triumphe, Schlachten, gebannte Bedrohungen und Albedos Truhe bringen Artefakte."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
		items_flow.add_child(l)
	for e in inv:
		var it := Progress.item_def(e.id)
		if _slot_filter != "" and it.slot != _slot_filter:
			continue
		items_flow.add_child(_item_tile(e, it))
	if _selected == "" or Progress.inv_entry(_selected).is_empty():
		_selected = inv[0].uid if not inv.is_empty() else ""
	_build_detail()


func _item_tile(e: Dictionary, it: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(86, 86)
	b.tooltip_text = "%s (%s)" % [it.name, Progress.rarity(it.rarity).name]
	var sel: bool = e.uid == _selected
	var col := Progress.rarity_color(it.rarity)
	b.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.ABYSS, 0.6), Color(col, 0.9 if sel else 0.0), 2, 10, Color.TRANSPARENT, 0, 4))
	b.add_theme_stylebox_override("hover", NazarickTheme.box(Color(col, 0.15), col, 1, 10, Color(col, 0.4), 6, 4))
	var icon := ItemIcon.new(e.id, 70)
	icon.position = Vector2(8, 8)
	b.add_child(icon)
	var holder := Progress.owner_of(e.uid)
	if holder != "":
		var p := Portrait.new()
		p.char_id = holder
		p.framed = false
		p.show_symbol = false
		p.custom_minimum_size = Vector2(26, 30)
		p.size = Vector2(26, 30)
		p.position = Vector2(58, 54)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(p)
	b.pressed.connect(func(): _selected = e.uid; _refresh_treasury())
	return b


func _build_detail() -> void:
	for c in item_detail.get_children():
		c.queue_free()
	var e := Progress.inv_entry(_selected)
	if e.is_empty():
		var l := Label.new()
		l.text = "Wählt ein Artefakt aus."
		l.theme_type_variation = "MutedLabel"
		item_detail.add_child(l)
		return
	var it := Progress.item_def(e.id)
	var col := Progress.rarity_color(it.rarity)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.add_child(ItemIcon.new(e.id, 110))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := Label.new()
	nl.text = it.name
	nl.theme_type_variation = "GoldLabel"
	nl.add_theme_font_size_override("font_size", 24)
	nl.add_theme_color_override("font_color", col.lightened(0.2))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nl)
	var r := Label.new()
	r.text = "%s · %s" % [Progress.rarity(it.rarity).name, Progress.SLOT_LABELS[it.slot]]
	r.add_theme_color_override("font_color", col)
	tv.add_child(r)
	top.add_child(tv)
	item_detail.add_child(top)
	var info := _rich()
	var lines := PackedStringArray()
	for k in it.stats:
		lines.append("[color=#6fdc8c]+%d %s[/color]" % [int(it.stats[k]), Game.STAT_LABELS.get(k, k)])
	for k in it.get("effects", {}):
		var v := float(it.effects[k])
		lines.append("[color=#7fd8ff]%s[/color]" % (EFFECT_LABELS.get(k, k) % (roundi(v * 100) if k != "score" else roundi(v))))
	if it.has("fav"):
		lines.append("[color=#ff7aa8]♥ Bevorzugt von %s (+50 %% Werte, Freude beim Anlegen)[/color]" % Game.char_name(it.fav).split(" ")[0])
	info.text = "\n".join(lines) + "\n\n[i][color=#b7aecb]%s[/color][/i]" % it.desc
	if e.get("source", "") != "":
		info.text += "\n[color=#8f86a3]Herkunft: %s (Tag %d)[/color]" % [e.source, int(e.get("day", 0))]
	item_detail.add_child(info)
	var holder := Progress.owner_of(e.uid)
	var ol := Label.new()
	ol.text = "Getragen von: " + (Game.char_name(holder) if holder != "" else "— niemandem —")
	ol.theme_type_variation = "MutedLabel"
	item_detail.add_child(ol)
	var row := HBoxContainer.new()
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = []
	for cid in Game.unlocked_chars():
		var cur: String = Progress.ps().equip.get(cid, {}).get(it.slot, "")
		var cur_name: String = Progress.item_def(Progress.inv_entry(cur).get("id", "")).get("name", "frei") if cur != "" else "frei"
		pick.add_item("%s%s  (%s: %s)" % ["♥ " if it.get("fav", "") == cid else "", Game.char_name(cid).split(" ")[0], Progress.SLOT_LABELS[it.slot], cur_name])
		ids.append(cid)
		if cid == holder or (holder == "" and it.get("fav", "") == cid):
			pick.select(ids.size() - 1)
	row.add_child(pick)
	var eq := Button.new()
	eq.text = "Anlegen"
	eq.theme_type_variation = "ButtonPrimary"
	eq.disabled = ids.is_empty()
	eq.pressed.connect(func():
		var cid: String = ids[pick.selected]
		Progress.equip(cid, e.uid)
		Audio.sfx("love" if it.get("fav", "") == cid else "order", 0.7)
		_say("%s trägt nun: %s" % [Game.char_name(cid), it.name])
		_refresh_treasury())
	row.add_child(eq)
	item_detail.add_child(row)
	var row2 := HBoxContainer.new()
	if holder != "":
		var un := Button.new()
		un.text = "Ablegen"
		un.pressed.connect(func(): Progress.unequip(holder, it.slot); _refresh_treasury())
		row2.add_child(un)
	var sell := Button.new()
	sell.text = "Einschmelzen  +%d Gold" % int(Progress.rarity(it.rarity).sell)
	sell.theme_type_variation = "ButtonDanger"
	sell.pressed.connect(func():
		var g := Progress.sell(e.uid)
		Audio.sfx("page", 0.7)
		_say("%s wurde eingeschmolzen: +%d Gold." % [it.name, g])
		_selected = ""
		_refresh_treasury())
	row2.add_child(sell)
	item_detail.add_child(row2)


# =====================================================================
#  Wochenziele
# =====================================================================

func _build_weekly_tab() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	var left := VBoxContainer.new()
	var p := Portrait.new()
	p.char_id = "albedo"
	p.variant = "love"
	p.custom_minimum_size = Vector2(260, 360)
	left.add_child(p)
	var q := _rich()
	q.custom_minimum_size.x = 260
	q.text = "[i][color=#c79bff]»Ich habe Eure Woche vorbereitet, %s. Erfüllt jedes Ziel – und Eure Oberaufseherin hält eine Belohnung bereit. Eine, die Ihr nicht vergessen werdet.«[/color][/i]" % Game.lord()
	left.add_child(q)
	hb.add_child(left)
	weekly_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_box.add_theme_constant_override("separation", 12)
	hb.add_child(weekly_box)
	return hb


func _refresh_weekly() -> void:
	for c in weekly_box.get_children():
		c.queue_free()
	var pr := Progress.ps()
	var head := _rich()
	head.add_theme_font_size_override("normal_font_size", 20)
	var streak := int(pr.streak)
	head.text = "[color=#d4af37][b]Woche %d[/b][/color]   [color=#8f86a3]noch %d %s[/color]   %s" % [
		Progress.week_index() + 1, Progress.week_days_left(), "Tag" if Progress.week_days_left() == 1 else "Tage",
		"[color=#ff7aa8]❤ Serie: %d %s[/color]" % [streak, "Woche" if streak == 1 else "Wochen"] if streak > 0 else "[color=#8f86a3]Noch keine Serie – erfüllt alle drei Ziele![/color]"]
	weekly_box.add_child(head)
	for i in pr.goals.size():
		weekly_box.add_child(_goal_row(i, pr.goals[i]))
	# Truhe
	var chest := PanelContainer.new()
	var can := Progress.can_claim_chest()
	var col := Palette.GOLD_BRIGHT if can else Color(Palette.VIOLET, 0.7)
	chest.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.NIGHT, 0.95), col, 2, 14, Color(col, 0.5 if can else 0.2), 18 if can else 6, 16))
	var cv := VBoxContainer.new()
	chest.add_child(cv)
	var ct := Label.new()
	ct.text = "♛  Albedos Truhe"
	ct.theme_type_variation = "GoldLabel"
	ct.add_theme_font_size_override("font_size", 24)
	cv.add_child(ct)
	var cfg: Dictionary = Progress.data.weekly_chest
	var next_streak := streak + 1
	var mult := 1.0 + float(cfg.streak_bonus) * mini(next_streak - 1, int(cfg.streak_max))
	var gold := roundi(float(cfg.gold) * mult * (1.0 + Game.state.chapter * 0.1))
	var cd := _rich()
	cd.text = "Enthält [color=#f5d77a]%d Gold[/color]%s und ein [color=%s]garantiert %s Artefakt[/color]. Jede Woche in Folge erhöht den Inhalt – ab der 4. Woche sogar episch oder besser.%s" % [
		gold, " (Serienbonus +%d %%)" % roundi((mult - 1.0) * 100) if mult > 1.0 else "",
		"#c37bff" if next_streak >= 4 else "#6fb3ff", "episches" if next_streak >= 4 else "seltenes",
		"\n[color=#6fdc8c][b]Bereits geöffnet – neue Ziele in %d Tagen.[/b][/color]" % Progress.week_days_left() if pr.chest_claimed else ""]
	cv.add_child(cd)
	var cb := Button.new()
	cb.text = "Truhe öffnen!" if can else ("Geöffnet ✔" if pr.chest_claimed else "Erfüllt erst alle drei Ziele")
	cb.theme_type_variation = "ButtonPrimary"
	cb.disabled = not can
	cb.custom_minimum_size.y = 50
	if can:
		UIFx.pulse(cb, 0.75, 0.9)
	cb.pressed.connect(func():
		var res := Progress.claim_chest()
		if not res.is_empty():
			_say("Albedos Truhe: +%d Gold und %s!" % [res.gold, Progress.item_def(res.item).get("name", "")])
		_refresh())
	cv.add_child(cb)
	weekly_box.add_child(chest)
	var hint := Label.new()
	hint.text = "Erfüllte Ziele werden am Wochenende automatisch gutgeschrieben – die Serie bleibt aber nur erhalten, wenn alle drei Ziele erfüllt sind."
	hint.theme_type_variation = "MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weekly_box.add_child(hint)


func _goal_row(i: int, g: Dictionary) -> Control:
	var done := Progress.goal_done(g)
	var p := PanelContainer.new()
	var col := Palette.SUCCESS if done else Color(Palette.VIOLET, 0.7)
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.ABYSS, 0.85), col, 1, 10, Color.TRANSPARENT, 0, 12))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var mark := Label.new()
	mark.text = "✔" if done else "◇"
	mark.add_theme_font_size_override("font_size", 26)
	mark.add_theme_color_override("font_color", col.lightened(0.2))
	hb.add_child(mark)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var t := Label.new()
	t.text = g.text
	t.add_theme_font_size_override("font_size", 18)
	vb.add_child(t)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	bar.max_value = int(g.target)
	bar.value = mini(Progress.goal_value(g), int(g.target))
	bar.add_theme_stylebox_override("fill", NazarickTheme.box(col, Color.TRANSPARENT, 0, 5, Color(col, 0.5), 4, 0))
	vb.add_child(bar)
	var rl := Label.new()
	rl.text = "%d / %d  ·  Belohnung: %s" % [mini(Progress.goal_value(g), int(g.target)), int(g.target), Progress.reward_text(g.reward)]
	rl.theme_type_variation = "MutedLabel"
	rl.add_theme_font_size_override("font_size", 14)
	vb.add_child(rl)
	var b := Button.new()
	b.text = "Eingefordert" if g.claimed else "Einfordern"
	b.disabled = g.claimed or not done
	b.theme_type_variation = "ButtonPrimary"
	b.pressed.connect(func():
		var s := Progress.claim_goal(i)
		Audio.sfx("love", 0.7)
		_say("Albedo: »Wie erwartet, %s.«  %s" % [Game.lord(), ", ".join(s.map(func(x): return "%s %+d" % [x[0], x[1]]))])
		_refresh_weekly())
	hb.add_child(b)
	return p


# =====================================================================
#  Errungenschaften
# =====================================================================

func _build_achievements_tab() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	ach_head.theme_type_variation = "GoldLabel"
	vb.add_child(ach_head)
	ach_grid.columns = 3
	ach_grid.add_theme_constant_override("h_separation", 10)
	ach_grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(_scroll(ach_grid))
	return vb


func _refresh_achievements() -> void:
	var done: int = Progress.ps().achievements.size()
	ach_head.text = "Errungenschaften: %d / %d freigeschaltet" % [done, Progress.achievements.size()]
	for c in ach_grid.get_children():
		c.queue_free()
	# Freigeschaltete zuerst, dann nach Fortschritt
	var list: Array = Progress.achievements.duplicate()
	list.sort_custom(func(a, b):
		var da := Progress.achievement_done(a.id)
		var db := Progress.achievement_done(b.id)
		if da != db:
			return da
		var pa: Array = Progress.achievement_progress(a)
		var pb: Array = Progress.achievement_progress(b)
		return float(pa[0]) / maxf(1, pa[1]) > float(pb[0]) / maxf(1, pb[1]))
	for a in list:
		ach_grid.add_child(_ach_card(a))


func _ach_card(a: Dictionary) -> Control:
	var done := Progress.achievement_done(a.id)
	var tcol := Progress.tier_color(a.get("tier", "bronze"))
	var col := tcol if done else Color(Palette.MUTED, 0.6)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.NIGHT, 0.95 if done else 0.6), Color(col, 0.8), 2 if done else 1, 12,
		Color(tcol, 0.35) if done else Color.TRANSPARENT, 10 if done else 0, 10))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	var icon := Label.new()
	icon.text = a.icon
	icon.custom_minimum_size = Vector2(58, 58)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 30)
	icon.add_theme_color_override("font_color", col)
	icon.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.VOID, 0.9), col, 2, 29, Color.TRANSPARENT, 0, 0))
	hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	var t := Label.new()
	t.text = a.name
	t.add_theme_font_override("font", NazarickTheme.display_font(700))
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", tcol if done else Palette.PARCHMENT.darkened(0.3))
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size.x = 200
	vb.add_child(t)
	var d := Label.new()
	d.text = a.desc
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Palette.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	var pr: Array = Progress.achievement_progress(a)
	if a.has("stat") and not done:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.max_value = pr[1]
		bar.value = pr[0]
		vb.add_child(bar)
	var rw := Label.new()
	rw.text = ("✔ Tag %d · " % int(Progress.ps().achievements[a.id]) if done else ("%d / %d · " % pr if a.has("stat") else "")) + "Belohnung: " + Progress.reward_text(a.get("reward", {}))
	rw.add_theme_font_size_override("font_size", 13)
	rw.add_theme_color_override("font_color", Palette.SUCCESS if done else Palette.GOLD_DARK.lightened(0.3))
	vb.add_child(rw)
	return p

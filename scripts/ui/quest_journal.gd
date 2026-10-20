class_name QuestJournal
extends Overlay
## Questbuch [J]: laufende und erledigte Abenteuer mit Schritten und Lohn, Verfolgen im HUD,
## der Beutel mit gesammelten Materialien und die Kapitel-Momente (spielbare Story-Einsätze, als Erinnerung wiederholbar).

signal replay_requested(mission_id: String)

var _list := VBoxContainer.new()
var _detail := VBoxContainer.new()
var _sel := ""


func _init() -> void:
	super._init(Vector2(1180, 720))
	content.add_child(make_header("Questbuch", "Abenteuer von Ainz Ooal Gown – und von Momon, dem Dunklen Helden"))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var page := HBoxContainer.new()
	page.name = "Aufträge"
	page.add_theme_constant_override("separation", 18)
	tabs.add_child(page)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.x = 400
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	page.add_child(sc)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	ds.add_child(_detail)
	page.add_child(ds)
	tabs.add_child(_bag_page())
	tabs.add_child(_story_page())
	_sel = Quests.tracked
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var act := Quests.active()
	var done: Array = Quests.data.get("quests", []).filter(func(q): return Quests.state_of(q.id) == "done")
	if _sel == "" and not act.is_empty():
		_sel = act[0].id
	elif _sel == "" and not done.is_empty():
		_sel = done[0].id
	_section("LAUFEND (%d)" % act.size())
	if act.is_empty():
		var l := Label.new()
		l.text = "Keine laufenden Aufträge. Sprecht mit Figuren, die ein „!“ tragen, oder lest die Anschlagtafeln."
		l.theme_type_variation = "MutedLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(l)
	for q in act:
		_entry(q, true)
	_section("ERLEDIGT (%d)" % done.size())
	for q in done:
		_entry(q, false)
	_show(_sel)


func _section(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = "SubHeaderLabel"
	_list.add_child(l)


func _entry(q: Dictionary, running: bool) -> void:
	var b := Button.new()
	b.theme_type_variation = "ButtonCard" if q.id != _sel else "ButtonPrimary"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var icon: String = {"main": "⚜", "guardian": "♛", "bounty": "✠"}.get(q.get("kind", ""), "✦")
	var tr := "  ◉" if q.id == Quests.tracked else ""
	b.text = "%s  %s%s%s" % [icon, q.title, tr, ("\n" + Quests.step_text(q)) if running else ""]
	if not running:
		b.modulate = Color(0.75, 0.75, 0.75)
	var qid: String = q.id
	b.pressed.connect(func(): _sel = qid; _rebuild())
	_list.add_child(b)


func _show(qid: String) -> void:
	for c in _detail.get_children():
		c.queue_free()
	if not Quests.by_id.has(qid):
		return
	var q: Dictionary = Quests.by_id[qid]
	var t := Label.new()
	t.text = q.title
	t.theme_type_variation = "HeaderLabel"
	t.add_theme_font_size_override("font_size", 26)
	_detail.add_child(t)
	var giver := ""
	if q.has("giver"):
		giver = "Auftraggeber: " + String(Content.char_data(q.giver).get("name", q.giver))
	elif q.has("board"):
		giver = "Anschlagtafel: " + String(Content.location_by_id.get(q.board, {}).get("name", q.board))
	var g := Label.new()
	g.text = giver
	g.theme_type_variation = "MutedLabel"
	_detail.add_child(g)
	var off := RichTextLabel.new()
	off.bbcode_enabled = true
	off.fit_content = true
	off.add_theme_font_override("normal_font", NazarickTheme.italic_font(600))
	off.text = "»%s«" % q.get("offer", "")
	_detail.add_child(off)
	_detail.add_child(HSeparator.new())
	var st: Dictionary = Quests.qs().get(qid, {})
	var cur := int(st.get("step", 0))
	var done: bool = Quests.state_of(qid) == "done"
	var steps := RichTextLabel.new()
	steps.bbcode_enabled = true
	steps.fit_content = true
	var lines := PackedStringArray()
	for i in q.steps.size():
		var s: Dictionary = q.steps[i]
		if done or i < cur:
			lines.append("[color=#6fdc8c]✔  %s[/color]" % s.text)
		elif i == cur:
			lines.append("[color=#f5d77a]◆  %s[/color]" % Quests.step_text(q))
		else:
			lines.append("[color=#6a6478]◇  …[/color]")
	steps.text = "\n".join(lines)
	_detail.add_child(steps)
	var r: Dictionary = q.get("rewards", {})
	var parts := PackedStringArray()
	if r.has("gold"):
		parts.append("%d Gold" % int(r.gold))
	for k in r.get("res", {}):
		parts.append("%s +%d" % [Game.RESOURCE_LABELS.get(k, k), int(r.res[k])])
	for cid in r.get("chars", {}):
		parts.append("%s: Gunst" % Content.char_data(cid).get("name", cid))
	if String(r.get("item", "")) != "":
		parts.append("Gegenstand (%s)" % String(r.item).replace("roll:", ""))
	var rl := Label.new()
	rl.text = "Lohn: " + (", ".join(parts) if not parts.is_empty() else "Ruhm")
	rl.theme_type_variation = "GoldLabel"
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(rl)
	if Quests.is_active(qid):
		var b := Button.new()
		b.text = "◉  Im HUD verfolgen" if Quests.tracked != qid else "◉  Wird verfolgt"
		b.theme_type_variation = "ButtonPrimary"
		b.disabled = Quests.tracked == qid
		b.pressed.connect(func(): Quests.tracked = qid; Quests.changed.emit(); _rebuild())
		_detail.add_child(b)


## Große Augenblicke der Geschichte: erlebt (als Erinnerung wiederholbar), wartend (in einer Depesche) oder verborgen.
func _story_page() -> Control:
	var sc := ScrollContainer.new()
	sc.name = "Kapitel-Momente"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	var intro := Label.new()
	intro.text = "Die großen Augenblicke der Geschichte – selbst erlebt in 3D. Erlebte und entschiedene Momente kehren als Erinnerung wieder: frei spielbar, ohne Folgen für das Reich."
	intro.theme_type_variation = "MutedLabel"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(intro)
	var waiting_ev := {}
	for d in Game.pending():
		waiting_ev[String(d.get("context", {}).get("event_id", ""))] = true
	var fired: Dictionary = Game.state.get("fired", {})
	var all := StoryMission.load_all()
	var n := 0
	for mid in all:
		var m: Dictionary = all[mid]
		n += 1
		var ev := String(m.get("event", ""))
		var played := Game.has_flag("story_" + String(mid))
		var waiting := waiting_ev.has(ev)
		var decided := fired.has(ev) and not waiting and not played
		var known := played or waiting or decided
		var panel := PanelContainer.new()
		panel.theme_type_variation = "PanelDim"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var num := Label.new()
		num.text = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][mini(n - 1, 7)]
		num.theme_type_variation = "GoldLabel"
		num.custom_minimum_size.x = 44
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(num)
		var t := RichTextLabel.new()
		t.bbcode_enabled = true
		t.fit_content = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var where: String = String(Content.location_by_id.get(String(m.get("loc", "")), {}).get("name", ""))
		var status := "[color=#6fdc8c]✔ Selbst erlebt[/color]" if played else ("[color=#ffd36a]✉ Wartet in einer Depesche – [Enter] öffnet sie[/color]" if waiting else ("[color=#8f86a3]Entschieden, ohne dabei zu sein[/color]" if decided else "[color=#5a5468]Noch nicht geschehen[/color]"))
		t.text = ("[b]%s[/b]   [color=#8f86a3]%s[/color]\n%s" % [String(m.get("title", mid)), where, status]) if known else ("[b][color=#5a5468]? ? ?[/color][/b]\n%s" % status)
		row.add_child(t)
		if played or decided:
			var b := Button.new()
			b.text = "▶ Als Erinnerung erleben"
			b.theme_type_variation = "ButtonPrimary" if played else "Button"
			var id := String(mid)
			b.pressed.connect(func():
				replay_requested.emit(id)
				close())
			row.add_child(b)
		vb.add_child(panel)
	return sc


func _bag_page() -> Control:
	var vb := VBoxContainer.new()
	vb.name = "Beutel"
	vb.add_theme_constant_override("separation", 6)
	var bag: Dictionary = Quests.bag()
	if bag.is_empty():
		var l := Label.new()
		l.text = "Der Beutel ist leer. Kräuter, Erze und Beute findet Ihr in der Welt – Händler in Carne und E-Rantel kaufen sie."
		l.theme_type_variation = "MutedLabel"
		vb.add_child(l)
		return vb
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	var total := 0
	for m in bag:
		var d := Quests.material(m)
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.custom_minimum_size.x = 520
		l.text = "[color=%s]%s[/color]  [b]%s[/b] ×%d  [color=#8f86a3]%s[/color]" % [d.get("color", "#ffffff"), d.get("icon", "•"), d.get("name", m), int(bag[m]),
			("Questgegenstand" if d.get("unique", false) else "%d Gold je Stück" % int(d.get("value", 1)))]
		grid.add_child(l)
		if not d.get("unique", false):
			total += int(bag[m]) * int(d.get("value", 1))
	vb.add_child(grid)
	var sum := Label.new()
	sum.text = "Gesamtwert: ~%d Gold (Verkauf bei Lizzie Bareare, der Gilde oder Enri)" % total
	sum.theme_type_variation = "GoldLabel"
	vb.add_child(sum)
	return vb

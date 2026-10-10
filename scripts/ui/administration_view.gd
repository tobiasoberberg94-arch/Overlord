class_name AdministrationView
extends Overlay
## Reichsverwaltung: Finanzen (Einkünfte je Region, Unterhalt) und Erlasse.
## Erlasse sind dauerhafte Regierungsentscheidungen mit laufenden Kosten und
## Wirkungen. Die Zahl der Plätze wächst mit den Kapiteln; die Wächter haben
## eine Meinung zu jedem Erlass.

var finance := RichTextLabel.new()
var decrees_box := GridContainer.new()
var slots_label := Label.new()
var feedback := RichTextLabel.new()


func _init() -> void:
	super._init(Vector2(1480, 820))
	content.add_child(make_header("Reichsverwaltung", "Schatzkammer, Einkünfte und die Erlasse des Overlords"))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)

	var left := PanelContainer.new()
	left.theme_type_variation = "PanelDim"
	left.custom_minimum_size.x = 520
	row.add_child(left)
	finance.bbcode_enabled = true
	finance.add_theme_font_size_override("normal_font_size", 17)
	finance.add_theme_font_size_override("bold_font_size", 17)
	left.add_child(finance)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	var head := HBoxContainer.new()
	var hl := Label.new()
	hl.text = "ERLASSE"
	hl.theme_type_variation = "HeaderLabel"
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	slots_label.theme_type_variation = "GoldLabel"
	head.add_child(slots_label)
	right.add_child(head)
	var hint := Label.new()
	hint.text = "Ein Erlass wirkt jeden Tag, bis er widerrufen wird. Mehr Plätze erhaltet Ihr im Laufe der Kapitel."
	hint.theme_type_variation = "MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decrees_box.columns = 2
	decrees_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decrees_box.add_theme_constant_override("h_separation", 10)
	decrees_box.add_theme_constant_override("v_separation", 10)
	sc.add_child(decrees_box)
	right.add_child(sc)
	feedback.bbcode_enabled = true
	feedback.fit_content = true
	feedback.scroll_active = false
	right.add_child(feedback)
	_refresh()


func _refresh() -> void:
	_build_finance()
	_build_decrees()


func _build_finance() -> void:
	var t := "[font_size=22][color=#d4af37]Schatzkammer: %d Gold[/color][/font_size]\n\n" % Game.state.resources.gold
	t += "[color=#d4af37][b]Einkünfte je Region (pro Tag)[/b][/color]\n"
	var total := 0.0
	for r in Content.regions:
		var st := World.rs(r.id)
		if not st.discovered or r.get("home", false):
			continue
		var factor: float = st.influence / 100.0 * (1.0 - st.unrest / 150.0)
		var g := float(r.income.get("gold", 0)) * factor * Game.diff("income")
		total += g
		var unrest := "  [color=#ff7a7a](Unruhe %d)[/color]" % st.unrest if st.unrest >= 35 else ""
		t += "  %s: [color=#6fdc8c]+%.1f[/color]  [color=#8f86a3]Einfluss %d%%[/color]%s\n" % [r.short, g, st.influence, unrest]
	var dg := World.decree_daily_gold()
	t += "  Erlasse: [color=#6fdc8c]+%.1f[/color]\n" % dg
	var mult := World._income_mult()
	if mult < 1.0:
		t += "  [color=#ff9a3c]Geheimhaltung senkt Regionserträge auf %d %%[/color]\n" % roundi(mult * 100)
	t += "\n[color=#d4af37][b]Unterhalt (pro Tag)[/b][/color]\n"
	var eco: Dictionary = Content.systems.economy
	var agents := 0
	for am in Game.state.active:
		agents += 2 if am.get("partner", "") != "" else 1
	var dm := Game.diff("upkeep")
	t += "  Großes Grab: [color=#ff7a7a]−%d[/color]\n" % roundi(int(eco.upkeep_base) * dm)
	t += "  Einsätze (%d Untertanen): [color=#ff7a7a]−%d[/color]\n" % [agents, roundi(agents * int(eco.upkeep_per_agent) * dm)]
	t += "  Erlasse: [color=#ff7a7a]−%d[/color]\n" % roundi(World._decree_upkeep() * dm)
	t += "  Legionen: [color=#ff7a7a]−%d[/color]\n" % roundi(Military.total_upkeep() * dm)
	var up := World.daily_upkeep()
	var net := total + dg - up
	t += "\n[font_size=20][b]Bilanz: [color=%s]%+.0f Gold pro Tag[/color][/b][/font_size]\n" % ["#6fdc8c" if net >= 0 else "#ff4a5a", net]
	if net < 0:
		var days := int(Game.state.resources.gold / maxf(-net, 0.01))
		t += "[color=#ff9a3c]Bei diesem Kurs ist die Schatzkammer in etwa %d Tagen leer.[/color]\n" % days
	t += "\n[color=#8f86a3]Schwierigkeitsgrad: %s[/color]" % Content.difficulty(Game.state.get("difficulty", "normal")).get("name", "")
	finance.text = t


func _build_decrees() -> void:
	for c in decrees_box.get_children():
		c.queue_free()
	slots_label.text = "Plätze: %d / %d" % [Game.state.decrees.size(), World.decree_slots()]
	for d in World.available_decrees():
		decrees_box.add_child(_decree_card(d))


func _decree_card(d: Dictionary) -> Control:
	var active := World.decree_active(d.id)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := Palette.GOLD if active else Color(Palette.VIOLET, 0.6)
	p.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.NIGHT, 0.95), border, 2 if active else 1, 12,
		Color(Palette.GOLD, 0.35) if active else Color(0, 0, 0, 0.5), 12 if active else 6, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	var title := Label.new()
	title.text = "%s  %s%s" % [d.icon, d.name, "   ✔ IN KRAFT" if active else ""]
	title.theme_type_variation = "GoldLabel"
	title.add_theme_color_override("font_color", Palette.GOLD_BRIGHT if active else Palette.PARCHMENT)
	vb.add_child(title)
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.add_theme_font_size_override("normal_font_size", 16)
	var eff := PackedStringArray()
	for k in d.get("daily", {}):
		var v := float(d.daily[k])
		var good := v > 0 if k != "attention" else v < 0
		eff.append("[color=%s]%s %+.2f/Tag[/color]" % ["#6fdc8c" if good else "#ff7a7a", Game.RESOURCE_LABELS.get(k, k), v])
	if d.has("upkeep"):
		eff.append("[color=#ff7a7a]Unterhalt −%d Gold/Tag[/color]" % int(d.upkeep))
	if d.has("income_mult"):
		eff.append("[color=#ff7a7a]Regionserträge ×%.1f[/color]" % float(d.income_mult))
	if d.has("unrest_decay"):
		eff.append("[color=#6fdc8c]Unruhe −%d/Tag[/color]" % int(d.unrest_decay))
	if d.has("fatigue_bonus"):
		eff.append("[color=#6fdc8c]Erholung +%d/Tag[/color]" % int(d.fatigue_bonus))
	if d.has("region_influence"):
		eff.append("[color=#6fdc8c]Einfluss in allen Regionen wächst[/color]")
	var ops := PackedStringArray()
	for cid in d.get("opinions", {}):
		if Game.state.chars.has(cid) and Game.cs(cid).unlocked:
			var v := int(d.opinions[cid])
			ops.append("[color=%s]%s %s[/color]" % ["#6fdc8c" if v > 0 else "#ff7a7a", Game.char_name(cid).split(" ")[0], "♥" if v > 0 else "✗"])
	desc.text = "[color=#b7aecb]%s[/color]\n%s\n[color=#8f86a3]Meinungen:[/color] %s" % [d.desc, "  ·  ".join(eff), " ".join(ops)]
	vb.add_child(desc)
	var b := Button.new()
	b.text = "Widerrufen" if active else "Verkünden"
	b.theme_type_variation = "ButtonDanger" if active else "ButtonPrimary"
	b.disabled = not active and Game.state.decrees.size() >= World.decree_slots()
	b.pressed.connect(func():
		var res := World.toggle_decree(d.id)
		Audio.sfx("order" if res.ok else "rebuke", 0.7)
		feedback.text = res.get("text", "")
		_refresh())
	vb.add_child(b)
	return p

class_name Grimoire
extends Overlay
## Zauberbuch des Overlords [B]: Seelen aus besiegten Gegnern in neue Magie und höhere Ränge verwandeln (I–III, ab
## Rang III mit Sonderwirkung), Zauber auf die Tasten 1–5 und R legen, Ringe anstecken oder einschmelzen.

const KEYS := ["1", "2", "3", "4", "5", "R"]
const STYLE_TITLES := {"ainz": "Ainz – Magie", "momon": "Momon – Techniken"}

var _tabs := TabContainer.new()
var _souls := Label.new()
var _sel := {"ainz": "fireball", "momon": "leap"}
var _pages := {}


func _init() -> void:
	super._init(Vector2(1220, 760))
	var head := make_header("Zauberbuch des Overlords", "Seelen Gefallener werden zu Macht – neue Zauber, höhere Ränge, Ringe")
	content.add_child(head)
	_souls.theme_type_variation = "GoldLabel"
	_souls.add_theme_font_size_override("font_size", 22)
	_souls.add_theme_color_override("font_color", Color(0.8, 0.62, 1.0))
	head.add_child(_souls)
	head.move_child(_souls, head.get_child_count() - 2)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_tabs)
	for st in ["ainz", "momon"]:
		var page := HBoxContainer.new()
		page.name = STYLE_TITLES[st]
		page.add_theme_constant_override("separation", 18)
		_tabs.add_child(page)
		_pages[st] = page
	var rp := VBoxContainer.new()
	rp.name = "Ringe des Overlords"
	rp.add_theme_constant_override("separation", 10)
	_tabs.add_child(rp)
	_pages["rings"] = rp
	Progress.grimoire_changed.connect(_refresh)
	Progress.souls_changed.connect(_on_souls)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() and _pages.is_empty():
		return
	_refresh_souls()
	for st in ["ainz", "momon"]:
		_build_style(st)
	_build_rings()


func _on_souls(_total: int, _gained: int) -> void:
	_refresh_souls()


func _refresh_souls() -> void:
	_souls.text = "❖  %d Seelen" % Progress.souls()


# ------------------------------------------------------------------ Zauber

func _base(st: String) -> Array:
	return Content.combat.player.styles[st].get("spells", [])


func _build_style(st: String) -> void:
	var page: HBoxContainer = _pages[st]
	for c in page.get_children():
		c.queue_free()
	# links: Liste
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.x = 400
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	page.add_child(sc)
	var lo := Progress.loadout(st, _base(st))
	for id in Progress.style_spells(st):
		var sp: Dictionary = Content.combat.spells.get(id, {})
		if sp.is_empty():
			continue
		var known := Progress.spell_known(id)
		var r := Progress.spell_rank(id)
		var b := Button.new()
		b.theme_type_variation = "ButtonPrimary" if _sel[st] == id else "ButtonCard"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var key_txt := ""
		var ki := lo.find(id)
		if ki >= 0:
			key_txt = "   [%s]" % KEYS[ki]
		elif sp.get("super", false):
			key_txt = "   [%s]" % Player3D.key_label("spell_super")
		var pips := "◆".repeat(r) + "◇".repeat(3 - r)
		if known:
			b.text = "%s   %s   %s%s" % [sp.get("icon", "✦"), sp.name, pips, key_txt]
		else:
			var e := Progress.spell_entry(id)
			b.text = "%s   %s   🔒 %d ❖" % [sp.get("icon", "✦"), sp.name, int(e.get("unlock", 0))]
			b.modulate = Color(0.72, 0.7, 0.8)
		var sid: String = id
		b.pressed.connect(func():
			_sel[st] = sid
			_build_style(st))
		list.add_child(b)
	# rechts: Einzelheiten
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 10)
	ds.add_child(det)
	page.add_child(ds)
	_detail(st, String(_sel[st]), det, lo)


func _detail(st: String, id: String, det: VBoxContainer, lo: Array) -> void:
	var sp: Dictionary = Content.combat.spells.get(id, {})
	if sp.is_empty():
		return
	var known := Progress.spell_known(id)
	var r := Progress.spell_rank(id)
	var col := Color(sp.get("color", "#c37bff"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	det.add_child(head)
	var ic := Label.new()
	ic.text = String(sp.get("icon", "✦"))
	ic.custom_minimum_size = Vector2(76, 76)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.add_theme_font_size_override("font_size", 44)
	ic.add_theme_color_override("font_color", col.lightened(0.15))
	ic.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.NIGHT, 0.9), col, 2, 38, Color(col, 0.5), 14))
	head.add_child(ic)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var t := Label.new()
	t.text = String(sp.name)
	t.theme_type_variation = "HeaderLabel"
	t.add_theme_font_size_override("font_size", 26)
	hv.add_child(t)
	var rl := Label.new()
	rl.text = ("Rang %s von III" % Progress.ROMAN[r - 1]) if known else "Noch nicht erlernt"
	rl.theme_type_variation = "GoldLabel"
	hv.add_child(rl)
	var desc := Label.new()
	desc.text = String(sp.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", NazarickTheme.italic_font(600))
	det.add_child(desc)
	# Werte: jetzt → nächster Rang
	var cur := Progress.effective_spell(id)
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	var lines := PackedStringArray()
	var nxt := {}
	if known and r < 3:
		var save: Dictionary = Progress.gs().ranks.duplicate()
		Progress.gs().ranks[id] = r + 1
		nxt = Progress.effective_spell(id)
		Progress.gs().ranks = save
	for spec in [["damage", "Schaden", "%d"], ["cooldown", "Abklingzeit", "%.1f s"], ["cost", "Kosten", "%d " + ("Mana" if sp.get("cost_type", "mana") == "mana" else "Ausdauer")]]:
		if not cur.has(spec[0]) or (spec[0] == "damage" and float(cur.damage) <= 0.0):
			continue
		var line := "[color=#8f86a3]%s:[/color]  %s" % [spec[1], String(spec[2]) % float(cur[spec[0]])]
		if not nxt.is_empty() and absf(float(nxt.get(spec[0], 0)) - float(cur[spec[0]])) > 0.01:
			line += "  [color=#6fdc8c]→ %s[/color]" % (String(spec[2]) % float(nxt[spec[0]]))
		lines.append(line)
	stats.text = "\n".join(lines)
	det.add_child(stats)
	# Rangstufen
	var ranks := RichTextLabel.new()
	ranks.bbcode_enabled = true
	ranks.fit_content = true
	var rt := PackedStringArray()
	var e := Progress.spell_entry(id)
	for k in [1, 2, 3]:
		var txt := "Grundform" if k == 1 else String(e.get("ranks", {}).get(str(k), {}).get("text", "stärker"))
		var mark := "[color=#6fdc8c]✔[/color]" if known and r >= k else "[color=#5a5468]◇[/color]"
		rt.append("%s  [b]Rang %s[/b] – %s" % [mark, Progress.ROMAN[k - 1], txt])
	ranks.text = "\n".join(rt)
	det.add_child(ranks)
	det.add_child(HSeparator.new())
	# Aktionen
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	det.add_child(acts)
	if not known:
		var can := Progress.can_unlock(id)
		var b := Button.new()
		b.text = "✦  Erlernen  (%d ❖)" % int(e.get("unlock", 0))
		b.theme_type_variation = "ButtonPrimary"
		b.disabled = not can[0]
		if not can[0]:
			b.tooltip_text = String(can[1])
			var why := Label.new()
			why.text = String(can[1])
			why.theme_type_variation = "MutedLabel"
			acts.add_child(b)
			acts.add_child(why)
		else:
			acts.add_child(b)
		b.pressed.connect(func():
			if Progress.unlock_spell(id):
				_fanfare()
				# frisch erlernt: auf die erste freie Taste
				var l := Progress.loadout(st, _base(st))
				var free := l.find("")
				if free >= 0 and not sp.get("super", false):
					Progress.set_loadout(st, _base(st), free, id))
	elif r < 3:
		var cost := Progress.upgrade_cost(id)
		var b := Button.new()
		b.text = "▲  Aufwerten auf Rang %s  (%d ❖)" % [Progress.ROMAN[r], cost]
		b.theme_type_variation = "ButtonPrimary"
		b.disabled = Progress.souls() < cost
		if b.disabled:
			b.tooltip_text = "Noch %d Seelen nötig" % (cost - Progress.souls())
		b.pressed.connect(func():
			if Progress.upgrade_spell(id):
				_fanfare())
		acts.add_child(b)
	else:
		var m := Label.new()
		m.text = "✦  Gemeistert"
		m.theme_type_variation = "GoldLabel"
		acts.add_child(m)
	# Tastenbelegung (Superrang bleibt auf seiner eigenen Taste)
	if known and not sp.get("super", false):
		var kl := Label.new()
		kl.text = "Auf Taste legen:"
		kl.theme_type_variation = "SubHeaderLabel"
		det.add_child(kl)
		var kr := HBoxContainer.new()
		kr.add_theme_constant_override("separation", 6)
		det.add_child(kr)
		for i in 6:
			var kb := Button.new()
			var on: String = String(lo[i])
			var on_name: String = String(Content.combat.spells.get(on, {}).get("name", "frei")) if on != "" else "frei"
			kb.text = "%s · %s" % [Player3D.key_label(Player3D.SPELL_ACTIONS[i]), on_name]
			kb.tooltip_text = on_name
			kb.clip_text = true
			kb.custom_minimum_size = Vector2(118, 40)
			kb.theme_type_variation = "ButtonPrimary" if on == id else "Button"
			var slot := i
			kb.pressed.connect(func():
				Progress.set_loadout(st, _base(st), slot, id)
				Audio.sfx("click", 0.6))
			kr.add_child(kb)
		if lo.has(id):
			var clr := Button.new()
			clr.text = "Von der Leiste nehmen"
			clr.pressed.connect(func():
				Progress.set_loadout(st, _base(st), lo.find(id), ""))
			det.add_child(clr)


func _fanfare() -> void:
	Audio.sfx("combat/rank_up", 0.8)
	var p: Node3D = CombatFX.player
	if p and is_instance_valid(p) and p.is_inside_tree():
		GroundMark.rune(p.get_parent(), p.global_position, 2.2, Color(0.66, 0.36, 1.0), 2.0, "a", p, 2.0)
		CombatFX.burst(p.get_parent(), "motes", p.global_position + Vector3.UP, Color(0.66, 0.36, 1.0), Vector3.UP, 2.0)


# ------------------------------------------------------------------ Ringe

func _build_rings() -> void:
	var page: VBoxContainer = _pages["rings"]
	for c in page.get_children():
		c.queue_free()
	var intro := Label.new()
	intro.text = "Drei Ringe kann Ainz zugleich tragen. Ringe fallen von Elite-Gegnern und Bossen; jeder Kapitel-Moment schenkt einen einzigartigen. Überzählige lassen sich zu Seelen einschmelzen."
	intro.theme_type_variation = "MutedLabel"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(intro)
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 12)
	page.add_child(slots_row)
	var slots: Array = Progress.gs().ring_slots
	for i in 3:
		var uid := String(slots[i])
		var e := Progress.ring_entry(uid)
		var d := Progress.ring_def(String(e.get("id", "")))
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelDim"
		card.custom_minimum_size = Vector2(380, 118)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var hl := Label.new()
		hl.text = "Platz %d" % (i + 1)
		hl.theme_type_variation = "SubHeaderLabel"
		cv.add_child(hl)
		if d.is_empty():
			var em := Label.new()
			em.text = "— frei —"
			em.theme_type_variation = "MutedLabel"
			cv.add_child(em)
		else:
			cv.add_child(_ring_label(d))
			var ub := Button.new()
			ub.text = "Ablegen"
			var si := i
			ub.pressed.connect(func():
				Progress.unequip_ring(si)
				Audio.sfx("click", 0.6))
			cv.add_child(ub)
		slots_row.add_child(card)
	var total := RichTextLabel.new()
	total.bbcode_enabled = true
	total.fit_content = true
	var sum := {}
	for uid in slots:
		var dd := Progress.ring_def(String(Progress.ring_entry(String(uid)).get("id", "")))
		for k in dd.get("effects", {}):
			sum[k] = float(sum.get(k, 0.0)) + float(dd.effects[k])
	total.text = ("[color=#8f86a3]Wirkung zusammen:[/color]  " + Progress.ring_text({"effects": sum})) if not sum.is_empty() else "[color=#8f86a3]Noch kein Ring angesteckt.[/color]"
	page.add_child(total)
	page.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	page.add_child(sc)
	var owned: Array = Progress.rings()
	if owned.is_empty():
		var l := Label.new()
		l.text = "Die Sammlung ist leer. Besiegt Elite-Gegner und Bosse – ihre Beute leuchtet am Boden."
		l.theme_type_variation = "MutedLabel"
		grid.add_child(l)
	for e in owned:
		var d := Progress.ring_def(String(e.id))
		if d.is_empty():
			continue
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelDim"
		card.custom_minimum_size = Vector2(560, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)
		var lv := _ring_label(d, String(e.get("source", "")))
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lv)
		var worn := String(e.uid) in slots
		if worn:
			var wl := Label.new()
			wl.text = "✔ getragen"
			wl.theme_type_variation = "GoldLabel"
			hb.add_child(wl)
		else:
			for i in 3:
				var eb := Button.new()
				eb.text = "→ %d" % (i + 1)
				eb.tooltip_text = "An Platz %d anstecken" % (i + 1)
				var u := String(e.uid)
				var si := i
				eb.pressed.connect(func():
					Progress.equip_ring(u, si)
					Audio.sfx("combat/ring_equip", 0.8))
				hb.add_child(eb)
			if not d.get("unique", false):
				var mb := Button.new()
				mb.text = "⟲ %d ❖" % int(Progress.gcfg().get("ring_melt", {}).get(String(d.rarity), 20))
				mb.tooltip_text = "Einschmelzen: der Ring wird zu Seelen"
				var u2 := String(e.uid)
				mb.pressed.connect(func():
					Progress.melt_ring(u2)
					Audio.sfx("combat/soul_burst", 0.6))
				hb.add_child(mb)
		grid.add_child(card)


func _ring_label(d: Dictionary, src: String = "") -> RichTextLabel:
	var r := Progress.rarity(String(d.rarity))
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.custom_minimum_size.x = 300
	l.text = "[color=%s][b]%s  %s[/b][/color]  [color=#8f86a3]%s%s[/color]\n%s\n[i][color=#8f86a3]%s[/color][/i]" % [
		String(r.get("color", "#ffffff")), String(d.get("icon", "◍")), String(d.name), String(r.get("name", "")),
		"  · einzigartig" if d.get("unique", false) else "", Progress.ring_text(d), String(d.get("desc", "")) + (("  – " + src) if src != "" else "")]
	return l

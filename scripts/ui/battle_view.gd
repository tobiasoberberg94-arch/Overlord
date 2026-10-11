class_name BattleView
extends Overlay
## Schlachtansicht: Schlachtfeld mit beiden Heeren, Feldherr, Taktikwahl und drei
## animierten Kampfrunden. Das Ergebnis berechnet Military.resolve_battle – diese
## Ansicht inszeniert es.

var dispatch: Dictionary
var canvas := BattleCanvas.new()
var ours_bar := StatBar.new("Nazarick", Palette.VIOLET_GLOW, "", 90)
var theirs_bar := StatBar.new("Feind", Palette.CRIMSON, "", 90)
var bottom := VBoxContainer.new()
var info := RichTextLabel.new()
var _battle: Dictionary
var _army: Dictionary


func _init(d: Dictionary) -> void:
	super._init(Vector2(1500, 840))
	closable = false
	dispatch = d
	_battle = Game.state.battles.get(d.get("context", {}).get("battle", ""), {})
	_army = Military.army(_battle.get("army", ""))
	var rname: String = World.region(_battle.get("region", "")).get("name", "")
	content.add_child(make_header(d.title, rname))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	content.add_child(top)
	var cid: String = _army.get("commander", "")
	var left := _side_box(cid, _army.get("name", "Legion"), true)
	top.add_child(left)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var vs := Label.new()
	vs.text = "⚔"
	vs.theme_type_variation = "TitleLabel"
	vs.add_theme_font_size_override("font_size", 44)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(vs)
	mid.add_child(ours_bar)
	mid.add_child(theirs_bar)
	top.add_child(mid)
	top.add_child(_side_box("", _battle.get("enemy_name", "Feind"), false))

	canvas.custom_minimum_size.y = 220
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var foe := float(_battle.get("enemy_strength", 0))
	if _battle.get("kind", "") == "conquest":
		foe *= Game.diff("enemy")
	canvas.setup(_army, int(foe))
	content.add_child(canvas)
	var ours := float(Military.strength(_army))
	var total := ours + foe
	ours_bar.set_value(ours, total, str(int(ours)))
	theirs_bar.set_value(foe, total, "~%d" % int(foe))

	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.add_theme_font_size_override("normal_font_size", 18)
	bottom.add_child(info)
	content.add_child(bottom)
	_build_tactics()


func _ready() -> void:
	super._ready()
	Audio.play_music("battle")


func _side_box(cid: String, title: String, ours: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size.x = 420
	hb.add_theme_constant_override("separation", 10)
	if not ours:
		hb.alignment = BoxContainer.ALIGNMENT_END
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(80, 96)
	p.char_id = cid if cid != "" else ("cocytus" if ours else "")
	if ours:
		p.variant = "battle"
	p.show_symbol = false
	var vb := VBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "GoldLabel"
	t.add_theme_color_override("font_color", Palette.GOLD_BRIGHT if ours else Color("ff8090"))
	vb.add_child(t)
	var s := Label.new()
	s.theme_type_variation = "MutedLabel"
	if ours:
		s.text = ("Feldherr: " + Game.char_name(cid)) if cid != "" else "Ohne Feldherr"
	else:
		s.text = "Verteidiger" if _battle.get("kind", "") == "conquest" else "Feindliches Heer"
	vb.add_child(s)
	if ours:
		hb.add_child(p)
		hb.add_child(vb)
	else:
		vb.alignment = BoxContainer.ALIGNMENT_BEGIN
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(vb)
	return hb


func _build_tactics() -> void:
	info.text = "[color=#d4af37]Wählt die Taktik, {lord}.[/color]".replace("{lord}", Game.lord())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	for t in Content.systems.tactics:
		var b := Button.new()
		b.text = "%s %s\n%s" % [t.icon, t.name, t.desc]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 88)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.theme_type_variation = "ButtonDanger" if t.id == "terror" else ("ButtonPrimary" if t.id == "assault" else "ButtonCard")
		b.pressed.connect(_fight.bind(t.id))
		grid.add_child(b)
	bottom.add_child(grid)


func _fight(tactic: String) -> void:
	for c in bottom.get_children():
		if c != info:
			c.queue_free()
	var before := float(Military.base_strength(_army))
	var result := Game.respond(dispatch.uid, "t_" + tactic)
	var r: Dictionary = Military.last_result
	var won: bool = r.get("won", false)
	var lost_strength := 0.0
	for k in r.get("lost", {}):
		lost_strength += float(Military.unit(k).strength) * int(r.lost[k])
	var our_loss := clampf(lost_strength / maxf(before, 1.0), 0.0, 1.0)
	var their_loss := 1.0 if won else clampf(float(r.get("ours", 0)) / maxf(float(r.get("theirs", 1)), 1.0) * 0.45, 0.1, 0.7)
	info.text = "[color=#c79bff]Taktik: %s[/color]" % r.get("tactic", "")
	var o0 := canvas.ours_alive
	var t0 := canvas.theirs_alive
	var ours_v := float(r.get("ours", 0))
	var theirs_v := float(r.get("theirs", 0))
	var total := ours_v + theirs_v
	for round_i in 3:
		var tw := create_tween()
		tw.tween_property(canvas, "charge", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		Audio.sfx("order" if round_i < 2 else "gong", 0.8)
		var frac := (round_i + 1) / 3.0
		canvas.ours_alive = o0 - roundi(o0 * our_loss * frac)
		canvas.theirs_alive = t0 - roundi(t0 * their_loss * frac)
		canvas.hit(true, roundi(lost_strength / 3.0))
		canvas.hit(false, roundi(theirs_v * their_loss / 3.0))
		ours_bar.set_value(ours_v * (1.0 - our_loss * frac), total, str(roundi(ours_v * (1.0 - our_loss * frac))))
		theirs_bar.set_value(theirs_v * (1.0 - their_loss * frac), total, str(roundi(theirs_v * (1.0 - their_loss * frac))))
		var back := create_tween()
		back.tween_property(canvas, "charge", 0.45, 0.45)
		await back.finished
	_show_result(won, result)


func _show_result(won: bool, result: Dictionary) -> void:
	var banner := Label.new()
	banner.text = "⚔  SIEG  ⚔" if won else "✗  NIEDERLAGE  ✗"
	banner.theme_type_variation = "TitleLabel"
	banner.add_theme_font_size_override("font_size", 38)
	banner.add_theme_color_override("font_color", Palette.GOLD_BRIGHT if won else Palette.DANGER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIFx.pop_in(banner, 0.4)
	Audio.sfx("love" if won else "rebuke", 0.8)
	info.text = result.get("reaction", "")
	UIFx.typewriter(info, 160.0)
	var summary: Array = result.get("summary", [])
	if not summary.is_empty():
		bottom.add_child(effect_chips(summary))
	var row := HBoxContainer.new()
	row.add_child(banner)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(row)
	bottom.move_child(row, 0)
	var done := Button.new()
	done.text = "Entlassen  ⟶"
	done.theme_type_variation = "ButtonPrimary"
	done.custom_minimum_size = Vector2(240, 48)
	done.pressed.connect(close)
	row.add_child(done)

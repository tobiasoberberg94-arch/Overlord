class_name GuardianCard
extends PanelContainer
## Statuskarte eines Untertanen (Portrait, Name, Status, Gunst & Stimmung).
## Albedo und Shalltear zeigen zusätzlich ihre Eifersucht als kleinen UI-Hinweis.

signal selected(cid: String)

var cid: String
var portrait := Portrait.new()
var name_label := Label.new()
var title_label := Label.new()
var status_label := Label.new()
var favor_bar := ProgressBar.new()
var mood_bar := ProgressBar.new()
var emotion_label := RichTextLabel.new()
var level_badge := Label.new()
var xp_bar := ProgressBar.new()
var _last_rank := 0
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _pulse: Tween


func _init(char_id: String) -> void:
	cid = char_id
	var col := Content.char_color(cid)
	custom_minimum_size = Vector2(158, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_normal_style = NazarickTheme.box(Color(Palette.NIGHT, 0.94), Color(col, 0.45), 2, 14, Color(0, 0, 0, 0.6), 8, 7)
	_hover_style = NazarickTheme.box(Color(Palette.NIGHT, 0.98), Palette.GOLD, 2, 14, Color(col, 0.55), 18, 7)
	add_theme_stylebox_override("panel", _normal_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	portrait.char_id = cid
	portrait.custom_minimum_size = Vector2(144, 150)
	vb.add_child(portrait)
	# Rang-Abzeichen (I–X) unten rechts im Portrait
	level_badge.add_theme_font_override("font", NazarickTheme.display_font(800))
	level_badge.add_theme_font_size_override("font_size", 14)
	level_badge.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	level_badge.add_theme_stylebox_override("normal", NazarickTheme.box(Color(Palette.VOID, 0.85), Palette.GOLD, 1, 9, Color.TRANSPARENT, 0, 3))
	level_badge.position = Vector2(96, 122)
	portrait.add_child(level_badge)

	name_label.text = Content.char_data(cid).get("name", cid).split(" ")[0]
	name_label.theme_type_variation = "GoldLabel"
	name_label.add_theme_color_override("font_color", col.lerp(Palette.GOLD_BRIGHT, 0.35))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(name_label)

	title_label.text = Content.char_data(cid).get("title", "")
	title_label.theme_type_variation = "MutedLabel"
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size.x = 140
	vb.add_child(title_label)

	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(status_label)

	for pair in [[favor_bar, Palette.GOLD, "Gunst"], [mood_bar, Palette.VIOLET_GLOW, "Stimmung"]]:
		var b: ProgressBar = pair[0]
		b.show_percentage = false
		b.custom_minimum_size = Vector2(0, 7)
		b.add_theme_stylebox_override("fill", NazarickTheme.box(pair[1], Color.TRANSPARENT, 0, 4, Color(pair[1], 0.5), 3, 0))
		b.tooltip_text = pair[2]
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		vb.add_child(b)
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 4)
	xp_bar.add_theme_stylebox_override("fill", NazarickTheme.box(Palette.GOLD_BRIGHT, Color.TRANSPARENT, 0, 2, Color(Palette.GOLD, 0.6), 3, 0))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(xp_bar)

	emotion_label.bbcode_enabled = true
	emotion_label.fit_content = true
	emotion_label.scroll_active = false
	emotion_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	emotion_label.add_theme_font_size_override("normal_font_size", 14)
	emotion_label.add_theme_font_size_override("bold_font_size", 14)
	emotion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(emotion_label)

	mouse_entered.connect(func(): add_theme_stylebox_override("panel", _hover_style))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", _normal_style))
	UIFx.add_hover_scale(self, 1.05)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(cid)


func refresh() -> void:
	var c := Game.cs(cid)
	visible = c.unlocked
	if not c.unlocked:
		return
	var st: String = c.status
	var status_col: Color = {
		Game.STATUS_READY: Palette.SUCCESS, Game.STATUS_MISSION: Palette.WARNING,
		Game.STATUS_RECOVER: Palette.MUTED, Game.STATUS_CONTROLLED: Palette.DANGER, "feldzug": Color("8fb8ff"),
	}.get(st, Palette.MUTED)
	var text: String = Game.STATUS_LABELS.get(st, st)
	if st == Game.STATUS_MISSION:
		for am in Game.state.active:
			if am.char_id == cid:
				text = "◷ noch %d T." % maxi(0, am.end_day - Game.state.day)
	status_label.text = "● " + text
	status_label.add_theme_color_override("font_color", status_col)
	portrait.dimmed = st in [Game.STATUS_MISSION, Game.STATUS_RECOVER, "feldzug"]
	favor_bar.value = c.favor
	mood_bar.value = c.mood
	var rk := Progress.rank(cid)
	var rp: Array = Progress.rank_progress(cid)
	level_badge.text = " %s " % Progress.ROMAN[rk - 1]
	xp_bar.max_value = maxi(1, rp[1])
	xp_bar.value = rp[0] if rp[1] > 0 else 1
	xp_bar.tooltip_text = "%s · %d / %d EP" % [Progress.rank_title(cid), rp[0], rp[1]] if rp[1] > 0 else Progress.rank_title(cid)
	if _last_rank != 0 and rk > _last_rank:
		UIFx.flash(self, Color(1.6, 1.4, 0.9))
	_last_rank = rk
	tooltip_text = "%s · %s\nGunst %d · Stimmung %d · Erschöpfung %d\nKlicken für Details" % [
		Content.char_data(cid).name, Progress.rank_title(cid), c.favor, c.mood, c.fatigue]

	# Emotionale Hinweise – nur bei den Rivalinnen
	if Content.char_data(cid).has("emotion"):
		var jcol := "#ff4a5a" if c.jealousy >= 60 else ("#ff9a3c" if c.jealousy >= 35 else "#8f86a3")
		var line := "[center][color=#ff7aa8]♥ %d[/color]  [color=%s]⚡ %d[/color][/center]" % [c.favor, jcol, c.jealousy]
		if c.jealousy >= 60:
			line = "[center][color=#ff4a5a][b]EIFERSÜCHTIG[/b][/color][/center]"
		elif c.favor < 35:
			line = "[center][color=#c79bff][b]sehnt sich nach Euch[/b][/color][/center]"
		emotion_label.text = line
		emotion_label.visible = true
		if c.jealousy >= 60 and _pulse == null:
			_pulse = UIFx.pulse(emotion_label, 0.4, 0.9)
		elif c.jealousy < 60 and _pulse != null:
			_pulse.kill()
			_pulse = null
			emotion_label.modulate.a = 1.0
	else:
		emotion_label.visible = false
	if st == Game.STATUS_CONTROLLED:
		add_theme_stylebox_override("panel", NazarickTheme.box(Color("2a050c"), Palette.CRIMSON, 2, 14, Color(Palette.CRIMSON, 0.7), 16, 7))

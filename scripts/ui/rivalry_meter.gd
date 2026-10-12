class_name RivalryMeter
extends VBoxContainer
## „Herzenskrieg“ – zeigt die Rivalität zwischen Albedo und Shalltear sowie
## deren Eifersucht. Färbt sich mit steigender Spannung blutrot.

var left := Portrait.new()
var right := Portrait.new()
var bar: Range
var _ornate := false
var value_label := Label.new()
var hint_label := Label.new()
var jl := Label.new()
var jr := Label.new()
var _fill := StyleBoxFlat.new()

const HINTS := [
	[15, "Ein seltener Frieden herrscht."],
	[35, "Höfliche Blicke, spitze Worte."],
	[55, "Spannung liegt in der Luft …"],
	[75, "Der Thronsaal wird zum Schlachtfeld."],
	[101, "Gleich fließt Blut. Viel Blut."],
]


func _init() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "⚔  HERZENSKRIEG  ⚔"
	title.theme_type_variation = "HeaderLabel"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for p in [left, right]:
		p.custom_minimum_size = Vector2(58, 66)
		p.show_symbol = false
	left.char_id = "albedo"
	right.char_id = "shalltear"
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.theme_type_variation = "GoldLabel"
	value_label.add_theme_font_size_override("font_size", 15)
	# Hinweis: Die Ornament-Leiste (bar_red) war zu kleinteilig – klarer Balken liest sich besser.
	var tex: Texture2D = null
	if tex:
		# Ornamentierter Balken: gedimmte Grafik als Grund, leuchtende als Füllung
		var tp := TextureProgressBar.new()
		tp.texture_under = tex
		tp.texture_progress = tex
		tp.tint_under = Color(0.3, 0.25, 0.35)
		tp.nine_patch_stretch = true
		tp.stretch_margin_left = 120
		tp.stretch_margin_right = 110
		tp.custom_minimum_size = Vector2(0, 54)
		tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar = tp
		_ornate = true
	else:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 12)
		_fill = NazarickTheme.box(Palette.CRIMSON, Color.TRANSPARENT, 0, 5, Color(Palette.CRIMSON, 0.6), 6, 0)
		pb.add_theme_stylebox_override("fill", _fill)
		bar = pb
	mid.add_child(value_label)
	row.add_child(left)
	row.add_child(mid)
	row.add_child(right)
	if _ornate:
		add_child(bar)
	else:
		mid.add_child(bar)

	var jrow := HBoxContainer.new()
	add_child(jrow)
	for l in [jl, jr]:
		l.add_theme_font_size_override("font_size", 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	jrow.add_child(jl)
	jrow.add_child(jr)

	hint_label.theme_type_variation = "MutedLabel"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint_label)


func refresh() -> void:
	var r: int = Game.state.rivalry
	var create := create_tween()
	create.tween_property(bar, "value", float(r), 0.6).set_trans(Tween.TRANS_CUBIC)
	value_label.text = "Rivalität %d" % r
	if _ornate:
		(bar as TextureProgressBar).tint_progress = Color(1, 1, 1).lerp(Color(1.4, 0.8, 0.8), r / 100.0)
	else:
		var col := Palette.VIOLET_GLOW.lerp(Palette.CRIMSON, r / 100.0)
		_fill.bg_color = col
		_fill.shadow_color = Color(col, 0.6)
	for h in HINTS:
		if r < h[0]:
			hint_label.text = "»%s«" % h[1]
			break
	var a := Game.cs("albedo")
	var s := Game.cs("shalltear")
	jl.text = "⚡ %d" % a.jealousy
	jr.text = "%d ⚡" % s.jealousy
	jl.add_theme_color_override("font_color", Palette.DANGER if a.jealousy >= 60 else Color("f1e6ff"))
	jr.add_theme_color_override("font_color", Palette.DANGER if s.jealousy >= 60 else Color("ff8fa3"))
	right.dimmed = s.status == Game.STATUS_CONTROLLED

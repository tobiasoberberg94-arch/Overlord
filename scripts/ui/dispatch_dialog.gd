class_name DispatchDialog
extends Overlay
## Zeigt eine Depesche (Bericht, Ereignis, Vorschlag, Eigeninitiative, Kapitel)
## mit Portrait, Text im Schreibmaschinen-Stil und Antwortoptionen.
## Nach der Wahl erscheint die Reaktion des Charakters samt Auswirkungen.

const KIND_LABELS := {
	"report": "BERICHT", "event": "EREIGNIS", "story": "KAPITEL",
	"proposal": "EIGENER VORSCHLAG", "initiative": "EIGENINITIATIVE",
}
const TIER_COLORS := {
	"triumph": Color("f5d77a"), "success": Color("6fdc8c"),
	"partial": Color("f2b43c"), "failure": Color("ff4a5a"),
}

var dispatch: Dictionary
var text := RichTextLabel.new()
var options_box := VBoxContainer.new()
var extra_box := VBoxContainer.new()
var portrait := Portrait.new()
var _typing: Tween


func _init(d: Dictionary) -> void:
	super._init(Vector2(1180, 740))
	dispatch = d
	closable = false
	var cid: String = d.get("char_id", "")
	var accent := Content.char_color(cid) if cid != "" else Palette.GOLD
	if Palette.frame("frame_skull"):
		frame_texture = Palette.frame("frame_skull")
	else:
		panel.add_theme_stylebox_override("panel", NazarickTheme.box(Color(Palette.ABYSS, 0.97), accent.lerp(Palette.GOLD, 0.4), 2, 16, Color(accent, 0.35), 32, 22))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)

	# ---------------- linke Spalte: Portrait
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var kind := Label.new()
	kind.text = "✦ " + KIND_LABELS.get(d.kind, "DEPESCHE") + " ✦"
	kind.theme_type_variation = "SubHeaderLabel"
	kind.add_theme_color_override("font_color", accent)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(kind)
	portrait.char_id = cid if cid != "" else "ainz"
	# Verliebte Variante, wenn Albedo/Shalltear triumphieren oder sehr in Gunst stehen
	if cid in ["albedo", "shalltear"] and (d.get("context", {}).get("tier", "") == "triumph" or Game.cs(cid).favor >= 80):
		portrait.variant = "love"
	portrait.custom_minimum_size = Vector2(300, 420)
	left.add_child(portrait)
	var nm := Label.new()
	nm.text = Content.char_data(cid).get("name", "Das Große Grab von Nazarick") if cid != "" else Game.state.lord_name
	nm.theme_type_variation = "GoldLabel"
	nm.add_theme_color_override("font_color", accent.lerp(Palette.GOLD_BRIGHT, 0.3))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(nm)
	var ttl := Label.new()
	ttl.text = Content.char_data(cid).get("title", "") if cid != "" else Game.format_date(Game.state.day)
	ttl.theme_type_variation = "MutedLabel"
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(ttl)
	if cid in ["albedo", "shalltear"]:
		var heart := Label.new()
		var c := Game.cs(cid)
		heart.text = "♥ Gunst %d   ⚡ Eifersucht %d" % [c.favor, c.jealousy]
		heart.add_theme_color_override("font_color", Color("ff7aa8"))
		heart.add_theme_font_size_override("font_size", 15)
		heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_child(heart)

	# ---------------- rechte Spalte: Text & Optionen
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	var ctx: Dictionary = d.get("context", {})
	right.add_child(make_header(d.title, ctx.get("subtitle", ctx.get("location", ""))))
	_add_location_banner(right, ctx)
	right.add_child(HSeparator.new())

	if d.kind == "report":
		var tier: String = ctx.get("tier", "success")
		var banner := Label.new()
		banner.text = "— %s —" % Game.TIER_LABELS.get(tier, tier).to_upper()
		banner.theme_type_variation = "HeaderLabel"
		banner.add_theme_color_override("font_color", TIER_COLORS.get(tier, Palette.GOLD))
		banner.add_theme_font_size_override("font_size", 24)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(banner)
		var dl := Label.new()
		if ctx.get("deviated", false):
			dl.text = "Befehl: %s   ⟶   eigenmächtig ausgelegt als: %s" % [ctx.directive, ctx.effective]
			dl.add_theme_color_override("font_color", Color("c79bff"))
		else:
			dl.text = "Befehl: %s" % ctx.get("effective", ctx.get("directive", ""))
			dl.theme_type_variation = "MutedLabel"
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(dl)

	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.scroll_following = false
	text.text = d.body
	text.gui_input.connect(_on_text_input)
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("italics_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 21)
	right.add_child(text)

	right.add_child(extra_box)
	var summary: Array = ctx.get("summary", [])
	if not summary.is_empty():
		var lbl := Label.new()
		lbl.text = "Auswirkungen auf Nazarick"
		lbl.theme_type_variation = "SubHeaderLabel"
		extra_box.add_child(lbl)
		extra_box.add_child(effect_chips(summary))

	options_box.add_theme_constant_override("separation", 8)
	right.add_child(options_box)
	_build_options()


## Ortsbild über dem Text (aus assets/backgrounds/, per Stichwort oder explizit).
func _add_location_banner(parent: Control, ctx: Dictionary) -> void:
	var tex: Texture2D = null
	if str(ctx.get("image", "")) != "":
		tex = Content.find_image("backgrounds", ctx.image)
	if tex == null:
		tex = Content.location_image(str(ctx.get("location", ctx.get("subtitle", ""))))
	if tex == null:
		return
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", NazarickTheme.box(Color.BLACK, Color(Palette.GOLD, 0.7), 1, 8, Color(0, 0, 0, 0.6), 6, 0))
	frame.custom_minimum_size.y = 130
	frame.clip_contents = true
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.modulate = Color(0.85, 0.8, 0.9)
	frame.add_child(tr)
	parent.add_child(frame)
	UIFx.fade_in(tr, 0.8, 0.2)


func _ready() -> void:
	super._ready()
	_typing = UIFx.typewriter(text, 160.0)


func _on_text_input(event: InputEvent) -> void:
	# Klick in den Text überspringt den Schreibmaschinen-Effekt
	if event is InputEventMouseButton and event.pressed and _typing and _typing.is_running():
		_typing.kill()
		text.visible_ratio = 1.0


func _build_options() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	options_box.add_child(flow)
	var variants := {"primary": "ButtonPrimary", "danger": "ButtonDanger", "success": "ButtonSuccess", "warning": "ButtonWarning"}
	var i := 0
	for opt in dispatch.options:
		var b := Button.new()
		b.text = opt.label
		b.theme_type_variation = variants.get(opt.get("variant", "default"), "Button")
		b.custom_minimum_size = Vector2(0, 46)
		if opt.key == "reward" and Game.state.resources.gold < 40:
			b.disabled = true
			b.tooltip_text = "Nicht genug Gold"
		b.pressed.connect(_choose.bind(opt.key))
		flow.add_child(b)
		UIFx.pop_in(b, 0.25, 0.15 + i * 0.06)
		i += 1


func _choose(key: String) -> void:
	var result := Game.respond(dispatch.uid, key)
	if key in ["praise", "reward", "approve"] and dispatch.get("char_id", "") in ["albedo", "shalltear"]:
		portrait.variant = "love"
		UIFx.flash(portrait, Color(1.5, 1.2, 1.3))
	for c in options_box.get_children():
		c.queue_free()
	for c in extra_box.get_children():
		c.queue_free()
	var reaction: String = result.get("reaction", "")
	var summary: Array = result.get("summary", [])
	if reaction == "" and summary.is_empty():
		close()
		return
	text.text = reaction if reaction != "" else "[i]Euer Wille geschehe.[/i]"
	_typing = UIFx.typewriter(text, 150.0)
	if not summary.is_empty():
		extra_box.add_child(effect_chips(summary))
	var done := Button.new()
	done.text = "Entlassen  ⟶"
	done.theme_type_variation = "ButtonPrimary"
	done.custom_minimum_size = Vector2(220, 46)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(close)
	options_box.add_child(done)
	UIFx.pop_in(done, 0.25, 0.2)
	done.grab_focus.call_deferred()

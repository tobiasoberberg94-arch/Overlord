class_name NazarickTheme
## Erzeugt das dunkle Nazarick-Theme (Schwarz, Violett, Gold, Blutrot).
##
## Das Theme wird einmalig per `tools/build_theme.gd` als
## res://assets/ui/nazarick_theme.tres gespeichert und in den Projekteinstellungen
## als Standard-Theme eingetragen. Wer Farben oder Rahmen ändern will, passt diese
## Datei an und baut das Theme neu:
##     godot --headless --script res://tools/build_theme.gd
##
## Typ-Varianten (theme_type_variation):
##   Button:  ButtonPrimary, ButtonDanger, ButtonSuccess, ButtonWarning, ButtonGhost, ButtonCard
##   Panel:   PanelGlass, PanelCard, PanelOrnate, PanelDim
##   Label:   TitleLabel, HeaderLabel, SubHeaderLabel, MutedLabel, GoldLabel

const FONT_DISPLAY := "res://assets/ui/fonts/Cinzel.ttf"
const FONT_BODY := "res://assets/ui/fonts/CormorantGaramond.ttf"
const FONT_ITALIC := "res://assets/ui/fonts/CormorantGaramond-Italic.ttf"
## Fallback für Symbole (⚔ ♛ ⚜ ☠ …), die Cinzel/Cormorant nicht enthalten.
const FONT_SYMBOLS := "res://assets/ui/fonts/DejaVuSans.ttf"


static func display_font(weight: int = 700) -> Font:
	return _variation(FONT_DISPLAY, weight)


static func body_font(weight: int = 600) -> Font:
	return _variation(FONT_BODY, weight)


static func italic_font(weight: int = 500) -> Font:
	return _variation(FONT_ITALIC, weight)


static func _variation(path: String, weight: int) -> Font:
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	# Variable Fonts: Achse "wght" über ihren OpenType-Tag setzen
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	fv.fallbacks = [load(FONT_SYMBOLS)]
	return fv


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 10,
		shadow: Color = Color.TRANSPARENT, shadow_size: int = 0, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = shadow
	sb.shadow_size = shadow_size
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 19

	# ------------------------------------------------------------ Labels
	t.set_color("font_color", "Label", Palette.PARCHMENT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	_label_variant(t, "TitleLabel", display_font(800), 40, Palette.GOLD_BRIGHT, Palette.BLOOD, 3)
	_label_variant(t, "HeaderLabel", display_font(700), 21, Palette.GOLD, Color(0, 0, 0, 0.8), 0)
	_label_variant(t, "SubHeaderLabel", display_font(600), 15, Palette.MUTED, Color(0, 0, 0, 0.8), 0)
	_label_variant(t, "MutedLabel", body_font(500), 16, Palette.MUTED, Color(0, 0, 0, 0.6), 0)
	_label_variant(t, "GoldLabel", display_font(700), 18, Palette.GOLD_BRIGHT, Color(0, 0, 0, 0.8), 0)

	# ------------------------------------------------------------ Panels
	var glass := box(Color(Palette.ABYSS, 0.86), Palette.GOLD_DARK, 1, 12, Color(Palette.VIOLET, 0.35), 14, 14)
	t.set_stylebox("panel", "Panel", glass)
	t.set_stylebox("panel", "PanelContainer", glass)
	for v in ["PanelGlass", "PanelCard", "PanelOrnate", "PanelDim"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "PanelGlass", glass)
	var card := box(Color(Palette.NIGHT, 0.95), Palette.GOLD_DARK, 2, 14, Color(0, 0, 0, 0.6), 10, 8)
	t.set_stylebox("panel", "PanelCard", card)
	var ornate := box(Color(Palette.ABYSS, 0.97), Palette.GOLD, 2, 16, Color(Palette.VIOLET_GLOW, 0.35), 28, 22)
	ornate.border_blend = true
	t.set_stylebox("panel", "PanelOrnate", ornate)
	t.set_stylebox("panel", "PanelDim", box(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 10, Color.TRANSPARENT, 0, 10))

	# ------------------------------------------------------------ Buttons
	_button(t, "Button", Palette.NIGHT, Palette.GOLD_DARK, Palette.GOLD, Palette.PARCHMENT)
	for v in ["ButtonPrimary", "ButtonDanger", "ButtonSuccess", "ButtonWarning", "ButtonGhost", "ButtonCard"]:
		t.set_type_variation(v, "Button")
	_button(t, "ButtonPrimary", Color("2b1a07"), Palette.GOLD, Palette.GOLD_BRIGHT, Palette.GOLD_BRIGHT)
	_button(t, "ButtonDanger", Color("2a050c"), Palette.BLOOD, Palette.CRIMSON, Color("ffc9d0"))
	_button(t, "ButtonSuccess", Color("0b2414"), Color("2f7a45"), Palette.SUCCESS, Color("d6ffe0"))
	_button(t, "ButtonWarning", Color("2a1c05"), Color("8a5d12"), Palette.WARNING, Color("ffe9bf"))
	_button(t, "ButtonGhost", Color(0, 0, 0, 0.0), Color(Palette.GOLD_DARK, 0.5), Palette.GOLD, Palette.MUTED)
	_button(t, "ButtonCard", Color(Palette.NIGHT, 0.92), Color(Palette.VIOLET, 0.6), Palette.GOLD, Palette.PARCHMENT)
	t.set_font("font", "Button", body_font(700))
	t.set_font_size("font_size", "Button", 19)
	t.set_font("font", "ButtonCard", body_font(600))
	t.set_font_size("font_size", "ButtonCard", 18)

	# ------------------------------------------------------------ ProgressBar
	t.set_stylebox("background", "ProgressBar", box(Color("0a0610"), Color(Palette.GOLD_DARK, 0.6), 1, 5, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.VIOLET_GLOW, Color.TRANSPARENT, 0, 5, Color(Palette.VIOLET_GLOW, 0.5), 4, 0))
	t.set_color("font_color", "ProgressBar", Palette.PARCHMENT)
	t.set_font_size("font_size", "ProgressBar", 12)

	# ------------------------------------------------------------ Scrollbars
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, box(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 4, Color.TRANSPARENT, 0, 2))
		t.set_stylebox("grabber", sb_type, box(Color(Palette.GOLD_DARK, 0.8), Color.TRANSPARENT, 0, 4, Color.TRANSPARENT, 0, 2))
		t.set_stylebox("grabber_highlight", sb_type, box(Palette.GOLD, Color.TRANSPARENT, 0, 4, Color.TRANSPARENT, 0, 2))
		t.set_stylebox("grabber_pressed", sb_type, box(Palette.GOLD_BRIGHT, Color.TRANSPARENT, 0, 4, Color.TRANSPARENT, 0, 2))

	# ------------------------------------------------------------ RichText
	t.set_color("default_color", "RichTextLabel", Palette.PARCHMENT)
	t.set_font("normal_font", "RichTextLabel", body_font(600))
	t.set_font("bold_font", "RichTextLabel", body_font(800))
	t.set_font("italics_font", "RichTextLabel", italic_font(600))
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	t.set_font_size("italics_font_size", "RichTextLabel", 20)
	t.set_constant("line_separation", "RichTextLabel", 2)

	# ------------------------------------------------------------ Tooltip
	t.set_stylebox("panel", "TooltipPanel", box(Palette.ABYSS, Palette.GOLD, 1, 6, Color(0, 0, 0, 0.7), 6, 8))
	t.set_color("font_color", "TooltipLabel", Palette.PARCHMENT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# ------------------------------------------------------------ Separator
	var sep := StyleBoxLine.new()
	sep.color = Color(Palette.GOLD, 0.35)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 10)
	return t


static func _label_variant(t: Theme, name: String, font: Font, size: int, color: Color, outline: Color, outline_size: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	if outline_size > 0:
		t.set_color("font_outline_color", name, outline)
		t.set_constant("outline_size", name, outline_size)


static func _button(t: Theme, type: String, bg: Color, border: Color, hover_border: Color, font: Color) -> void:
	var normal := box(bg, border, 1, 9, Color(0, 0, 0, 0.5), 4, 10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := box(bg.lightened(0.1), hover_border, 2, 9, Color(hover_border, 0.45), 12, 10)
	hover.content_margin_left = 16
	hover.content_margin_right = 16
	var pressed := box(bg.darkened(0.2), hover_border, 2, 9, Color(hover_border, 0.7), 6, 10)
	pressed.content_margin_left = 16
	pressed.content_margin_right = 16
	var disabled := box(Color(0.06, 0.05, 0.08, 0.8), Color(0.25, 0.22, 0.3), 1, 9, Color.TRANSPARENT, 0, 10)
	disabled.content_margin_left = 16
	disabled.content_margin_right = 16
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, box(Color.TRANSPARENT, Color(hover_border, 0.7), 1, 9, Color.TRANSPARENT, 0, 10))
	t.set_color("font_color", type, font)
	t.set_color("font_hover_color", type, font.lightened(0.25))
	t.set_color("font_pressed_color", type, hover_border)
	t.set_color("font_hover_pressed_color", type, hover_border)
	t.set_color("font_focus_color", type, font)
	t.set_color("font_disabled_color", type, Color(0.45, 0.42, 0.5))

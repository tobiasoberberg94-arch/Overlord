class_name StatBar
extends HBoxContainer
## Beschriftete, animierte Statusleiste (Icon · Name · Balken · Wert).

var icon_label := Label.new()
var icon_rect := TextureRect.new()
var name_label := Label.new()
var bar := ProgressBar.new()
var value_label := Label.new()
var _fill: StyleBoxFlat
var _shown := -1.0


func _init(label_text: String = "", color: Color = Palette.VIOLET_GLOW, icon: String = "", name_width: int = 110) -> void:
	add_theme_constant_override("separation", 8)
	icon_label.text = icon
	icon_label.custom_minimum_size.x = 18 if icon != "" else 0
	icon_label.add_theme_color_override("font_color", color)
	icon_label.visible = icon != ""
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(26, 26)
	icon_rect.visible = false
	name_label.text = label_text
	name_label.custom_minimum_size.x = name_width
	name_label.add_theme_font_size_override("font_size", 16)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(60, 12)
	value_label.custom_minimum_size.x = 44
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 16)
	set_color(color)
	add_child(icon_rect)
	add_child(icon_label)
	add_child(name_label)
	add_child(bar)
	add_child(value_label)


## Ersetzt das Zeichen-Icon durch eine Grafik.
func set_icon_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	icon_rect.texture = tex
	icon_rect.visible = true
	icon_label.visible = false


func set_color(color: Color) -> void:
	_fill = NazarickTheme.box(color, Color.TRANSPARENT, 0, 5, Color(color, 0.55), 5, 0)
	bar.add_theme_stylebox_override("fill", _fill)
	icon_label.add_theme_color_override("font_color", color)


## Setzt den Wert; animiert die Änderung und blitzt kurz auf.
func set_value(v: float, max_value: float = 100.0, text: String = "") -> void:
	bar.max_value = max_value
	value_label.text = text if text != "" else str(int(v))
	if _shown < 0:
		bar.value = v
	elif not is_equal_approx(_shown, v):
		var tw := create_tween()
		tw.tween_property(bar, "value", v, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		UIFx.flash(value_label, Color(1.6, 1.4, 0.7) if v > _shown else Color(1.6, 0.6, 0.6))
	_shown = v

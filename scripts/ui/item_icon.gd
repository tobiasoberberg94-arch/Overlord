class_name ItemIcon
extends Control
## Artefakt-Symbol: Seltenheitsfarbe als leuchtender Rahmen, darin die Grafik
## assets/ui/icons/item_<id>.webp – oder ersatzweise das Zeichen aus progression.json.
## Liegt frame_<seltenheit>.webp vor, wird es darübergelegt.

var item_id := "":
	set(v):
		item_id = v
		_def = Progress.item_def(v)
		_tex = Palette.icon("item_" + v)
		_frame = Palette.icon("frame_" + _def.get("rarity", "common"))
		queue_redraw()
var glow := true
var _def: Dictionary = {}
var _tex: Texture2D
var _frame: Texture2D
var _t := 0.0


func _init(id: String = "", size_px: float = 64.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_id = id


func _process(delta: float) -> void:
	if glow and _def.get("rarity", "common") in ["epic", "legendary", "world"]:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _def.is_empty():
		return
	var col := Progress.rarity_color(_def.rarity)
	var r := Rect2(Vector2.ZERO, size)
	var c := size / 2.0
	var rad := minf(size.x, size.y) / 2.0
	var tier := Progress.RARITY_ORDER.find(_def.rarity)
	if glow and tier >= 2:
		var pulse := 0.5 + 0.5 * sin(_t * 2.4)
		for i in 4:
			draw_circle(c, rad * (0.95 + i * 0.06 + pulse * 0.04), Color(col, 0.06 + 0.02 * tier))
	var sb := NazarickTheme.box(Color(Palette.VOID, 0.92).lerp(col, 0.12), col, 2 if tier >= 2 else 1, int(rad * 0.3))
	draw_style_box(sb, r.grow(-2))
	if _tex:
		draw_texture_rect(_tex, r.grow(-rad * 0.12), false)
	else:
		var font := get_theme_default_font()
		var fs := int(rad * 0.95)
		var glyph: String = _def.get("icon", "◆")
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(c.x - w / 2.0, c.y + fs * 0.36)
		draw_string_outline(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.25))
	if _frame:
		draw_texture_rect(_frame, r, false)
	if tier == 4:
		# Weltgegenstand: umlaufender Funke
		var a := _t * 1.8
		draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.86, 3.0, Color(1, 0.9, 0.9, 0.9))

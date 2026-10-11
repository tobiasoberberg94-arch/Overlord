class_name Actor3D
extends Node3D
## Begehbare Figur in der Welt: Portrait als „Aufsteller“ (Billboard) auf einem
## leuchtenden Podest, Name darüber. Kann angesprochen werden (Interaktion E).
## Auch für Objekte (Thron, Kriegstisch, Portal) – dann ohne Portrait.

signal used(actor: Actor3D)

var id := ""
var label := ""
var prompt := "Sprechen"
var kind := "char"        ## char | npc | object
var line := ""            ## Text für einfache NPCs
var radius := 2.6
var color := Palette.GOLD
var _sprite: Sprite3D
var _name: Label3D
var _ring: MeshInstance3D
var _t := randf() * 10.0
var _base_y := 0.0


static func character(cid: String, variant: String = "", height: float = 2.3) -> Actor3D:
	var a := Actor3D.new()
	a.id = cid
	a.kind = "char" if Game.state.get("chars", {}).has(cid) else "npc"
	a.label = Content.char_data(cid).get("name", cid)
	a.color = Content.char_color(cid)
	a._make_standee(cid, variant, height)
	return a


static func object(oid: String, text: String, prompt_text: String, col: Color, r: float = 3.0) -> Actor3D:
	var a := Actor3D.new()
	a.id = oid
	a.kind = "object"
	a.label = text
	a.prompt = prompt_text
	a.color = col
	a.radius = r
	return a


func _ready() -> void:
	_base_y = position.y
	if kind != "object":
		_ring = B3.cyl(self, 0.75, 0.85, 0.12, Vector3(0, 0.06, 0), B3.mat(Color(0.05, 0.03, 0.08), 0.5, 0.4), true, 24)
		B3.cyl(self, 0.8, 0.8, 0.02, Vector3(0, 0.13, 0), B3.mat(Color(color, 0.8), 0.3, 0.0, color, 2.0), false, 24)
		var l := B3.light(self, Vector3(0, 1.2, 0.8), color, 0.7, 4.0)
		l.shadow_enabled = false
	_name = Label3D.new()
	_name.text = label
	_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name.font = NazarickTheme.display_font(700)
	_name.font_size = 44
	_name.outline_size = 10
	_name.modulate = color.lerp(Palette.GOLD_BRIGHT, 0.4)
	_name.outline_modulate = Color(0, 0, 0, 0.85)
	_name.pixel_size = 0.006
	_name.position = Vector3(0, 2.75 if kind != "object" else 2.6, 0)
	_name.no_depth_test = false
	add_child(_name)


func _make_standee(cid: String, variant: String, height: float) -> void:
	var tex: Texture2D = null
	if variant != "":
		tex = Portrait.find_texture(cid + "_" + variant)
	if tex == null:
		tex = Portrait.find_texture(cid)
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.double_sided = true
	if tex:
		_sprite.texture = tex
		_sprite.pixel_size = height / float(tex.get_height())
		_sprite.position = Vector3(0, 0.25 + height / 2.0, 0)
	add_child(_sprite)


func set_highlight(on: bool) -> void:
	if _name:
		_name.modulate = Palette.GOLD_BRIGHT if on else color.lerp(Palette.GOLD_BRIGHT, 0.4)
		_name.font_size = 52 if on else 44


func _process(delta: float) -> void:
	_t += delta
	if _sprite:
		_sprite.position.y = 0.25 + _sprite.pixel_size * (_sprite.texture.get_height() if _sprite.texture else 0) / 2.0 + sin(_t * 1.3) * 0.04

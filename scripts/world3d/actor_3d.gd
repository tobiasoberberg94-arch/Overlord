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
var rig: CharacterRig
var mood := ""
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


func _make_standee(cid: String, variant: String, _height: float) -> void:
	# 3D-Figur: echtes Modell (assets/models/characters/<id>.glb) oder prozedurale Gestalt
	rig = CharacterRig.create(cid, func(r): ProcModel.figure(r, cid))
	rig.position.y = 0.13
	add_child(rig)
	mood = variant
	# Stimmung als farbiges Licht (verliebt, wütend, traurig)
	var mc: Variant = {"love": Color(1, 0.4, 0.7), "angry": Color(1, 0.15, 0.1), "sad": Color(0.3, 0.5, 1.0)}.get(variant)
	if mc != null:
		var l := B3.light(self, Vector3(0, 2.2, 0.6), mc, 1.2, 3.0)
		l.shadow_enabled = false


func set_highlight(on: bool) -> void:
	if _name:
		_name.modulate = Palette.GOLD_BRIGHT if on else color.lerp(Palette.GOLD_BRIGHT, 0.4)
		_name.font_size = 52 if on else 44


func _process(delta: float) -> void:
	_t += delta
	# Namen aus nächster Nähe ausblenden (steht dann ohnehin im Interaktionshinweis)
	var cam := get_viewport().get_camera_3d()
	if cam and _name:
		var d := cam.global_position.distance_to(_name.global_position)
		var a := clampf((d - 3.0) / 2.5, 0.0, 1.0)
		_name.modulate.a = a
		_name.outline_modulate.a = 0.85 * a
	if rig and not rig.has_model:
		var st := Fighter.S.BLOCK if mood == "battle" else (Fighter.S.STAGGER if mood == "sad" else Fighter.S.IDLE)
		rig.pose(st, "", 0.6 if st == Fighter.S.STAGGER else 0.0, 0.0)
	elif rig:
		rig.play("block" if mood == "battle" else "idle")

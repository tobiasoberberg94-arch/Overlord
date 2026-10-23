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
## Eigenleben: um den Heimatpunkt schlendern, stehen bleiben, sich dem Spieler zuwenden
static var player: Node3D
var wander_radius := 3.5
var home := Vector3.ZERO
var _goal := Vector3.ZERO
var _wait := randf_range(1.0, 5.0)
var _walking := false
var _look: HeadLook
var _look_w := 0.0
var _mark: Label3D
static var hide_labels := false   ## Filmszene: keine Namensschilder
var scripted := false          ## von einer Szene gesteuert: kein Schlendern, kein Zuwenden
var scripted_pose := "stand"   ## stand · walk · run · kneel · bow · battle · cast · anim:<key>
const WALK_SPEED := 1.05


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
	home = global_position
	_goal = home
	if kind != "object":
		# kein Podest mehr: die Figuren bewegen sich frei; ein schwaches Licht in ihrer Farbe bleibt
		var l := B3.light(self, Vector3(0, 1.6, 0.9), color, 0.45, 3.5)
		l.shadow_enabled = false
		if rig and rig.has_model:
			var sk: Skeleton3D = null
			for n in rig.find_children("*", "Skeleton3D", true, false):
				sk = n
				break
			if sk:
				_look = HeadLook.new()
				_look.rig = rig
				sk.add_child(_look)
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
	rig = CharacterRig.create(ProcModel.model_of(cid), func(r): ProcModel.figure(r, cid))
	rig.position.y = 0.13
	add_child(rig)
	ProcModel.accessories(rig, cid)
	mood = variant
	# Stimmung als farbiges Licht (verliebt, wütend, traurig)
	var mc: Variant = {"love": Color(1, 0.4, 0.7), "angry": Color(1, 0.15, 0.1), "sad": Color(0.3, 0.5, 1.0)}.get(variant)
	if mc != null:
		var l := B3.light(self, Vector3(0, 2.2, 0.6), mc, 1.2, 3.0)
		l.shadow_enabled = false


## Quest-Markierung über dem Kopf: "!" neue Quest, "?" Abgabe, "…" läuft, "" keine.
func set_quest_mark(m: String) -> void:
	if m == "":
		if _mark:
			_mark.visible = false
		return
	if _mark == null:
		_mark = Label3D.new()
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.font = NazarickTheme.display_font(800)
		_mark.font_size = 96
		_mark.outline_size = 14
		_mark.pixel_size = 0.006
		_mark.no_depth_test = true
		_mark.position = Vector3(0, 3.25, 0)
		add_child(_mark)
	_mark.visible = true
	_mark.text = m
	_mark.modulate = Palette.GOLD_BRIGHT if m == "!" else (Color(0.55, 1.0, 0.6) if m == "?" else Color(0.75, 0.72, 0.8))
	_mark.outline_modulate = Color(0.1, 0.05, 0.0, 0.9)


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
		# … und in der Ferne ebenfalls, damit sich die Namen im Thronsaal nicht stapeln
		var a := clampf((d - 3.0) / 2.5, 0.0, 1.0) * clampf((15.0 - d) / 4.0, 0.0, 1.0)
		if _name.font_size > 44:
			a = maxf(a, 0.0 if d < 3.0 else 1.0)
		if hide_labels or scripted:
			a = 0.0                        # Filmszene oder Szenenfigur: keine Namensschilder im Bild
		_name.modulate.a = a
		_name.outline_modulate.a = 0.85 * a
	if _mark and _mark.visible:
		_mark.position.y = 3.25 + sin(_t * 2.4) * 0.08
	if kind == "object":
		return
	_behave(delta)


func _behave(delta: float) -> void:
	if scripted:
		_behave_scripted()
		return
	var near := false
	var dp := 99.0
	if player and is_instance_valid(player):
		dp = Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		near = dp < 7.0
	var moving := false
	if near and dp < 4.5:
		# Spieler ist da: stehen bleiben und zuwenden
		_walking = false
		_wait = randf_range(2.0, 4.0)
		var to := player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 3.5 * delta))
	elif _walking:
		var to := _goal - global_position
		to.y = 0.0
		if to.length() < 0.25:
			_walking = false
			_wait = randf_range(3.0, 9.0)
		else:
			var step := to.normalized() * WALK_SPEED * delta
			global_position += step
			global_position.y = _ground_y(global_position)
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 5.0 * delta))
			moving = true
	else:
		_wait -= delta
		if _wait <= 0.0 and wander_radius > 0.1 and mood != "battle":
			_pick_goal()
	# Kopf folgt dem Spieler
	_look_w = move_toward(_look_w, 1.0 if near else 0.0, delta * 2.0)
	if _look:
		_look.weight = _look_w
		if player and is_instance_valid(player):
			_look.target = player.global_position + Vector3(0, 1.75, 0)
	if rig and not rig.has_model:
		var st := Fighter.S.BLOCK if mood == "battle" else (Fighter.S.STAGGER if mood == "sad" and not moving else Fighter.S.IDLE)
		rig.pose(st, "", 0.6 if st == Fighter.S.STAGGER else 0.0, 0.35 if moving else 0.0)
	elif rig:
		if moving:
			rig.play("walk", 0.85)
		else:
			rig.play("block" if mood == "battle" else "idle")


func _behave_scripted() -> void:
	if _look:
		_look.weight = 0.0
	if rig == null:
		return
	var p := scripted_pose
	if not rig.has_model:
		var st := Fighter.S.IDLE
		var mv := 0.0
		match p:
			"walk": mv = 0.4
			"run": mv = 1.0
			"battle": st = Fighter.S.BLOCK
			"cast": st = Fighter.S.CAST
		rig.pose(st, "", 0.0, mv)
		return
	match p:
		"walk": rig.play("walk", 0.9)
		"run": rig.play("run", 1.0)
		"battle": rig.play("block")
		"cast": rig.play("cast")
		_:
			if p.begins_with("anim:"):
				rig.play(p.substr(5))
			else:
				rig.play("idle")


## Ziel in der Nähe des Heimatpunkts, nur wenn der Weg frei ist und dort Boden liegt.
func _pick_goal() -> void:
	var space := get_world_3d().direct_space_state
	for i in 6:
		var a := randf() * TAU
		var r := randf_range(1.0, wander_radius)
		var g := home + Vector3(cos(a) * r, 0, sin(a) * r)
		var from := global_position + Vector3(0, 1.0, 0)
		var rq := PhysicsRayQueryParameters3D.create(from, g + Vector3(0, 1.0, 0))
		if not space.intersect_ray(rq).is_empty():
			continue
		g.y = _ground_y(g)
		if absf(g.y - global_position.y) > 0.4:
			continue
		_goal = g
		_walking = true
		return
	_wait = randf_range(2.0, 5.0)


func _ground_y(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p + Vector3(0, -2.0, 0))
	var r := space.intersect_ray(rq)
	return r.position.y if not r.is_empty() else p.y

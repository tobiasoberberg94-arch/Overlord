class_name Pickup
extends Node3D
## Aufhebbares in der Welt: Sammelstellen (Kräuter, Pilze, Früchte, Käfer, Erz, Relikte), Truhen und
## die Beute besiegter Gegner. Leuchtet und glitzert, Aufheben mit [E] (Beutel auch im Vorbeilaufen).
## Inhalt: entries = [[material|"gold"|"item", item_id, anzahl], …]

var entries: Array = []
var kind := "herb"            ## herb | ore | bug | chest | relic | bag
var label := ""
var color := Color.WHITE
var key := ""                 ## Merker für bereits gesammelte Stellen (Ort+Index)
var radius := 1.6
var auto := false             ## Beutel: im Vorbeilaufen aufheben
var _t := randf() * 10.0
var _visual: Node3D
var _light: OmniLight3D


static func material_pickup(item: String, n: int = 1) -> Pickup:
	var p := Pickup.new()
	var d: Dictionary = Quests.material(item)
	p.entries = [[item, "", n]]
	p.label = String(d.get("name", item))
	p.color = Color(d.get("color", "#ffffff"))
	p.kind = _kind_for(item)
	return p


static func chest() -> Pickup:
	var p := Pickup.new()
	p.kind = "chest"
	p.label = "Truhe"
	p.color = Palette.GOLD_BRIGHT
	p.radius = 2.0
	var gold := randi_range(15, 45)
	p.entries = [["gold", "", gold]]
	if randf() < 0.55:
		p.entries.append(["item", Progress.roll_item("uncommon" if randf() < 0.7 else "rare"), 1])
	if randf() < 0.5:
		p.entries.append(["relic_shard", "", 1])
	return p


static func loot_bag(entries_in: Array) -> Pickup:
	var p := Pickup.new()
	p.kind = "bag"
	p.label = "Beute"
	p.color = Palette.GOLD
	p.entries = entries_in
	p.auto = true
	p.radius = 1.4
	return p


static func _kind_for(item: String) -> String:
	match item:
		"moonleaf", "bloodrose", "bloodcap", "sunfruit": return "herb"
		"glowbeetle": return "bug"
		"iron_ore": return "ore"
		_: return "relic"


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var c := color
	match kind:
		"herb":
			for i in 5:
				var a := TAU * i / 5.0
				var leaf := B3.box(_visual, Vector3(0.05, 0.38, 0.14), Vector3(cos(a) * 0.08, 0.18, sin(a) * 0.08), B3.mat(Color(0.18, 0.42, 0.14), 0.7), false)
				leaf.rotation = Vector3(0.35 * cos(a), a, 0.35 * sin(a))
			B3.sphere(_visual, 0.07, Vector3(0, 0.42, 0), B3.mat(c, 0.4, 0.0, c, 2.2))
		"bug":
			for i in 3:
				B3.sphere(_visual, 0.035, Vector3(randf_range(-0.2, 0.2), randf_range(0.3, 0.7), randf_range(-0.2, 0.2)), B3.mat(c, 0.3, 0.0, c, 4.0))
		"ore":
			for i in 3:
				var r := B3.box(_visual, Vector3(0.28, 0.22, 0.24) * randf_range(0.7, 1.2), Vector3(randf_range(-0.15, 0.15), 0.1, randf_range(-0.15, 0.15)), B3.mat(Color(0.32, 0.3, 0.3), 0.9), false)
				r.rotation = Vector3(randf(), randf() * TAU, randf())
			B3.box(_visual, Vector3(0.08, 0.16, 0.08), Vector3(0.05, 0.28, 0.0), B3.mat(c, 0.2, 0.8, c, 1.5), false)
		"chest":
			B3.box(_visual, Vector3(0.9, 0.5, 0.55), Vector3(0, 0.25, 0), B3.mat(Color(0.32, 0.18, 0.08), 0.75), false)
			B3.box(_visual, Vector3(0.94, 0.16, 0.6), Vector3(0, 0.58, 0), B3.mat(Color(0.36, 0.2, 0.09), 0.75), false)
			B3.box(_visual, Vector3(0.96, 0.06, 0.62), Vector3(0, 0.5, 0), B3.mat(Palette.GOLD, 0.3, 0.9), false)
			B3.box(_visual, Vector3(0.12, 0.14, 0.04), Vector3(0, 0.45, 0.29), B3.mat(Palette.GOLD_BRIGHT, 0.3, 0.9), false)
		"bag":
			B3.sphere(_visual, 0.2, Vector3(0, 0.2, 0), B3.mat(Color(0.42, 0.3, 0.16), 0.9), Vector3(1, 0.85, 1))
			B3.cyl(_visual, 0.05, 0.08, 0.12, Vector3(0, 0.4, 0), B3.mat(Color(0.35, 0.24, 0.12), 0.9), false, 8)
			for i in 4:
				B3.cyl(_visual, 0.05, 0.05, 0.012, Vector3(randf_range(-0.3, 0.3), 0.01 + i * 0.012, randf_range(-0.3, 0.3)), B3.mat(Palette.GOLD_BRIGHT, 0.25, 1.0), false, 10)
		_:
			var cr := B3.box(_visual, Vector3(0.16, 0.26, 0.16), Vector3(0, 0.5, 0), B3.mat(c, 0.1, 0.4, c, 2.5), false)
			cr.rotation = Vector3(0.6, 0.7, 0.3)
	_light = OmniLight3D.new()
	_light.light_color = c
	_light.light_energy = 0.9 if kind != "chest" else 0.6
	_light.omni_range = 2.2
	_light.position.y = 0.6
	_light.shadow_enabled = false
	add_child(_light)
	if Settings.particles:
		var p := CPUParticles3D.new()
		p.amount = 10
		p.lifetime = 1.6
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.35
		p.direction = Vector3.UP
		p.spread = 20.0
		p.gravity = Vector3(0, 0.25, 0)
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.2
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var qm := QuadMesh.new()
		qm.size = Vector2(0.04, 0.04)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = c.lightened(0.3)
		m.emission_enabled = true
		m.emission = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = m
		p.mesh = qm
		p.position.y = 0.4
		add_child(p)


func _process(delta: float) -> void:
	_t += delta
	if _visual and kind in ["relic", "bug"]:
		_visual.rotation.y += delta * 1.2
		_visual.position.y = sin(_t * 2.0) * 0.06
	if _light:
		_light.light_energy = (0.9 if kind != "chest" else 0.6) * (0.8 + 0.2 * sin(_t * 3.0))


## Kurztext für den Interaktionshinweis.
func prompt() -> String:
	return "Öffnen" if kind == "chest" else ("Beute aufheben" if kind == "bag" else "Aufheben")

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


## Entdeckungen: Inschriftenstein (lore), Schrein (shrine), versteckter Schatz (cache).
static func discovery(kind_in: String, title: String, text: String) -> Pickup:
	var p := Pickup.new()
	p.kind = kind_in
	p.label = title
	p.set_meta("text", text)
	p.radius = 2.4
	match kind_in:
		"lore", "lectern", "plaque", "note", "spot": p.color = Color(0.55, 0.85, 1.0)
		"shrine": p.color = Color(1.0, 0.86, 0.5)
		_:
			p.color = Palette.GOLD
			p.entries = [["gold", "", randi_range(30, 80)], ["item", Progress.roll_item("rare" if randf() < 0.4 else "uncommon"), 1]]
			if randf() < 0.6:
				p.entries.append(["relic_shard", "", randi_range(1, 2)])
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
		"lore":
			# verwitterter Standstein (Fotoscan) mit schwach leuchtenden Runen
			var w := PhProps.whole("rock_07")
			var depth := 0.3
			if w.is_empty():
				B3.box(_visual, Vector3(0.7, 1.9, 0.28), Vector3(0, 0.95, 0), B3.mat(Color(0.42, 0.42, 0.44), 0.95), true)
			else:
				var sz: Vector3 = w.size
				var dims := [sz.x, sz.y, sz.z]
				dims.sort()
				# längste Achse aufrichten: Stein steht hochkant (≈ 0,8 × 1,8 × 0,45 m)
				var b := Basis()
				if sz.x == dims[2]:
					b = Basis(Vector3.BACK, PI / 2)
				elif sz.z == dims[2]:
					b = Basis(Vector3.RIGHT, PI / 2)
				var rs: Vector3 = (b * sz).abs()
				var sc := Vector3(0.8 / rs.x, 1.8 / rs.y, 0.45 / rs.z)
				var t := Transform3D(Basis().scaled(sc) * b, Vector3.ZERO)
				var a := t * AABB(-sz * 0.5 + Vector3(0, sz.y * 0.5, 0), sz)
				t.origin = Vector3(-a.get_center().x, -a.position.y - 0.08, -a.get_center().z)
				PhProps.attach(_visual, "rock_07", t)
				depth = 0.45
			for k in 4:
				B3.box(_visual, Vector3(0.26, 0.035, 0.01), Vector3(randf_range(-0.06, 0.06), 0.62 + k * 0.22, depth * 0.5 + 0.03), B3.mat(c, 0.3, 0.0, c, 1.4), false)
		"spot":
			pass                               # unsichtbar: das Sichtbare steht in data/dressing.json
		"lectern":
			# aufgeschlagenes Buch auf einem Lesepult (Innenräume)
			var wood := BuildingLook.photo_material("logs", "wood", Color(0.42, 0.33, 0.25), 0.5)
			B3.box(_visual, Vector3(0.44, 1.0, 0.44), Vector3(0, 0.5, 0), wood)
			var top := B3.box(_visual, Vector3(0.7, 0.05, 0.6), Vector3(0, 1.06, 0.04), wood, false)
			top.rotation_degrees.x = 22
			var page := B3.mat(Color(0.9, 0.85, 0.7), 0.9)
			for s in [-1.0, 1.0]:
				var pg := B3.box(_visual, Vector3(0.27, 0.05, 0.42), Vector3(0.15 * s, 1.1, 0.05), page, false)
				pg.rotation_degrees = Vector3(22, 0, 6 * s)
			B3.box(_visual, Vector3(0.03, 0.06, 0.42), Vector3(0, 1.11, 0.05), B3.mat(Color(0.3, 0.1, 0.1), 0.8), false).rotation_degrees.x = 22
		"plaque":
			# Holztafel an der Wand mit Metallplatten (z. B. die Rangtafel der Gilde)
			var wood := BuildingLook.photo_material("logs", "wood", Color(0.4, 0.3, 0.22), 0.5)
			B3.box(_visual, Vector3(1.5, 1.0, 0.06), Vector3(0, 1.65, 0), wood, false)
			B3.box(_visual, Vector3(1.56, 0.06, 0.09), Vector3(0, 2.18, 0), wood, false)
			var ranks := [Color(0.72, 0.45, 0.2), Color(0.5, 0.5, 0.52), Color(0.85, 0.85, 0.9), Color(0.95, 0.78, 0.3), Color(0.85, 0.88, 0.92), Color(0.6, 0.75, 0.95), Color(0.95, 0.6, 0.35), Color(0.3, 0.32, 0.4)]
			for k in ranks.size():
				var rc: Color = ranks[k]
				B3.box(_visual, Vector3(0.28, 0.16, 0.02), Vector3(-0.55 + (k % 4) * 0.37, 1.85 - (k / 4) * 0.32, 0.04), B3.mat(rc, 0.3, 0.85, rc * 0.2, 0.6), false)
		"note":
			# Aushang: Papier an einem Holzbrett
			var paper := B3.mat(Color(0.86, 0.8, 0.64), 0.95)
			B3.box(_visual, Vector3(0.5, 0.62, 0.012), Vector3(0, 1.55, 0.02), paper, false)
			B3.box(_visual, Vector3(0.04, 0.04, 0.03), Vector3(0, 1.84, 0.03), B3.mat(Color(0.7, 0.1, 0.1), 0.5), false)
		"shrine":
			# Heiligenfigur auf Steinsockel, Kerzenleuchter davor
			B3.box(_visual, Vector3(1.2, 0.7, 0.8), Vector3(0, 0.35, 0), B3.mat(Color(0.5, 0.48, 0.44), 0.9), true)
			if PhProps.attach(_visual, "gothic_statue", Transform3D(Basis(), Vector3(0, 0.7, -0.05))) == Vector3.ZERO:
				B3.box(_visual, Vector3(0.2, 1.2, 0.2), Vector3(0, 1.3, -0.25), B3.mat(Color(0.8, 0.76, 0.68), 0.7), false)
			PhProps.attach(_visual, "brass_candleholders", Transform3D(Basis(), Vector3(-0.42, 0.7, 0.25)))
			PhProps.attach(_visual, "wooden_candlestick", Transform3D(Basis(), Vector3(0.45, 0.7, 0.28)))
			for k in 3:
				var cp := Vector3(randf_range(-0.5, 0.5), 0.72, randf_range(0.1, 0.35))
				B3.cyl(_visual, 0.025, 0.025, 0.12, cp + Vector3(0, 0.06, 0), B3.mat(Color(0.95, 0.92, 0.85), 0.6), false, 6)
				B3.sphere(_visual, 0.02, cp + Vector3(0, 0.15, 0), B3.mat(Color(1, 0.7, 0.3), 0.3, 0.0, Color(1, 0.65, 0.25), 5.0))
		"cache":
			# Truhe, halb zwischen bemoosten Steinen versteckt (Fotoscans)
			if PhProps.attach(_visual, "treasure_chest", Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(0.8, 0.8, 0.8)), Vector3(0, -0.05, 0))) == Vector3.ZERO:
				B3.box(_visual, Vector3(0.9, 0.5, 0.55), Vector3(0, 0.25, 0), B3.mat(Color(0.32, 0.18, 0.08), 0.75), false)
			var stones := PhProps.pool(["boulder_01", "namaqualand_boulder_05", "rock_moss_set_02"])
			for k in 4:
				if stones.is_empty():
					break
				var v: Dictionary = stones[randi() % stones.size()]
				var vs: Vector3 = v.size
				var s := 0.6 / maxf(vs.x, maxf(vs.y, vs.z)) * randf_range(0.7, 1.15)
				var mi := MeshInstance3D.new()
				mi.mesh = v.mesh
				var a := float(k) / 4.0 * TAU + randf() * 0.5
				mi.transform = Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s, s)), Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.5)) * (v.xf as Transform3D)
				_visual.add_child(mi)
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
	_light.light_energy = {"chest": 0.6, "lore": 1.2, "shrine": 1.6, "cache": 0.0, "lectern": 0.5, "plaque": 0.3, "note": 0.3, "spot": 0.0}.get(kind, 0.9)
	_light.omni_range = 2.2
	_light.position.y = 0.6
	_light.shadow_enabled = false
	add_child(_light)
	if Settings.particles and not kind in ["cache", "lectern", "plaque", "note", "spot"]:
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
	if _light and kind != "cache":
		_light.light_energy = {"chest": 0.6, "lore": 1.2, "shrine": 1.6, "lectern": 0.5, "plaque": 0.3, "note": 0.3, "spot": 0.0}.get(kind, 0.9) * (0.8 + 0.2 * sin(_t * 3.0))
	elif _light:
		# versteckter Schatz glitzert erst aus der Nähe
		var pl := Actor3D.player
		var near := pl != null and is_instance_valid(pl) and pl.global_position.distance_to(global_position) < 7.0
		_light.light_energy = move_toward(_light.light_energy, 0.9 if near else 0.0, 0.05)


## Kurztext für den Interaktionshinweis.
func prompt() -> String:
	return {"chest": "Öffnen", "bag": "Beute aufheben", "lore": "Lesen", "lectern": "Lesen", "plaque": "Lesen", "note": "Lesen", "spot": "Lesen", "shrine": "Beten", "cache": "Durchsuchen"}.get(kind, "Aufheben")

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
		"memento": p.color = Color(1.0, 0.85, 0.45)
		"key": p.color = Color(1.0, 0.82, 0.4)
		_:
			p.color = Palette.GOLD
			p.entries = [["gold", "", randi_range(30, 80)], ["item", Progress.roll_item("rare" if randf() < 0.4 else "uncommon"), 1]]
			if randf() < 0.6:
				p.entries.append(["relic_shard", "", randi_range(1, 2)])
	return p


## Inschriften als Gegenstände (Hallen Nazaricks), lokal zeigt +z zum Spieler, die Wand/das Objekt liegt bei -z:
##   glyphs: leuchtende Zeilen auf einem vorhandenen Objekt 0,85 m dahinter (Grabstein) · lectern: Lesepult mit Buch
##   paper: Blätter, Feder und Tintenfass auf einer Tischplatte · board: Dienstplan an der Wand (Fundpunkt an der Wand)
##   coffins: großer und kleiner Sarg mit Rosen · bar: Bartisch mit Flaschen und Kelchen · sign: Warnschild auf Pfosten
func _lore_object(style: String, c: Color) -> void:
	_visual.set_meta("still", true)
	var glow := B3.mat(c, 0.3, 0.0, c, 1.4)
	match style:
		"glyphs":
			for k in 4:
				B3.box(_visual, Vector3(0.34 - (k % 2) * 0.1, 0.028, 0.01), Vector3(0, 1.3 - k * 0.13, -0.8), glow, false)
		"lectern":
			var wood := B3.mat(Color(0.3, 0.2, 0.13), 0.75)
			var gold := B3.mat(Color(0.86, 0.67, 0.27), 0.28, 0.92)
			B3.box(_visual, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.03, 0), wood)
			B3.box(_visual, Vector3(0.16, 1.0, 0.16), Vector3(0, 0.5, 0), wood)
			var top := B3.box(_visual, Vector3(0.62, 0.05, 0.48), Vector3(0, 1.05, 0), wood, false)
			top.rotation_degrees.x = 22
			var page := B3.mat(Color(0.9, 0.85, 0.7), 0.9)
			for sx in [-1.0, 1.0]:
				var pg := B3.box(_visual, Vector3(0.25, 0.04, 0.36), Vector3(0.14 * sx, 1.09, 0.0), page, false)
				pg.rotation_degrees = Vector3(22, 0, 5 * sx)
			B3.box(_visual, Vector3(0.03, 0.05, 0.37), Vector3(0, 1.1, 0.0), B3.mat(Color(0.35, 0.08, 0.08), 0.8), false).rotation_degrees.x = 22
			# Kette am Buch: „Verbotenes Regal“
			B3.box(_visual, Vector3(0.02, 0.02, 0.5), Vector3(0.28, 0.92, 0.1), gold, false).rotation_degrees.x = 50
		"paper":
			var sheet := B3.mat(Color(0.88, 0.83, 0.7), 0.92)
			for k in 3:
				var sh := B3.box(_visual, Vector3(0.21, 0.003, 0.29), Vector3(-0.12 + k * 0.11, 0.004 + k * 0.002, 0.02 * k), sheet, false)
				sh.rotation.y = -0.4 + k * 0.35
			B3.cyl(_visual, 0.035, 0.04, 0.06, Vector3(0.22, 0.03, -0.14), B3.mat(Color(0.06, 0.06, 0.08), 0.3, 0.4), false, 10)
			var quill := B3.box(_visual, Vector3(0.012, 0.012, 0.3), Vector3(0.12, 0.02, 0.05), B3.mat(Color(0.92, 0.9, 0.86), 0.8), false)
			quill.rotation = Vector3(0.12, 0.9, 0)
		"board":
			var frame := B3.mat(Color(0.36, 0.24, 0.14), 0.7)
			B3.box(_visual, Vector3(0.66, 0.86, 0.04), Vector3(0, 1.55, 0.02), frame, false)
			var paper := B3.mat(Color(0.9, 0.86, 0.74), 0.92)
			B3.box(_visual, Vector3(0.52, 0.7, 0.008), Vector3(0, 1.55, 0.045), paper, false)
			var ink := B3.mat(Color(0.2, 0.16, 0.14), 0.9)
			for k in 8:
				B3.box(_visual, Vector3(0.36 - (k % 3) * 0.06, 0.012, 0.004), Vector3(-0.02, 1.82 - k * 0.075, 0.05), ink, false)
			B3.sphere(_visual, 0.018, Vector3(0, 1.9, 0.055), B3.mat(Color(0.75, 0.1, 0.12), 0.4))
		"coffins":
			# schwarzes Holz, Deckel leicht verschoben, innen rot ausgeschlagen, Rosen auf dem Deckel; daneben ein kleiner Sarg
			var black := B3.mat(Color(0.06, 0.045, 0.045), 0.45, 0.1)
			var velvet := B3.mat(Color(0.42, 0.02, 0.04), 0.9)
			var rose := B3.mat(Color(0.62, 0.02, 0.05), 0.6)
			var gold := B3.mat(Color(0.86, 0.67, 0.27), 0.28, 0.92)
			for cf in [[Vector3(-0.55, 0, 0), Vector3(2.05, 0.56, 0.72), 7.0], [Vector3(1.05, 0, 0.12), Vector3(1.15, 0.38, 0.44), -4.0]]:
				var at: Vector3 = cf[0]
				var sz: Vector3 = cf[1]
				B3.box(_visual, Vector3(sz.x, sz.y * 0.82, sz.z), at + Vector3(0, sz.y * 0.41, 0), black)
				B3.box(_visual, Vector3(sz.x - 0.1, 0.03, sz.z - 0.1), at + Vector3(0, sz.y * 0.82 + 0.005, 0), velvet, false)
				var lid := B3.box(_visual, Vector3(sz.x + 0.04, sz.y * 0.16, sz.z + 0.04), at + Vector3(0.12, sz.y * 0.92, 0.06), black, false)
				lid.rotation_degrees.y = float(cf[2])
				B3.box(_visual, Vector3(sz.x * 0.5, 0.012, 0.03), at + Vector3(0.12, sz.y + 0.002, 0.06), gold, false).rotation_degrees.y = float(cf[2])
				for k in 5:
					B3.sphere(_visual, 0.045, at + Vector3(-sz.x * 0.25 + k * sz.x * 0.12, sz.y + 0.04, 0.04 + (k % 2) * 0.08), rose, Vector3(1.0, 0.7, 1.0))
			# zwei hohe Kerzenständer mit roten Kerzen zu beiden Seiten (sonst verschwänden die schwarzen Särge im Dunkel)
			var iron := B3.mat(Color(0.12, 0.11, 0.1), 0.5, 0.7)
			var wax := B3.mat(Color(0.55, 0.05, 0.06), 0.6)
			for cx in [-1.95, 2.0]:
				B3.cyl(_visual, 0.03, 0.12, 1.1, Vector3(cx, 0.55, 0.05), iron, false, 8)
				B3.cyl(_visual, 0.11, 0.08, 0.04, Vector3(cx, 1.12, 0.05), iron, false, 10)
				B3.cyl(_visual, 0.035, 0.035, 0.22, Vector3(cx, 1.25, 0.05), wax, false, 8)
				B3.fire(_visual, Vector3(cx, 1.38, 0.05), Color(1.0, 0.62, 0.3), 6)
				var cl := B3.light(_visual, Vector3(cx, 1.5, 0.35), Color(1.0, 0.62, 0.35), 0.9, 4.5)
				cl.shadow_enabled = false
				cl.set_meta("flicker", true)
		"bar":
			if not PhProps.attach(_visual, "round_wooden_table_01", Transform3D(Basis(), Vector3.ZERO)) == Vector3.ZERO:
				var ty := 0.78
				PhProps.attach(_visual, "wine_bottles_01", Transform3D(Basis(Vector3.UP, 0.6), Vector3(-0.12, ty, -0.05)))
				PhProps.attach(_visual, "brass_goblets", Transform3D(Basis(Vector3.UP, 1.7), Vector3(0.22, ty, 0.12)))
				PhProps.attach(_visual, "metal_jug", Transform3D(Basis(Vector3.UP, 2.4), Vector3(0.05, ty, 0.28)))
			else:
				var wood := B3.mat(Color(0.32, 0.2, 0.12), 0.7)
				B3.cyl(_visual, 0.55, 0.55, 0.05, Vector3(0, 0.76, 0), wood, false, 20)
				B3.cyl(_visual, 0.08, 0.12, 0.74, Vector3(0, 0.37, 0), wood, true, 10)
				for k in 3:
					B3.cyl(_visual, 0.035, 0.04, 0.3, Vector3(-0.2 + k * 0.18, 0.93, -0.1), B3.mat(Color(0.1, 0.25, 0.12), 0.15, 0.2), false, 10)
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.55
			cy.height = 0.8
			cs.shape = cy
			cs.position = Vector3(0, 0.4, 0)
			body.add_child(cs)
			_visual.add_child(body)
		"sign":
			var stone := BuildingLook.photo_material("limestone", "stone", Color(0.62, 0.58, 0.52), 0.05)
			var bronze := B3.mat(Color(0.55, 0.36, 0.18), 0.35, 0.85)
			B3.box(_visual, Vector3(0.5, 0.12, 0.5), Vector3(0, 0.06, 0), stone)
			B3.box(_visual, Vector3(0.22, 1.1, 0.22), Vector3(0, 0.66, 0), stone)
			var plate := B3.box(_visual, Vector3(0.7, 0.46, 0.05), Vector3(0, 1.35, 0.06), bronze, false)
			plate.rotation_degrees.x = -12
			for k in 3:
				var ln := B3.box(_visual, Vector3(0.5 - k * 0.08, 0.026, 0.01), Vector3(0, 1.47 - k * 0.1, 0.09 + k * 0.02), glow, false)
				ln.rotation_degrees.x = -12


## Bäumchen mit Namensschild (Dschungel): junger Baum auf einem Erdhügel im Steinkranz, daneben ein Holzpflock mit
## Schild in Auras Schrift.
func _lore_sapling() -> void:
	_visual.set_meta("still", true)
	var soil := B3.mat(Color(0.36, 0.26, 0.17), 0.97)
	B3.sphere(_visual, 0.6, Vector3(0, -0.03, 0), soil, Vector3(1.0, 0.14, 1.0))
	var stones := PhProps.pool(["stone_01", "boulder_01"])
	for k in 9:
		var a := TAU * k / 9.0
		if stones.is_empty():
			B3.sphere(_visual, 0.07, Vector3(cos(a) * 0.6, 0.02, sin(a) * 0.6), B3.mat(Color(0.45, 0.44, 0.4), 0.9), Vector3(1.2, 0.7, 1.0))
			continue
		var v: Dictionary = stones[k % stones.size()]
		var vs: Vector3 = v.size
		var s := 0.16 / maxf(vs.x, maxf(vs.y, vs.z))
		var mi := MeshInstance3D.new()
		mi.mesh = v.mesh
		mi.transform = Transform3D(Basis(Vector3.UP, a * 2.3).scaled(Vector3(s, s, s)), Vector3(cos(a) * 0.62, -0.01, sin(a) * 0.62)) * (v.xf as Transform3D)
		_visual.add_child(mi)
	# Bäumchen: Fotoscan-Strauch als Krone auf einem dünnen Stämmchen, sonst einfache Krone
	var bark := B3.mat(Color(0.42, 0.33, 0.24), 0.9)
	B3.cyl(_visual, 0.03, 0.05, 0.9, Vector3(0, 0.45, 0), bark, false, 7)
	if not _scan("shrub_01", 1.15, 0.6, Vector3(0, 0.55, 0)):
		var leaf := B3.mat(Color(0.16, 0.32, 0.1), 0.9)
		for k in 4:
			B3.sphere(_visual, 0.26 - k * 0.03, Vector3(sin(k * 2.1) * 0.12, 0.85 + k * 0.14, cos(k * 2.1) * 0.12), leaf, Vector3(1.0, 0.8, 1.0))
	# Pflock mit Schild
	var wood := B3.mat(Color(0.62, 0.48, 0.32), 0.85)
	B3.box(_visual, Vector3(0.06, 1.05, 0.06), Vector3(0.8, 0.52, 0.18), wood, false)
	var board := B3.box(_visual, Vector3(0.62, 0.32, 0.035), Vector3(0.8, 0.95, 0.21), wood, false)
	board.rotation_degrees.z = -4.0
	var lb := Label3D.new()
	lb.text = "Gepflanzt von Mare\nNICHT gießen!"
	lb.font_size = 34
	lb.pixel_size = 0.0017
	lb.modulate = Color(0.14, 0.07, 0.02)
	lb.outline_size = 0
	lb.position = Vector3(0.8, 0.95, 0.23)
	lb.rotation_degrees.z = -4.0
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_visual.add_child(lb)


## Gefrorener Krieger (Gletscher): ein Todesritter in einem klaren Eisblock, mitten im schweren Hieb erstarrt – die
## Klinge noch erhoben. Ohne Modell eine dunkle Gestalt in Rüstung.
func _lore_frozen() -> void:
	_visual.set_meta("still", true)
	var rig := CharacterRig.create("death_knight", Callable())
	if rig.has_model:
		rig.position = Vector3(0, 0.04, 0)
		rig.scale = Vector3.ONE * 0.8
		_visual.add_child(rig)
		# Ausholen: die Klinge steht über dem Kopf (später im Hieb ragt sie seitlich weit aus dem Block)
		rig.play("attack_heavy")
		if rig.anim and rig.anim.current_animation != "":
			rig.anim.seek(rig.anim_length("attack_heavy") * 0.2, true)
		rig.time_mult = 0.0
		rig.glow(Color(0.45, 0.75, 1.0), 0.22)
	else:
		var armor := B3.mat(Color(0.2, 0.22, 0.26), 0.45, 0.8)
		var steel := B3.mat(Color(0.7, 0.74, 0.8), 0.2, 1.0)
		for sx in [-1.0, 1.0]:
			B3.box(_visual, Vector3(0.16, 0.7, 0.18), Vector3(sx * 0.13, 0.55, 0.0), armor, false)
		B3.box(_visual, Vector3(0.5, 0.62, 0.3), Vector3(0, 1.2, 0), armor, false)
		B3.sphere(_visual, 0.15, Vector3(0, 1.65, 0.02), armor, Vector3(1.0, 1.15, 1.05))
		var blade := B3.box(_visual, Vector3(0.07, 1.25, 0.02), Vector3(0.38, 2.45, 0.05), steel, false)
		blade.rotation_degrees.z = -8.0
	# Eisblock: klar, bläulich, glänzend (durchsichtig, damit die Gestalt zu sehen ist), Reif oben, Wehe am Fuß
	var ice := StandardMaterial3D.new()
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.albedo_color = Color(0.62, 0.82, 0.96, 0.3)
	ice.roughness = 0.04
	ice.metallic_specular = 0.9
	ice.clearcoat_enabled = true
	ice.clearcoat = 1.0
	ice.rim_enabled = true
	ice.rim = 0.7
	ice.rim_tint = 0.3
	ice.cull_mode = BaseMaterial3D.CULL_DISABLED
	var size := Vector3(2.0, 3.1, 1.6)
	var blk := B3.box(_visual, size, Vector3(0, size.y * 0.5, 0), ice, false)
	blk.rotation_degrees = Vector3(0, 0, 2.0)
	blk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(cs)
	_visual.add_child(body)
	var frost := B3.mat(Color(0.9, 0.94, 1.0), 0.85)
	B3.box(_visual, Vector3(size.x + 0.05, 0.07, size.z + 0.05), Vector3(0.05, size.y + 0.02, 0), frost, false)
	B3.sphere(_visual, 1.0, Vector3(0, 0.0, 0), frost, Vector3(1.05, 0.2, 0.85))


## Snow Globe Cottage (Gletscher): Schneekugel auf einem Steinsockel mit Goldring, darin ein Häuschen mit Tannen im
## Schnee.
func _lore_globe() -> void:
	_visual.set_meta("still", true)
	var gr := Node3D.new()
	gr.scale = Vector3.ONE * 1.45
	_visual.add_child(gr)
	var stone := BuildingLook.photo_material("limestone", "stone", Color(0.55, 0.56, 0.62), 0.05)
	var gold := B3.mat(Color(0.86, 0.67, 0.27), 0.28, 0.92)
	B3.cyl(gr, 0.42, 0.5, 0.55, Vector3(0, 0.27, 0), stone, true, 16)
	B3.cyl(gr, 0.47, 0.47, 0.06, Vector3(0, 0.57, 0), gold, false, 24)
	var snow := B3.mat(Color(0.93, 0.95, 1.0), 0.85)
	B3.cyl(gr, 0.44, 0.44, 0.06, Vector3(0, 0.63, 0), snow, false, 24)
	# Häuschen: Wände, Dach, Tür, ein warm erleuchtetes Fenster, Schnee auf dem Dach
	var wall := BuildingLook.photo_material("planks", "wood", Color(0.62, 0.42, 0.3), 0.2)
	B3.box(gr, Vector3(0.3, 0.2, 0.22), Vector3(0, 0.76, 0), wall, false)
	var roof := B3.prism(gr, Vector3(0.36, 0.15, 0.28), Vector3(0, 0.935, 0), B3.mat(Color(0.5, 0.16, 0.12), 0.7))
	roof.rotation_degrees.y = 90.0
	var rs := B3.prism(gr, Vector3(0.37, 0.05, 0.29), Vector3(0, 0.99, 0), snow)
	rs.rotation_degrees.y = 90.0
	B3.box(gr, Vector3(0.06, 0.11, 0.01), Vector3(-0.06, 0.715, 0.112), B3.mat(Color(0.25, 0.15, 0.08), 0.8), false)
	B3.box(gr, Vector3(0.06, 0.05, 0.01), Vector3(0.07, 0.78, 0.112), B3.mat(Color(1.0, 0.75, 0.4), 0.4, 0.0, Color(1.0, 0.7, 0.35), 2.2), false)
	var fir := B3.mat(Color(0.1, 0.24, 0.14), 0.85)
	for p in [Vector3(-0.26, 0.66, 0.08), Vector3(0.25, 0.66, -0.1), Vector3(0.18, 0.66, 0.24)]:
		B3.cone(gr, 0.07, 0.24, p, fir)
		B3.cone(gr, 0.05, 0.1, p + Vector3(0, 0.14, 0), snow)
	# Glaskugel: klar, kräftige Spiegelung am Rand
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.86, 0.93, 1.0, 0.17)
	glass.roughness = 0.0
	glass.metallic_specular = 1.0
	glass.clearcoat_enabled = true
	glass.clearcoat = 1.0
	glass.rim_enabled = true
	glass.rim = 1.0
	glass.rim_tint = 0.15
	var g := B3.sphere(gr, 0.46, Vector3(0, 1.02, 0), glass)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ein paar Flocken in der Kugel
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 14:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.1, 0.38)
		B3.sphere(gr, 0.008, Vector3(0, 1.02, 0) + d, snow)


static func _kind_for(item: String) -> String:
	match item:
		"moonleaf", "bloodrose", "bloodcap", "sunfruit": return "herb"
		"glowbeetle": return "bug"
		"iron_ore": return "ore"
		_: return "relic"


## Fotoscan auf Zielhöhe h einsetzen (Boden auf 0, mittig); false = Scan fehlt.
func _scan(name: String, h: float, yaw: float = 0.0, at := Vector3.ZERO) -> bool:
	var wh := PhProps.whole(name)
	if wh.is_empty():
		return false
	var sz: Vector3 = wh.size
	var s := h / maxf(sz.y, 0.001)
	PhProps.attach(_visual, name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), at))
	return true


## Pilzgruppe (Blutkappe): helle Stiele, rote Hüte mit weißen Tupfen.
func _mushrooms(c: Color) -> void:
	var stem := B3.mat(Color(0.86, 0.82, 0.74), 0.8)
	var cap := B3.mat(Color(0.62, 0.06, 0.08), 0.55, 0.0, c * 0.25, 0.6)
	var spot := B3.mat(Color(0.95, 0.92, 0.85), 0.7)
	for i in 3:
		var hgt := randf_range(0.12, 0.24)
		var p := Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
		B3.cyl(_visual, 0.022, 0.03, hgt, p + Vector3(0, hgt * 0.5, 0), stem, false, 8)
		var r := randf_range(0.06, 0.1)
		B3.sphere(_visual, r, p + Vector3(0, hgt, 0), cap, Vector3(1.0, 0.55, 1.0))
		for k in 4:
			var a := randf() * TAU
			B3.sphere(_visual, r * 0.14, p + Vector3(cos(a) * r * 0.55, hgt + r * 0.38, sin(a) * r * 0.55), spot)


## Kristallsplitter auf einem Stein (Reliktsplitter cyan, Dunkle Essenz schwarzviolett).
func _shards(c: Color, dark: bool) -> void:
	_scan("stone_01", 0.18, randf() * TAU)
	var m := B3.mat(Color(0.05, 0.02, 0.08) if dark else Color(c, 0.85), 0.12, 0.3, c, 1.6 if dark else 2.4)
	for k in 3:
		var h := randf_range(0.18, 0.34)
		var pr := B3.prism(_visual, Vector3(0.07, h, 0.07), Vector3(randf_range(-0.06, 0.06), 0.12 + h * 0.4, randf_range(-0.06, 0.06)), m, Vector3(randf_range(-25, 25), randf() * 360.0, randf_range(-25, 25)))
		pr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var c := color
	var item := String(entries[0][0]) if not entries.is_empty() and entries[0].size() > 0 else ""
	match kind:
		"herb":
			# echte Pflanze (Fotoscan) mit ein paar leuchtenden Blüten bzw. Früchten
			var ok := true
			match item:
				"bloodrose": ok = _scan("flower_gazania", 0.45, randf() * TAU)
				"sunfruit": ok = _scan("anthurium_botany_01", 0.6, randf() * TAU)
				"bloodcap": _mushrooms(c)
				_: ok = _scan("periwinkle_plant", 0.4, randf() * TAU)
			if not ok:
				_mushrooms(c)
			for i in 3:
				B3.sphere(_visual, 0.022, Vector3(randf_range(-0.12, 0.12), randf_range(0.22, 0.4), randf_range(-0.12, 0.12)), B3.mat(c, 0.4, 0.0, c, 2.0))
		"bug":
			# Leuchtkäfer: kleiner Busch, darin glimmende Punkte
			if _scan("shrub_01", 0.65, randf() * TAU):
				_visual.set_meta("still", true)
			for i in 3:
				B3.sphere(_visual, 0.035, Vector3(randf_range(-0.2, 0.2), randf_range(0.3, 0.7), randf_range(-0.2, 0.2)), B3.mat(c, 0.3, 0.0, c, 4.0))
		"ore":
			# Erzbrocken: Fotoscan-Fels mit metallisch glänzenden Adern
			if not _scan("rock_07", 0.5, randf() * TAU):
				for i in 3:
					var r := B3.box(_visual, Vector3(0.28, 0.22, 0.24) * randf_range(0.7, 1.2), Vector3(randf_range(-0.15, 0.15), 0.1, randf_range(-0.15, 0.15)), B3.mat(Color(0.32, 0.3, 0.3), 0.9), false)
					r.rotation = Vector3(randf(), randf() * TAU, randf())
			var vein := B3.mat(Color(0.42, 0.38, 0.34), 0.28, 0.95, c * 0.3, 0.6)
			for i in 4:
				var vb := B3.box(_visual, Vector3(0.05, 0.09, 0.03) * randf_range(0.8, 1.4), Vector3(randf_range(-0.14, 0.14), randf_range(0.12, 0.36), randf_range(-0.14, 0.14)), vein, false)
				vb.rotation = Vector3(randf(), randf() * TAU, randf())
			B3.box(_visual, Vector3(0.08, 0.16, 0.08), Vector3(0.05, 0.28, 0.0), B3.mat(c, 0.2, 0.8, c, 1.5), false)
		"memento":
			# Erinnerungsstück der 41: kleiner Sockel, darüber ein schwebendes, goldglühendes Fragment
			B3.cyl(_visual, 0.22, 0.26, 0.12, Vector3(0, 0.06, 0), B3.mat(Color(0.3, 0.28, 0.3), 0.85), false, 10)
			var frag := B3.box(_visual, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.55, 0), B3.mat(Color(1.0, 0.85, 0.45), 0.25, 0.8, Color(1.0, 0.75, 0.3), 2.2), false)
			frag.rotation_degrees = Vector3(35, 20, 45)
			frag.set_meta("spin", 0.9)
		"key":
			# Schlüssel eines Verlieses: Steinsockel, darüber ein schwebender, sich drehender Schlüssel (Schaft, Bart, Ring)
			B3.cyl(_visual, 0.2, 0.24, 0.1, Vector3(0, 0.05, 0), B3.mat(Color(0.3, 0.28, 0.3), 0.85), false, 10)
			var km := B3.mat(c, 0.35, 0.9, c, 0.8)
			var kh := Node3D.new()
			kh.position = Vector3(0, 0.55, 0)
			kh.rotation_degrees = Vector3(0, 0, 25)
			kh.set_meta("spin", 1.2)
			_visual.add_child(kh)
			B3.cyl(kh, 0.03, 0.03, 0.42, Vector3.ZERO, km, false, 8)
			B3.box(kh, Vector3(0.12, 0.05, 0.03), Vector3(0.06, -0.17, 0), km, false)
			B3.box(kh, Vector3(0.08, 0.05, 0.03), Vector3(0.04, -0.08, 0), km, false)
			B3.cyl(kh, 0.1, 0.1, 0.03, Vector3(0, 0.28, 0), km, false, 12).rotation_degrees = Vector3(90, 0, 0)
		"chest":
			# Truhe: Fotoscan (Holz, Eisenbeschläge); ohne Scan die alte Kiste
			if _scan("treasure_chest", 0.62):
				pass
			else:
				B3.box(_visual, Vector3(0.9, 0.5, 0.55), Vector3(0, 0.25, 0), B3.mat(Color(0.32, 0.18, 0.08), 0.75), false)
			B3.box(_visual, Vector3(0.94, 0.16, 0.6), Vector3(0, 0.58, 0), B3.mat(Color(0.36, 0.2, 0.09), 0.75), false)
			B3.box(_visual, Vector3(0.96, 0.06, 0.62), Vector3(0, 0.5, 0), B3.mat(Palette.GOLD, 0.3, 0.9), false)
			B3.box(_visual, Vector3(0.12, 0.14, 0.04), Vector3(0, 0.45, 0.29), B3.mat(Palette.GOLD_BRIGHT, 0.3, 0.9), false)
		"lore" when has_meta("style") and get_meta("style") == "tablet":
			# Inschrift in den Hallen Nazaricks: Steintafel aus dunklem Marmor an der Wand, Goldrahmen, leuchtende Zeilen,
			# darunter eine schmale Konsole (die Wand liegt lokal 0,55 m hinter dem Fundpunkt)
			var marble := BuildingLook.photo_material("limestone", "stone", Color(0.22, 0.2, 0.26), 0.05)
			var gold := B3.mat(Color(0.86, 0.67, 0.27), 0.28, 0.92)
			B3.box(_visual, Vector3(0.95, 1.3, 0.1), Vector3(0, 1.48, -0.47), marble, false)
			for sy in [-1.0, 1.0]:
				B3.box(_visual, Vector3(1.03, 0.05, 0.04), Vector3(0, 1.48 + sy * 0.67, -0.41), gold, false)
				B3.box(_visual, Vector3(0.05, 1.38, 0.04), Vector3(sy * 0.5, 1.48, -0.41), gold, false)
			B3.box(_visual, Vector3(0.7, 0.08, 0.26), Vector3(0, 0.8, -0.4), marble, false)
			for k in 5:
				B3.box(_visual, Vector3(0.6 - (k % 2) * 0.14, 0.03, 0.01), Vector3(0, 1.85 - k * 0.17, -0.415), B3.mat(c, 0.3, 0.0, c, 1.3), false)
		"lore" when has_meta("style") and get_meta("style") in ["glyphs", "lectern", "paper", "board", "coffins", "bar", "sign"]:
			_lore_object(String(get_meta("style")), c)
		"lore" when has_meta("style") and get_meta("style") == "sapling":
			_lore_sapling()
		"lore" when has_meta("style") and get_meta("style") == "frozen":
			_lore_frozen()
		"lore" when has_meta("style") and get_meta("style") == "globe":
			_lore_globe()
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
			# Lederbeutel mit Kordel, ein paar Münzen daneben
			var leather := BuildingLook.photo_material("bark", "wood", Color(0.62, 0.47, 0.32), 0.1)
			B3.sphere(_visual, 0.2, Vector3(0, 0.2, 0), leather, Vector3(1, 0.85, 1))
			B3.cyl(_visual, 0.05, 0.08, 0.12, Vector3(0, 0.4, 0), leather, false, 8)
			B3.cyl(_visual, 0.06, 0.06, 0.02, Vector3(0, 0.35, 0), B3.mat(Color(0.75, 0.62, 0.4), 0.8), false, 10)
			for i in 4:
				B3.cyl(_visual, 0.05, 0.05, 0.012, Vector3(randf_range(-0.3, 0.3), 0.01 + i * 0.012, randf_range(-0.3, 0.3)), B3.mat(Palette.GOLD_BRIGHT, 0.25, 1.0), false, 10)
		_:
			# Relikte: Knochenstaub als Gebeinhaufen, Dunkle Essenz und Splitter als Kristalle auf einem Stein
			match item:
				"bone_dust":
					var rng := RandomNumberGenerator.new()
					rng.randomize()
					preload("res://scripts/world3d/interiors_more.gd")._bones(_visual, Vector3.ZERO, rng)
					B3.sphere(_visual, 0.22, Vector3(0, 0.0, 0), B3.mat(Color(0.62, 0.6, 0.56), 0.95), Vector3(1.0, 0.18, 1.0))
					_visual.set_meta("still", true)
				"dark_essence":
					_shards(c, true)
					_visual.set_meta("still", true)
				_:
					_shards(c, false)
					_visual.set_meta("still", true)
	_light = OmniLight3D.new()
	_light.light_color = c
	_light.light_energy = {"chest": 0.6, "lore": 1.2, "shrine": 1.6, "cache": 0.0, "lectern": 0.5, "plaque": 0.3, "note": 0.3, "spot": 0.0, "memento": 1.0, "key": 1.1}.get(kind, 0.9)
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
		qm.size = Vector2(0.07, 0.07)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = B3.fx_tex("fx_dot")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
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
	if _visual and kind in ["relic", "bug"] and not _visual.has_meta("still"):
		_visual.rotation.y += delta * 1.2
		_visual.position.y = sin(_t * 2.0) * 0.06
	if _light and kind != "cache":
		_light.light_energy = {"chest": 0.6, "lore": 1.2, "shrine": 1.6, "lectern": 0.5, "plaque": 0.3, "note": 0.3, "spot": 0.0, "memento": 1.0, "key": 1.1}.get(kind, 0.9) * (0.8 + 0.2 * sin(_t * 3.0))
	elif _light:
		# versteckter Schatz glitzert erst aus der Nähe
		var pl := Actor3D.player
		var near := pl != null and is_instance_valid(pl) and pl.global_position.distance_to(global_position) < 7.0
		_light.light_energy = move_toward(_light.light_energy, 0.9 if near else 0.0, 0.05)


## Kurztext für den Interaktionshinweis.
func prompt() -> String:
	return {"chest": "Öffnen", "bag": "Beute aufheben", "lore": "Lesen", "lectern": "Lesen", "plaque": "Lesen", "note": "Lesen", "spot": "Lesen", "shrine": "Beten", "cache": "Durchsuchen", "memento": "An sich nehmen", "key": "Nehmen"}.get(kind, "Aufheben")

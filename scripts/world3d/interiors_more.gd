class_name InteriorsMore
## Weitere begehbare Innenräume (Baukasten und erste Räume: interiors.gd). Alle Räume: Tür in der Südwand (+z),
## Rückgabe der Ankerpunkte spawn/yaw/exit/slots wie bei Interiors.
##   smithy      Schmiede in E-Rantel: Esse mit Glut und Rauchfang, Amboss, Löschtrog, Werkbank, Schwertständer,
##               Erzkisten, Kohlehaufen, Funken in der Luft.
##   temple      Tempel der Vier Götter in E-Rantel: Säulenschiff, Bänke, Altar mit Sonnenscheibe, vier Statuen,
##               bunte Fenster, Priester und Betende.
##   basilica    Kathedrale der Sechs Götter (Slane-Theokratie): wie der Tempel, nur größer, goldener, mit Bannern.
##   academy     Magierakademie von Arwintar (Fluders Studierzimmer): Bücherwände, Beschwörungskreis, Kristall,
##               Sternkarte, Fernrohr, Trankregal, Magier.
##   forge_hall  Schmiedehalle von Feo Jera: drei Zwergenessen, Runenpfeiler, Erzkarren, Statue des Runenkönigs.
##   inn         Dorfschenke in Carne: kleine Schankstube mit Herd, Tresen, Spinnrad und Dorfbewohnern.
##   court       Thronsaal eines Menschenreiches (loc.faction = kingdom | empire): Säulenschiff mit Bannern, Teppich,
##               Podest mit Thron, Statuen, Kriegstisch, Wachen und Hofstaat – Ro-Lente-Schloss und Kaiserpalast.
##   cellar      Keller der Acht Finger (Re-Estize): Kerker mit Käfigen, Zähltisch, Schmuggelware.
##   sewer       Kanalisation von E-Rantel: langes Steingewölbe mit Wasserrinne, Bögen, Gittern, Schleim, Gebeinen
##               und dem Kultaltar der Zurrernon am Nordende (Verlies, nur mit Schlüssel).
##   crypt       Gruft der Gefallenen unter der Katze-Ebene: Säulenhalle mit Sarkophagen, kalten Feuerschalen,
##               Bannern beider Reiche und dem Podest des Generals (Bosskampf, nur mit Siegel).

const WARM := Color(1.0, 0.78, 0.5)


static func build(kind: String, root: Node3D, loc: Dictionary) -> Dictionary:
	match kind:
		"smithy":
			return smithy(root, loc)
		"temple":
			return temple(root, loc, false)
		"basilica":
			return temple(root, loc, true)
		"academy":
			return academy(root, loc)
		"forge_hall":
			return forge_hall(root, loc)
		"inn":
			return inn(root, loc)
		"court":
			return court(root, loc)
		"cellar":
			return cellar(root, loc)
		"sewer":
			return sewer(root, loc)
		"crypt":
			return crypt(root, loc)
	return {}


# =====================================================================
#  Bausteine: Esse, Amboss, Schwertständer, Kamin, Kegel
# =====================================================================

## Esse: Steinblock mit Glutbett, Rauchfang bis zur Decke, Blasebalg, Zangen am Sims. Rückseite = lokal -z.
static func _forge(root: Node3D, pos: Vector3, yaw_deg: float, m: Dictionary, H: float, strength: float = 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	root.add_child(n)
	B3.box(n, Vector3(2.4, 1.1, 1.5), Vector3(0, 0.55, 0), m.stone)
	B3.box(n, Vector3(2.0, H - 2.0, 1.3), Vector3(0, 2.0 + (H - 2.0) * 0.5, -0.1), m.stone, false)
	B3.box(n, Vector3(2.4, 0.16, 1.5), Vector3(0, 2.0, 0), m.timber, false)
	var coal := B3.noise_mat(Color(0.12, 0.08, 0.06), Color(0.3, 0.1, 0.03), 0.3, 0.9, Color(1.0, 0.35, 0.05) * strength, 2.0)
	B3.box(n, Vector3(1.4, 0.14, 0.9), Vector3(0, 1.17, 0.05), coal, false)
	B3.fire(n, Vector3(0, 1.3, 0.05), Color(1.0, 0.55, 0.2), int(18 * strength))
	B3.light(n, Vector3(0, 1.9, 0.7), Color(1.0, 0.5, 0.2), 2.4 * strength, 9.0).set_meta("flicker", true)
	B3.smoke(n, Vector3(0, 2.2, 0), 5)
	# Blasebalg rechts, Zangen und Haken am Sims
	B3.box(n, Vector3(0.5, 0.28, 0.9), Vector3(1.55, 0.95, 0.4), m.timber, false, Vector3(0, 0, -8))
	B3.cyl(n, 0.03, 0.03, 0.9, Vector3(1.75, 1.3, 0.75), m.timber, false, 6).rotation_degrees = Vector3(50, 0, 0)
	var iron := B3.mat(Color(0.25, 0.25, 0.27), 0.5, 0.8)
	for k in 3:
		B3.cyl(n, 0.012, 0.012, 0.6, Vector3(-0.9 + k * 0.25, 1.5, 0.72), iron, false, 5).rotation_degrees = Vector3(0, 0, 15 - k * 10)
	B3.motes(n, Vector3(0, 1.9, 0.3), Vector3(0.8, 0.6, 0.6), Color(1.0, 0.6, 0.2, 0.7), int(18 * strength))


## Amboss auf einem Baumstumpf, Horn nach +x.
static func _anvil(root: Node3D, pos: Vector3, yaw_deg: float, iron: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	root.add_child(n)
	if Interiors.prop_h(n, "tree_stump_01", Vector3.ZERO, 0.55, 0.0, true) == Vector3.ZERO:
		B3.cyl(n, 0.3, 0.34, 0.55, Vector3(0, 0.275, 0), B3.mat(Color(0.3, 0.22, 0.14), 0.9), true, 10)
	B3.box(n, Vector3(0.9, 0.22, 0.3), Vector3(0, 0.68, 0), iron)
	B3.box(n, Vector3(0.5, 0.14, 0.34), Vector3(0, 0.5, 0), iron, false)
	B3.mesh(n, _cone_mesh(0.12, 0.45), Vector3(0.62, 0.7, 0), iron, Vector3(0, 0, -90))
	# Hammer liegt bereit
	B3.cyl(n, 0.02, 0.02, 0.4, Vector3(-0.2, 0.81, 0.05), B3.mat(Color(0.35, 0.25, 0.15), 0.8), false, 6).rotation_degrees = Vector3(0, 20, 90)
	B3.box(n, Vector3(0.12, 0.07, 0.07), Vector3(-0.42, 0.83, 0.12), iron, false)


static func _cone_mesh(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	return cm


## Schwertständer: Gestell mit `count` Klingen (Spitze unten), Rückseite = lokal -z.
static func _sword_rack(root: Node3D, pos: Vector3, yaw_deg: float, m: Dictionary, iron: Material, count: int = 4) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	root.add_child(n)
	B3.box(n, Vector3(1.6, 0.06, 0.4), Vector3(0, 0.03, 0), m.timber)
	B3.box(n, Vector3(1.6, 0.06, 0.1), Vector3(0, 1.2, -0.15), m.timber, false)
	for sx in [-0.78, 0.78]:
		B3.box(n, Vector3(0.06, 1.25, 0.06), Vector3(sx, 0.625, -0.15), m.timber, false)
	var grip := B3.mat(Color(0.3, 0.2, 0.12), 0.8)
	for k in count:
		var x := -0.55 + k * (1.1 / maxf(1.0, count - 1))
		var s := Node3D.new()
		s.position = Vector3(x, 0.06, -0.05)
		s.rotation_degrees = Vector3(-8, 0, 0)
		n.add_child(s)
		B3.box(s, Vector3(0.05, 0.85, 0.012), Vector3(0, 0.425, 0), iron, false)
		B3.box(s, Vector3(0.22, 0.03, 0.04), Vector3(0, 0.87, 0), iron, false)
		B3.box(s, Vector3(0.04, 0.3, 0.04), Vector3(0, 1.03, 0), grip, false)
		B3.sphere(s, 0.03, Vector3(0, 1.2, 0), iron)


## Kamin an der Ost- (dir = 1) oder Westwand (dir = -1); fx = Wand-x, fz = Position entlang der Wand.
static func _hearth(root: Node3D, fx: float, fz: float, H: float, dir: float, m: Dictionary, strength: float = 1.0) -> void:
	B3.box(root, Vector3(0.7, 2.0, 2.2), Vector3(fx - dir * 0.35, 1.0, fz), m.stone)
	B3.box(root, Vector3(0.8, H - 2.0, 1.5), Vector3(fx - dir * 0.4, 2.0 + (H - 2.0) * 0.5, fz), m.stone, false)
	B3.box(root, Vector3(0.9, 0.12, 2.5), Vector3(fx - dir * 0.45, 2.0, fz), m.timber, false)
	B3.box(root, Vector3(0.6, 1.1, 1.3), Vector3(fx - dir * 0.6, 0.6, fz), B3.mat(Color(0.06, 0.05, 0.05), 0.95), false)
	var logm := B3.mat(Color(0.2, 0.12, 0.06), 0.9)
	for k in 3:
		var lg := B3.cyl(root, 0.08, 0.08, 0.8, Vector3(fx - dir * 0.55, 0.12 + k * 0.1, fz + (k - 1) * 0.2), logm, false, 8)
		lg.rotation_degrees = Vector3(0, 0, 90)
	B3.fire(root, Vector3(fx - dir * 0.5, 0.3, fz), Color(1.0, 0.55, 0.2), int(36 * strength))
	B3.light(root, Vector3(fx - dir * 1.1, 1.1, fz), Color(1.0, 0.55, 0.25), 2.2 * strength, 9.0).set_meta("flicker", true)


# =====================================================================
#  Schmiede (E-Rantel)
# =====================================================================

static func smithy(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	var W := 10.0
	var D := 9.0
	var H := 4.2
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.6, 0.54, 0.47), Color(0.5, 0.42, 0.32))
	var iron := B3.mat(Color(0.25, 0.25, 0.27), 0.5, 0.8)
	# rußiger Steinboden um die Esse
	B3.box(root, Vector3(5.0, 0.03, 5.0), Vector3(-hx + 2.5, 0.015, -1.0), BuildingLook.photo_material("rubble", "stone", Color(0.35, 0.33, 0.3), 0.6), false)
	for x in [-3.2, 3.2]:
		Interiors.window(root, Vector3(x, 2.3, hz + 0.02), Vector3(0, 0, -1), 1.0, 1.1, 2.4)
	Interiors.window(root, Vector3(hx + 0.02, 2.3, 1.0), Vector3(-1, 0, 0), 1.0, 1.1, 2.0)

	# --- Esse an der Westwand, Amboss davor, Löschtrog, Kohle ------------------------------------------
	_forge(root, Vector3(-hx + 0.8, 0, -1.0), 90.0, m, H)
	_anvil(root, Vector3(-hx + 2.9, 0, -1.0), 0.0, iron)
	B3.box(root, Vector3(1.2, 0.55, 0.6), Vector3(-hx + 2.2, 0.275, 1.6), m.planks_dark)
	B3.box(root, Vector3(1.1, 0.02, 0.5), Vector3(-hx + 2.2, 0.5, 1.6), B3.mat(Color(0.08, 0.12, 0.14), 0.1, 0.2), false)
	B3.sphere(root, 0.7, Vector3(-hx + 1.0, 0.25, 2.8), B3.noise_mat(Color(0.05, 0.05, 0.05), Color(0.15, 0.13, 0.12), 0.2, 0.95), Vector3(1.0, 0.45, 1.0), true)
	Interiors.prop(root, "rusted_spade_01", Vector3(-hx + 1.9, 0, 3.1), 40.0)
	Interiors.prop(root, "wooden_bucket_01", Vector3(-hx + 2.9, 0, 1.4), 0.0)

	# --- Werkbank an der Nordwand: Barren, Beil, Krug, Hammer -------------------------------------------
	var bench := Interiors.prop_h(root, "WoodenTable_02", Vector3(2.4, 0, -hz + 1.0), 0.85, 0.0, true)
	var by := bench.y if bench != Vector3.ZERO else 0.85
	Interiors.prop(root, "hatchet", Vector3(1.7, by, -hz + 1.0), 30.0)
	Interiors.prop(root, "metal_jug", Vector3(3.1, by, -hz + 0.8), 0.0)
	for k in 5:
		B3.box(root, Vector3(0.28, 0.07, 0.1), Vector3(2.0 + (k % 3) * 0.32, by + 0.035 + floori(k / 3.0) * 0.07, -hz + 1.35 - floori(k / 3.0) * 0.05), iron, false)
	B3.cyl(root, 0.02, 0.02, 0.4, Vector3(2.7, by + 0.04, -hz + 0.6), B3.mat(Color(0.35, 0.25, 0.15), 0.8), false, 6).rotation_degrees = Vector3(0, 70, 90)
	B3.box(root, Vector3(0.12, 0.07, 0.07), Vector3(2.5, by + 0.05, -hz + 0.55), iron, false)
	# Regal über der Werkbank mit Werkzeug und Hufeisen
	B3.box(root, Vector3(3.0, 0.05, 0.3), Vector3(2.4, 1.8, -hz + 0.2), m.planks_dark, false)
	for k in 4:
		var hs := TorusMesh.new()
		hs.inner_radius = 0.07
		hs.outer_radius = 0.1
		B3.mesh(root, hs, Vector3(1.2 + k * 0.5, 2.15, -hz + 0.07), iron, Vector3(90, 0, 0))

	# --- Waffen an der Ostwand ------------------------------------------------------------------------
	_sword_rack(root, Vector3(hx - 0.35, 0, -1.6), -90.0, m, iron, 4)
	Interiors.prop_h(root, "kite_shield", Vector3(hx - 0.08, 2.4, 0.6), 1.0, -90.0)
	for k in 3:
		B3.cyl(root, 0.015, 0.015, 1.9, Vector3(hx - 0.25 - k * 0.12, 0.95, 2.4 + k * 0.1), iron, false, 5).rotation_degrees = Vector3(0, 0, 6)
	Interiors.prop_h(root, "wooden_crate_01", Vector3(hx - 0.9, 0, 3.2), 0.5, 10.0, true)
	Interiors.prop_h(root, "wooden_crate_02", Vector3(hx - 2.0, 0, 3.5), 0.45, 80.0, true)
	Interiors.prop_h(root, "barrel_03", Vector3(-3.8, 0, 3.6), 0.9, 0.0, true)
	# Erzbrocken in der Kiste
	for k in 5:
		B3.sphere(root, rng.randf_range(0.07, 0.12), Vector3(hx - 0.9 + rng.randf_range(-0.2, 0.2), 0.55, 3.2 + rng.randf_range(-0.2, 0.2)), B3.mat(Color(0.35, 0.3, 0.28), 0.9, 0.3))
	# Kette mit Haken vom Deckenbalken
	B3.cyl(root, 0.02, 0.02, 1.4, Vector3(0.6, H - 0.8, 0.2), iron, false, 6)
	var hook := TorusMesh.new()
	hook.inner_radius = 0.05
	hook.outer_radius = 0.08
	B3.mesh(root, hook, Vector3(0.6, H - 1.55, 0.2), iron, Vector3(0, 90, 0))

	# --- Licht, Funken, Geselle -----------------------------------------------------------------------
	Interiors.lantern(root, Vector3(0.6, 3.4, 1.4), H - 0.3)
	Interiors.lantern(root, Vector3(2.6, 3.4, -2.4), H - 0.3)
	B3.motes(root, Vector3(-1.5, 2.0, 0.2), Vector3(3.0, 1.5, 3.0), Color(1.0, 0.7, 0.4, 0.45), 40)
	Townsfolk.spawn(root, [], [Vector3(2.2, 0, -hz + 2.3)], 1202, 1, "smith")
	return {"spawn": Vector3(0, 0.2, 3.2), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(-1.4, 0, 0.1), Vector3(1.4, 0, 1.6)]}


# =====================================================================
#  Tempel (E-Rantel, vier Götter) und Kathedrale (Theokratie, sechs Götter)
# =====================================================================

static func temple(root: Node3D, _loc: Dictionary, big: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1302 if big else 1301
	var W := 18.0 if big else 12.0
	var D := 30.0 if big else 20.0
	var H := 10.0 if big else 7.0
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.86, 0.84, 0.78) if big else Color(0.8, 0.77, 0.7), Color(0.6, 0.55, 0.48), 2.2)
	var lime := BuildingLook.photo_material("limestone", "stone", Color(0.88, 0.85, 0.78), 0.5)
	var gold := B3.mat(Color(0.95, 0.78, 0.35), 0.3, 0.9)
	var cloth := B3.mat(Color(0.95, 0.92, 0.85) if big else Color(0.9, 0.88, 0.8), 0.95)
	var carpet := B3.mat(Color(0.5, 0.1, 0.12) if not big else Color(0.55, 0.45, 0.15), 0.95)
	# Steinboden über den Dielen, Läufer im Mittelgang
	B3.box(root, Vector3(W, 0.04, D), Vector3(0, 0.02, 0), lime, false)
	B3.box(root, Vector3(2.0, 0.015, D - 2.0), Vector3(0, 0.045, 0.5), carpet, false)
	# Säulenreihen und bunte Fenster dazwischen
	var px := 5.5 if big else 3.6
	var nz := 7 if big else 4
	var glass := [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9), Color(0.95, 0.8, 0.3), Color(0.3, 0.8, 0.4)]
	var gap := (D - 8.0) / (nz - 1)
	for i in nz:
		var z := -hz + 4.0 + i * gap
		for sx in [-1.0, 1.0]:
			B3.pillar(root, Vector3(sx * px, 0, z), H - 0.3, 0.42 if big else 0.32, lime, gold)
			if big:
				B3.banner(root, Vector3(sx * (px - 0.55), H * 0.62, z), Color(0.9, 0.86, 0.75), null, 3.2, 0.0)
			if i < nz - 1:
				var wz := z + gap * 0.5
				var wy := H * 0.48
				var col: Color = glass[(i + (0 if sx < 0 else 2)) % 4]
				B3.box(root, Vector3(0.06, 2.6 if big else 2.2, 1.3), Vector3(sx * (hx - 0.03), wy, wz), m.timber, false)
				B3.box(root, Vector3(0.04, 2.4 if big else 2.0, 1.1), Vector3(sx * (hx - 0.06), wy, wz), B3.mat(col, 0.4, 0.0, col, 1.6), false)
				B3.light(root, Vector3(sx * (hx - 1.2), wy - 0.6, wz), col.lerp(Color.WHITE, 0.3), 1.8 if big else 0.9, 10.0 if big else 6.0)
	# Bänke
	var rows := 10 if big else 6
	var bench_x: Array = [-4.2, -2.1, 2.1, 4.2] if big else [-2.0, 2.0]
	for i in rows:
		var z := -hz + 7.5 + i * 1.5
		for x in bench_x:
			Interiors.prop_h(root, "painted_wooden_bench", Vector3(x, 0, z), 0.5, 0.0, true)
	# Altar auf einem Podest mit Sonnenscheibe an der Nordwand
	var az := -hz + 2.4
	B3.box(root, Vector3(W - 2.0, 0.18, 4.2), Vector3(0, 0.09, az + 1.1), lime)
	Interiors._slope(root, Vector3(0, 0.05, az + 3.9), Vector3(0, 0.2, az + 3.2), W - 2.0)
	B3.box(root, Vector3(3.0 if big else 2.4, 1.0, 1.0), Vector3(0, 0.68, az), lime)
	B3.box(root, Vector3(3.2 if big else 2.6, 0.04, 1.2), Vector3(0, 1.2, az), cloth, false)
	Interiors.prop(root, "brass_candleholders", Vector3(-0.8, 1.22, az), 0.0)
	Interiors.prop(root, "brass_candleholders", Vector3(0.8, 1.22, az), 0.0)
	Interiors.prop(root, "book_encyclopedia_set_01", Vector3(0.0, 1.22, az - 0.15), 90.0)
	Interiors.prop(root, "brass_goblets", Vector3(0.35, 1.22, az + 0.25), 0.0)
	B3.light(root, Vector3(0, 1.9, az + 0.5), WARM, 1.3, 6.0).set_meta("flicker", true)
	var disc := B3.cyl(root, 1.3 if big else 0.85, 1.3 if big else 0.85, 0.06, Vector3(0, H * 0.62, -hz + 0.1), B3.mat(Color(1.0, 0.85, 0.4), 0.3, 0.9, Color(1.0, 0.8, 0.3), 2.0), false, 28)
	disc.rotation_degrees = Vector3(90, 0, 0)
	for k in (12 if big else 8):
		var a := TAU * k / (12.0 if big else 8.0)
		var ray := B3.box(root, Vector3(0.12, 0.9 if big else 0.6, 0.05), Vector3(cos(a) * (1.8 if big else 1.2), H * 0.62 + sin(a) * (1.8 if big else 1.2), -hz + 0.1), gold, false)
		ray.rotation_degrees.z = rad_to_deg(a) - 90.0
	B3.light(root, Vector3(0, H * 0.62, -hz + 1.2), Color(1.0, 0.85, 0.5), 3.0 if big else 1.6, 14.0 if big else 9.0)
	if big:
		# die große Halle braucht mehr Licht: warmes Füll-Licht unter der Decke
		B3.light(root, Vector3(0, H - 3.5, -hz * 0.35), WARM, 3.0, 22.0)
		B3.light(root, Vector3(0, H - 3.5, hz * 0.4), WARM, 2.6, 20.0)
	for sx in [-1.0, 1.0]:
		B3.brazier(root, Vector3(sx * (3.2 if big else 2.2), 0.18, az + 1.8), Color(1.0, 0.8, 0.4))
	# Statuen der Götter in Nischen mit Kerzen
	var ns := 6 if big else 4
	for i in ns:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var z := -hz + 5.5 + floori(i / 2.0) * (7.0 if big else 5.5)
		var pos := Vector3(sx * (hx - 1.0), 0, z)
		B3.box(root, Vector3(1.2, 0.6, 1.2), pos + Vector3(0, 0.3, 0), lime)
		Interiors.prop_h(root, "gothic_statue", pos + Vector3(0, 0.6, 0), 2.3 if big else 1.9, -sx * 90.0)
		Interiors.candle(root, pos + Vector3(-sx * 0.95, 0.0, 0.55), "wooden_candlestick")
		Interiors.candle(root, pos + Vector3(-sx * 0.95, 0.0, -0.55), "brass_candleholders")
		B3.light(root, pos + Vector3(-sx * 0.9, 1.3, 0), WARM, 0.8, 4.5).set_meta("flicker", true)
	# Weihwasserbecken und Opferstock beim Eingang
	B3.cyl(root, 0.42, 0.3, 0.9, Vector3(-hx + 1.4, 0.45, hz - 2.0), lime, true, 14)
	B3.cyl(root, 0.4, 0.4, 0.04, Vector3(-hx + 1.4, 0.9, hz - 2.0), B3.mat(Color(0.1, 0.16, 0.2), 0.1, 0.2), false, 14)
	B3.box(root, Vector3(0.5, 1.0, 0.5), Vector3(hx - 1.4, 0.5, hz - 2.0), m.timber)
	B3.box(root, Vector3(0.3, 0.02, 0.02), Vector3(hx - 1.4, 1.01, hz - 2.0), B3.mat(Color(0.05, 0.05, 0.05)), false)
	# Kronleuchter, Lichtstaub, Priester und Betende
	for z in ([-7.0, -1.0, 5.0, 10.0] if big else [-4.0, 2.0, 7.0]):
		for sx in [-1.0, 1.0]:
			Interiors.lantern(root, Vector3(sx * 2.4, H - 1.6, z), H - 0.3, 1.8 if big else 1.1)
	B3.motes(root, Vector3(0, H * 0.45, -hz * 0.3), Vector3(hx * 0.7, H * 0.3, hz * 0.5), Color(1.0, 0.95, 0.8, 0.45), 90)
	Townsfolk.spawn(root, [], [Vector3(-1.6, 0, az + 2.6), Vector3(2.8, 0, az + 3.6)], 1311 if big else 1303, 2 if not big else 2, "priest")
	Townsfolk.spawn(root, [], [Vector3(-2.0, 0, -hz + 6.8), Vector3(2.0, 0, -hz + 9.8), Vector3(-2.0, 0, -hz + 12.8)], 1304, 3)
	if big:
		Townsfolk.spawn(root, [], [Vector3(4.2, 0, -hz + 15.8), Vector3(-4.2, 0, -hz + 18.8), Vector3(0.0, 0, az + 5.0)], 1312, 3, "priest")
	return {"spawn": Vector3(0, 0.2, hz - 1.6), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(1.0, 0, az + 2.6), Vector3(-3.0, 0, az + 4.0)]}


# =====================================================================
#  Magierakademie (Arwintar): Fluders Studierzimmer
# =====================================================================

static func academy(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1401
	var W := 12.0
	var D := 12.0
	var H := 6.0
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.5, 0.5, 0.58), Color(0.42, 0.36, 0.32))
	var violet := Color(0.65, 0.45, 1.0)
	var brass := B3.mat(Color(0.85, 0.66, 0.28), 0.3, 0.9)
	var dark := BuildingLook.photo_material("limestone", "stone", Color(0.42, 0.4, 0.46), 0.5)
	B3.box(root, Vector3(W, 0.04, D), Vector3(0, 0.02, 0), dark, false)
	for sx in [-1.0, 1.0]:
		Interiors.window(root, Vector3(sx * (hx + 0.02), 3.2, -2.5), Vector3(-sx, 0, 0), 1.0, 2.2, 1.6)
	Interiors.window(root, Vector3(3.6, 3.2, hz + 0.02), Vector3(0, 0, -1), 1.0, 2.2, 1.6)

	# --- Beschwörungskreis in der Mitte, Kristall auf dem Sockel an der Nordwand ------------------------
	GroundMark.rune(root, Vector3(0, 0.05, -0.5), 2.6, violet, 1.0e9, "a")
	B3.light(root, Vector3(0, 0.6, -0.5), violet, 1.2, 7.0)
	B3.motes(root, Vector3(0, 1.6, -0.5), Vector3(2.4, 1.4, 2.4), Color(0.75, 0.6, 1.0, 0.7), 60)
	B3.box(root, Vector3(1.2, 0.9, 1.2), Vector3(0, 0.45, -hz + 1.0), dark)
	B3.crystal(root, Vector3(0, 0.9, -hz + 1.0), violet, 1.5)
	B3.light(root, Vector3(0, 2.4, -hz + 1.6), violet, 2.0, 10.0).set_meta("flicker", true)

	# --- Bücherwände (West und Nord), Leiter ----------------------------------------------------------
	for z in [-3.6, -1.2, 1.2, 3.6]:
		var sh := Interiors.prop_h(root, "GothicCabinet_01", Vector3(-hx + 0.5, 0, z), 2.8, 90.0, true)
		if sh != Vector3.ZERO:
			Interiors.prop(root, "book_encyclopedia_set_01", Vector3(-hx + 0.5, 2.8, z), 90.0)
	for x in [-3.6, 3.6]:
		var sh := Interiors.prop_h(root, "GothicCabinet_01", Vector3(x, 0, -hz + 0.5), 2.8, 0.0, true)
		if sh != Vector3.ZERO:
			Interiors.prop(root, "book_encyclopedia_set_01", Vector3(x, 2.8, -hz + 0.5), 0.0)
	Interiors.prop_h(root, "wooden_ladder", Vector3(-hx + 0.95, 0, 5.0), 3.4, 90.0)
	# Bücherstapel auf dem Boden
	for k in 4:
		Interiors.prop(root, "book_encyclopedia_set_01", Vector3(-hx + 1.5 + k * 0.1, 0.0, 4.6 - k * 0.05), rng.randf_range(0, 360), 0.9)

	# --- Schreibtische: Fluders Arbeitsplatz und ein Studientisch ----------------------------------------
	var d1 := Interiors.prop_h(root, "WoodenTable_03", Vector3(3.2, 0, 2.2), 0.8, 0.0, true)
	var d1y := d1.y if d1 != Vector3.ZERO else 0.8
	Interiors.chair_at(root, Vector3(3.2, 0, 2.2), 180.0, 0.9)
	Interiors.prop(root, "book_encyclopedia_set_01", Vector3(2.6, d1y, 2.1), 10.0)
	Interiors.prop(root, "ceramic_vase_01", Vector3(3.9, d1y, 2.5), 0.0)
	Interiors.candle(root, Vector3(3.6, d1y, 1.8), "brass_candleholders")
	Interiors.prop(root, "chess_set", Vector3(3.2, d1y, 2.3), 35.0, 0.8)
	var d2 := Interiors.prop_h(root, "WoodenTable_02", Vector3(-2.6, 0, 3.0), 0.82, 90.0, true)
	var d2y := d2.y if d2 != Vector3.ZERO else 0.82
	Interiors.chair_at(root, Vector3(-2.6, 0, 3.0), 0.0, 0.9)
	Interiors.chair_at(root, Vector3(-2.6, 0, 3.0), 180.0, 0.9)
	Interiors.prop(root, "jug_01", Vector3(-2.3, d2y, 2.6), 0.0)
	Interiors.prop(root, "wine_bottles_01", Vector3(-3.0, d2y, 3.4), 90.0)
	Interiors.candle(root, Vector3(-2.6, d2y, 3.0))
	# Schriftrollen (Röhren) und Tintenfass
	for k in 3:
		B3.cyl(root, 0.03, 0.03, 0.35, Vector3(3.9 - k * 0.08, d1y + 0.03, 2.9 + k * 0.05), B3.mat(Color(0.9, 0.85, 0.7), 0.9), false, 6).rotation_degrees = Vector3(0, 30 + k * 15, 90)

	# --- Sternkarte an der Ostwand, Fernrohr, Trankregal -----------------------------------------------
	B3.box(root, Vector3(0.05, 2.2, 3.2), Vector3(hx - 0.04, 3.2, -1.5), B3.mat(Color(0.08, 0.1, 0.22), 0.8), false)
	for k in 16:
		var sp := Vector3(hx - 0.08, 3.2 + rng.randf_range(-0.95, 0.95), -1.5 + rng.randf_range(-1.45, 1.45))
		B3.sphere(root, rng.randf_range(0.015, 0.035), sp, B3.mat(Color(1, 1, 0.9), 0.3, 0.0, Color(1.0, 0.95, 0.8), 3.0))
	B3.cyl(root, 0.06, 0.09, 1.5, Vector3(hx - 1.6, 1.55, 3.2), brass, false, 10).rotation_degrees = Vector3(-50, 0, 0)
	for k in 3:
		B3.cyl(root, 0.02, 0.02, 1.3, Vector3(hx - 1.6 + cos(TAU * k / 3.0) * 0.4, 0.6, 3.2 + sin(TAU * k / 3.0) * 0.4), m.timber, false, 5).rotation_degrees = Vector3(sin(TAU * k / 3.0) * 18.0, 0, -cos(TAU * k / 3.0) * 18.0)
	for k in 3:
		var y := 1.2 + k * 0.55
		B3.box(root, Vector3(0.3, 0.04, 2.0), Vector3(hx - 0.2, y, 0.6), m.planks_dark, false)
		for j in 5:
			var pc := Color.from_hsv(rng.randf(), 0.7, 1.0)
			var vial := B3.cyl(root, 0.05, 0.06, 0.2, Vector3(hx - 0.2, y + 0.12, -0.2 + j * 0.4), B3.mat(pc, 0.2, 0.0, pc, 1.4), false, 8)
			vial.rotation_degrees.y = rng.randf_range(0, 360)
	B3.light(root, Vector3(hx - 0.8, 2.0, 0.6), Color(0.7, 0.9, 1.0), 0.6, 4.0)

	# --- Licht, Magier ----------------------------------------------------------------------------------
	Interiors.lantern(root, Vector3(3.2, 4.4, 2.2), H - 0.3)
	Interiors.lantern(root, Vector3(-2.6, 4.4, 3.0), H - 0.3)
	Interiors.lantern(root, Vector3(0, 4.6, -3.6), H - 0.3, 0.9)
	Townsfolk.spawn(root, [], [Vector3(3.0, 0, 3.4), Vector3(-3.6, 0, -3.2), Vector3(2.6, 0, -3.8)], 1402, 3, "mage")
	return {"spawn": Vector3(0, 0.2, hz - 1.4), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(-1.4, 0, -3.4), Vector3(1.6, 0, 0.6)]}


# =====================================================================
#  Schmiedehalle von Feo Jera (Zwerge)
# =====================================================================

static func forge_hall(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1501
	var W := 20.0
	var D := 14.0
	var H := 6.0
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.52, 0.5, 0.47), Color(0.4, 0.36, 0.32), 2.4)
	var iron := B3.mat(Color(0.25, 0.25, 0.27), 0.5, 0.8)
	var cyan := Color(0.4, 0.9, 1.0)
	var rock := BuildingLook.photo_material("rubble", "stone", Color(0.5, 0.48, 0.45), 0.7)
	var gold := B3.mat(Color(0.95, 0.78, 0.35), 0.3, 0.9)
	B3.box(root, Vector3(W, 0.04, D), Vector3(0, 0.02, 0), rock, false)
	# --- drei Essen an der Nordwand, Ambosse, Löschtröge -------------------------------------------------
	for x in [-6.0, 0.0, 6.0]:
		_forge(root, Vector3(x, 0, -hz + 0.8), 0.0, m, H, 1.2)
		_anvil(root, Vector3(x + 0.3, 0, -hz + 3.4), 0.0, iron)
	for x in [-3.0, 3.0]:
		B3.box(root, Vector3(1.4, 0.55, 0.7), Vector3(x, 0.275, -hz + 1.0), m.planks_dark)
		B3.box(root, Vector3(1.3, 0.02, 0.6), Vector3(x, 0.5, -hz + 1.0), B3.mat(Color(0.08, 0.12, 0.14), 0.1, 0.2), false)
	# --- Runenpfeiler mit Leuchtsteinen -----------------------------------------------------------------
	for x in [-7.0, -2.3, 2.3, 7.0]:
		B3.pillar(root, Vector3(x, 0, 1.5), H - 0.3, 0.45, rock, gold)
		for k in 3:
			var rp := Vector3(x, 1.2 + k * 1.3, 1.5 + 0.47)
			B3.box(root, Vector3(0.22, 0.3, 0.03), rp, B3.mat(cyan, 0.3, 0.0, cyan, 2.2), false)
			B3.box(root, Vector3(0.22, 0.3, 0.03), Vector3(x, rp.y, 1.5 - 0.47), B3.mat(cyan, 0.3, 0.0, cyan, 2.2), false)
		B3.light(root, Vector3(x, 2.6, 1.5), cyan, 0.9, 5.0)
	for sx in [-1.0, 1.0]:
		B3.crystal(root, Vector3(sx * (hx - 1.2), 0, -hz + 1.0), cyan, 1.3)
		B3.light(root, Vector3(sx * (hx - 1.6), 1.2, -hz + 1.6), cyan, 1.2, 7.0)
	# --- Statue des Runenkönigs am Ostende -------------------------------------------------------------
	B3.box(root, Vector3(1.8, 1.0, 1.8), Vector3(hx - 1.5, 0.5, 2.0), rock)
	Interiors.prop_h(root, "gothic_statue", Vector3(hx - 1.5, 1.0, 2.0), 3.2, -90.0)
	for sz in [-1.0, 1.0]:
		B3.brazier(root, Vector3(hx - 1.5, 0, 2.0 + sz * 1.8), Color(1.0, 0.6, 0.25))
	# --- Erzkarren, Fässer, Körbe, Werkzeug entlang der Südwand ----------------------------------------
	for k in 4:
		var cx := -6.0 + k * 4.0
		Interiors.prop_h(root, "wooden_crate_01" if k % 2 == 0 else "wooden_crate_02", Vector3(cx, 0, hz - 0.9), 0.55, rng.randf_range(-15, 15), true)
		for j in 5:
			B3.sphere(root, rng.randf_range(0.08, 0.14), Vector3(cx + rng.randf_range(-0.25, 0.25), 0.6, hz - 0.9 + rng.randf_range(-0.2, 0.2)), B3.mat(Color(0.4, 0.33, 0.28), 0.85, 0.4))
	Interiors.prop_h(root, "wine_barrel_01", Vector3(-8.6, 0, hz - 1.0), 0.95, 20.0, true)
	Interiors.prop_h(root, "wine_barrel_01", Vector3(8.6, 0, hz - 1.0), 0.95, 70.0, true)
	Interiors.prop(root, "wicker_basket_01", Vector3(-4.0, 0, hz - 1.6), 30.0)
	Interiors.prop(root, "wooden_bucket_02", Vector3(4.2, 0, hz - 1.7), 0.0)
	_sword_rack(root, Vector3(-hx + 0.35, 0, -3.0), 90.0, m, iron, 5)
	Interiors.prop_h(root, "kite_shield", Vector3(-hx + 0.08, 2.3, 0.0), 1.0, 90.0)
	Interiors.prop_h(root, "wooden_ladder", Vector3(-hx + 0.95, 0, 4.6), 3.6, 90.0)
	# Ketten von der Decke, Funken, Staub
	for x in [-4.0, 4.0]:
		B3.cyl(root, 0.025, 0.025, 2.0, Vector3(x, H - 1.1, -1.0), iron, false, 6)
		var hook := TorusMesh.new()
		hook.inner_radius = 0.06
		hook.outer_radius = 0.1
		B3.mesh(root, hook, Vector3(x, H - 2.15, -1.0), iron, Vector3(0, 90, 0))
	B3.motes(root, Vector3(0, 2.5, 0), Vector3(8.0, 2.0, 5.0), Color(1.0, 0.7, 0.4, 0.4), 90)
	for p in [Vector3(-5.0, 4.5, 4.0), Vector3(5.0, 4.5, 4.0), Vector3(0.0, 4.5, 4.0)]:
		Interiors.lantern(root, p, H - 0.3, 1.1)
	# --- Zwerge an den Essen und unterwegs ---------------------------------------------------------------
	Townsfolk.spawn(root, [Vector3(-7.0, 0, 4.0), Vector3(7.0, 0, 4.0), Vector3(0.0, 0, 3.0), Vector3(-4.0, 0, -0.5)],
		[Vector3(-5.7, 0, -hz + 4.8), Vector3(6.3, 0, -hz + 4.8), Vector3(0.3, 0, -hz + 5.0)], 1502, 6, "dwarf")
	return {"spawn": Vector3(0, 0.2, hz - 1.6), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(-3.0, 0, 3.0), Vector3(3.6, 0, 3.4)]}


# =====================================================================
#  Dorfschenke (Carne)
# =====================================================================

static func inn(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1601
	var W := 10.0
	var D := 8.0
	var H := 3.6
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.78, 0.7, 0.58), Color(0.62, 0.5, 0.36))
	for x in [-3.0, 3.0]:
		Interiors.window(root, Vector3(x, 2.1, hz + 0.02), Vector3(0, 0, -1), 1.0, 1.1, 2.4)
	Interiors.window(root, Vector3(-hx - 0.02, 2.1, 1.5), Vector3(1, 0, 0), 0.9, 1.0, 2.0)
	# --- kurzer Tresen an der Westwand, Fässer, Regal ----------------------------------------------------
	var bar_x := -hx + 1.9
	B3.box(root, Vector3(0.7, 1.0, 3.6), Vector3(bar_x, 0.5, -1.4), m.planks_dark)
	B3.box(root, Vector3(0.9, 0.07, 3.8), Vector3(bar_x, 1.035, -1.4), m.planks, false)
	Interiors.prop_h(root, "wine_barrel_01", Vector3(-hx + 0.6, 0, -3.2), 0.9, 15.0, true)
	Interiors.prop_h(root, "barrel_03", Vector3(-hx + 0.6, 0, 0.2), 0.85, 40.0, true)
	for k in 2:
		var y := 1.4 + k * 0.6
		B3.box(root, Vector3(0.3, 0.04, 3.0), Vector3(-hx + 0.2, y, -1.5), m.planks_dark, false)
		for j in 4:
			var p := Vector3(-hx + 0.2, y + 0.02, -2.7 + j * 0.8)
			match (k + j) % 3:
				0: Interiors.prop(root, "jug_01", p, rng.randf_range(0, 360))
				1: Interiors.prop(root, "wooden_bowl_01", p, 0.0)
				_: Interiors.prop(root, "metal_jug", p, rng.randf_range(0, 360))
	Interiors.prop(root, "brass_goblets", Vector3(bar_x, 1.07, -2.6), 20.0)
	Interiors.prop(root, "CheeseBox_01", Vector3(bar_x - 0.1, 1.07, -1.4), 10.0)
	Interiors.prop(root, "wooden_cutting_board", Vector3(bar_x, 1.07, -0.3), 80.0)
	Interiors.prop(root, "yellow_onion", Vector3(bar_x + 0.05, 1.1, -0.25), 0.0)
	Interiors.candle(root, Vector3(bar_x + 0.1, 1.07, -2.0))
	# --- Herd an der Ostwand mit Kochtopf ---------------------------------------------------------------
	_hearth(root, hx, -1.2, H, 1.0, m, 0.9)
	Interiors.prop(root, "brass_pot_01", Vector3(hx - 0.55, 0.42, -1.2), 0.0)
	B3.box(root, Vector3(1.6, 0.02, 2.0), Vector3(hx - 1.7, 0.012, -1.2), B3.mat(Color(0.36, 0.26, 0.2), 0.95), false)
	# --- drei Tische mit Hockern, Gäste ---------------------------------------------------------------
	var tables := [Vector3(-1.4, 0, 1.4), Vector3(2.2, 0, 2.2), Vector3(1.6, 0, -2.4)]
	for i in tables.size():
		var t: Vector3 = tables[i]
		var ts := Interiors.prop_h(root, "round_wooden_table_01", t, 0.76, rng.randf_range(0, 360), true)
		var ty := ts.y if ts != Vector3.ZERO else 0.76
		for k in 3:
			Interiors.chair_at(root, t, 20.0 + k * 120.0 + rng.randf_range(-15, 15), 0.85, "wooden_stool_01" if k % 2 == 0 else "wooden_stool_02")
		Interiors.candle(root, t + Vector3(0.05, ty, 0.0))
		if i == 0:
			Interiors.prop(root, "carved_wooden_plate", t + Vector3(-0.3, ty, 0.1), 0.0)
			Interiors.prop(root, "food_apple_01", t + Vector3(-0.3, ty + 0.02, 0.1), 0.0)
		else:
			Interiors.prop(root, "jug_01", t + Vector3(0.3, ty, -0.2), 40.0)
			Interiors.prop(root, "brass_goblets", t + Vector3(-0.25, ty, 0.2), rng.randf_range(0, 360))
	# --- Dörfliches: Spinnrad, Besen, Gemüsekörbe, Laternen ------------------------------------------
	Interiors.prop_h(root, "spinning_wheel_01", Vector3(-hx + 1.3, 0, 3.0), 1.1, 40.0, true)
	Interiors.prop(root, "wooden_broom", Vector3(hx - 0.4, 0, 3.3), -70.0)
	Interiors.prop(root, "wicker_basket_01", Vector3(hx - 1.2, 0, -hz + 0.7), 20.0)
	Interiors.prop(root, "wicker_basket_02", Vector3(hx - 2.0, 0, -hz + 0.6), 100.0)
	Interiors.prop(root, "sweet_potato", Vector3(hx - 1.2, 0.28, -hz + 0.7), 0.0)
	Interiors.prop(root, "yellow_onion", Vector3(hx - 2.0, 0.26, -hz + 0.6), 0.0)
	for p in [Vector3(-1.4, 2.8, 1.4), Vector3(2.2, 2.8, 2.2), Vector3(1.6, 2.8, -2.4)]:
		Interiors.lantern(root, p, H - 0.3, 1.0)
	B3.motes(root, Vector3(0, 1.8, 0.3), Vector3(4.5, 1.4, 3.5), Color(1.0, 0.9, 0.7, 0.5), 50)
	Townsfolk.spawn(root, [], [Vector3(-2.3, 0, 0.6), Vector3(2.9, 0, 1.3), Vector3(0.8, 0, -3.2), Vector3(-0.6, 0, 2.6)], 1602, 4)
	return {"spawn": Vector3(0, 0.2, hz - 1.2), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(bar_x - 1.0, 0, -1.4), Vector3(2.4, 0, -0.2)]}


# =====================================================================
#  Thronsaal (Ro-Lente-Schloss in Re-Estize, Kaiserpalast in Arwintar)
# =====================================================================

static func court(root: Node3D, loc: Dictionary) -> Dictionary:
	var empire: bool = String(loc.get("faction", "kingdom")) == "empire"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1702 if empire else 1701
	var W := 20.0
	var D := 34.0
	var H := 10.0
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.9, 0.88, 0.84) if empire else Color(0.78, 0.74, 0.68), Color(0.6, 0.55, 0.48), 2.4)
	var stone: Material = B3.mat(Color(0.92, 0.9, 0.86), 0.25) if empire else BuildingLook.photo_material("limestone", "stone", Color(0.84, 0.8, 0.72), 0.5)
	var gold := B3.mat(Color(0.95, 0.78, 0.35), 0.3, 0.9)
	var crest: Texture2D = null if empire else Palette.icon("faction_kingdom")
	var col := Color(0.55, 0.08, 0.08) if empire else Color(0.11, 0.18, 0.42)
	var carpet := B3.mat(Color(0.5, 0.08, 0.1) if not empire else Color(0.55, 0.1, 0.08), 0.95)
	B3.box(root, Vector3(W, 0.04, D), Vector3(0, 0.02, 0), stone, false)
	B3.box(root, Vector3(3.0, 0.015, D - 6.0), Vector3(0, 0.045, 2.0), carpet, false)
	# Säulen mit Bannern, hohe Fenster dazwischen
	var nz := 6
	var gap := (D - 8.0) / (nz - 1)
	for i in nz:
		var z := -hz + 4.0 + i * gap
		for sx in [-1.0, 1.0]:
			B3.pillar(root, Vector3(sx * 6.5, 0, z), H - 0.3, 0.45, stone, gold)
			B3.banner(root, Vector3(sx * 5.9, H * 0.6, z), col, crest, 3.4, 0.0)
			if i < nz - 1:
				var wz := z + gap * 0.5
				var glass_cols := [Color(0.9, 0.3, 0.3), Color(0.3, 0.45, 0.9), Color(0.95, 0.8, 0.3)]
				var wcol: Color = Color(0.9, 0.92, 1.0) if empire else glass_cols[i % 3]
				B3.box(root, Vector3(0.06, 3.4, 1.4), Vector3(sx * (hx - 0.03), H * 0.5, wz), m.timber, false)
				B3.box(root, Vector3(0.04, 3.2, 1.2), Vector3(sx * (hx - 0.06), H * 0.5, wz), B3.mat(wcol, 0.4, 0.0, wcol, 1.5), false)
				B3.light(root, Vector3(sx * (hx - 1.4), H * 0.5 - 1.0, wz), wcol.lerp(Color.WHITE, 0.4), 1.6, 10.0)
	# Podest mit drei Stufen, Thron, Baldachin
	var dz := -hz + 3.2
	for k in 3:
		B3.box(root, Vector3(10.0 - k * 1.2, 0.2, 5.2 - k * 0.9), Vector3(0, 0.1 + k * 0.2, dz + 0.6 + k * 0.45), stone)
	Interiors._slope(root, Vector3(0, 0.05, dz + 3.6), Vector3(0, 0.62, dz + 1.6), 9.0)
	var tz := dz - 0.6
	var velvet := B3.mat(Color(0.45, 0.06, 0.1), 0.9)
	B3.box(root, Vector3(1.4, 2.6, 0.3), Vector3(0, 0.6 + 1.3, tz - 0.55), gold)
	B3.box(root, Vector3(1.2, 2.2, 0.08), Vector3(0, 0.6 + 1.2, tz - 0.36), velvet, false)
	B3.box(root, Vector3(1.4, 0.6, 1.1), Vector3(0, 0.6 + 0.3, tz), gold)
	B3.box(root, Vector3(1.2, 0.12, 1.0), Vector3(0, 0.6 + 0.66, tz), velvet, false)
	for sx in [-1.0, 1.0]:
		B3.box(root, Vector3(0.14, 0.7, 1.1), Vector3(sx * 0.67, 0.6 + 0.95, tz), gold, false)
	B3.box(root, Vector3(4.0, 0.12, 3.0), Vector3(0, H - 2.2, tz), gold, false)
	B3.box(root, Vector3(3.8, 0.4, 2.8), Vector3(0, H - 2.4, tz), B3.mat(col, 0.9), false)
	B3.light(root, Vector3(0, 3.6, tz + 1.2), Color(1.0, 0.85, 0.6), 2.0, 9.0)
	for sx in [-1.0, 1.0]:
		B3.brazier(root, Vector3(sx * 4.4, 0.6, dz + 0.4), Color(1.0, 0.8, 0.4))
		B3.box(root, Vector3(1.2, 0.6, 1.2), Vector3(sx * 8.4, 0.3, dz + 1.0), stone)
		Interiors.prop_h(root, "gothic_statue", Vector3(sx * 8.4, 0.6, dz + 1.0), 2.4, -sx * 90.0)
		B3.light(root, Vector3(sx * 7.6, 1.6, dz + 1.6), WARM, 0.9, 5.0).set_meta("flicker", true)
	# Kriegstisch mit Karte und Figuren, Schreibpult des Kanzlers
	var wt := Interiors.prop_h(root, "WoodenTable_03", Vector3(-8.2, 0, 4.0), 0.82, 90.0, true)
	var wty := wt.y if wt != Vector3.ZERO else 0.82
	B3.box(root, Vector3(1.6, 0.01, 1.1), Vector3(-8.2, wty + 0.005, 4.0), B3.noise_mat(Color(0.86, 0.8, 0.62), Color(0.6, 0.55, 0.4), 0.3, 0.9), false)
	for k in 6:
		B3.cyl(root, 0.04, 0.05, 0.12, Vector3(-8.2 + rng.randf_range(-0.6, 0.6), wty + 0.06, 4.0 + rng.randf_range(-0.4, 0.4)), B3.mat(col if k % 2 == 0 else Color(0.2, 0.2, 0.2), 0.6), false, 8)
	Interiors.candle(root, Vector3(-8.9, wty, 3.5), "brass_candleholders")
	Interiors.chair_at(root, Vector3(-8.2, 0, 4.0), 90.0, 1.0)
	Interiors.chair_at(root, Vector3(-8.2, 0, 4.0), 270.0, 1.0)
	var dk := Interiors.prop_h(root, "WoodenTable_02", Vector3(8.0, 0, -2.0), 0.85, 0.0, true)
	var dky := dk.y if dk != Vector3.ZERO else 0.85
	Interiors.prop(root, "book_encyclopedia_set_01", Vector3(7.6, dky, -2.0), 20.0)
	Interiors.prop(root, "metal_jug", Vector3(8.6, dky, -2.3), 0.0)
	Interiors.candle(root, Vector3(8.4, dky, -1.6))
	# Kronleuchter, Lichtstaub, Wachen und Hofstaat
	for z in [-9.0, -1.0, 7.0, 13.0]:
		for sx in [-1.0, 1.0]:
			Interiors.lantern(root, Vector3(sx * 2.8, H - 1.8, z), H - 0.3, 1.7)
	B3.light(root, Vector3(0, H - 3.5, -2.0), WARM, 2.4, 20.0)
	B3.motes(root, Vector3(0, H * 0.45, 0), Vector3(hx * 0.7, H * 0.3, hz * 0.6), Color(1.0, 0.95, 0.8, 0.4), 80)
	var tab := "#8a1a1a" if empire else "#1d2f6b"
	Townsfolk.spawn(root, [], [Vector3(-3.0, 0, dz + 5.5), Vector3(3.0, 0, dz + 5.5), Vector3(-8.5, 0, 0.0), Vector3(8.5, 0, 9.0),
		Vector3(-2.6, 0, hz - 2.6), Vector3(2.6, 0, hz - 2.6)], 1712 if empire else 1711, 6, "guard", tab)
	Townsfolk.spawn(root, [], [Vector3(-5.0, 0, 2.0), Vector3(-4.0, 0, 4.2), Vector3(5.0, 0, -3.0), Vector3(6.2, 0, -1.2),
		Vector3(-6.0, 0, -9.0), Vector3(5.5, 0, 9.5)], 1714 if empire else 1713, 6, "noble")
	return {"spawn": Vector3(0, 0.2, hz - 1.8), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(0.6, 0.6, dz + 0.2), Vector3(-3.6, 0, dz + 7.0)]}


# =====================================================================
#  Keller der Acht Finger (Re-Estize): Schmuggellager und Verlies – mit Gegnern (encounters des Ortes)
# =====================================================================

## Wandfackel: Halter, Schaft, Flamme, flackerndes Licht. `side` = +1 Ostwand, -1 Westwand.
static func _torch(root: Node3D, pos: Vector3, side: float) -> void:
	var iron := B3.mat(Color(0.2, 0.2, 0.22), 0.5, 0.8)
	B3.box(root, Vector3(0.12, 0.12, 0.12), pos + Vector3(-side * 0.06, 0, 0), iron, false)
	var shaft := B3.cyl(root, 0.025, 0.03, 0.5, pos + Vector3(-side * 0.18, 0.15, 0), B3.mat(Color(0.3, 0.2, 0.12), 0.8), false, 6)
	shaft.rotation_degrees = Vector3(0, 0, side * 25.0)
	B3.fire(root, pos + Vector3(-side * 0.28, 0.42, 0), Color(1.0, 0.6, 0.25), 10)
	B3.light(root, pos + Vector3(-side * 0.6, 0.5, 0), Color(1.0, 0.6, 0.3), 2.6, 10.0).set_meta("flicker", true)


## Käfig aus Gitterstäben (2,4 × 2,2 × 2,4 m), Rückseite offen zur Wand.
static func _cage(root: Node3D, pos: Vector3, iron: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	root.add_child(n)
	for k in 9:
		var x := -1.2 + k * 0.3
		B3.cyl(n, 0.02, 0.02, 2.2, Vector3(x, 1.1, 1.2), iron, false, 5)
	for k in 8:
		var z := -1.2 + k * 0.3 + 0.15
		B3.cyl(n, 0.02, 0.02, 2.2, Vector3(-1.2, 1.1, z), iron, false, 5)
		B3.cyl(n, 0.02, 0.02, 2.2, Vector3(1.2, 1.1, z), iron, false, 5)
	for y in [0.05, 2.2]:
		B3.box(n, Vector3(2.5, 0.05, 0.05), Vector3(0, y, 1.2), iron, false)
		B3.box(n, Vector3(0.05, 0.05, 2.5), Vector3(-1.2, y, 0), iron, false)
		B3.box(n, Vector3(0.05, 0.05, 2.5), Vector3(1.2, y, 0), iron, false)
	B3.wall_invisible(n, Vector3(2.5, 2.2, 0.1), Vector3(0, 1.1, 1.2))
	B3.wall_invisible(n, Vector3(0.1, 2.2, 2.5), Vector3(-1.2, 1.1, 0))
	B3.wall_invisible(n, Vector3(0.1, 2.2, 2.5), Vector3(1.2, 1.1, 0))
	Interiors.prop(n, "wooden_bowl_01", Vector3(0.6, 0, 0.6), 0.0)
	B3.box(n, Vector3(1.4, 0.08, 0.7), Vector3(-0.3, 0.04, -0.6), B3.mat(Color(0.5, 0.42, 0.3), 0.95), false)


static func cellar(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1801
	var W := 16.0
	var D := 22.0
	var H := 4.2
	var hx := W * 0.5
	var hz := D * 0.5
	var m := Interiors.shell(root, W, D, H, Color(0.58, 0.55, 0.52), Color(0.4, 0.37, 0.34), 1.8)
	var rock := BuildingLook.photo_material("rubble", "stone", Color(0.45, 0.43, 0.42), 0.75)
	var iron := B3.mat(Color(0.22, 0.22, 0.24), 0.5, 0.8)
	B3.box(root, Vector3(W, 0.04, D), Vector3(0, 0.02, 0), rock, false)
	# Pfeiler und Fackeln
	for z in [-6.0, 0.0, 6.0]:
		for sx in [-1.0, 1.0]:
			B3.box(root, Vector3(0.7, H, 0.7), Vector3(sx * 4.5, H * 0.5, z), rock)
			_torch(root, Vector3(sx * (hx - 0.1), 2.2, z + 3.0), sx)
	# Verlies: zwei Käfige an der Westwand, ein Gefangener
	for z in [-7.0, -3.0]:
		_cage(root, Vector3(-hx + 1.6, 0, z), iron)
	Townsfolk.spawn(root, [], [Vector3(-hx + 1.6, 0, -3.0)], 1802, 1, "adventurer")
	# Zähltisch der Acht Finger: Gold, Schuldbuch, Kerzen
	var tbl := Interiors.prop_h(root, "WoodenTable_01", Vector3(3.0, 0, -7.5), 0.78, 90.0, true)
	var ty := tbl.y if tbl != Vector3.ZERO else 0.78
	var goldm := B3.mat(Color(1.0, 0.82, 0.3), 0.3, 0.9, Color(0.6, 0.45, 0.1), 0.6)
	for k in 16:
		B3.cyl(root, 0.06, 0.06, 0.012, Vector3(3.0 + rng.randf_range(-0.6, 0.6), ty + 0.006 + (k % 3) * 0.012, -7.5 + rng.randf_range(-0.35, 0.35)), goldm, false, 10)
	B3.sphere(root, 0.22, Vector3(2.6, ty + 0.1, -7.3), goldm, Vector3(1.3, 0.5, 1.0))
	Interiors.prop(root, "book_encyclopedia_set_01", Vector3(3.6, ty, -7.9), 15.0)
	Interiors.candle(root, Vector3(2.3, ty, -7.95))
	Interiors.candle(root, Vector3(3.8, ty, -7.1), "brass_candleholders")
	Interiors.chair_at(root, Vector3(3.0, 0, -7.5), 270.0, 0.95)
	# Schmuggelware entlang der Ostwand, Waffen an der Westwand
	Interiors.prop_h(root, "wooden_crate_01", Vector3(hx - 0.9, 0, 4.0), 0.55, 10.0, true)
	Interiors.prop_h(root, "wooden_crate_02", Vector3(hx - 0.9, 0.55, 4.0), 0.5, 80.0, false)
	Interiors.prop_h(root, "wooden_crate_02", Vector3(hx - 2.0, 0, 4.4), 0.5, 30.0, true)
	Interiors.prop_h(root, "barrel_03", Vector3(hx - 0.8, 0, 7.5), 0.9, 0.0, true)
	Interiors.prop_h(root, "wine_barrel_01", Vector3(hx - 0.8, 0, 1.2), 0.95, 20.0, true)
	Interiors.prop_h(root, "wooden_barrels_01", Vector3(-hx + 1.8, 0, 6.5), 0.9, 60.0, true)
	Interiors.prop(root, "wicker_basket_02", Vector3(hx - 2.2, 0, 7.4), 40.0)
	_sword_rack(root, Vector3(-hx + 0.35, 0, 1.5), 90.0, m, iron, 5)
	Interiors.prop_h(root, "kite_shield", Vector3(-hx + 0.08, 2.0, 3.5), 1.0, 90.0)
	# Blut, Ketten, Staub
	GroundMark.ring(root, Vector3(0.5, 0.03, -2.0), 0.9, Color(0.3, 0.02, 0.03), 3600.0, 0.6)
	GroundMark.ring(root, Vector3(-2.5, 0.03, 5.0), 0.6, Color(0.3, 0.02, 0.03), 3600.0, 0.6)
	for x in [-2.0, 2.0]:
		B3.cyl(root, 0.02, 0.02, 1.6, Vector3(x, H - 0.9, 2.0), iron, false, 6)
	B3.motes(root, Vector3(0, 2.0, 0), Vector3(6.5, 1.5, 9.0), Color(0.8, 0.75, 0.7, 0.4), 60)
	Interiors.lantern(root, Vector3(0, 3.5, -7.0), H - 0.3, 1.4)
	Interiors.lantern(root, Vector3(0, 3.5, 5.0), H - 0.3, 1.4)
	B3.light(root, Vector3(0, H - 1.0, -1.0), Color(1.0, 0.75, 0.5), 3.0, 18.0)
	Interiors.lantern(root, Vector3(0, 3.5, 8.5), H - 0.3, 1.4)
	return {"spawn": Vector3(0, 0.2, hz - 1.6), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5), "slots": [Vector3(0, 0, -9.5)]}


# =====================================================================
#  Verliese: Steingewölbe, Gebeine, Kanalisation, Gruft
# =====================================================================

## Steingewölbe: Boden, Wände, Decke, Türöffnung mit Steingewände in der Südwand (+z), unsichtbare Grenzen.
static func _vault(root: Node3D, W: float, D: float, H: float, wall: Material, floor_m: Material, ceil_m: Material, door_w: float = 1.8) -> void:
	var hx := W * 0.5
	var hz := D * 0.5
	B3.box(root, Vector3(W + 0.8, 0.2, D + 0.8), Vector3(0, -0.1, 0), floor_m)
	B3.box(root, Vector3(0.4, H, D + 0.8), Vector3(-hx - 0.2, H * 0.5, 0), wall)
	B3.box(root, Vector3(0.4, H, D + 0.8), Vector3(hx + 0.2, H * 0.5, 0), wall)
	B3.box(root, Vector3(W + 0.8, H, 0.4), Vector3(0, H * 0.5, -hz - 0.2), wall)
	var side := (W - door_w) * 0.5
	B3.box(root, Vector3(side + 0.4, H, 0.4), Vector3(-(door_w * 0.5 + side * 0.5) - 0.2, H * 0.5, hz + 0.2), wall)
	B3.box(root, Vector3(side + 0.4, H, 0.4), Vector3((door_w * 0.5 + side * 0.5) + 0.2, H * 0.5, hz + 0.2), wall)
	B3.box(root, Vector3(door_w, H - 2.6, 0.4), Vector3(0, 2.6 + (H - 2.6) * 0.5, hz + 0.2), wall)
	B3.box(root, Vector3(W + 0.8, 0.3, D + 0.8), Vector3(0, H + 0.15, 0), ceil_m)
	var trim := B3.mat(Color(0.3, 0.29, 0.28), 0.9)
	for sx in [-1.0, 1.0]:
		B3.box(root, Vector3(0.25, 2.7, 0.5), Vector3(sx * (door_w * 0.5 + 0.12), 1.35, hz + 0.2), trim, false)
	B3.box(root, Vector3(door_w + 0.5, 0.25, 0.5), Vector3(0, 2.72, hz + 0.2), trim, false)
	B3.box(root, Vector3(door_w, 0.05, 0.9), Vector3(0, 0.025, hz), trim, false)
	B3.bounds(root, maxf(hx, hz) + 0.3, H + 1.0)


## Gebeine: Schädel und ein paar Knochen in einem kleinen Haufen.
static func _bones(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var bone := B3.mat(Color(0.82, 0.78, 0.68), 0.8)
	B3.sphere(root, 0.12, pos + Vector3(0.1, 0.11, 0.05), bone, Vector3(1, 1.1, 1.15))
	for k in 6:
		var b := B3.cyl(root, 0.025, 0.03, rng.randf_range(0.3, 0.55), pos + Vector3(rng.randf_range(-0.35, 0.35), 0.03, rng.randf_range(-0.35, 0.35)), bone, false, 6)
		b.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0.0)


static func sewer(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1901
	var W := 11.0
	var D := 46.0
	var H := 4.2
	var hx := W * 0.5
	var hz := D * 0.5
	var wall := BuildingLook.photo_material("rubble", "stone", Color(0.36, 0.38, 0.35), 0.85)
	var floor_m := BuildingLook.photo_material("rubble", "stone", Color(0.3, 0.31, 0.29), 0.9)
	var iron := B3.mat(Color(0.2, 0.2, 0.22), 0.55, 0.8)
	_vault(root, W, D, H, wall, floor_m, wall, 1.8)
	# Wasserrinne in der Mitte (endet vor dem Südende): trübes Wasser zwischen zwei Bordsteinen
	var water := B3.mat(Color(0.06, 0.13, 0.11, 0.82), 0.12, 0.5)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cl := D - 6.0
	var cz := -2.0
	B3.box(root, Vector3(3.2, 0.03, cl), Vector3(0, 0.03, cz), water, false)
	var curb := B3.mat(Color(0.25, 0.26, 0.24), 0.95)
	for sx in [-1.0, 1.0]:
		B3.box(root, Vector3(0.25, 0.16, cl), Vector3(sx * 1.72, 0.08, cz), curb, false)
	B3.box(root, Vector3(3.7, 0.16, 0.25), Vector3(0, 0.08, cz + cl * 0.5), curb, false)
	# Bögen alle 5,5 m, Fackeln wechselseitig, vergitterte Nischen
	var nb := int(D / 5.5)
	for i in nb:
		var z := -hz + 3.0 + i * 5.5
		for sx in [-1.0, 1.0]:
			B3.box(root, Vector3(0.6, H, 0.6), Vector3(sx * (hx - 0.3), H * 0.5, z), wall)
		B3.box(root, Vector3(W, 0.5, 0.6), Vector3(0, H - 0.25, z), wall, false)
		var ts := -1.0 if i % 2 == 0 else 1.0
		_torch(root, Vector3(ts * (hx - 0.1), 2.1, z + 2.7), ts)
		if i % 3 == 1:
			B3.box(root, Vector3(0.15, 1.2, 1.2), Vector3(-ts * (hx - 0.1), 1.4, z - 2.0), B3.mat(Color(0.03, 0.03, 0.03), 1.0), false)
			for k in 5:
				B3.cyl(root, 0.02, 0.02, 1.2, Vector3(-ts * (hx - 0.14), 1.4, z - 2.5 + k * 0.25), iron, false, 5)
	# Schleim und leuchtende Pilze an den Rändern
	for k in 7:
		var p := Vector3(rng.randf_range(2.3, hx - 1.0) * (1.0 if k % 2 == 0 else -1.0), 0.0, rng.randf_range(-hz + 5.0, hz - 5.0))
		GroundMark.ring(root, p + Vector3(0, 0.035, 0), rng.randf_range(0.4, 0.8), Color(0.35, 0.9, 0.4), 3600.0, 0.3)
		for j in 3:
			var q := p + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			B3.cyl(root, 0.03, 0.04, 0.16, q + Vector3(0, 0.08, 0), B3.mat(Color(0.8, 0.85, 0.7), 0.8), false, 6)
			B3.sphere(root, 0.07, q + Vector3(0, 0.18, 0), B3.mat(Color(0.5, 1.0, 0.5), 0.5, 0.0, Color(0.4, 1.0, 0.45), 2.5), Vector3(1, 0.6, 1))
		B3.light(root, p + Vector3(0, 0.5, 0), Color(0.45, 1.0, 0.5), 0.7, 4.5)
	# Gebeine, Kisten und Fässer der Schmuggler
	for k in 4:
		_bones(root, Vector3(rng.randf_range(2.4, hx - 1.0) * (1.0 if k % 2 == 0 else -1.0), 0, rng.randf_range(-hz + 6.0, hz - 6.0)), rng)
	Interiors.prop_h(root, "wooden_crate_01", Vector3(hx - 1.2, 0, hz - 6.0), 0.55, 20.0, true)
	Interiors.prop_h(root, "wooden_crate_02", Vector3(hx - 1.3, 0.55, hz - 6.0), 0.5, 70.0, false)
	Interiors.prop_h(root, "barrel_03", Vector3(-hx + 1.1, 0, hz - 9.0), 0.9, 0.0, true)
	# Tropfen von der Decke, fauliger Dunst
	B3.motes(root, Vector3(0, H - 0.4, 0), Vector3(hx - 0.5, 0.2, hz - 1.0), Color(0.6, 0.75, 0.7, 0.5), 50, 2.2)
	B3.motes(root, Vector3(0, 1.2, 0), Vector3(hx - 0.5, 0.8, hz - 1.0), Color(0.5, 0.7, 0.5, 0.25), 40)
	# Kultaltar der Zurrernon am Nordende: Steinblock, Runenkreis, Kerzen, Schädel, Banner, violettes Licht
	var az := -hz + 3.2
	B3.box(root, Vector3(2.4, 1.0, 1.1), Vector3(0, 0.5, az), B3.mat(Color(0.2, 0.18, 0.22), 0.8))
	B3.box(root, Vector3(2.6, 0.1, 1.3), Vector3(0, 1.05, az), B3.mat(Color(0.12, 0.1, 0.14), 0.7), false)
	GroundMark.rune(root, Vector3(0, 0.04, az + 2.4), 1.7, Color(0.7, 0.35, 1.0), 3600.0, "a", null, 0.15)
	for x in [-0.95, 0.95]:
		Interiors.candle(root, Vector3(x, 1.1, az - 0.3), "brass_candleholders")
	B3.sphere(root, 0.13, Vector3(0.0, 1.23, az - 0.2), B3.mat(Color(0.85, 0.8, 0.7), 0.7), Vector3(1, 1.1, 1))
	for x in [-3.2, 3.2]:
		B3.banner(root, Vector3(x, 0, az - 1.4), Color(0.3, 0.1, 0.4), null, 2.6, 0.0)
	B3.light(root, Vector3(0, 2.0, az + 1.0), Color(0.7, 0.4, 1.0), 2.2, 9.0).set_meta("flicker", true)
	B3.motes(root, Vector3(0, 1.5, az + 1.5), Vector3(2.0, 1.0, 2.0), Color(0.75, 0.45, 1.0, 0.5), 30)
	for z in [-hz + 10.0, 0.0, hz - 10.0]:
		B3.light(root, Vector3(0, H - 0.8, z), Color(0.6, 0.75, 0.65), 1.4, 16.0)
	return {"spawn": Vector3(0, 0.2, hz - 2.0), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5), "slots": [Vector3(2.8, 0, hz - 8.0)]}


static func crypt(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1902
	var W := 20.0
	var D := 32.0
	var H := 6.5
	var hx := W * 0.5
	var hz := D * 0.5
	var wall := BuildingLook.photo_material("rubble", "stone", Color(0.4, 0.4, 0.42), 0.8)
	var floor_m := BuildingLook.photo_material("rubble", "stone", Color(0.33, 0.33, 0.36), 0.85)
	var dark := B3.mat(Color(0.22, 0.22, 0.25), 0.9)
	var sarc := B3.mat(Color(0.45, 0.44, 0.46), 0.75)
	var bone := B3.mat(Color(0.82, 0.78, 0.68), 0.8)
	_vault(root, W, D, H, wall, floor_m, wall, 2.2)
	# Säulen in zwei Reihen mit Kapitellen
	for z in [-9.0, -2.0, 5.0, 12.0]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * 5.5, 0, z)
			B3.box(root, Vector3(0.9, H, 0.9), p + Vector3(0, H * 0.5, 0), wall)
			B3.box(root, Vector3(1.3, 0.3, 1.3), p + Vector3(0, 0.15, 0), dark, false)
			B3.box(root, Vector3(1.3, 0.3, 1.3), p + Vector3(0, H - 0.15, 0), dark, false)
	# Sarkophage entlang der Wände, manche aufgebrochen, Kerzen mit kaltem Licht
	var k := 0
	for z in [-8.0, -3.5, 1.0, 5.5, 10.0]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (hx - 1.6), 0, z)
			B3.box(root, Vector3(1.1, 0.9, 2.3), p + Vector3(0, 0.45, 0), sarc)
			var broken := k % 3 == 1
			var lid := B3.box(root, Vector3(1.2, 0.16, 2.4), p + Vector3(0.35 if broken else 0.0, 1.1 if broken else 0.98, 0.3 if broken else 0.0), dark, false)
			if broken:
				lid.rotation_degrees = Vector3(4.0, 0, sx * 14.0)
				B3.sphere(root, 0.12, p + Vector3(-0.2, 1.0, -0.4), bone, Vector3(1, 1.1, 1.15))
			if k % 2 == 0:
				for c in 3:
					var cp := p + Vector3(rng.randf_range(-0.4, 0.4), 0.98, rng.randf_range(-0.9, 0.9))
					B3.cyl(root, 0.025, 0.025, 0.14, cp + Vector3(0, 0.07, 0), B3.mat(Color(0.92, 0.9, 0.82), 0.6), false, 6)
					B3.sphere(root, 0.02, cp + Vector3(0, 0.17, 0), B3.mat(Color(0.7, 0.8, 1.0), 0.3, 0.0, Color(0.6, 0.75, 1.0), 5.0))
				B3.light(root, p + Vector3(0, 1.4, 0), Color(0.6, 0.75, 1.0), 0.8, 5.0).set_meta("flicker", true)
			k += 1
	# Gebeine, altes Blut, zerrissene Banner beider Reiche
	for i in 5:
		_bones(root, Vector3(rng.randf_range(-4.0, 4.0), 0, rng.randf_range(-6.0, hz - 4.0)), rng)
	GroundMark.ring(root, Vector3(1.5, 0.03, 3.0), 1.1, Color(0.25, 0.02, 0.03), 3600.0, 0.7)
	for z in [-4.0, 4.0]:
		B3.banner(root, Vector3(-(hx - 0.6), 0, z), Color(0.11, 0.18, 0.42), null, 3.2, PI * 0.5)
		B3.banner(root, Vector3(hx - 0.6, 0, z), Color(0.55, 0.1, 0.1), null, 3.2, -PI * 0.5)
	# Kalte Feuerschalen (blaue Flammen) am Mittelgang
	for z in [-6.0, 2.0, 10.0]:
		for sx in [-1.0, 1.0]:
			B3.brazier(root, Vector3(sx * 3.0, 0, z), Color(0.45, 0.65, 1.0))
	# Podest mit Steinthron des Generals, sein aufgebrochener Sarkophag, Wächterstatuen
	var dz := -hz + 4.5
	B3.box(root, Vector3(10.0, 0.15, 6.0), Vector3(0, 0.075, dz), dark)
	B3.box(root, Vector3(1.4, 0.6, 1.2), Vector3(0, 0.45, dz - 1.8), sarc)
	B3.box(root, Vector3(1.4, 1.6, 0.3), Vector3(0, 1.55, dz - 2.35), sarc)
	for sx in [-1.0, 1.0]:
		B3.box(root, Vector3(0.25, 0.8, 1.2), Vector3(sx * 0.82, 0.8, dz - 1.8), sarc, false)
	B3.box(root, Vector3(2.4, 1.0, 1.2), Vector3(-3.6, 0.65, dz - 1.5), sarc)
	var lid2 := B3.box(root, Vector3(2.5, 0.16, 1.3), Vector3(-2.4, 0.5, dz - 0.4), dark, false)
	lid2.rotation_degrees = Vector3(0, 20, -60)
	Interiors.prop(root, "gothic_statue", Vector3(-4.6, 0.15, dz - 2.4), 20.0, 1.3)
	Interiors.prop(root, "gothic_statue", Vector3(4.6, 0.15, dz - 2.4), -20.0, 1.3)
	B3.light(root, Vector3(0, 3.2, dz), Color(0.55, 0.7, 1.0), 2.6, 12.0).set_meta("flicker", true)
	B3.motes(root, Vector3(0, 1.0, 0), Vector3(hx - 1.0, 0.8, hz - 1.0), Color(0.6, 0.7, 0.9, 0.3), 70)
	for z in [-6.0, 4.0, 12.0]:
		B3.light(root, Vector3(0, H - 1.0, z), Color(0.55, 0.62, 0.8), 1.5, 16.0)
	return {"spawn": Vector3(0, 0.2, hz - 2.0), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5), "slots": [Vector3(0, 0, dz + 3.0)]}

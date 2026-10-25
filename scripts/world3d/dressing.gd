class_name Dressing
## Ausstattung der Orte aus Daten (data/dressing.json): Banner, Feuerschalen, Lagerfeuer, Statuen, Kisten,
## Fässer, Zelte, Palisaden, Brunnen, Gedenksteine, Laternenpfähle, Heuhaufen, Wäscheleinen, Fotoscans …
## Jeder Eintrag: {"kind": "...", "at": [x, z] (auf den Boden gesetzt) oder [x, y, z], "yaw": Grad, "scale": f, …}.
## Alles landet unter einem Knoten „Ausstattung“ und wird beim Verlassen mit dem Ort freigegeben.
## Ziel: Orte erzählen ihre Geschichte (Überfall, Lager, Markt, Trauer), ohne dass die Ortsmodelle neu gebaut werden.

static var _data: Dictionary = {}
## Arten ohne Körper – schweben, brauchen weder Boden noch freien Platz.
const SOFT := ["light", "motes", "smoke", "rug"]   # liegen flach bzw. schweben: keine Ausweichsuche
## Arten, die sich dem Boden anschmiegen dürfen (Reisig, Heu, Trümmer, Felsen): bis 45° Hang erlaubt, Knoten wird geneigt.
const TILT := ["ph", "hay", "debris", "memorial"]


## Boden unter (x, z): erster Treffer von oben – liegt knapp darunter (bis 1,4 m) noch eine Fläche, zählt die untere
## (Büsche, Brüstungen und Geländer sind kein Boden; Dächer schon, die liegen höher über dem Hausboden).
static func _ground(space: PhysicsDirectSpaceState3D, pos: Vector3) -> Dictionary:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 60.0, pos - Vector3.UP * 60.0, 0x7FFFFFFF))
	var excl: Array[RID] = []
	for k in 3:
		if hit.is_empty() or (hit.collider is Node and String((hit.collider as Node).name).begins_with("Ground")):
			break    # Gelände (auch Wasserflächen) ist Boden – nicht weiter nach unten suchen
		excl.append(hit.rid)
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(hit.position - Vector3.UP * 0.05, hit.position - Vector3.UP * 1.4, 1, excl))
		if below.is_empty():
			break
		hit = below
	return hit


## Passt ein Stück hierher? Nichts im Umkreis von 0,6 m auf Brusthöhe.
static func _fits(space: PhysicsDirectSpaceState3D, pos: Vector3) -> bool:
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis(), pos + Vector3.UP * 1.0)
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()


## Freier, flacher Platz für ein Stück: die Wunschposition, sonst der nächste freie Punkt im Umkreis von 5 m
## (Boden flacher als 20°, nicht mehr als 2,5 m höher oder tiefer). Nichts gefunden → Wunschposition.
static func _free_spot(space: PhysicsDirectSpaceState3D, pos: Vector3, g: Dictionary, min_ny: float = 0.94) -> Vector3:
	var flat: bool = not g.is_empty() and (g.normal as Vector3).y >= min_ny
	if flat and _fits(space, pos):
		return pos
	for r in [1.5, 2.5, 3.5, 5.0]:
		for k in 12:
			var a := TAU * k / 12.0 + float(r)
			var c := pos + Vector3(cos(a) * float(r), 0.0, sin(a) * float(r))
			var h := _ground(space, c)
			if h.is_empty() or (h.normal as Vector3).y < min_ny:
				continue
			c.y = float(h.position.y)
			if absf(c.y - pos.y) > 2.5:
				continue
			if _fits(space, c):
				return c
	return pos


static func apply(loc: Dictionary, root: Node3D) -> void:
	if _data.is_empty():
		var f := FileAccess.open("res://data/dressing.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	var list: Array = _data.get(String(loc.get("id", "")), [])
	if list.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Ausstattung"
	root.add_child(holder)
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(loc.get("id", "")) + "ausstattung")
	var idx := 0
	for e in list:
		idx += 1
		if e.has("requires") and not Game.check(e.requires):
			continue
		if e.has("requires_not") and Game.check(e.requires_not):
			continue
		var at: Array = e.get("at", [0, 0])
		var pos := Vector3(float(at[0]), float(at[1]) if at.size() > 2 else 0.0, float(at[2] if at.size() > 2 else at[1]))
		var tilt_to := Vector3.UP
		if at.size() < 3:
			# auf den Boden setzen; Stücke mit Körper weichen Gebäuden, Zelten, Fels und Dächern aus
			var g := _ground(space, pos)
			if not g.is_empty():
				pos.y = float(g.position.y)
			var kind := String(e.kind)
			if kind in TILT:
				pos = _free_spot(space, pos, g, 0.85)
				var g2 := _ground(space, pos)
				if not g2.is_empty() and (g2.normal as Vector3).y >= 0.7 and (g2.normal as Vector3).y < 0.999:
					tilt_to = g2.normal
			elif not kind in SOFT:
				pos = _free_spot(space, pos, g)
		var n := Node3D.new()
		n.name = "%s_%d" % [e.kind, idx]
		n.set_meta("entry", e)
		n.position = pos
		n.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
		if tilt_to != Vector3.UP:
			# dem Hang anschmiegen: erst um die Hochachse drehen, dann die Hochachse auf die Bodennormale kippen
			var yaw_basis := Basis(Vector3.UP, deg_to_rad(float(e.get("yaw", 0.0))))
			var axis := Vector3.UP.cross(tilt_to)
			if axis.length() > 0.001:
				n.basis = Basis(axis.normalized(), Vector3.UP.angle_to(tilt_to)) * yaw_basis
		holder.add_child(n)
		_build(String(e.kind), n, e, rng)


static func _build(kind: String, n: Node3D, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var sc := float(e.get("scale", 1.0))
	match kind:
		"banner":
			var col := Color(String(e.get("color", "#2a0a3a")))
			var emblem: Texture2D = Palette.icon("faction_" + String(e.get("faction", "nazarick")))
			var post := BuildingLook.photo_material("logs", "wood", Color(0.45, 0.36, 0.28), 0.6)
			B3.cyl(n, 0.08, 0.1, 4.6 * sc, Vector3(0, 2.3 * sc, 0), post, true, 8)
			B3.box(n, Vector3(1.6 * sc, 0.08, 0.08), Vector3(0, 4.4 * sc, 0), post, false)
			B3.banner(n, Vector3(0, 4.35 * sc, 0.1), col, emblem, 2.6 * sc, 0.0)
		"brazier":
			B3.brazier(n, Vector3.ZERO, Color(String(e.get("color", "#ff8c38"))))
		"campfire":
			# Steinring (Fotoscan), Glut, Flammen, Rauch, Licht – ggf. erloschen (cold)
			if PhProps.attach(n, "stone_fire_pit", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.9), Vector3.ZERO)) == Vector3.ZERO:
				B3.cyl(n, 0.7, 0.7, 0.25, Vector3(0, 0.12, 0), B3.mat(Color(0.4, 0.38, 0.35), 0.95), true, 12)
			var logm := B3.mat(Color(0.18, 0.1, 0.05), 0.9)
			for k in 3:
				var lg := B3.cyl(n, 0.07, 0.07, 0.8, Vector3(0, 0.18, 0), logm, false, 7)
				lg.rotation_degrees = Vector3(0, 60 * k, 78)
			if not e.get("cold", false):
				B3.fire(n, Vector3(0, 0.3, 0), Color(1.0, 0.55, 0.2), 30)
				B3.light(n, Vector3(0, 1.1, 0), Color(1.0, 0.55, 0.25), 2.0, 9.0).set_meta("flicker", true)
				B3.smoke(n, Vector3(0, 0.8, 0), 8)
			else:
				B3.motes(n, Vector3(0, 0.6, 0), Vector3(0.3, 0.3, 0.3), Color(0.5, 0.5, 0.5, 0.3), 6)
		"statue":
			var ped := BuildingLook.photo_material("limestone", "stone", Color(0.85, 0.82, 0.76), 0.5)
			B3.box(n, Vector3(1.4, 0.8, 1.4) * sc, Vector3(0, 0.4 * sc, 0), ped)
			PhProps.attach(n, "gothic_statue", Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3(0, 0.8 * sc, 0)))
		"crates":
			var cnt := int(e.get("count", 3))
			var names := ["wooden_crate_01", "wooden_crate_02"]
			for k in cnt:
				var w := PhProps.whole(names[k % 2])
				var y := 0.0 if k < 2 else float((PhProps.whole(names[0]).size as Vector3).y)
				var off := Vector3((k % 2) * 0.9 - 0.45, y, (k / 2) * 0.1) if k < 2 else Vector3(0.0, y, 0.05)
				PhProps.attach(n, names[k % 2], Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * sc), off))
				if not w.is_empty():
					B3.wall_invisible(n, Vector3(1.0, 0.5, 0.9) * sc, off + Vector3(0, 0.25 * sc, 0))
		"barrels":
			PhProps.attach(n, "wooden_barrels_01", Transform3D(Basis().scaled(Vector3.ONE * sc * 0.9), Vector3.ZERO))
			B3.wall_invisible(n, Vector3(3.8, 0.9, 2.8) * sc * 0.9, Vector3(0, 0.45, 0))
		"tent":
			# Zeltplane (Prisma) über zwei Pfosten, Boden aus Fell; farbe = Plane
			var canvas := B3.mat(Color(String(e.get("color", "#8a7a5a"))), 0.95)
			var post := B3.mat(Color(0.35, 0.25, 0.15), 0.8)
			B3.prism(n, Vector3(3.2, 1.9, 3.6) * sc, Vector3(0, 0.95 * sc, 0), canvas)
			B3.wall_invisible(n, Vector3(3.0, 1.8, 3.4) * sc, Vector3(0, 0.9 * sc, 0))
			for z in [-1.7, 1.7]:
				B3.cyl(n, 0.05, 0.06, 1.9 * sc, Vector3(0, 0.95 * sc, z * sc), post, false, 6)
			B3.box(n, Vector3(2.4, 0.04, 2.6) * sc, Vector3(0, 0.02, 0), B3.mat(Color(0.5, 0.42, 0.3), 0.95), false)
		"palisade":
			# Reihe angespitzter Pfähle entlang +x, Länge len
			var length := float(e.get("len", 6.0))
			var post := BuildingLook.photo_material("logs", "wood", Color(0.5, 0.4, 0.3), 0.6)
			var cnt := maxi(2, int(length / 0.45))
			for k in cnt:
				var h := rng.randf_range(2.3, 2.7) * sc
				B3.cyl(n, 0.2, 0.22, h, Vector3(-length * 0.5 + k * length / (cnt - 1), h * 0.5, 0), post, false, 7)
				B3.cone(n, 0.21, 0.4, Vector3(-length * 0.5 + k * length / (cnt - 1), h, 0), post)
			B3.wall_invisible(n, Vector3(length + 0.4, 2.6, 0.5), Vector3(0, 1.3, 0))
			B3.box(n, Vector3(length, 0.1, 0.12), Vector3(0, 1.4, 0.2), post, false)
		"well":
			var stone := BuildingLook.photo_material("rubble", "stone", Color(0.7, 0.68, 0.64), 0.7)
			var wood := BuildingLook.photo_material("logs", "wood", Color(0.45, 0.36, 0.28), 0.6)
			B3.cyl(n, 1.1, 1.15, 1.0, Vector3(0, 0.5, 0), stone, true, 16)
			B3.cyl(n, 0.85, 0.85, 1.02, Vector3(0, 0.52, 0), B3.mat(Color(0.03, 0.04, 0.05), 0.4), false, 16)
			for s in [-1.0, 1.0]:
				B3.box(n, Vector3(0.14, 2.2, 0.14), Vector3(s * 0.95, 1.1, 0), wood, false)
			B3.box(n, Vector3(2.3, 0.1, 0.1), Vector3(0, 2.15, 0), wood, false)
			B3.prism(n, Vector3(2.8, 0.7, 2.6), Vector3(0, 2.55, 0), BuildingLook.photo_material("roof_slate", "roof", Color(0.7, 0.7, 0.72), 0.8))
			PhProps.attach(n, "wooden_bucket_01", Transform3D(Basis(), Vector3(0, 1.0, 0)))
		"memorial":
			# Gedenkstein mit Blumen und Kerzen
			PhProps.attach(n, "rock_07", Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled(Vector3(0.9, 0.9, 0.9)), Vector3(0, 0.0, 0)))
			var flowers := ["celandine_01", "flower_gazania", "flower_ursinia"]
			for k in 5:
				var a := rng.randf() * TAU
				PhProps.attach(n, flowers[k % 3], Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.6, 0, sin(a) * 0.6 + 0.3)))
			for k in 3:
				var cp := Vector3(-0.3 + k * 0.3, 0.0, 0.75)
				B3.cyl(n, 0.025, 0.025, 0.12, cp + Vector3(0, 0.06, 0), B3.mat(Color(0.95, 0.92, 0.85), 0.6), false, 6)
				B3.sphere(n, 0.02, cp + Vector3(0, 0.15, 0), B3.mat(Color(1, 0.7, 0.3), 0.3, 0.0, Color(1, 0.65, 0.25), 5.0))
			B3.light(n, Vector3(0, 0.5, 0.8), Color(1.0, 0.7, 0.35), 0.5, 3.0).set_meta("flicker", true)
		"lantern_post":
			var post := BuildingLook.photo_material("logs", "wood", Color(0.4, 0.32, 0.25), 0.6)
			B3.cyl(n, 0.07, 0.09, 3.0, Vector3(0, 1.5, 0), post, true, 8)
			B3.box(n, Vector3(0.06, 0.06, 0.7), Vector3(0, 2.9, 0.3), B3.mat(Color(0.2, 0.19, 0.18), 0.5, 0.7), false)
			PhProps.attach(n, "wooden_lantern_01", Transform3D(Basis(), Vector3(0, 2.3, 0.6)))
			B3.sphere(n, 0.05, Vector3(0, 2.56, 0.6), B3.mat(Color(1.0, 0.85, 0.55), 0.3, 0.0, Color(1.0, 0.78, 0.5), 4.0))
			B3.light(n, Vector3(0, 2.5, 0.75), Color(1.0, 0.78, 0.5), 1.4, 8.0).set_meta("flicker", true)
		"hay":
			var hm := B3.noise_mat(Color(0.62, 0.5, 0.25), Color(0.85, 0.72, 0.4), 0.9, 0.95, Color.BLACK, 3.0)
			B3.sphere(n, 1.2 * sc, Vector3(0, 0.7 * sc, 0), hm, Vector3(1.0, 0.75, 1.0), true)
			B3.sphere(n, 0.8 * sc, Vector3(0.6 * sc, 0.4 * sc, 0.5 * sc), hm, Vector3(1.0, 0.7, 1.0), false)
		"laundry":
			# Wäscheleine zwischen zwei Pfosten mit bunten Tüchern
			var post := B3.mat(Color(0.35, 0.25, 0.15), 0.8)
			var length := float(e.get("len", 5.0))
			for s in [-1.0, 1.0]:
				B3.cyl(n, 0.05, 0.06, 2.2, Vector3(s * length * 0.5, 1.1, 0), post, false, 6)
			B3.cyl(n, 0.012, 0.012, length, Vector3(0, 2.05, 0), B3.mat(Color(0.8, 0.78, 0.7), 0.9), false, 4).rotation_degrees.z = 90
			var cols := [Color(0.85, 0.82, 0.74), Color(0.5, 0.3, 0.25), Color(0.35, 0.45, 0.6), Color(0.6, 0.55, 0.35)]
			var cnt := int(length / 0.8)
			for k in cnt:
				var w := rng.randf_range(0.4, 0.6)
				var cloth := B3.box(n, Vector3(w, rng.randf_range(0.5, 0.9), 0.02), Vector3(-length * 0.5 + 0.5 + k * 0.8, 1.65, 0.02), B3.mat(cols[k % 4], 0.95), false)
				cloth.rotation_degrees.y = rng.randf_range(-8, 8)
		"debris":
			# Überfall/Schlacht: zerbrochener Karren, verstreute Fässer, ein abgebrochener Speer, Blutspur
			PhProps.attach(n, "wooden_crate_02", Transform3D(Basis(Vector3.RIGHT, 0.6).scaled(Vector3.ONE * sc), Vector3(0.8, 0.3, 0)))
			PhProps.attach(n, "barrel_03", Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(-1.1, 0.3, 0.6)))
			var wood := B3.mat(Color(0.3, 0.2, 0.1), 0.9)
			for k in 4:
				var pl := B3.box(n, Vector3(rng.randf_range(0.6, 1.4), 0.05, 0.18), Vector3(rng.randf_range(-1.5, 1.5), 0.03, rng.randf_range(-1.5, 1.5)), wood, false)
				pl.rotation_degrees = Vector3(0, rng.randf_range(0, 180), rng.randf_range(-20, 20))
			var wheel := TorusMesh.new()
			wheel.inner_radius = 0.42
			wheel.outer_radius = 0.5
			B3.mesh(n, wheel, Vector3(1.6, 0.5, -0.8), wood, Vector3(rng.randf_range(60, 80), rng.randf_range(0, 360), 0))
			B3.cyl(n, 0.02, 0.02, 1.6, Vector3(-0.4, 0.25, -1.2), wood, false, 5).rotation_degrees = Vector3(0, 30, 70)
			if e.get("blood", true):
				GroundMark.ring(n, Vector3(0.2, 0.02, 0.3), 0.9, Color(0.3, 0.02, 0.03), 3600.0, 0.6)
		"gallows":
			var wood := BuildingLook.photo_material("logs", "wood", Color(0.4, 0.32, 0.25), 0.7)
			B3.box(n, Vector3(3.0, 0.3, 2.0), Vector3(0, 0.15, 0), wood)
			B3.box(n, Vector3(0.22, 3.6, 0.22), Vector3(-1.2, 1.8, 0), wood)
			B3.box(n, Vector3(2.8, 0.2, 0.2), Vector3(0, 3.5, 0), wood, false)
			B3.cyl(n, 0.02, 0.02, 1.0, Vector3(0.9, 3.0, 0), B3.mat(Color(0.6, 0.5, 0.35), 0.95), false, 5)
			B3.mesh(n, TorusMesh.new(), Vector3(0.9, 2.45, 0), B3.mat(Color(0.6, 0.5, 0.35), 0.95), Vector3(0, 90, 0), Vector3(0.2, 0.2, 0.2))
		"ph":
			# beliebiger Fotoscan: {"kind": "ph", "model": "wine_barrel_01", "scale": 1, "solid": true}
			var size := PhProps.attach(n, String(e.get("model", "")), Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3.ZERO))
			if e.get("solid", false) and size != Vector3.ZERO:
				var ext := Vector3(maxf(size.x, size.z), size.y, maxf(size.x, size.z)) * sc
				B3.wall_invisible(n, ext, Vector3(0, ext.y * 0.5, 0))
		"rug":
			# Teppich/Läufer flach auf dem Boden (Muster wie der Läufer im Thronsaal): {"size": [breite, länge]}
			var rs: Array = e.get("size", [2.4, 6.0])
			var cm := StandardMaterial3D.new()
			cm.albedo_texture = LocationBuilder._carpet_texture()
			cm.uv1_scale = Vector3(1.0, float(rs[1]) / (float(rs[0]) * 1.4), 1.0)
			cm.roughness = 0.97
			cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			var rug := B3.mesh(n, LocationBuilder._carpet_mesh(float(rs[0]), float(rs[1])), Vector3(0, float(e.get("h", 0.02)), 0), cm)
			rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"smoke":
			B3.smoke(n, Vector3(0, float(e.get("h", 0.5)), 0), int(e.get("amount", 14)))
		"motes":
			B3.motes(n, Vector3(0, 1.5, 0), Vector3(float(e.get("r", 6.0)), 1.5, float(e.get("r", 6.0))), Color(String(e.get("color", "#fff2b0"))), int(e.get("amount", 60)))
		"light":
			B3.light(n, Vector3(0, float(e.get("h", 2.0)), 0), Color(String(e.get("color", "#ffc880"))), float(e.get("energy", 1.5)), float(e.get("range", 8.0))).set_meta("flicker", e.get("flicker", true))
		"crystal":
			# leuchtender Kristall (Gletscher, Schatzkammer, Runen): {"color", "h", "energy"}
			var cc := Color(String(e.get("color", "#8ad0ff")))
			B3.crystal(n, Vector3.ZERO, cc, float(e.get("h", 1.6)))
			B3.light(n, Vector3(0, float(e.get("h", 1.6)) * 0.6, 0), cc, float(e.get("energy", 1.2)), float(e.get("range", 7.0))).set_meta("flicker", false)
		"fire":
			# offenes Feuer ohne Steinring (Lavaspalten, Opferschalen im Boden): {"color", "amount", "energy"}
			var fc := Color(String(e.get("color", "#ff8c38")))
			B3.fire(n, Vector3(0, float(e.get("h", 0.2)), 0), fc, int(e.get("amount", 30)))
			B3.light(n, Vector3(0, float(e.get("h", 0.2)) + 1.0, 0), fc, float(e.get("energy", 2.0)), float(e.get("range", 9.0))).set_meta("flicker", true)
			if e.get("smoke", true):
				B3.smoke(n, Vector3(0, float(e.get("h", 0.2)) + 0.6, 0), 8)
		"chest":
			# Truhe (Fotoscan), geschlossen: {"scale"}
			if PhProps.attach(n, "treasure_chest", Transform3D(Basis().scaled(Vector3.ONE * sc), Vector3.ZERO)) != Vector3.ZERO:
				B3.wall_invisible(n, Vector3(1.0, 0.7, 0.7) * sc, Vector3(0, 0.35 * sc, 0))
		"folk":
			# Bewohner/Gäste: {"style": maid|guard|noble|merchant|priest|mage|adventurer|"", "idle": [[x,y,z]…],
			# "walk": [[x,y,z]…], "count": n, "tabard": "#…"} – Positionen relativ zu `at`
			var idle: Array = []
			for q in e.get("idle", []):
				idle.append(n.position + Vector3(float(q[0]), float(q[1]), float(q[2])))
			var walk: Array = []
			for q in e.get("walk", []):
				walk.append(n.position + Vector3(float(q[0]), float(q[1]), float(q[2])))
			var t := Townsfolk.spawn(n.get_parent(), walk, idle, rng.randi(), int(e.get("count", idle.size())), String(e.get("style", "")), String(e.get("tabard", "#1d2f6b")))
			t.name = "Townsfolk_%s" % String(e.get("style", "folk"))
		_:
			push_warning("Dressing: unbekannte Art '%s'" % kind)

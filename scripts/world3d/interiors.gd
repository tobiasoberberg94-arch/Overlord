class_name Interiors
## Begehbare Innenräume (eigene Orte mit group "interior", erreichbar über Türen – data/locations.json → "doors").
## Alles prozedural aus Fotomaterialien (BuildingLook.photo_material) und Fotoscan-Requisiten (PhProps):
## Wände mit Fachwerk, Dielenboden, Balkendecke, Fenster mit Tageslicht, Laternen, Kamin.
##
##   guild   Abenteurergilde von E-Rantel: Empfang mit Tresen, Auftragstafel, Schankstube, Kamin, Trophäenwand,
##           Lager, Büro des Gildenmeisters, Abenteurer als Gäste.
##   tavern  Gasthaus: Tresen mit Fässern und Regal, Kamin, Tische, Empore mit Zimmertüren (Treppe begehbar).
##   shop    Apotheke Bareare: Ladentresen mit Waage, Regale voller Tränke, Kräuter an der Decke, Kessel,
##           Werkstatt, Hinterzimmer mit Bett hinter einem Vorhang.
##   cottage Enris Haus in Carne: Herd, Tisch, zwei Betten, das Horn des Goblin-Generals, Nemus Zeichnungen.

const DAYLIGHT := Color(0.86, 0.9, 1.0)
const WARM := Color(1.0, 0.78, 0.5)


static func build(kind: String, root: Node3D, loc: Dictionary) -> Dictionary:
	match kind:
		"guild":
			return guild(root, loc)
		"tavern":
			return tavern(root, loc)
		"shop":
			return shop(root, loc)
		"cottage":
			return cottage(root, loc)
	return {}


# =====================================================================
#  Baukasten
# =====================================================================

## Fotoscan mit Drehung (Grad) und Maßstab an `pos`; Rückgabe: Größe in Metern (nach Maßstab).
static func prop(parent: Node3D, name: String, pos: Vector3, yaw_deg: float = 0.0, scale: float = 1.0, solid: bool = false) -> Vector3:
	var size := PhProps.attach(parent, name, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), pos))
	size *= scale
	if solid and size != Vector3.ZERO:
		var ext := Vector3(maxf(size.x, size.z), size.y, maxf(size.x, size.z))
		B3.wall_invisible(parent, ext, pos + Vector3(0, size.y * 0.5, 0))
	return size


## Fotoscan auf eine Zielhöhe skaliert.
static func prop_h(parent: Node3D, name: String, pos: Vector3, height: float, yaw_deg: float = 0.0, solid: bool = false) -> Vector3:
	var w := PhProps.whole(name)
	if w.is_empty():
		return Vector3.ZERO
	var k := height / maxf((w.size as Vector3).y, 0.01)
	return prop(parent, name, pos, yaw_deg, k, solid)


## Balken (dunkles Holz) zwischen zwei Punkten.
static func beam(parent: Node3D, a: Vector3, b: Vector3, thick: float, m: Material) -> MeshInstance3D:
	var mi := B3.box(parent, Vector3(thick, thick, a.distance_to(b)), (a + b) * 0.5, m, false)
	mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	return mi


## Fenster in einer Wand: Rahmen, leuchtende Scheibe, Tageslicht-Kegel in den Raum. `dir` = Blickrichtung ins Innere.
static func window(parent: Node3D, pos: Vector3, dir: Vector3, w: float = 1.1, h: float = 1.4, energy: float = 3.0) -> void:
	var frame := BuildingLook.photo_material("logs", "wood", Color(0.5, 0.42, 0.34), 0.5)
	var holder := Node3D.new()
	holder.position = pos
	holder.look_at_from_position(pos, pos + dir, Vector3.UP)
	parent.add_child(holder)
	# Rahmen und Sprosse (lokales -Z zeigt in den Raum)
	B3.box(holder, Vector3(w + 0.24, h + 0.24, 0.12), Vector3(0, 0, 0.05), frame, false)
	var pane := B3.mat(Color(0.7, 0.78, 0.9), 0.25, 0.0, Color(0.9, 0.94, 1.0), 0.9)
	B3.box(holder, Vector3(w, h, 0.04), Vector3(0, 0, -0.02), pane, false)
	B3.box(holder, Vector3(0.06, h, 0.07), Vector3(0, 0, -0.04), frame, false)
	B3.box(holder, Vector3(w, 0.06, 0.07), Vector3(0, 0, -0.04), frame, false)
	var sl := SpotLight3D.new()
	sl.light_color = DAYLIGHT
	sl.light_energy = energy
	sl.spot_range = 11.0
	sl.spot_angle = 48.0
	sl.spot_attenuation = 0.9
	sl.shadow_enabled = false
	sl.position = Vector3(0, 0.1, -0.3)
	sl.rotation_degrees = Vector3(-28, 0, 0)
	holder.add_child(sl)


## Hängelaterne an einem Deckenbalken (Seil + Fotoscan + warmes Licht).
static func lantern(parent: Node3D, pos: Vector3, beam_y: float, energy: float = 1.3) -> void:
	var rope := B3.mat(Color(0.45, 0.38, 0.28), 0.95)
	B3.cyl(parent, 0.015, 0.015, beam_y - pos.y, Vector3(pos.x, (beam_y + pos.y) * 0.5, pos.z), rope, false, 6)
	var size := prop_h(parent, "wooden_lantern_01", pos - Vector3(0, 0.42, 0), 0.42)
	if size == Vector3.ZERO:
		B3.box(parent, Vector3(0.22, 0.3, 0.22), pos - Vector3(0, 0.2, 0), B3.mat(Color(0.2, 0.16, 0.12), 0.6, 0.4), false)
	B3.sphere(parent, 0.05, pos - Vector3(0, 0.22, 0), B3.mat(Color(1.0, 0.85, 0.55), 0.3, 0.0, WARM, 4.0))
	var l := B3.light(parent, pos - Vector3(0, 0.3, 0), WARM, energy, 8.0)
	l.shadow_enabled = false
	l.set_meta("flicker", true)


## Kerzenleuchter mit kleinem Licht auf einer Tischplatte.
static func candle(parent: Node3D, pos: Vector3, name: String = "wooden_candlestick") -> void:
	prop(parent, name, pos, randf_range(0.0, 360.0))
	var l := B3.light(parent, pos + Vector3(0, 0.32, 0), Color(1.0, 0.72, 0.4), 0.35, 2.6)
	l.shadow_enabled = false
	l.set_meta("flicker", true)


## Stuhl, dessen Vorderseite zur Tischmitte zeigt.
static func chair_at(parent: Node3D, table: Vector3, angle_deg: float, dist: float, name: String = "WoodenChair_01") -> void:
	var a := deg_to_rad(angle_deg)
	var p := table + Vector3(cos(a) * dist, 0.0, sin(a) * dist)
	# Modell-Vorderseite zeigt nach +Z: Drehung so, dass +Z zur Tischmitte weist
	var yaw := rad_to_deg(atan2(table.x - p.x, table.z - p.z))
	prop_h(parent, name, p, 1.0, yaw + randf_range(-8.0, 8.0), true)


static func railing(parent: Node3D, a: Vector3, b: Vector3, m: Material, h: float = 1.0) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / 1.6))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		B3.box(parent, Vector3(0.1, h, 0.1), p + Vector3(0, h * 0.5, 0), m, true)
	beam(parent, a + Vector3(0, h - 0.06, 0), b + Vector3(0, h - 0.06, 0), 0.08, m)
	beam(parent, a + Vector3(0, h * 0.5, 0), b + Vector3(0, h * 0.5, 0), 0.06, m)


# =====================================================================
#  Abenteurergilde von E-Rantel
# =====================================================================

## Halle 18 × 13 m, Eingang an der Südwand (+z), Tresen an der Nordwand. Rückgabe: Ankerpunkte
## (spawn, yaw, board, slots, exit) – kein Gate: hinaus geht es durch die Tür.
static func guild(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var W := 18.0
	var D := 13.0
	var H := 5.0
	var hx := W * 0.5
	var hz := D * 0.5
	var planks := BuildingLook.photo_material("planks", "wood", Color(0.78, 0.66, 0.5), 0.55)
	var planks_dark := BuildingLook.photo_material("planks", "wood", Color(0.5, 0.4, 0.3), 0.6)
	var plaster := BuildingLook.photo_material("plaster", "plaster", Color(0.86, 0.8, 0.68), 0.45)
	var timber := BuildingLook.photo_material("logs", "wood", Color(0.42, 0.33, 0.25), 0.5)
	var stone := BuildingLook.photo_material("rubble", "stone", Color(0.72, 0.7, 0.66), 0.6)
	var fabric := B3.mat(Color(0.4, 0.09, 0.11), 0.95)
	var brass := B3.mat(Color(0.85, 0.66, 0.28), 0.3, 0.9)

	# --- Hülle: Boden, Wände, Decke ---------------------------------------------------------------
	B3.box(root, Vector3(W + 0.8, 0.2, D + 0.8), Vector3(0, -0.1, 0), planks)
	B3.box(root, Vector3(2.0, 0.02, D - 2.2), Vector3(0, 0.011, 0.2), fabric, false)      # Läufer zum Tresen
	B3.box(root, Vector3(0.4, H, D + 0.8), Vector3(-hx - 0.2, H * 0.5, 0), plaster)    # West
	B3.box(root, Vector3(0.4, H, D + 0.8), Vector3(hx + 0.2, H * 0.5, 0), plaster)     # Ost
	# Nordwand in voller Höhe, Südwand mit Türöffnung (1,8 m breit, 2,6 m hoch)
	B3.box(root, Vector3(W + 0.8, H, 0.4), Vector3(0, H * 0.5, -hz - 0.2), plaster)
	B3.box(root, Vector3(hx - 0.9 + 0.4, H, 0.4), Vector3(-(hx + 0.9) * 0.5 - 0.2, H * 0.5, hz + 0.2), plaster)
	B3.box(root, Vector3(hx - 0.9 + 0.4, H, 0.4), Vector3((hx + 0.9) * 0.5 + 0.2, H * 0.5, hz + 0.2), plaster)
	B3.box(root, Vector3(1.8, H - 2.6, 0.4), Vector3(0, 2.6 + (H - 2.6) * 0.5, hz + 0.2), plaster)
	B3.box(root, Vector3(W + 0.8, 0.24, D + 0.8), Vector3(0, H + 0.12, 0), planks_dark)   # Decke
	# Fachwerk: Eckpfosten, Wandpfosten, Riegel; Deckenbalken quer
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B3.box(root, Vector3(0.32, H, 0.32), Vector3(sx * (hx - 0.16), H * 0.5, sz * (hz - 0.16)), timber, false)
		for z in [-2.2, 2.2]:
			B3.box(root, Vector3(0.26, H, 0.26), Vector3(sx * (hx - 0.13), H * 0.5, z), timber, false)
		for x in [3.6, 7.2]:
			B3.box(root, Vector3(0.26, H, 0.26), Vector3(sx * x, H * 0.5, hz - 0.13), timber, false)
			B3.box(root, Vector3(0.26, H, 0.26), Vector3(sx * x, H * 0.5, -hz + 0.13), timber, false)
		B3.box(root, Vector3(0.2, 0.2, D), Vector3(sx * (hx - 0.1), 2.7, 0), timber, false)
		B3.box(root, Vector3(W, 0.2, 0.2), Vector3(0, 2.7, sx * (hz - 0.1)), timber, false)
	for z in [-4.3, -1.45, 1.45, 4.3]:
		B3.box(root, Vector3(W, 0.34, 0.34), Vector3(0, H - 0.17, z), timber, false)
	B3.box(root, Vector3(0.3, 0.3, D), Vector3(0, H - 0.4, 0), timber, false)
	# Türrahmen, Schwelle, Türblatt (steht offen)
	for sx in [-1.0, 1.0]:
		B3.box(root, Vector3(0.22, 2.75, 0.5), Vector3(sx * 1.0, 1.375, hz + 0.2), timber, false)
	B3.box(root, Vector3(2.3, 0.22, 0.5), Vector3(0, 2.72, hz + 0.2), timber, false)
	B3.box(root, Vector3(1.8, 0.05, 0.9), Vector3(0, 0.025, hz), stone, false)
	if prop_h(root, "large_castle_door", Vector3(-0.95, 0, hz - 0.1), 2.55, 118.0) == Vector3.ZERO:
		B3.box(root, Vector3(0.08, 2.5, 1.6), Vector3(-0.6, 1.25, hz - 0.8), timber, false)
	# Fenster: Süd (links/rechts der Tür), West und Ost
	for x in [-3.6, -6.8, 3.6, 6.8]:
		window(root, Vector3(x, 2.75, hz + 0.02), Vector3(0, 0, -1))
	for z in [-3.4, 3.4]:
		window(root, Vector3(-hx - 0.02, 2.75, z), Vector3(1, 0, 0), 1.1, 1.4, 2.4)
	window(root, Vector3(hx + 0.02, 2.75, -3.6), Vector3(-1, 0, 0), 1.1, 1.4, 2.4)

	# --- Empfang: Tresen, Regale, Bücher, Rangtafel -----------------------------------------------
	B3.box(root, Vector3(5.8, 1.0, 0.8), Vector3(0, 0.5, -4.2), planks_dark)
	B3.box(root, Vector3(6.1, 0.08, 1.0), Vector3(0, 1.04, -4.2), planks, false)
	B3.box(root, Vector3(6.1, 0.06, 0.08), Vector3(0, 0.6, -3.76), timber, false)
	prop(root, "book_encyclopedia_set_01", Vector3(-1.9, 1.08, -4.25), 12.0)
	prop_h(root, "brass_candleholders", Vector3(1.5, 1.08, -4.3), 0.42, 0.0)
	prop(root, "jug_01", Vector3(2.4, 1.08, -4.05), 30.0)
	prop(root, "metal_jug", Vector3(-2.6, 1.08, -4.1), -20.0)
	var bl := B3.light(root, Vector3(1.5, 1.6, -4.3), Color(1.0, 0.72, 0.4), 0.45, 3.0)
	bl.shadow_enabled = false
	bl.set_meta("flicker", true)
	prop_h(root, "GothicCabinet_01", Vector3(-2.5, 0, -hz + 0.45), 2.4, 0.0, true)
	prop_h(root, "GothicCabinet_01", Vector3(2.5, 0, -hz + 0.45), 2.4, 0.0, true)
	# Wappen der Gilde über dem Tresen
	B3.box(root, Vector3(2.4, 1.3, 0.06), Vector3(0, 3.45, -hz + 0.03), fabric, false)
	B3.box(root, Vector3(2.6, 0.08, 0.1), Vector3(0, 4.15, -hz + 0.05), brass, false)
	var emblem: Texture2D = Palette.icon("icon_emblem")
	if emblem:
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		B3.mesh(root, q, Vector3(0, 3.45, -hz + 0.07), B3.tex_mat(emblem, true, true))

	# --- Büro des Gildenmeisters (Nordost) ----------------------------------------------------------
	railing(root, Vector3(3.9, 0, -hz + 0.2), Vector3(3.9, 0, -3.0), timber)
	railing(root, Vector3(3.9, 0, -3.0), Vector3(5.4, 0, -3.0), timber)
	railing(root, Vector3(6.6, 0, -3.0), Vector3(hx - 0.2, 0, -3.0), timber)
	var desk := prop_h(root, "WoodenTable_03", Vector3(6.7, 0, -4.7), 0.8, 90.0, true)
	var desk_y := desk.y if desk != Vector3.ZERO else 0.78
	prop(root, "chess_set", Vector3(7.5, desk_y, -4.6), 15.0)
	prop(root, "book_encyclopedia_set_01", Vector3(6.0, desk_y, -4.8), -80.0)
	candle(root, Vector3(6.6, desk_y, -4.2))
	prop_h(root, "WoodenChair_01", Vector3(6.7, 0, -5.7), 1.0, 0.0, true)
	prop_h(root, "WoodenChair_01", Vector3(5.6, 0, -3.9), 1.0, 150.0, true)
	prop_h(root, "GothicCabinet_01", Vector3(hx - 0.5, 0, -5.0), 2.4, -90.0, true)
	prop_h(root, "kite_shield", Vector3(6.7, 2.4, -hz + 0.08), 1.0, 0.0)
	B3.box(root, Vector3(2.2, 0.02, 1.6), Vector3(6.7, 0.011, -4.4), B3.mat(Color(0.25, 0.2, 0.3), 0.95), false)

	# --- Auftragstafel und Lager (Nordwest) ---------------------------------------------------------
	var board := Vector3(-6.0, 0, -3.9)
	railing(root, Vector3(-3.9, 0, -hz + 0.2), Vector3(-3.9, 0, -4.9), timber, 0.9)
	prop_h(root, "wine_barrel_01", Vector3(-8.2, 0, -5.6), 0.95, 20.0, true)
	prop_h(root, "wine_barrel_01", Vector3(-7.15, 0, -5.9), 0.95, 95.0, true)
	prop_h(root, "barrel_03", Vector3(-8.3, 0, -4.4), 0.9, -30.0, true)
	var crate := prop_h(root, "wooden_crate_02", Vector3(-6.0, 0, -5.8), 0.6, 10.0, true)
	prop_h(root, "wooden_crate_01", Vector3(-6.0, crate.y, -5.8), 0.55, -14.0)
	prop_h(root, "wooden_crate_01", Vector3(-4.9, 0, -5.9), 0.55, 40.0, true)
	prop(root, "wicker_basket_02", Vector3(-7.3, 0, -4.7), 60.0)
	prop_h(root, "Lantern_01", Vector3(-4.9, 0.55, -5.9), 0.4, 20.0)
	var ll := B3.light(root, Vector3(-4.9, 1.1, -5.7), WARM, 0.7, 5.0)
	ll.shadow_enabled = false
	ll.set_meta("flicker", true)
	prop_h(root, "wooden_ladder", Vector3(-8.1, 0, -6.1), 3.6, 0.0)
	# Säcke mit Vorräten
	for i in 4:
		var p := Vector3(-8.4 + (i % 2) * 0.55, 0.0, -2.6 - (i / 2) * 0.5)
		B3.sphere(root, 0.3, p + Vector3(0, 0.26, 0), B3.mat(Color(0.5, 0.42, 0.3), 0.95), Vector3(1, 0.8, 1))
		B3.cyl(root, 0.06, 0.1, 0.14, p + Vector3(0, 0.52, 0), B3.mat(Color(0.42, 0.34, 0.24), 0.9), false, 8)

	# --- Trophäenwand (West) ------------------------------------------------------------------------
	prop_h(root, "kite_shield", Vector3(-hx + 0.08, 2.35, -0.9), 1.0, 90.0)
	prop_h(root, "kite_shield", Vector3(-hx + 0.08, 2.35, 1.5), 1.0, 90.0)
	var sw := PhProps.whole("antique_estoc")
	if not sw.is_empty():
		for s in [-1.0, 1.0]:
			var holder := Node3D.new()
			holder.position = Vector3(-hx + 0.1, 2.3, 0.3)
			holder.rotation_degrees = Vector3(0, 90, 55 * s)
			root.add_child(holder)
			PhProps.attach(holder, "antique_estoc", Transform3D(Basis(), Vector3(0, -(sw.size as Vector3).y * 0.5, 0)))
	B3.banner(root, Vector3(-hx + 0.12, 4.5, 3.6), Color(0.4, 0.08, 0.1), emblem, 2.4, 90.0)
	# (Das Lesepult mit der Gildenchronik kommt als Entdeckung aus data/discoveries.json.)

	# --- Schankstube: Tische, Stühle, Bänke -------------------------------------------------------
	var tables := [Vector3(-5.3, 0, 1.4), Vector3(5.1, 0, 1.9), Vector3(-4.6, 0, -1.7)]
	for i in tables.size():
		var t: Vector3 = tables[i]
		var ts := prop_h(root, "round_wooden_table_01", t, 0.76, rng.randf_range(0, 360), true)
		var ty := ts.y if ts != Vector3.ZERO else 0.76
		for k in 3:
			chair_at(root, t, 25.0 + k * 120.0 + rng.randf_range(-12, 12), 0.95)
		candle(root, t + Vector3(0.05, ty, 0.1))
		match i:
			0:
				prop(root, "brass_goblets", t + Vector3(-0.3, ty, -0.15), 20.0)
				prop(root, "wine_bottles_01", t + Vector3(0.28, ty, -0.2), 0.0)
				prop(root, "food_apple_01", t + Vector3(-0.1, ty, 0.3), 0.0)
			1:
				prop(root, "jug_01", t + Vector3(0.3, ty, 0.1), 60.0)
				prop(root, "carved_wooden_plate", t + Vector3(-0.3, ty, 0.2), 0.0)
				prop(root, "wooden_bowl_02", t + Vector3(-0.25, ty, -0.25), 0.0)
			2:
				prop(root, "chess_set", t + Vector3(-0.2, ty, -0.1), -35.0)
				prop(root, "brass_goblets", t + Vector3(0.3, ty, 0.2), 0.0)
	prop_h(root, "painted_wooden_bench", Vector3(-4.6, 0, hz - 0.45), 0.9, 0.0, true)
	prop_h(root, "painted_wooden_bench", Vector3(4.6, 0, hz - 0.45), 0.9, 0.0, true)
	prop(root, "wooden_stool_02", Vector3(7.0, 0, 1.3), 30.0, 1.0, true)
	prop(root, "folding_wooden_stool", Vector3(7.1, 0, 3.9), -40.0, 1.0, true)
	prop_h(root, "barrel_03", Vector3(2.3, 0, hz - 0.6), 0.85, 0.0, true)
	prop_h(root, "wooden_bucket_01", Vector3(3.0, 0, hz - 0.5), 0.3, 0.0)

	# --- Kamin an der Ostwand ---------------------------------------------------------------------
	var fx := hx
	var fz := 2.6
	B3.box(root, Vector3(0.7, 2.3, 2.6), Vector3(fx - 0.35, 1.15, fz), stone)
	B3.box(root, Vector3(0.8, 2.9, 1.7), Vector3(fx - 0.4, H - 1.45, fz), stone, false)
	B3.box(root, Vector3(0.9, 0.12, 2.9), Vector3(fx - 0.45, 2.3, fz), timber, false)
	B3.box(root, Vector3(0.6, 1.3, 1.5), Vector3(fx - 0.6, 0.7, fz), B3.mat(Color(0.06, 0.05, 0.05), 0.95), false)
	var logm := B3.mat(Color(0.2, 0.12, 0.06), 0.9)
	for k in 3:
		var lg := B3.cyl(root, 0.09, 0.09, 0.9, Vector3(fx - 0.55, 0.12 + k * 0.1, fz + (k - 1) * 0.22), logm, false, 8)
		lg.rotation_degrees = Vector3(0, 0, 90)
	B3.fire(root, Vector3(fx - 0.5, 0.3, fz), Color(1.0, 0.55, 0.2), 40)
	var fl := B3.light(root, Vector3(fx - 1.1, 1.1, fz), Color(1.0, 0.55, 0.25), 2.4, 9.0)
	fl.set_meta("flicker", true)
	B3.box(root, Vector3(1.8, 0.02, 2.4), Vector3(fx - 1.9, 0.012, fz), fabric, false)
	B3.motes(root, Vector3(fx - 0.6, 1.6, fz), Vector3(0.2, 0.6, 0.5), Color(1.0, 0.6, 0.25), 18)

	# --- Licht und Atmosphäre -----------------------------------------------------------------------
	for p in [Vector3(-4.5, 3.75, -1.45), Vector3(4.5, 3.75, -1.45), Vector3(0, 3.75, 1.45), Vector3(0, 3.75, -4.3)]:
		lantern(root, p, H - 0.34)
	B3.motes(root, Vector3(0, 2.4, 0), Vector3(8.5, 2.0, 5.8), Color(1.0, 0.92, 0.72, 0.5), 110)
	B3.bounds(root, hx + 0.3, H + 1.0)

	# --- Abenteurer als Gäste ----------------------------------------------------------------------
	var idle := [Vector3(-5.3, 0, -2.9), Vector3(-6.7, 0, -2.6), Vector3(-3.4, 0, 0.3), Vector3(4.0, 0, 3.4),
		Vector3(1.3, 0, -2.5), Vector3(7.6, 0, 0.6), Vector3(3.0, 0, 5.0)]
	Townsfolk.spawn(root, [], idle, 1771, 7, "adventurer")

	return {"spawn": Vector3(0, 0.2, 4.6), "yaw": 0.0, "board": board, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(0, 0, -5.25), Vector3(7.7, 0, -5.6), Vector3(2.4, 0, 2.6)]}


# =====================================================================
#  Gemeinsame Hülle: Boden, Wände mit Fachwerk, Decke, Tür nach Süden
# =====================================================================

## Raumhülle; Rückgabe: Dictionary mit den Materialien. Tür in der Südwand (+z), Breite 1.6 m.
static func shell(root: Node3D, W: float, D: float, H: float, wall_tint: Color, floor_tint: Color, door_w: float = 1.6) -> Dictionary:
	var hx := W * 0.5
	var hz := D * 0.5
	var m := {
		"planks": BuildingLook.photo_material("planks", "wood", floor_tint, 0.55),
		"planks_dark": BuildingLook.photo_material("planks", "wood", floor_tint.darkened(0.35), 0.6),
		"plaster": BuildingLook.photo_material("plaster", "plaster", wall_tint, 0.45),
		"timber": BuildingLook.photo_material("logs", "wood", Color(0.42, 0.33, 0.25), 0.5),
		"stone": BuildingLook.photo_material("rubble", "stone", Color(0.72, 0.7, 0.66), 0.6),
	}
	B3.box(root, Vector3(W + 0.8, 0.2, D + 0.8), Vector3(0, -0.1, 0), m.planks)
	B3.box(root, Vector3(0.4, H, D + 0.8), Vector3(-hx - 0.2, H * 0.5, 0), m.plaster)
	B3.box(root, Vector3(0.4, H, D + 0.8), Vector3(hx + 0.2, H * 0.5, 0), m.plaster)
	B3.box(root, Vector3(W + 0.8, H, 0.4), Vector3(0, H * 0.5, -hz - 0.2), m.plaster)
	var side := (W - door_w) * 0.5
	B3.box(root, Vector3(side + 0.4, H, 0.4), Vector3(-(door_w * 0.5 + side * 0.5) - 0.2, H * 0.5, hz + 0.2), m.plaster)
	B3.box(root, Vector3(side + 0.4, H, 0.4), Vector3((door_w * 0.5 + side * 0.5) + 0.2, H * 0.5, hz + 0.2), m.plaster)
	B3.box(root, Vector3(door_w, H - 2.5, 0.4), Vector3(0, 2.5 + (H - 2.5) * 0.5, hz + 0.2), m.plaster)
	B3.box(root, Vector3(W + 0.8, 0.24, D + 0.8), Vector3(0, H + 0.12, 0), m.planks_dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B3.box(root, Vector3(0.3, H, 0.3), Vector3(sx * (hx - 0.15), H * 0.5, sz * (hz - 0.15)), m.timber, false)
		B3.box(root, Vector3(0.18, 0.18, D), Vector3(sx * (hx - 0.09), 2.5, 0), m.timber, false)
		B3.box(root, Vector3(W, 0.18, 0.18), Vector3(0, 2.5, sx * (hz - 0.09)), m.timber, false)
	var nb := maxi(2, int(D / 2.8))
	for i in nb:
		var z := -hz + D * (i + 0.5) / nb
		B3.box(root, Vector3(W, 0.3, 0.3), Vector3(0, H - 0.15, z), m.timber, false)
	for sx in [-1.0, 1.0]:
		B3.box(root, Vector3(0.2, 2.6, 0.5), Vector3(sx * (door_w * 0.5 + 0.1), 1.3, hz + 0.2), m.timber, false)
	B3.box(root, Vector3(door_w + 0.5, 0.2, 0.5), Vector3(0, 2.6, hz + 0.2), m.timber, false)
	B3.box(root, Vector3(door_w, 0.05, 0.9), Vector3(0, 0.025, hz), m.stone, false)
	if prop_h(root, "large_castle_door", Vector3(-door_w * 0.5 - 0.1, 0, hz - 0.1), 2.45, 118.0) == Vector3.ZERO:
		B3.box(root, Vector3(0.08, 2.4, 1.4), Vector3(-door_w * 0.5, 1.2, hz - 0.7), m.timber, false)
	B3.bounds(root, hx + 0.3, H + 1.0)
	return m


# =====================================================================
#  Gasthaus (E-Rantel): Schankraum mit Tresen, Kamin, Empore und Gästen
# =====================================================================

static func tavern(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var W := 14.0
	var D := 11.0
	var H := 4.6
	var hx := W * 0.5
	var hz := D * 0.5
	var m := shell(root, W, D, H, Color(0.8, 0.72, 0.6), Color(0.66, 0.54, 0.4))
	var brass := B3.mat(Color(0.85, 0.66, 0.28), 0.3, 0.9)
	var fabric := B3.mat(Color(0.32, 0.12, 0.1), 0.95)
	# Fenster: Süd (links/rechts der Tür) und West
	for x in [-3.6, 3.6]:
		window(root, Vector3(x, 2.4, hz + 0.02), Vector3(0, 0, -1), 1.0, 1.2, 2.6)
	window(root, Vector3(-hx - 0.02, 2.4, 2.0), Vector3(1, 0, 0), 1.0, 1.2, 2.2)

	# --- Tresen entlang der Westwand, Fässer und Regal dahinter ---------------------------------------
	var bar_x := -hx + 2.2
	B3.box(root, Vector3(0.8, 1.05, 6.4), Vector3(bar_x, 0.525, -1.4), m.planks_dark)
	B3.box(root, Vector3(1.0, 0.08, 6.6), Vector3(bar_x, 1.09, -1.4), m.planks, false)
	B3.box(root, Vector3(0.08, 0.06, 6.6), Vector3(bar_x + 0.45, 0.62, -1.4), m.timber, false)
	prop_h(root, "wine_barrel_01", Vector3(-hx + 0.6, 0, -4.2), 0.95, 10.0, true)
	prop_h(root, "wine_barrel_01", Vector3(-hx + 0.6, 0, -3.1), 0.95, 80.0, true)
	prop_h(root, "barrel_03", Vector3(-hx + 0.6, 0, 0.4), 0.9, 30.0, true)
	# Regal mit Flaschen und Krügen
	for k in 3:
		var y := 1.3 + k * 0.6
		B3.box(root, Vector3(0.32, 0.04, 4.2), Vector3(-hx + 0.2, y, -1.5), m.planks_dark, false)
		for j in 5:
			var z := -3.4 + j * 0.95 + rng.randf_range(-0.15, 0.15)
			var p := Vector3(-hx + 0.2, y + 0.02, z)
			match (k + j) % 4:
				0: prop(root, "jug_01", p, rng.randf_range(0, 360))
				1: prop(root, "wine_bottles_01", p, 90.0 + rng.randf_range(-15, 15))
				2: prop(root, "metal_jug", p, rng.randf_range(0, 360))
				_: prop(root, "ceramic_vase_01", p, rng.randf_range(0, 360))
	# auf dem Tresen: Becher, Krug, Käse, Kerzen
	prop(root, "brass_goblets", Vector3(bar_x, 1.13, -3.6), 20.0)
	prop(root, "jug_01", Vector3(bar_x + 0.1, 1.13, -2.4), 70.0)
	prop(root, "CheeseBox_01", Vector3(bar_x - 0.1, 1.13, -1.2), 10.0)
	prop(root, "carved_wooden_plate", Vector3(bar_x, 1.13, 0.2), 0.0)
	prop(root, "wooden_bowl_02", Vector3(bar_x + 0.05, 1.17, 0.25), 0.0)
	candle(root, Vector3(bar_x - 0.15, 1.13, -0.5))
	candle(root, Vector3(bar_x + 0.1, 1.13, 1.3), "brass_candleholders")
	# Preistafel hinter dem Tresen
	B3.box(root, Vector3(0.06, 0.9, 1.3), Vector3(-hx + 0.05, 3.3, 1.6), B3.mat(Color(0.12, 0.1, 0.09), 0.9), false)
	B3.box(root, Vector3(0.08, 1.0, 1.4), Vector3(-hx + 0.04, 3.3, 1.6), m.timber, false)
	for k in 4:
		B3.box(root, Vector3(0.02, 0.05, rng.randf_range(0.5, 1.0)), Vector3(-hx + 0.09, 3.6 - k * 0.2, 1.6 + rng.randf_range(-0.1, 0.1)), B3.mat(Color(0.85, 0.82, 0.75), 0.9), false)

	# --- Kamin an der Ostwand ------------------------------------------------------------------------
	var fx := hx
	var fz := -1.0
	B3.box(root, Vector3(0.7, 2.2, 2.4), Vector3(fx - 0.35, 1.1, fz), m.stone)
	B3.box(root, Vector3(0.8, H - 2.2, 1.6), Vector3(fx - 0.4, 2.2 + (H - 2.2) * 0.5, fz), m.stone, false)
	B3.box(root, Vector3(0.9, 0.12, 2.7), Vector3(fx - 0.45, 2.2, fz), m.timber, false)
	B3.box(root, Vector3(0.6, 1.2, 1.4), Vector3(fx - 0.6, 0.65, fz), B3.mat(Color(0.06, 0.05, 0.05), 0.95), false)
	var logm := B3.mat(Color(0.2, 0.12, 0.06), 0.9)
	for k in 3:
		var lg := B3.cyl(root, 0.09, 0.09, 0.9, Vector3(fx - 0.55, 0.12 + k * 0.1, fz + (k - 1) * 0.22), logm, false, 8)
		lg.rotation_degrees = Vector3(0, 0, 90)
	B3.fire(root, Vector3(fx - 0.5, 0.3, fz), Color(1.0, 0.55, 0.2), 40)
	B3.light(root, Vector3(fx - 1.1, 1.1, fz), Color(1.0, 0.55, 0.25), 2.4, 9.0).set_meta("flicker", true)
	B3.box(root, Vector3(1.8, 0.02, 2.2), Vector3(fx - 1.8, 0.012, fz), fabric, false)
	prop_h(root, "kite_shield", Vector3(fx - 0.08, 3.2, fz), 1.0, -90.0)
	# Holzstapel neben dem Kamin
	for k in 6:
		var lg := B3.cyl(root, 0.08, 0.08, 0.8, Vector3(fx - 0.5, 0.08 + (k / 3) * 0.17, fz + 1.7 + (k % 3) * 0.18), logm, false, 7)
		lg.rotation_degrees = Vector3(0, 0, 90)

	# --- Tische und Gäste -----------------------------------------------------------------------------
	var tables := [Vector3(-2.0, 0, 2.2), Vector3(2.6, 0, 3.0), Vector3(2.4, 0, -3.4), Vector3(-2.2, 0, -3.6)]
	for i in tables.size():
		var t: Vector3 = tables[i]
		var ts := prop_h(root, "round_wooden_table_01", t, 0.76, rng.randf_range(0, 360), true)
		var ty := ts.y if ts != Vector3.ZERO else 0.76
		for k in 3:
			chair_at(root, t, 35.0 + k * 120.0 + rng.randf_range(-15, 15), 0.95)
		candle(root, t + Vector3(0.1, ty, -0.05))
		if i % 2 == 0:
			prop(root, "brass_goblets", t + Vector3(-0.3, ty, 0.15), rng.randf_range(0, 360))
			prop(root, "CheeseBox_01", t + Vector3(0.25, ty, 0.2), 0.0)
		else:
			prop(root, "jug_01", t + Vector3(0.3, ty, -0.2), 40.0)
			prop(root, "carved_wooden_plate", t + Vector3(-0.28, ty, 0.1), 0.0)
			prop(root, "food_apple_01", t + Vector3(-0.28, ty + 0.02, 0.1), 0.0)
	# lange Tafel mit Bänken in der Mitte
	var lt := prop_h(root, "WoodenTable_01", Vector3(0.3, 0, -0.6), 0.78, 0.0, true)
	var lty := lt.y if lt != Vector3.ZERO else 0.78
	prop_h(root, "painted_wooden_bench", Vector3(0.3, 0, 0.3), 0.5, 0.0, true)
	prop_h(root, "painted_wooden_bench", Vector3(0.3, 0, -1.5), 0.5, 180.0, true)
	prop(root, "wine_bottles_01", Vector3(-0.3, lty, -0.6), 0.0)
	prop(root, "brass_goblets", Vector3(0.6, lty, -0.5), 0.0)
	prop(root, "chess_set", Vector3(-0.1, lty, -0.7), 20.0)
	candle(root, Vector3(1.0, lty, -0.7))

	# --- Empore an der Nordwand mit Treppe im Osten ---------------------------------------------------
	var gy := 2.55
	var gd := 2.3
	B3.box(root, Vector3(W, 0.16, gd), Vector3(0, gy - 0.08, -hz + gd * 0.5), m.planks)
	B3.box(root, Vector3(W, 0.3, 0.3), Vector3(0, gy - 0.3, -hz + gd), m.timber, false)
	for x in [-5.0, -1.5, 2.0]:
		B3.box(root, Vector3(0.24, gy, 0.24), Vector3(x, gy * 0.5, -hz + gd), m.timber, false)
	railing(root, Vector3(-hx + 0.3, gy, -hz + gd), Vector3(hx - 2.6, gy, -hz + gd), m.timber, 1.0)
	# Treppe: 13 Stufen entlang der Ostwand von Süden (z=+2.0) nach Norden hinauf auf die Empore
	var steps := 13
	var sh := gy / steps
	var sd := 0.32
	for i in steps:
		B3.box(root, Vector3(1.4, sh * (i + 1), sd), Vector3(hx - 1.1, sh * (i + 1) * 0.5, 2.4 - i * sd), m.planks_dark)
	var a := Vector3(hx - 1.1, 0.02, 2.4 + sd * 0.5)
	var b := Vector3(hx - 1.1, gy + 0.02, 2.4 - (steps - 0.5) * sd)
	_slope(root, a, b, 1.4)
	railing(root, Vector3(hx - 1.85, 0, 2.6), Vector3(hx - 1.85, gy, -hz + gd + 0.2), m.timber, 1.0)
	# Zimmertüren oben (geschlossen), Gepäck, Laterne
	for x in [-4.5, -0.5, 3.5]:
		B3.box(root, Vector3(1.0, 2.0, 0.08), Vector3(x, gy + 1.0, -hz + 0.05), m.timber, false)
		B3.box(root, Vector3(0.08, 0.08, 0.1), Vector3(x + 0.35, gy + 0.95, -hz + 0.1), brass, false)
	prop_h(root, "wooden_crate_01", Vector3(1.8, gy, -hz + 0.5), 0.35, 20.0)
	prop(root, "wicker_basket_02", Vector3(-2.6, gy, -hz + 0.45), 70.0)
	lantern(root, Vector3(hx - 1.1, 3.9, -hz + 1.0), H - 0.3, 1.0)
	# Durchgang unter der Empore: Lagerraum mit Fässern (dunkel)
	prop_h(root, "barrel_03", Vector3(-4.2, 0, -hz + 0.6), 0.9, 0.0, true)
	prop_h(root, "wooden_crate_02", Vector3(-2.2, 0, -hz + 0.7), 0.5, 90.0, true)
	prop(root, "wooden_bucket_01", Vector3(-0.8, 0, -hz + 0.5), 0.0)

	# --- Licht, Staub, Gäste ---------------------------------------------------------------------------
	for p in [Vector3(-2.0, 3.5, 2.2), Vector3(2.6, 3.5, 3.0), Vector3(0.3, 3.5, -0.6), Vector3(2.4, 3.5, -3.4)]:
		lantern(root, p, H - 0.3)
	B3.motes(root, Vector3(0, 2.2, 0.5), Vector3(6.5, 1.8, 4.8), Color(1.0, 0.9, 0.7, 0.5), 90)
	Townsfolk.spawn(root, [], [Vector3(-2.9, 0, 1.6), Vector3(2.0, 0, 3.9), Vector3(1.6, 0, -4.2), Vector3(-1.2, 0, 0.6)], 311, 4)
	Townsfolk.spawn(root, [], [Vector3(3.4, 0, -2.6), Vector3(-3.0, 0, -2.9), Vector3(5.2, 0, 1.2)], 312, 3, "adventurer")

	return {"spawn": Vector3(0, 0.2, 3.8), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(bar_x - 1.0, 0, -1.4), Vector3(4.6, 0, 3.6), Vector3(-0.5, 0, 2.0)]}


## Unsichtbare Rampe von a nach b (glattes Treppensteigen).
static func _slope(parent: Node3D, a: Vector3, b: Vector3, w: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 0.12, a.distance_to(b))
	cs.shape = box
	body.add_child(cs)
	parent.add_child(body)
	body.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)


# =====================================================================
#  Apotheke Bareare (E-Rantel): Lizzies Laden mit Werkstatt und Hinterzimmer
# =====================================================================

static func shop(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 515
	var W := 9.0
	var D := 8.0
	var H := 3.6
	var hx := W * 0.5
	var hz := D * 0.5
	var m := shell(root, W, D, H, Color(0.74, 0.76, 0.66), Color(0.6, 0.5, 0.38))
	var green := Color(0.55, 0.9, 0.5)
	for x in [-2.6, 2.6]:
		window(root, Vector3(x, 2.1, hz + 0.02), Vector3(0, 0, -1), 0.9, 1.1, 2.4)
	window(root, Vector3(hx + 0.02, 2.1, 1.0), Vector3(-1, 0, 0), 0.9, 1.1, 2.0)

	# --- Ladentresen quer durch den Raum, Lizzie dahinter ----------------------------------------------
	B3.box(root, Vector3(4.6, 1.0, 0.7), Vector3(-0.6, 0.5, -0.6), m.planks_dark)
	B3.box(root, Vector3(4.8, 0.07, 0.9), Vector3(-0.6, 1.035, -0.6), m.planks, false)
	# Waage, Mörser, Rezeptbuch, Kasse, Krüge auf dem Tresen
	var brass := B3.mat(Color(0.85, 0.66, 0.28), 0.3, 0.9)
	B3.cyl(root, 0.02, 0.02, 0.5, Vector3(-2.2, 1.32, -0.6), brass, false, 6)
	B3.box(root, Vector3(0.5, 0.015, 0.015), Vector3(-2.2, 1.55, -0.6), brass, false)
	for s in [-1.0, 1.0]:
		B3.cyl(root, 0.09, 0.09, 0.012, Vector3(-2.2 + 0.24 * s, 1.36 + 0.04 * s, -0.6), brass, false, 10)
		B3.cyl(root, 0.003, 0.003, 0.18, Vector3(-2.2 + 0.24 * s, 1.46 + 0.04 * s, -0.6), brass, false, 4)
	prop(root, "wooden_bowl_01", Vector3(-1.2, 1.07, -0.55), 0.0)
	prop(root, "book_encyclopedia_set_01", Vector3(0.2, 1.07, -0.7), 95.0)
	prop(root, "jug_01", Vector3(1.0, 1.07, -0.5), 30.0)
	prop(root, "ceramic_vase_01", Vector3(1.35, 1.07, -0.75), 0.0)
	candle(root, Vector3(-0.3, 1.07, -0.45))
	# Kräuterbündel an der Decke (getrocknet, kopfüber)
	var twine := B3.mat(Color(0.45, 0.38, 0.28), 0.95)
	for i in 7:
		var p := Vector3(-3.6 + i * 1.15, H - 0.3, -1.9)
		B3.cyl(root, 0.01, 0.01, 0.35, p - Vector3(0, 0.17, 0), twine, false, 4)
		var hold := Node3D.new()
		hold.position = p - Vector3(0, 0.36, 0)
		hold.rotation_degrees = Vector3(180, rng.randf_range(0, 360), 0)
		root.add_child(hold)
		var herb: String = ["nettle_plant", "shrub_sorrel_01", "periwinkle_plant", "weed_plant_02"][i % 4]
		var size := prop_h(hold, herb, Vector3.ZERO, 0.5)
		if size == Vector3.ZERO:
			B3.box(hold, Vector3(0.14, 0.4, 0.14), Vector3(0, 0.2, 0), B3.mat(Color(0.3, 0.38, 0.18), 0.9), false)

	# --- Regale an der Westwand: Flaschen, Krüge, leuchtende Tränke ----------------------------------
	for k in 4:
		var y := 0.8 + k * 0.62
		B3.box(root, Vector3(0.34, 0.04, 5.4), Vector3(-hx + 0.22, y, -0.4), m.planks_dark, false)
		for j in 7:
			var z := -2.9 + j * 0.8 + rng.randf_range(-0.12, 0.12)
			var p := Vector3(-hx + 0.22, y + 0.02, z)
			match (k * 3 + j) % 5:
				0: prop(root, "jug_01", p, rng.randf_range(0, 360))
				1: prop(root, "ceramic_vase_01", p, rng.randf_range(0, 360))
				2: prop(root, "metal_jug", p, rng.randf_range(0, 360))
				3: prop(root, "wine_bottles_01", p, 90.0)
				_:
					var col: Color = [Color(0.3, 1.0, 0.5), Color(0.5, 0.6, 1.0), Color(1.0, 0.4, 0.5), Color(1.0, 0.85, 0.3)][(k + j) % 4]
					B3.cyl(root, 0.05, 0.06, 0.18, p + Vector3(0, 0.09, 0), B3.mat(col, 0.15, 0.0, col, 1.6), false, 10)
					B3.cyl(root, 0.02, 0.025, 0.06, p + Vector3(0, 0.21, 0), B3.mat(Color(0.35, 0.25, 0.15), 0.8), false, 8)
	B3.box(root, Vector3(0.36, 3.4, 0.08), Vector3(-hx + 0.22, 1.9, -3.15), m.timber, false)
	B3.box(root, Vector3(0.36, 3.4, 0.08), Vector3(-hx + 0.22, 1.9, 2.35), m.timber, false)
	var gl := B3.light(root, Vector3(-hx + 0.8, 1.9, -0.4), Color(0.6, 1.0, 0.7), 0.6, 4.0)
	gl.shadow_enabled = false

	# --- Werkstatt (Nordost): Kessel über dem Feuer, Arbeitstisch, Nfireas Platz -------------------------
	var cx := hx - 1.1
	var cz := -hz + 1.0
	B3.cyl(root, 0.55, 0.6, 0.5, Vector3(cx, 0.25, cz), m.stone, true, 12)
	B3.fire(root, Vector3(cx, 0.5, cz), Color(1.0, 0.6, 0.25), 22)
	var pot := prop_h(root, "brass_pot_01", Vector3(cx, 0.55, cz), 0.5)
	B3.cyl(root, 0.26, 0.26, 0.02, Vector3(cx, 0.55 + (pot.y if pot != Vector3.ZERO else 0.45) - 0.04, cz), B3.mat(green, 0.2, 0.0, green, 2.5), false, 14)
	B3.motes(root, Vector3(cx, 1.4, cz), Vector3(0.25, 0.5, 0.25), green, 24)
	var cl := B3.light(root, Vector3(cx, 1.3, cz), Color(0.6, 1.0, 0.6), 1.0, 4.5)
	cl.set_meta("flicker", true)
	var wt := prop_h(root, "WoodenTable_01", Vector3(1.6, 0, -hz + 0.75), 0.78, 0.0, true)
	var wty := wt.y if wt != Vector3.ZERO else 0.78
	prop(root, "wooden_cutting_board", Vector3(0.9, wty, -hz + 0.7), 10.0)
	prop(root, "wooden_bowl_02", Vector3(1.5, wty, -hz + 0.8), 0.0)
	prop(root, "hatchet", Vector3(1.0, wty + 0.02, -hz + 0.95), 60.0)
	prop(root, "book_encyclopedia_set_01", Vector3(2.3, wty, -hz + 0.7), -10.0)
	candle(root, Vector3(2.1, wty, -hz + 1.05), "brass_candleholders")
	prop_h(root, "WoodenChair_01", Vector3(1.6, 0, -hz + 1.6), 1.0, 180.0, true)
	B3.light(root, Vector3(1.6, 2.6, -hz + 1.0), WARM, 0.9, 5.0).set_meta("flicker", true)

	# --- Hinterzimmer (Nordwest) hinter einem Vorhang: Bett, Truhe, Vorräte --------------------------------
	var curtain := B3.mat(Color(0.3, 0.26, 0.2), 0.95)
	B3.box(root, Vector3(0.05, 2.4, 2.0), Vector3(-1.9, 1.2, -hz + 1.2), curtain, false)
	B3.box(root, Vector3(0.04, 0.04, 2.1), Vector3(-1.9, 2.45, -hz + 1.2), B3.mat(Color(0.2, 0.15, 0.1), 0.6), false)
	B3.box(root, Vector3(1.0, 0.45, 2.0), Vector3(-hx + 0.95, 0.225, -hz + 1.1), m.planks_dark)
	B3.box(root, Vector3(0.96, 0.18, 1.9), Vector3(-hx + 0.95, 0.54, -hz + 1.1), B3.mat(Color(0.75, 0.7, 0.6), 0.95), false)
	B3.box(root, Vector3(0.5, 0.12, 0.35), Vector3(-hx + 0.95, 0.69, -hz + 0.35), B3.mat(Color(0.85, 0.82, 0.74), 0.95), false)
	B3.box(root, Vector3(0.96, 0.08, 1.2), Vector3(-hx + 0.95, 0.67, -hz + 1.45), B3.mat(Color(0.35, 0.2, 0.18), 0.95), false)
	prop_h(root, "wooden_crate_02", Vector3(-2.8, 0, -hz + 0.65), 0.55, 0.0, true)
	prop(root, "wicker_basket_01", Vector3(-3.4, 0, -hz + 2.0), 30.0)
	prop_h(root, "Lantern_01", Vector3(-2.75, 0.55, -hz + 0.7), 0.35, 0.0)
	B3.light(root, Vector3(-2.75, 1.0, -hz + 0.9), WARM, 0.5, 4.0).set_meta("flicker", true)

	# --- Kisten mit Kräutern am Eingang, Laternen -------------------------------------------------------
	prop_h(root, "wooden_crate_01", Vector3(-3.6, 0, 2.6), 0.4, 15.0, true)
	prop(root, "wicker_basket_02", Vector3(-3.5, 0.4, 2.6), 0.0)
	prop(root, "sweet_potato", Vector3(-3.3, 0.6, 2.5), 0.0)
	prop(root, "yellow_onion", Vector3(-3.7, 0.6, 2.7), 0.0)
	prop_h(root, "barrel_03", Vector3(3.6, 0, 2.6), 0.85, 0.0, true)
	for p in [Vector3(-1.5, 2.9, 1.2), Vector3(2.2, 2.9, 0.4)]:
		lantern(root, p, H - 0.3, 1.1)
	B3.motes(root, Vector3(0, 1.8, 0), Vector3(4.0, 1.4, 3.6), Color(1.0, 0.95, 0.75, 0.5), 60)

	return {"spawn": Vector3(0, 0.2, 2.6), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(-0.6, 0, -1.6), Vector3(2.6, 0, 0.8)]}


# =====================================================================
#  Enris Haus (Carne): Bauernstube mit Herd, Tisch, zwei Betten, Goblin-Horn und Nemus Zeichnungen
# =====================================================================

static func cottage(root: Node3D, _loc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 171
	var W := 8.0
	var D := 6.5
	var H := 3.2
	var hx := W * 0.5
	var hz := D * 0.5
	var m := shell(root, W, D, H, Color(0.8, 0.74, 0.62), Color(0.58, 0.47, 0.35), 1.3)
	var linen := B3.mat(Color(0.8, 0.76, 0.66), 0.95)
	var wool := B3.mat(Color(0.45, 0.28, 0.2), 0.95)
	window(root, Vector3(-2.4, 1.9, hz + 0.02), Vector3(0, 0, -1), 0.9, 1.0, 2.2)
	window(root, Vector3(hx + 0.02, 1.9, -0.8), Vector3(-1, 0, 0), 0.9, 1.0, 2.0)

	# --- Herd an der Nordwand: Steinkamin, Kochtopf, Feuerholz ----------------------------------------
	var cx := -1.8
	B3.box(root, Vector3(2.0, 2.0, 0.7), Vector3(cx, 1.0, -hz + 0.35), m.stone)
	B3.box(root, Vector3(1.0, H - 2.0, 0.6), Vector3(cx, 2.0 + (H - 2.0) * 0.5, -hz + 0.3), m.stone, false)
	B3.box(root, Vector3(2.2, 0.1, 0.9), Vector3(cx, 2.0, -hz + 0.45), m.timber, false)
	B3.box(root, Vector3(1.2, 1.1, 0.5), Vector3(cx, 0.6, -hz + 0.55), B3.mat(Color(0.06, 0.05, 0.05), 0.95), false)
	var logm := B3.mat(Color(0.2, 0.12, 0.06), 0.9)
	for k in 2:
		var lg := B3.cyl(root, 0.08, 0.08, 0.7, Vector3(cx, 0.12 + k * 0.1, -hz + 0.6), logm, false, 8)
		lg.rotation_degrees = Vector3(0, 0, 90)
	B3.fire(root, Vector3(cx, 0.28, -hz + 0.6), Color(1.0, 0.55, 0.2), 26)
	B3.light(root, Vector3(cx, 1.0, -hz + 1.2), Color(1.0, 0.55, 0.25), 1.8, 7.0).set_meta("flicker", true)
	var pot := prop_h(root, "brass_pot_01", Vector3(cx + 0.1, 0.0, -hz + 0.62), 0.38)
	if pot == Vector3.ZERO:
		B3.cyl(root, 0.2, 0.17, 0.26, Vector3(cx, 0.13, -hz + 0.62), B3.mat(Color(0.25, 0.22, 0.2), 0.4, 0.6), false, 12)
	B3.motes(root, Vector3(cx, 1.6, -hz + 0.6), Vector3(0.2, 0.4, 0.2), Color(0.5, 0.5, 0.5, 0.4), 10)
	for k in 5:
		var lg := B3.cyl(root, 0.07, 0.07, 0.6, Vector3(cx + 1.5, 0.07 + (k / 3) * 0.15, -hz + 0.4 + (k % 3) * 0.16), logm, false, 7)
		lg.rotation_degrees = Vector3(0, 0, 90)
	# Regalbrett mit Geschirr und Krügen
	B3.box(root, Vector3(0.28, 0.04, 2.0), Vector3(hx - 0.16, 1.5, -hz + 1.4), m.planks_dark, false)
	prop(root, "wooden_bowl_01", Vector3(hx - 0.16, 1.52, -hz + 0.7), 0.0)
	prop(root, "carved_wooden_plate", Vector3(hx - 0.16, 1.52, -hz + 1.2), 0.0)
	prop(root, "jug_01", Vector3(hx - 0.16, 1.52, -hz + 1.7), 40.0)
	prop(root, "wooden_bowl_02", Vector3(hx - 0.16, 1.52, -hz + 2.15), 0.0)
	B3.box(root, Vector3(0.28, 0.04, 2.0), Vector3(hx - 0.16, 2.1, -hz + 1.4), m.planks_dark, false)
	prop(root, "wicker_basket_02", Vector3(hx - 0.16, 2.12, -hz + 0.9), 20.0)
	prop(root, "ceramic_vase_01", Vector3(hx - 0.16, 2.12, -hz + 1.8), 0.0)

	# --- Tisch mit Hockern, Essen, Kerze --------------------------------------------------------------
	var t := Vector3(0.9, 0, 0.2)
	var ts := prop_h(root, "WoodenTable_03", t, 0.76, 90.0, true)
	var ty := ts.y if ts != Vector3.ZERO else 0.76
	prop_h(root, "wooden_stool_01", t + Vector3(-0.9, 0, 0.0), 0.44, 0.0, true)
	prop_h(root, "wooden_stool_01", t + Vector3(0.9, 0, 0.1), 0.44, 30.0, true)
	prop_h(root, "folding_wooden_stool", t + Vector3(0.1, 0, 0.9), 0.42, 180.0, true)
	prop(root, "wooden_cutting_board", t + Vector3(-0.2, ty, -0.1), 15.0)
	prop(root, "yellow_onion", t + Vector3(-0.2, ty + 0.03, -0.1), 0.0)
	prop(root, "sweet_potato", t + Vector3(0.05, ty + 0.02, -0.15), 0.0)
	prop(root, "carved_wooden_plate", t + Vector3(0.35, ty, 0.15), 0.0)
	prop(root, "food_apple_01", t + Vector3(0.35, ty + 0.02, 0.15), 0.0)
	prop(root, "jug_01", t + Vector3(0.0, ty, 0.25), 60.0)
	candle(root, t + Vector3(-0.45, ty, 0.2))

	# --- Betten (Enri, Nemu) an der Westwand, Truhe, Bastkorb mit Kräutern -----------------------------
	for i in 2:
		var bz := -1.6 + i * 2.2
		var len := 2.0 if i == 0 else 1.6
		B3.box(root, Vector3(1.0, 0.4, len), Vector3(-hx + 0.75, 0.2, bz), m.planks_dark)
		B3.box(root, Vector3(0.96, 0.16, len - 0.1), Vector3(-hx + 0.75, 0.48, bz), linen, false)
		B3.box(root, Vector3(0.5, 0.1, 0.32), Vector3(-hx + 0.75, 0.61, bz - len * 0.5 + 0.25), B3.mat(Color(0.88, 0.85, 0.78), 0.95), false)
		B3.box(root, Vector3(0.96, 0.08, len * 0.55), Vector3(-hx + 0.75, 0.6, bz + len * 0.2), wool, false)
		B3.box(root, Vector3(1.0, 0.7, 0.06), Vector3(-hx + 0.75, 0.55, bz - len * 0.5 - 0.03), m.planks_dark, false)
	prop_h(root, "treasure_chest", Vector3(-hx + 0.7, 0, 2.6), 0.5, 90.0, true)
	prop(root, "wicker_basket_01", Vector3(-1.4, 0, -hz + 0.6), 20.0)
	var twine := B3.mat(Color(0.45, 0.38, 0.28), 0.95)
	for i in 3:
		var p := Vector3(-0.2 + i * 0.5, H - 0.3, -hz + 0.9)
		B3.cyl(root, 0.01, 0.01, 0.3, p - Vector3(0, 0.15, 0), twine, false, 4)
		var hold := Node3D.new()
		hold.position = p - Vector3(0, 0.3, 0)
		hold.rotation_degrees = Vector3(180, rng.randf_range(0, 360), 0)
		root.add_child(hold)
		if prop_h(hold, ["nettle_plant", "shrub_sorrel_01", "periwinkle_plant"][i], Vector3.ZERO, 0.4) == Vector3.ZERO:
			B3.box(hold, Vector3(0.12, 0.35, 0.12), Vector3(0, 0.17, 0), B3.mat(Color(0.3, 0.38, 0.18), 0.9), false)

	# --- Das Horn des Goblin-Generals an der Wand, Nemus Zeichnungen, Werkzeug ----------------------------
	var horn := B3.mat(Color(0.85, 0.78, 0.62), 0.5)
	var h0 := Vector3(2.6, 2.1, -hz + 0.12)
	for k in 6:
		var tt := float(k) / 6.0
		var seg := B3.cyl(root, 0.1 - tt * 0.07, 0.11 - tt * 0.07, 0.17, h0 + Vector3(tt * 0.5, tt * tt * 0.3, 0), horn, false, 8)
		seg.rotation_degrees = Vector3(0, 0, -70 - tt * 40)
	B3.box(root, Vector3(0.06, 0.06, 0.1), h0 + Vector3(0.2, -0.1, 0), B3.mat(Color(0.2, 0.18, 0.16), 0.5, 0.6), false)
	B3.box(root, Vector3(0.9, 0.18, 0.03), h0 + Vector3(0.2, -0.4, 0.01), m.planks_dark, false)
	var paper := B3.mat(Color(0.88, 0.84, 0.72), 0.95)
	for k in 3:
		var pg := B3.box(root, Vector3(0.32, 0.4, 0.012), Vector3(1.2 + k * 0.45, 1.5 + (k % 2) * 0.12, hz - 0.02), paper, false)
		pg.rotation_degrees.z = rng.randf_range(-6, 6)
		B3.box(root, Vector3(0.04, 0.04, 0.03), pg.position + Vector3(0, 0.2, -0.01), B3.mat(Color(0.5, 0.1, 0.1), 0.5), false)
	prop_h(root, "wooden_broom", Vector3(hx - 0.3, 0, hz - 0.5), 1.4, 20.0)
	prop_h(root, "wooden_bucket_01", Vector3(hx - 0.5, 0, hz - 1.1), 0.35, 0.0)
	prop_h(root, "wooden_axe", Vector3(cx + 1.9, 0, -hz + 0.25), 0.6, 0.0)
	prop(root, "wooden_crate_02", Vector3(2.8, 0, -hz + 0.7), 0.0, 0.55, true)

	# --- Licht --------------------------------------------------------------------------------------------
	lantern(root, Vector3(0.9, 2.55, 0.2), H - 0.3, 0.9)
	B3.motes(root, Vector3(0, 1.6, 0), Vector3(3.6, 1.2, 2.8), Color(1.0, 0.95, 0.75, 0.5), 40)

	return {"spawn": Vector3(0, 0.2, 2.2), "yaw": 0.0, "exit": Vector3(0, 0, hz - 0.5),
		"slots": [Vector3(-2.2, 0, 1.2), Vector3(2.4, 0, 1.6)]}

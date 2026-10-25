class_name ProcModel
## Prozedurale Ersatzfiguren mit Gelenken (für CharacterRig), solange keine .glb-Modelle
## vorliegen: Ainz (Robe + Stab), Momon (schwarze Rüstung + zwei Großschwerter) und
## Gegner (Skelett, Todesritter, Ritter, Wolf, Engel, Golem).
## Aufbau: body (Hüfte, Drehpunkt) → torso → arm_r/arm_l (Schultergelenke), leg_l/leg_r.

const HIP := 0.95
## Menschen (Bewohner, Ritter, Händler) sind 1,6–1,85 m groß – nicht 2,1 m wie Ainz. Die Figurenmaße in
## data/figures.json („scale“) bleiben relativ dazu; Ainz, Wächter mit Modell und Sonderformen sind unberührt.
const HUMAN := 0.84
const VLook := preload("res://scripts/world3d/villager_look.gd")


static func _skeleton(r: CharacterRig, scale: float = 1.0) -> Dictionary:
	var body := Node3D.new()
	body.name = "body"
	body.position.y = HIP * scale
	r.add_child(body)
	r.body_base = HIP * scale
	var torso := Node3D.new()
	torso.name = "torso"
	body.add_child(torso)
	var arm_r := Node3D.new()
	arm_r.position = Vector3(-0.36, 0.6, 0) * scale
	torso.add_child(arm_r)
	var arm_l := Node3D.new()
	arm_l.position = Vector3(0.36, 0.6, 0) * scale
	torso.add_child(arm_l)
	var leg_r := Node3D.new()
	leg_r.position = Vector3(-0.14, 0, 0) * scale
	body.add_child(leg_r)
	var leg_l := Node3D.new()
	leg_l.position = Vector3(0.14, 0, 0) * scale
	body.add_child(leg_l)
	r.parts = {"body": body, "torso": torso, "arm_r": arm_r, "arm_l": arm_l, "leg_r": leg_r, "leg_l": leg_l}
	return r.parts


## Markiert die Kopfposition (für Portrait-Ausschnitt und Blickrichtung).
static func _mark_head(r: CharacterRig, parent: Node3D, pos: Vector3) -> void:
	var h := Node3D.new()
	h.position = pos
	parent.add_child(h)
	r.parts["head"] = h


static func _limb(parent: Node3D, length: float, thick: float, m: Material) -> void:
	B3.cyl(parent, thick, thick * 0.85, length, Vector3(0, -length / 2.0, 0), m, false, 8)


# =====================================================================
#  Ainz & Momon
# =====================================================================

static func ainz(r: CharacterRig) -> void:
	var p := _skeleton(r)
	var robe_m := B3.mat(Color(0.05, 0.03, 0.07), 0.75, 0.1)
	var trim := B3.mat(Color(0.85, 0.66, 0.22), 0.3, 0.9)
	var violet := B3.mat(Color(0.22, 0.07, 0.32), 0.5, 0.2, Color(0.3, 0.05, 0.5), 0.3)
	var bone := B3.mat(Color(0.88, 0.85, 0.76), 0.6)
	var red := B3.mat(Color(1, 0.15, 0.1), 1.0, 0.0, Color(1, 0.1, 0.05), 6.0)
	var body: Node3D = p.body
	var torso: Node3D = p.torso
	# Robe hängt am Körper (verdeckt die Beine)
	B3.cyl(body, 0.3, 0.62, 1.55, Vector3(0, -0.17, 0), robe_m, false, 18)
	B3.cyl(body, 0.6, 0.63, 0.12, Vector3(0, -0.81, 0), violet, false, 18)
	B3.box(body, Vector3(0.12, 1.45, 0.05), Vector3(0, -0.15, 0.47), trim, false, Vector3(-11, 0, 0))
	B3.box(torso, Vector3(0.9, 1.6, 0.06), Vector3(0, 0.0, -0.42), robe_m, false, Vector3(12, 0, 0))
	# Schultern, Kragen, Schädel
	for s in [-1.0, 1.0]:
		B3.sphere(torso, 0.24, Vector3(0.36 * s, 0.6, 0), robe_m, Vector3(1.2, 0.8, 1.1))
		B3.cone(torso, 0.05, 0.35, Vector3(0.42 * s, 0.73, 0), trim).rotation_degrees.z = -25.0 * s
	B3.cyl(torso, 0.3, 0.22, 0.26, Vector3(0, 0.78, -0.1), violet, false, 14)
	B3.sphere(torso, 0.19, Vector3(0, 1.03, 0.02), bone, Vector3(0.95, 1.05, 1.0))
	B3.sphere(torso, 0.12, Vector3(0, 0.91, 0.08), bone, Vector3(0.9, 0.7, 1.0))
	for s in [-1.0, 1.0]:
		B3.sphere(torso, 0.035, Vector3(0.07 * s, 1.04, 0.17), red)
	B3.sphere(torso, 0.26, Vector3(0, 1.05, -0.08), robe_m, Vector3(1.05, 1.1, 1.0))
	_mark_head(r, torso, Vector3(0, 1.03, 0))
	B3.sphere(torso, 0.08, Vector3(0, 0.5, 0.27), B3.mat(Color(0.9, 0.05, 0.1), 0.1, 0.3, Color(1, 0, 0.1), 3.0))
	var eye := B3.light(torso, Vector3(0, 1.05, 0.3), Color(1, 0.15, 0.1), 0.8, 2.5)
	eye.shadow_enabled = false
	# Arme (Ärmel + Knochenhand); rechts der Stab von Ainz Ooal Gown
	for arm in [p.arm_r, p.arm_l]:
		B3.cyl(arm, 0.07, 0.11, 0.72, Vector3(0, -0.36, 0), robe_m, false, 8)
		B3.sphere(arm, 0.07, Vector3(0, -0.78, 0.04), bone)
	var staff := Node3D.new()
	staff.name = "staff"
	staff.position = Vector3(0, -0.78, 0.06)
	p.arm_r.add_child(staff)
	B3.cyl(staff, 0.03, 0.03, 2.0, Vector3(0, 0.2, 0), trim, false, 8)
	var cols := [Color(1, 0.2, 0.2), Color(0.3, 0.6, 1), Color(0.3, 1, 0.4), Color(1, 0.9, 0.3), Color(0.8, 0.3, 1), Color(1, 0.5, 0.1), Color(0.9, 0.9, 1)]
	for i in cols.size():
		var a := TAU * i / cols.size()
		B3.sphere(staff, 0.05, Vector3(cos(a) * 0.17, 1.25, sin(a) * 0.17), B3.mat(cols[i], 0.1, 0.2, cols[i], 3.0))
	B3.light(staff, Vector3(0, 1.25, 0), Color(0.7, 0.5, 1.0), 1.0, 3.5)
	r.parts["staff_tip"] = staff
	B3.motes(body, Vector3(0, -0.3, 0), Vector3(0.6, 0.5, 0.6), Color(0.5, 0.15, 0.8), 14)


static func momon(r: CharacterRig) -> void:
	var p := _skeleton(r, 1.05)
	var plate := B3.mat(Color(0.1, 0.1, 0.12), 0.35, 0.6)
	var gold := B3.mat(Color(0.75, 0.6, 0.25), 0.3, 0.9)
	var cape := B3.mat(Color(0.35, 0.03, 0.05), 0.9)
	var body: Node3D = p.body
	var torso: Node3D = p.torso
	B3.box(body, Vector3(0.6, 0.35, 0.36), Vector3(0, 0.05, 0), plate, false)
	B3.box(torso, Vector3(0.72, 0.62, 0.42), Vector3(0, 0.42, 0), plate, false)
	B3.box(torso, Vector3(0.3, 0.4, 0.05), Vector3(0, 0.45, 0.22), gold, false)
	B3.box(torso, Vector3(0.95, 1.7, 0.05), Vector3(0, -0.2, -0.26), cape, false, Vector3(10, 0, 0))
	# Helm mit Hörnern und Sehschlitz
	B3.box(torso, Vector3(0.34, 0.4, 0.36), Vector3(0, 0.98, 0), plate, false)
	_mark_head(r, torso, Vector3(0, 0.98, 0))
	B3.box(torso, Vector3(0.26, 0.04, 0.02), Vector3(0, 1.0, 0.185), B3.mat(Color(1, 0.2, 0.1), 1, 0, Color(1, 0.1, 0.05), 3), false)
	for s in [-1.0, 1.0]:
		var horn := B3.cone(torso, 0.05, 0.4, Vector3(0.16 * s, 1.1, 0), gold)
		horn.rotation_degrees.z = -35.0 * s
		B3.sphere(torso, 0.2, Vector3(0.4 * s, 0.68, 0), plate, Vector3(1.2, 0.9, 1.1))
	for leg in [p.leg_l, p.leg_r]:
		_limb(leg, 0.95, 0.12, plate)
		B3.box(leg, Vector3(0.18, 0.12, 0.3), Vector3(0, -0.95, 0.06), plate, false)
	# Zwei Großschwerter
	for arm in [p.arm_r, p.arm_l]:
		_limb(arm, 0.7, 0.1, plate)
		var sword := Node3D.new()
		sword.position = Vector3(0, -0.72, 0.05)
		sword.rotation_degrees.x = 90
		arm.add_child(sword)
		B3.box(sword, Vector3(0.12, 1.5, 0.03), Vector3(0, 0.85, 0), B3.mat(Color(0.75, 0.75, 0.8), 0.15, 1.0), false)
		B3.box(sword, Vector3(0.4, 0.06, 0.08), Vector3(0, 0.08, 0), gold, false)
		B3.cyl(sword, 0.035, 0.035, 0.3, Vector3(0, -0.08, 0), B3.mat(Color(0.15, 0.08, 0.05)), false, 6)


# =====================================================================
#  Gegner
# =====================================================================

static func enemy(r: CharacterRig, kind: String, color: Color, weapon: String = "") -> void:
	match kind:
		"wolf": _wolf(r, color)
		"golem": _golem(r, color)
		_: _humanoid(r, kind, color, weapon)


## Bogen: gebogener Holzstab aus Segmenten mit Sehne (Griff im Ursprung, Bogen entlang Y).
static func bow(col: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "bow"
	var wood := B3.mat(Color(0.34, 0.22, 0.12).lerp(col.darkened(0.5), 0.25), 0.7)
	var pts: Array = []
	for i in 9:
		var a := deg_to_rad(-58.0 + 116.0 * i / 8.0)
		pts.append(Vector3(0, sin(a) * 0.7, -cos(a) * 0.7 + 0.7))
	for i in 8:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := B3.cyl(n, 0.018 if i in [0, 7] else 0.026, 0.026 if i in [0, 7] else 0.03, a.distance_to(b), (a + b) * 0.5, wood, false, 6)
		seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	var string := B3.cyl(n, 0.004, 0.004, (pts[0] as Vector3).distance_to(pts[8]), ((pts[0] as Vector3) + pts[8]) * 0.5, B3.mat(Color(0.85, 0.82, 0.72), 0.9), false, 4)
	string.basis = Basis(Quaternion(Vector3.UP, ((pts[8] as Vector3) - pts[0]).normalized()))
	B3.box(n, Vector3(0.05, 0.12, 0.05), Vector3.ZERO, B3.mat(Color(0.25, 0.15, 0.08), 0.8), false)
	return n


## Zauberstab mit leuchtender Kugel (Priester, Leichname, Magier).
static func staff(col: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "staff"
	B3.cyl(n, 0.025, 0.03, 1.7, Vector3(0, 0.35, 0), B3.mat(Color(0.25, 0.18, 0.12), 0.7), false, 6)
	B3.sphere(n, 0.09, Vector3(0, 1.25, 0), B3.mat(col, 0.2, 0.0, col, 4.0))
	for k in 3:
		var prong := B3.cyl(n, 0.012, 0.012, 0.22, Vector3(0, 1.17, 0), B3.mat(Color(0.7, 0.6, 0.3), 0.3, 0.9), false, 4)
		prong.rotation = Vector3(0.45, TAU * k / 3.0, 0)
	var l := B3.light(n, Vector3(0, 1.25, 0), col, 0.9, 3.5)
	l.shadow_enabled = false
	return n


## Waffe an ein echtes Modell hängen (Bogen links, Stab rechts).
static func attach_weapon(r: CharacterRig, weapon: String, col: Color) -> void:
	match weapon:
		"bow":
			var b := bow(col)
			b.rotation = Vector3(0, 0, PI * 0.5)
			r.attach_to_bone("mixamorig_LeftHand", b)
		"staff":
			var st := staff(col)
			st.rotation = Vector3(PI * 0.5, 0, 0)
			st.position = Vector3(0, 0.05, 0)
			r.attach_to_bone("mixamorig_RightHand", st)


static func _humanoid(r: CharacterRig, kind: String, color: Color, weapon: String = "") -> void:
	var big := kind in ["death_knight", "angel"]
	var sc := 1.25 if big else 1.0
	var p := _skeleton(r, sc)
	var main: Material
	var skin: Material
	match kind:
		"skeleton":
			main = B3.mat(Color(0.84, 0.8, 0.7), 0.7)
			skin = main
		"death_knight":
			main = B3.mat(Color(0.08, 0.06, 0.1), 0.35, 0.8)
			skin = B3.mat(Color(0.85, 0.82, 0.72), 0.7)
		"angel":
			if color.get_luminance() < 0.3:
				main = B3.mat(Color(0.07, 0.04, 0.09), 0.3, 0.4, Color(0.35, 0.08, 0.5), 0.35)
			else:
				main = B3.mat(Color(1, 0.97, 0.88), 0.3, 0.2, Color(1, 0.9, 0.6), 0.4)
			skin = main
		_:
			main = B3.mat(color, 0.4, 0.6)
			skin = B3.mat(Color(0.85, 0.7, 0.58), 0.8)
	var torso: Node3D = p.torso
	var thin := 0.6 if kind == "skeleton" else 1.0
	B3.box(p.body, Vector3(0.5, 0.3, 0.3) * sc, Vector3(0, 0.05, 0) * sc, main, false)
	B3.box(torso, Vector3(0.62 * thin, 0.62, 0.36 * thin) * sc, Vector3(0, 0.4, 0) * sc, main, false)
	B3.sphere(torso, 0.17 * sc, Vector3(0, 0.95, 0) * sc, skin, Vector3(0.95, 1.1, 1.0))
	_mark_head(r, torso, Vector3(0, 0.95, 0) * sc)
	if kind == "skeleton" or kind == "death_knight":
		var ec := Color(1, 0.2, 0.15) if kind == "skeleton" else Color(0.75, 0.3, 1.0)
		for s in [-1.0, 1.0]:
			B3.sphere(torso, 0.03 * sc, Vector3(0.06 * s, 0.97, 0.15) * sc, B3.mat(ec, 1, 0, ec, 5))
	if kind == "death_knight":
		B3.box(torso, Vector3(0.38, 0.42, 0.4) * sc, Vector3(0, 0.98, 0) * sc, main, false)
		B3.box(torso, Vector3(1.0, 1.6, 0.05) * sc, Vector3(0, -0.2, -0.22) * sc, B3.mat(Color(0.25, 0.05, 0.1), 0.9), false, Vector3(10, 0, 0))
	if kind == "soldier":
		B3.box(torso, Vector3(0.3, 0.32, 0.32), Vector3(0, 1.0, 0), B3.mat(Color(0.7, 0.72, 0.78), 0.3, 0.9), false)
		B3.box(torso, Vector3(0.4, 0.55, 0.04), Vector3(0, 0.38, 0.2), B3.mat(color.darkened(0.4), 0.9), false)
	if kind == "angel":
		var fallen := color.get_luminance() < 0.3
		var halo := TorusMesh.new()
		halo.inner_radius = 0.18
		halo.outer_radius = 0.23
		B3.mesh(torso, halo, Vector3(0, 1.28, 0) * sc, B3.mat(Color(0.6, 0.05, 0.1), 1, 0, Color(0.9, 0.08, 0.15), 4) if fallen else B3.mat(Color(1, 0.9, 0.5), 1, 0, Color(1, 0.85, 0.4), 4))
		# Flügel aus gefächerten Schwungfedern (außen länger) und Deckfedern am Ansatz, leicht nach hinten gelegt
		var wing_mat := B3.mat(Color(0.05, 0.03, 0.06), 0.45, 0.0, Color(0.3, 0.05, 0.45), 0.5) if fallen else B3.mat(Color(1, 0.98, 0.93), 0.55, 0.0, Color(1, 0.93, 0.75), 0.9)
		var cover_mat := B3.mat(Color(0.08, 0.05, 0.09), 0.5, 0.0, Color(0.25, 0.04, 0.35), 0.4) if fallen else B3.mat(Color(1, 0.96, 0.88), 0.6, 0.0, Color(1, 0.9, 0.7), 0.6)
		for s in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.position = Vector3(0.15 * s, 0.66, -0.2) * sc
			wing.rotation_degrees = Vector3(-6, 30 * s, 0)
			torso.add_child(wing)
			for i in 7:
				var t := i / 6.0
				var flen := lerpf(0.5, 1.3, sin(t * PI * 0.5)) * sc
				var feather := Node3D.new()
				feather.rotation_degrees.z = lerpf(-40.0, 58.0, t) * s
				wing.add_child(feather)
				B3.box(feather, Vector3(flen, 0.12 * sc * (1.0 - t * 0.35), 0.025 * sc), Vector3(flen * 0.5 * s, 0, -0.008 * i * sc), wing_mat, false)
			B3.box(wing, Vector3(0.5, 0.34, 0.05) * sc, Vector3(0.27 * s, 0.1, 0.02) * sc, cover_mat, false, Vector3(0, 0, 24 * s))
			B3.box(wing, Vector3(0.36, 0.22, 0.06) * sc, Vector3(0.18 * s, 0.3, 0.03) * sc, cover_mat, false, Vector3(0, 0, 48 * s))
	for leg in [p.leg_l, p.leg_r]:
		_limb(leg, 0.95 * sc, 0.09 * sc * thin, main)
	for arm in [p.arm_r, p.arm_l]:
		_limb(arm, 0.7 * sc, 0.08 * sc * thin, main)
	# Waffen
	var w := Node3D.new()
	w.position = Vector3(0, -0.72, 0.05) * sc
	w.rotation_degrees.x = 90
	p.arm_r.add_child(w)
	var steel := B3.mat(Color(0.7, 0.7, 0.75), 0.2, 1.0)
	if weapon == "bow":
		w.queue_free()
		var b := bow(color)
		b.position = Vector3(0, -0.74, 0.06) * sc
		b.rotation = Vector3(0, PI * 0.5, 0)
		p.arm_l.add_child(b)
		return
	if weapon == "staff":
		w.queue_free()
		var st := staff(color.lightened(0.3))
		st.position = Vector3(0, -0.74, 0.06) * sc
		p.arm_r.add_child(st)
		return
	var wood := B3.mat(Color(0.34, 0.24, 0.14), 0.7)
	if weapon == "spear":
		B3.cyl(w, 0.022, 0.022, 2.3 * sc, Vector3(0, 0.55, 0) * sc, wood, false, 6)
		B3.cone(w, 0.05 * sc, 0.3 * sc, Vector3(0, 1.85, 0) * sc, steel)
		return
	if weapon == "axe":
		B3.cyl(w, 0.026, 0.026, 1.05 * sc, Vector3(0, 0.45, 0) * sc, wood, false, 6)
		B3.box(w, Vector3(0.05, 0.32, 0.34) * sc, Vector3(0, 0.88, 0.13) * sc, steel, false)
		B3.box(w, Vector3(0.04, 0.12, 0.12) * sc, Vector3(0, 0.88, -0.08) * sc, steel, false)
		return
	match kind:
		"death_knight":
			B3.box(w, Vector3(0.16, 1.9, 0.04) * sc, Vector3(0, 1.0, 0) * sc, B3.mat(Color(0.3, 0.1, 0.4), 0.2, 0.8, Color(0.4, 0.1, 0.6), 0.8), false)
			var shield := Node3D.new()
			shield.position = Vector3(0, -0.5, 0.2) * sc
			p.arm_l.add_child(shield)
			B3.box(shield, Vector3(0.7, 1.2, 0.08) * sc, Vector3.ZERO, B3.mat(Color(0.12, 0.08, 0.14), 0.4, 0.8), false)
		"angel":
			B3.cyl(w, 0.04, 0.04, 1.2, Vector3(0, 0.5, 0), B3.mat(Color(0.9, 0.8, 0.4), 0.3, 0.9), false, 8)
			B3.sphere(w, 0.15, Vector3(0, 1.15, 0), B3.mat(Color(1, 0.95, 0.7), 1, 0, Color(1, 0.9, 0.5), 3))
		_:
			B3.box(w, Vector3(0.08, 1.0, 0.03), Vector3(0, 0.55, 0), steel, false)
			B3.box(w, Vector3(0.26, 0.05, 0.06), Vector3(0, 0.05, 0), B3.mat(Color(0.5, 0.4, 0.2), 0.4, 0.8), false)


static func _wolf(r: CharacterRig, color: Color) -> void:
	var body := Node3D.new()
	body.name = "body"
	body.position.y = 0.6
	r.add_child(body)
	r.body_base = 0.6
	var fur := B3.noise_mat(color.darkened(0.3), color.lightened(0.1), 0.4, 0.95)
	var torso := Node3D.new()
	body.add_child(torso)
	B3.box(torso, Vector3(0.5, 0.45, 1.2), Vector3(0, 0.1, 0), fur, false)
	var head := Node3D.new()
	head.position = Vector3(0, 0.3, 0.65)
	torso.add_child(head)
	B3.box(head, Vector3(0.36, 0.34, 0.45), Vector3(0, 0, 0.1), fur, false)
	B3.box(head, Vector3(0.2, 0.16, 0.3), Vector3(0, -0.06, 0.42), fur, false)
	for s in [-1.0, 1.0]:
		B3.prism(head, Vector3(0.1, 0.18, 0.08), Vector3(0.12 * s, 0.25, 0.0), fur)
		B3.sphere(head, 0.03, Vector3(0.1 * s, 0.06, 0.34), B3.mat(Color(1, 0.8, 0.2), 1, 0, Color(1, 0.7, 0.1), 4))
	var legs := []
	for c in [Vector3(-0.18, 0, 0.45), Vector3(0.18, 0, 0.45), Vector3(-0.18, 0, -0.45), Vector3(0.18, 0, -0.45)]:
		var l := Node3D.new()
		l.position = c
		body.add_child(l)
		_limb(l, 0.6, 0.06, fur)
		legs.append(l)
	B3.cyl(torso, 0.04, 0.08, 0.6, Vector3(0, 0.25, -0.75), fur, false, 6).rotation_degrees.x = -50
	# Kopf zählt als „rechter Arm“ (Biss), Vorderbeine als Beine
	r.parts = {"body": body, "torso": torso, "arm_r": head, "leg_l": legs[0], "leg_r": legs[1]}


static func _golem(r: CharacterRig, color: Color) -> void:
	var p := _skeleton(r, 1.4)
	var stone := B3.noise_mat(color.darkened(0.3), color.lightened(0.15), 0.3, 0.95)
	var rune := B3.mat(Color(0.4, 0.8, 1.0), 1, 0, Color(0.3, 0.7, 1.0), 3)
	B3.box(p.torso, Vector3(1.1, 0.9, 0.7), Vector3(0, 0.5, 0), stone, false)
	B3.box(p.torso, Vector3(0.45, 0.4, 0.45), Vector3(0, 1.2, 0.05), stone, false)
	B3.box(p.torso, Vector3(0.3, 0.06, 0.02), Vector3(0, 1.22, 0.29), rune, false)
	B3.box(p.torso, Vector3(0.2, 0.2, 0.02), Vector3(0, 0.55, 0.36), rune, false)
	for arm in [p.arm_r, p.arm_l]:
		arm.position.x *= 1.5
		B3.box(arm, Vector3(0.3, 1.0, 0.3), Vector3(0, -0.5, 0), stone, false)
		B3.box(arm, Vector3(0.42, 0.42, 0.42), Vector3(0, -1.1, 0), stone, false)
	for leg in [p.leg_l, p.leg_r]:
		B3.box(leg, Vector3(0.34, 1.3, 0.34), Vector3(0, -0.65, 0), stone, false)


# =====================================================================
#  Figuren (Wächter, Pleiaden, NPCs) – Aussehen aus data/figures.json
# =====================================================================

static var _figures: Dictionary = {}


static func figure_spec(cid: String) -> Dictionary:
	if _figures.is_empty():
		var fa := FileAccess.open("res://data/figures.json", FileAccess.READ)
		if fa:
			var d: Variant = JSON.parse_string(fa.get_as_text())
			if d is Dictionary:
				_figures = d.get("figures", {})
	return _figures.get(cid, {})


## Modell einer Figur: "model" in data/figures.json (z. B. Jaldabaoth = Demiurges Modell), sonst die ID selbst.
static func model_of(cid: String) -> String:
	var f := figure_spec(cid)
	if f.has("model"):
		return String(f.model)
	if ModelLib.has("characters", cid):
		return cid
	# Menschen ohne eigenes Modell tragen das Dorfbewohner-Modell (villager_look.gd); Sonderformen bleiben prozedural
	if not f.is_empty() and String(f.get("special", "")) == "":
		var vm: String = VLook.model_for(f)
		if vm != "":
			return vm
	return cid


## Zubehör, das auch an echten Modellen hängt (figures.json): "mask" = Farbe der Maske (Jaldabaoth).
## Liegt assets/models/props/jaldabaoth_mask.glb vor (Drehpunkt auf Augenhöhe an der Rückseite, Blick nach +Z,
## Maße eingebacken), wird das echte Modell genommen, sonst die prozedurale Porzellanmaske.
static func accessories(r: CharacterRig, cid: String) -> void:
	var f := figure_spec(cid)
	if r.has_model and r.model_id.begins_with("villager_"):
		VLook.apply(r, f)
	if not f.has("mask"):
		return
	var mask: Node3D = ModelLib.instance("props", "jaldabaoth_mask")
	var real := mask != null
	if mask == null:
		mask = _mask(_c(f.mask))
	mask.name = "mask"
	if r.has_model:
		var put := func() -> void:
			if r.attach_to_bone("mixamorig_Head", mask):
				mask.position = Vector3(0, 0.09, 0.075) if real else Vector3(0, 0.1, 0.085)
			else:
				mask.queue_free()
		if r.is_inside_tree():
			put.call()
		else:
			r.tree_entered.connect(put, CONNECT_ONE_SHOT)
	elif r.parts.has("head"):
		(r.parts.head as Node3D).add_child(mask)
		mask.position = Vector3(0, 0.0, 0.1)


## Dämonenmaske: blasse Porzellanplatte mit schmalen Augenschlitzen, Goldrand und zwei kleinen Hörnern.
static func _mask(col: Color) -> Node3D:
	var m := Node3D.new()
	m.name = "mask"
	var plate := B3.mat(col, 0.25, 0.1)
	var dark := B3.mat(Color(0.03, 0.01, 0.02), 0.6)
	var gold := B3.mat(Color(0.85, 0.65, 0.25), 0.25, 1.0)
	B3.sphere(m, 0.5, Vector3.ZERO, plate, Vector3(0.17, 0.22, 0.07))
	for s in [-1.0, 1.0]:
		B3.box(m, Vector3(0.055, 0.012, 0.02), Vector3(0.042 * s, 0.025, 0.032), dark, false, Vector3(0, 0, -14 * s))
		B3.box(m, Vector3(0.006, 0.17, 0.008), Vector3(0.082 * s, -0.005, 0.012), gold, false, Vector3(0, 0, 8 * s))
		B3.cone(m, 0.012, 0.07, Vector3(0.05 * s, 0.11, -0.01), gold).rotation_degrees = Vector3(-20, 0, -25 * s)
	B3.box(m, Vector3(0.11, 0.006, 0.008), Vector3(0, 0.105, 0.016), gold, false)
	B3.box(m, Vector3(0.03, 0.005, 0.01), Vector3(0, -0.06, 0.034), dark, false)
	return m


## Baut die Figur zu einer Charakter-ID (Fallback: neutrale Gestalt in der Charakterfarbe).
static func figure(r: CharacterRig, cid: String) -> void:
	var f := figure_spec(cid)
	var special: String = f.get("special", "")
	if special == "ainz":
		ainz(r)
		return
	if special == "momon":
		momon(r)
		return
	if special.begins_with("enemy:"):
		var parts := special.split(":")
		enemy(r, parts[1], Color(f.get("color", "#888888")), parts[2] if parts.size() > 2 else "")
		return
	match special:
		"cocytus": _cocytus(r, Color(f.color))
		"pandora": _pandora(r)
		"hamsuke": _hamsuke(r, Color(f.color))
		"victim": _victim(r)
		"neuronist": _neuronist(r, Color(f.color))
		"armor": _platinum(r, Color(f.color))
		"lizard": _lizardman(r, f)
		_:
			if f.is_empty():
				f = {"skin": "#e8d0c0", "hair": ["#2a2a2a", "short"], "top": Content.char_color(cid).to_html(), "bottom": ["pants", "#2a2a2a"], "trim": "#d4af37"}
			_person(r, f)


static func _c(v: Variant, fallback: String = "#888888") -> Color:
	return Color(str(v)) if v != null and str(v) != "" else Color(fallback)


## Echsenmensch (Sümpfe): geschuppte Haut mit hellem Bauch, Schnauze mit Kiefer und Nüstern, Bernsteinaugen,
## Rückenkamm, Krallen an Händen und Füßen und ein langer Schwanz. figures.json: "skin", "belly", "crest", "eyes",
## "bottom" (Lendenschurz), "weapon", "big_arm" (Zenberus gewaltiger Arm), "scale".
static func _lizardman(r: CharacterRig, f: Dictionary) -> void:
	var sc := float(f.get("scale", 1.05))
	var p := _skeleton(r, sc)
	var sk := _c(f.get("skin"), "#4f7a42")
	var skin := B3.noise_mat(sk.darkened(0.3), sk.lightened(0.12), 0.22, 0.5, Color.BLACK, 4.0)
	var belly := B3.noise_mat(_c(f.get("belly"), "#a8b878").darkened(0.15), _c(f.get("belly"), "#a8b878"), 0.18, 0.6, Color.BLACK, 3.0)
	var crest := B3.mat(_c(f.get("crest"), "#2a4a2a"), 0.5)
	var claw := B3.mat(Color(0.12, 0.1, 0.08), 0.35)
	var spikes: bool = f.get("spikes", true)
	var snout := float(f.get("snout", 1.0))
	var claws := float(f.get("claws", 1.0))
	var body: Node3D = p.body
	var torso: Node3D = p.torso
	torso.rotation_degrees.x = 8.0                       # leicht vorgebeugt
	# Rumpf: kräftiger Brustkorb, heller Bauch, Schultern
	B3.sphere(torso, 0.5, Vector3(0, 0.36, 0) * sc, skin, Vector3(0.5, 0.66, 0.36) * sc)
	B3.sphere(torso, 0.5, Vector3(0, 0.3, 0.07) * sc, belly, Vector3(0.36, 0.54, 0.26) * sc)
	for s in [-1.0, 1.0]:
		B3.sphere(torso, 0.12 * sc, Vector3(0.26 * s, 0.6, 0) * sc, skin)
	B3.sphere(body, 0.5, Vector3(0, 0.02, 0) * sc, skin, Vector3(0.42, 0.3, 0.32) * sc)
	# Rückenkamm
	for i in (6 if spikes else 0):
		var t := i / 5.0
		var spike := B3.cone(torso, 0.035 * sc, (0.16 - t * 0.07) * sc, Vector3(0, (0.72 - t * 0.6), -0.17 + t * 0.02) * sc, crest)
		spike.rotation_degrees.x = -35.0
	# Hals und Kopf mit Schnauze
	_limb_to(torso, Vector3(0, 0.66, 0.02) * sc, Vector3(0, 0.84, 0.07) * sc, 0.08 * sc, 0.07 * sc, skin)
	var head := Node3D.new()
	head.position = Vector3(0, 0.9, 0.08) * sc
	torso.add_child(head)
	r.parts["head"] = head
	B3.sphere(head, 0.5, Vector3(0, 0.02, -0.01) * sc, skin, Vector3(0.21, 0.19, 0.23) * sc)
	B3.sphere(head, 0.5, Vector3(0, -0.01, 0.06 + 0.08 * snout) * sc, skin, Vector3(0.14, 0.11, 0.1 + 0.16 * snout) * sc)       # Schnauze
	B3.sphere(head, 0.5, Vector3(0, -0.06, 0.05 + 0.07 * snout) * sc, belly, Vector3(0.12, 0.06, 0.09 + 0.15 * snout) * sc)     # Unterkiefer
	if f.get("round_ears", false):
		for s in [-1.0, 1.0]:
			B3.sphere(head, 0.5, Vector3(0.1 * s, 0.07, -0.04) * sc, skin, Vector3(0.05, 0.07, 0.03) * sc)
	var eye := B3.mat(_c(f.get("eyes"), "#e8c040"), 0.2, 0.0, _c(f.get("eyes"), "#e8c040"), 1.6)
	var pupil := B3.mat(Color(0.02, 0.02, 0.02), 0.4)
	for s in [-1.0, 1.0]:
		B3.sphere(head, 0.026 * sc, Vector3(0.078 * s, 0.045, 0.06) * sc, eye)
		B3.box(head, Vector3(0.006, 0.03, 0.01) * sc, Vector3(0.1 * s, 0.045, 0.065) * sc, pupil, false)
		B3.sphere(head, 0.008 * sc, Vector3(0.025 * s, 0.015, 0.12 + 0.145 * snout) * sc, pupil)
		if spikes:
			var brow := B3.cone(head, 0.02 * sc, 0.09 * sc, Vector3(0.07 * s, 0.1, -0.02) * sc, crest)
			brow.rotation_degrees = Vector3(-60, 0, -20 * s)
	for i in (4 if spikes else 0):
		var spike := B3.cone(head, 0.025 * sc, (0.12 - i * 0.02) * sc, Vector3(0, 0.1 - i * 0.02, -0.06 - i * 0.05) * sc, crest)
		spike.rotation_degrees.x = -55.0
	# Schwanz: sich verjüngende Glieder nach hinten unten
	var prev := Vector3(0, -0.02, -0.12) * sc
	for i in (6 if f.get("tail", true) else 0):
		var t := (i + 1) / 6.0
		var nxt := Vector3(sin(t * 1.4) * 0.06, -0.12 - t * 0.6, -0.12 - t * 0.85) * sc
		_limb_to(body, prev, nxt, (0.13 - (t - 1.0 / 6.0) * 0.11) * sc, (0.13 - t * 0.11) * sc, skin)
		prev = nxt
	# Lendenschurz
	var bottom_spec: Array = f.get("bottom", ["loin", "#5a4028"])
	var cloth := B3.mat(_c(bottom_spec[1]), 0.85)
	B3.box(body, Vector3(0.36, 0.08, 0.27) * sc, Vector3(0, 0.0, 0.0) * sc, cloth, false)
	B3.box(body, Vector3(0.22, 0.36, 0.02) * sc, Vector3(0, -0.2, 0.15) * sc, cloth, false, Vector3(-6, 0, 0))
	# Beine mit Krallenfüßen
	for leg in [p.leg_l, p.leg_r]:
		_limb(leg, 0.48 * sc, 0.1 * sc, skin)
		_limb_to(leg, Vector3(0, -0.46, 0) * sc, Vector3(0, -0.88, -0.06) * sc, 0.08 * sc, 0.06 * sc, skin)
		B3.box(leg, Vector3(0.12, 0.05, 0.2) * sc, Vector3(0, -0.92, 0.05) * sc, skin, false)
		for k in 3:
			var c := B3.cone(leg, 0.018 * sc, 0.07 * sc, Vector3((k - 1) * 0.04, -0.93, 0.17) * sc, claw)
			c.rotation_degrees.x = 90.0
	# Arme mit Krallen (Zenberu: ein gewaltiger rechter Arm)
	var big: bool = f.get("big_arm", false)
	for arm in [p.arm_r, p.arm_l]:
		var huge: bool = big and arm == p.arm_r
		var th := (0.1 if huge else 0.065) * sc
		var ln := (0.72 if huge else 0.62) * sc
		_limb(arm, ln, th, skin)
		B3.sphere(arm, th * 1.15, Vector3(0, -ln - 0.02 * sc, 0), skin)
		for k in 3:
			var cs := (1.6 if huge else 1.0) * claws
			var c := B3.cone(arm, 0.014 * sc * cs, 0.06 * sc * cs, Vector3((k - 1) * 0.025 * sc * claws, -ln - 0.06 * sc * cs, 0.03 * sc), claw)
			c.rotation_degrees.x = 160.0
	if f.has("weapon"):
		_hand_weapon(r, p.arm_r, f.weapon, sc)


## Zylinder zwischen zwei Punkten (lokale Koordinaten von parent).
static func _limb_to(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, m: Material) -> MeshInstance3D:
	var seg := B3.cyl(parent, r1, r0, a.distance_to(b), (a + b) * 0.5, m, false, 8)
	seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return seg


static func _person(r: CharacterRig, f: Dictionary) -> void:
	var sc := float(f.get("scale", 1.0)) * HUMAN
	var p := _skeleton(r, sc)
	var skin := B3.mat(_c(f.get("skin"), "#e8d0c0"), 0.75)
	var top := B3.mat(_c(f.get("top")), 0.6, 0.1)
	var bottom_spec: Array = f.get("bottom", ["pants", "#2a2a2a"])
	var bottom := B3.mat(_c(bottom_spec[1]), 0.65, 0.1)
	var trim := B3.mat(_c(f.get("trim"), "#d4af37"), 0.3, 0.8)
	var hair_spec: Array = f.get("hair", ["#2a2a2a", "short"])
	var hair := B3.mat(_c(hair_spec[0]), 0.55)
	var body: Node3D = p.body
	var torso: Node3D = p.torso
	var armored: bool = f.get("armor", false)
	# Rumpf
	B3.box(torso, Vector3(0.44, 0.58, 0.26) * sc, Vector3(0, 0.36, 0) * sc, B3.mat(Color(0.6, 0.6, 0.65), 0.3, 0.8) if armored else top, false)
	B3.box(torso, Vector3(0.46, 0.06, 0.28) * sc, Vector3(0, 0.08, 0) * sc, trim, false)
	B3.box(torso, Vector3(0.12, 0.5, 0.02) * sc, Vector3(0, 0.38, 0.135) * sc, trim, false)
	if f.get("apron", false):
		B3.box(torso, Vector3(0.3, 0.4, 0.02) * sc, Vector3(0, 0.3, 0.14) * sc, B3.mat(Color(0.96, 0.96, 0.96), 0.8), false)
	if f.has("cape"):
		B3.box(torso, Vector3(0.5, 1.05, 0.03) * sc, Vector3(0, 0.05, -0.17) * sc, B3.mat(_c(f.cape), 0.75), false, Vector3(-8, 0, 0))
	if f.has("tabard"):
		B3.box(torso, Vector3(0.3, 0.75, 0.02) * sc, Vector3(0, 0.12, 0.142) * sc, B3.mat(_c(f.tabard), 0.7), false)
	for s in [-1.0, 1.0]:
		B3.sphere(torso, 0.1 * sc, Vector3(0.25 * s, 0.6, 0) * sc, B3.mat(Color(0.6, 0.6, 0.65), 0.3, 0.8) if armored else top)
	# Hals & Kopf
	B3.cyl(torso, 0.05 * sc, 0.06 * sc, 0.1 * sc, Vector3(0, 0.7, 0) * sc, skin, false, 8)
	var head := Node3D.new()
	head.position = Vector3(0, 0.88, 0) * sc
	torso.add_child(head)
	r.parts["head"] = head
	B3.sphere(head, 0.14 * sc, Vector3.ZERO, skin, Vector3(0.92, 1.08, 0.98))
	var eye := B3.mat(_c(f.get("eyes"), "#3a2a2a"), 1.0, 0.0, _c(f.get("eyes"), "#000000") * 0.6, 1.5)
	for s in [-1.0, 1.0]:
		B3.sphere(head, 0.022 * sc, Vector3(0.05 * s, 0.01, 0.12) * sc, eye)
	if f.get("ears", false):
		for s in [-1.0, 1.0]:
			B3.cone(head, 0.03 * sc, 0.18 * sc, Vector3(0.13 * s, -0.02, 0) * sc, skin).rotation_degrees.z = -70.0 * s
	if f.has("glasses"):
		var gm := B3.mat(_c(f.glasses), 0.2, 0.9)
		B3.box(head, Vector3(0.2, 0.012, 0.012) * sc, Vector3(0, 0.02, 0.135) * sc, gm, false)
	if f.has("beard"):
		B3.box(head, Vector3(0.16, 0.08, 0.06) * sc, Vector3(0, -0.1, 0.09) * sc, B3.mat(_c(f.beard), 0.8), false)
	if f.has("helmet"):
		# Topfhelm mit Sehschlitz und Kamm (Ritter) – die Haare verschwinden darunter
		var hm := B3.mat(_c(f.helmet), 0.3, 0.85)
		B3.sphere(head, 0.168 * sc, Vector3(0, 0.03, 0) * sc, hm, Vector3(1.0, 1.1, 1.06))
		B3.cyl(head, 0.172 * sc, 0.16 * sc, 0.1 * sc, Vector3(0, -0.07, 0) * sc, hm, false, 14)
		B3.box(head, Vector3(0.21, 0.024, 0.03) * sc, Vector3(0, 0.025, 0.165) * sc, B3.mat(Color(0.02, 0.02, 0.03), 0.9), false)
		B3.box(head, Vector3(0.035, 0.11, 0.24) * sc, Vector3(0, 0.2, -0.02) * sc, B3.mat(_c(f.get("plume", f.helmet)), 0.7), false)
	elif String(hair_spec[1]) != "bald":
		_hair(head, hair, String(hair_spec[1]), sc)
	if f.has("horns"):
		var hm := B3.mat(_c(f.horns), 0.4)
		for s in [-1.0, 1.0]:
			var horn := B3.cone(head, 0.035 * sc, 0.26 * sc, Vector3(0.1 * s, 0.1, -0.02) * sc, hm)
			horn.rotation_degrees = Vector3(-30, 0, -40.0 * s)
	if f.get("crown", false):
		B3.cyl(head, 0.13 * sc, 0.13 * sc, 0.06 * sc, Vector3(0, 0.15, 0) * sc, B3.mat(Color(0.9, 0.75, 0.3), 0.3, 0.9), false, 12)
	if f.has("cap"):
		B3.cyl(head, 0.15 * sc, 0.15 * sc, 0.08 * sc, Vector3(0, 0.12, 0) * sc, B3.mat(_c(f.cap), 0.8), false, 12)
	# Unterkörper
	match String(bottom_spec[0]):
		"dress":
			B3.cyl(body, 0.2 * sc, 0.4 * sc, 0.85 * sc, Vector3(0, -0.4, 0) * sc, bottom, false, 16)
			B3.cyl(body, 0.4 * sc, 0.41 * sc, 0.04 * sc, Vector3(0, -0.82, 0) * sc, trim, false, 16)
		"gown":
			B3.cyl(body, 0.22 * sc, 0.62 * sc, 0.92 * sc, Vector3(0, -0.45, 0) * sc, bottom, false, 20)
			B3.cyl(body, 0.5 * sc, 0.63 * sc, 0.3 * sc, Vector3(0, -0.75, 0) * sc, B3.mat(Color(0.08, 0.02, 0.05), 0.6), false, 20)
		"robe":
			B3.cyl(body, 0.24 * sc, 0.45 * sc, 0.95 * sc, Vector3(0, -0.45, 0) * sc, bottom, false, 16)
			B3.box(body, Vector3(0.1, 0.9, 0.02) * sc, Vector3(0, -0.45, 0.33) * sc, trim, false, Vector3(-12, 0, 0))
		_:
			for leg in [p.leg_l, p.leg_r]:
				_limb(leg, 0.9 * sc, 0.075 * sc, bottom)
				B3.box(leg, Vector3(0.11, 0.08, 0.22) * sc, Vector3(0, -0.92, 0.04) * sc, B3.mat(Color(0.1, 0.08, 0.08), 0.5), false)
	# Arme
	for arm in [p.arm_r, p.arm_l]:
		_limb(arm, 0.62 * sc, 0.055 * sc, B3.mat(Color(0.6, 0.6, 0.65), 0.3, 0.8) if armored else top)
		B3.sphere(arm, 0.05 * sc, Vector3(0, -0.66, 0) * sc, skin)
	# Flügel, Schwanz
	if f.has("wings"):
		var wm := B3.mat(_c(f.wings), 0.8)
		for s in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(0.1 * s, 0.5, -0.15) * sc
			w.rotation_degrees = Vector3(10, 30 * s, 20 * s)
			torso.add_child(w)
			B3.box(w, Vector3(0.9, 0.55, 0.03) * sc, Vector3(0.45 * s, 0.15, 0) * sc, wm, false)
			B3.box(w, Vector3(0.6, 0.35, 0.03) * sc, Vector3(0.75 * s, -0.15, 0) * sc, wm, false)
	if f.has("tail"):
		var tm := B3.mat(_c(f.tail), 0.3, 0.8)
		for i in 5:
			B3.cyl(body, 0.04 * sc * (1.0 - i * 0.15), 0.05 * sc * (1.0 - i * 0.15), 0.25 * sc, Vector3(0, -0.15 - i * 0.12, -0.2 - i * 0.12) * sc, tm, false, 6).rotation_degrees.x = 45
	_hand_weapon(r, p.arm_r, f.get("weapon", []), sc)


static func _hair(head: Node3D, m: Material, style: String, sc: float) -> void:
	B3.sphere(head, 0.15 * sc, Vector3(0, 0.04, -0.015) * sc, m, Vector3(1.0, 0.9, 1.0))
	match style:
		"long":
			B3.box(head, Vector3(0.3, 0.6, 0.08) * sc, Vector3(0, -0.25, -0.1) * sc, m, false)
		"twin":
			for s in [-1.0, 1.0]:
				B3.cyl(head, 0.06 * sc, 0.03 * sc, 0.5 * sc, Vector3(0.17 * s, -0.2, -0.05) * sc, m, false, 8)
		"ponytail":
			B3.cyl(head, 0.05 * sc, 0.02 * sc, 0.55 * sc, Vector3(0, -0.15, -0.17) * sc, m, false, 8)
		"bun":
			B3.sphere(head, 0.07 * sc, Vector3(0, 0.1, -0.14) * sc, m)
		"bob":
			B3.box(head, Vector3(0.31, 0.18, 0.26) * sc, Vector3(0, -0.04, -0.02) * sc, m, false)
		"slick":
			B3.box(head, Vector3(0.27, 0.06, 0.28) * sc, Vector3(0, 0.12, -0.02) * sc, m, false)


static func _hand_weapon(r: CharacterRig, arm: Node3D, spec: Array, sc: float) -> void:
	if spec.is_empty():
		return
	var w := Node3D.new()
	w.position = Vector3(0, -0.68, 0.04) * sc
	arm.add_child(w)
	var m := B3.mat(_c(spec[1]), 0.3, 0.7)
	match String(spec[0]):
		"halberd":
			B3.cyl(w, 0.02, 0.02, 2.0 * sc, Vector3(0, 0.3, 0) * sc, m, false, 6)
			B3.box(w, Vector3(0.3, 0.35, 0.02) * sc, Vector3(0.12, 1.15, 0) * sc, B3.mat(Color(0.75, 0.75, 0.8), 0.2, 1.0), false)
		"lance":
			B3.cone(w, 0.08 * sc, 1.8 * sc, Vector3(0, -0.4, 0) * sc, m)
		"staff":
			B3.cyl(w, 0.025, 0.025, 1.6 * sc, Vector3(0, 0.2, 0) * sc, m, false, 6)
			B3.sphere(w, 0.06 * sc, Vector3(0, 1.0, 0) * sc, B3.mat(Color(0.5, 1.0, 0.6), 1, 0, Color(0.4, 1.0, 0.5), 3))
		"sword", "dagger":
			var len := 0.9 if spec[0] == "sword" else 0.35
			B3.box(w, Vector3(0.06, len, 0.02) * sc, Vector3(0, len / 2.0, 0.05) * sc, m, false, Vector3(70, 0, 0))
		"frost_sword":
			# Frost Pain: echtes Modell (props/frost_pain.glb – Griff im Ursprung, Klinge nach +Y), sonst eisblaue Leuchtklinge
			var fp: Node3D = ModelLib.instance("props", "frost_pain")
			if fp:
				fp.position = Vector3(0, 0.04, 0.05) * sc
				fp.rotation_degrees = Vector3(70, 0, 0)
				fp.scale = Vector3.ONE * sc
				w.add_child(fp)
			else:
				var ice := B3.mat(_c(spec[1]), 0.1, 0.3, _c(spec[1]), 1.6)
				B3.box(w, Vector3(0.07, 0.95, 0.02) * sc, Vector3(0, 0.48, 0.05) * sc, ice, false, Vector3(70, 0, 0))
				B3.box(w, Vector3(0.2, 0.04, 0.05) * sc, Vector3(0, 0.02, 0.05) * sc, B3.mat(Color(0.5, 0.55, 0.6), 0.3, 0.9), false, Vector3(70, 0, 0))
			var gl := B3.light(w, Vector3(0, 0.5, 0.2) * sc, _c(spec[1]), 0.6, 2.5)
			gl.shadow_enabled = false
		"spear":
			B3.cyl(w, 0.02, 0.02, 2.1 * sc, Vector3(0, 0.45, 0) * sc, B3.mat(Color(0.34, 0.24, 0.14), 0.7), false, 6)
			B3.cone(w, 0.045 * sc, 0.26 * sc, Vector3(0, 1.62, 0) * sc, m)
		"axe", "hammer":
			var piv := Node3D.new()
			piv.rotation_degrees.x = 70
			w.add_child(piv)
			B3.cyl(piv, 0.022, 0.022, 0.75 * sc, Vector3(0, 0.3, 0.05) * sc, B3.mat(Color(0.34, 0.24, 0.14), 0.7), false, 6)
			if spec[0] == "axe":
				B3.box(piv, Vector3(0.04, 0.24, 0.26) * sc, Vector3(0, 0.62, 0.15) * sc, m, false)
			else:
				B3.box(piv, Vector3(0.13, 0.12, 0.24) * sc, Vector3(0, 0.66, 0.05) * sc, m, false)
		"whip":
			B3.cyl(w, 0.015, 0.015, 0.8 * sc, Vector3(0, -0.4, 0.1) * sc, m, false, 4)
		"bow":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42 * sc
			tm.outer_radius = 0.45 * sc
			B3.mesh(w, tm, Vector3(0, 0, 0.1), m, Vector3(0, 0, 90), Vector3(1, 1, 0.5))
		"gun":
			B3.box(w, Vector3(0.08, 0.12, 0.45) * sc, Vector3(0, 0, 0.2) * sc, m, false)
		"orb":
			# Todesperle (Khajit): schwarze Kugel mit violettem Schimmer
			B3.sphere(w, 0.1 * sc, Vector3(0, 0.02, 0.1) * sc, B3.mat(Color(0.05, 0.02, 0.08), 0.15, 0.6, _c(spec[1]), 2.2))
		"sword_shield":
			B3.box(w, Vector3(0.06, 0.9, 0.02) * sc, Vector3(0, 0.45, 0.05) * sc, m, false, Vector3(70, 0, 0))
			var lw := Node3D.new()
			lw.position = Vector3(-0.42, 0.0, 0.1) * sc
			w.add_child(lw)
			B3.box(lw, Vector3(0.04, 0.55, 0.4) * sc, Vector3.ZERO, B3.mat(_c(spec[1]).darkened(0.25), 0.4, 0.7), false)


static func _cocytus(r: CharacterRig, col: Color) -> void:
	var p := _skeleton(r, 1.3)
	var shell := B3.mat(col, 0.15, 0.4, col * 0.4, 0.6)
	var dark := B3.mat(col.darkened(0.5), 0.3, 0.4)
	var torso: Node3D = p.torso
	B3.box(torso, Vector3(0.6, 0.75, 0.4), Vector3(0, 0.5, 0), shell, false)
	B3.box(torso, Vector3(0.4, 0.35, 0.45), Vector3(0, 1.15, 0.08), shell, false)
	_mark_head(r, torso, Vector3(0, 1.15, 0))
	for s in [-1.0, 1.0]:
		B3.cone(torso, 0.05, 0.3, Vector3(0.12 * s, 0.95, 0.3), dark).rotation_degrees.x = 110   # Mandibeln
		B3.sphere(torso, 0.05, Vector3(0.12 * s, 1.2, 0.3), B3.mat(Color(0.3, 0.6, 1.0), 1, 0, Color(0.3, 0.7, 1.0), 3))
		B3.cone(torso, 0.06, 0.6, Vector3(0.3 * s, 0.9, -0.1), shell).rotation_degrees.z = -35.0 * s   # Dornen
		# zweites Armpaar
		var arm2 := Node3D.new()
		arm2.position = Vector3(0.38 * s, 0.25, 0.05)
		torso.add_child(arm2)
		_limb(arm2, 0.8, 0.06, shell)
		arm2.rotation_degrees.z = 20.0 * s
	for arm in [p.arm_r, p.arm_l]:
		_limb(arm, 0.9, 0.07, shell)
	for leg in [p.leg_l, p.leg_r]:
		_limb(leg, 0.95, 0.09, shell)
	for i in 5:
		B3.sphere(p.body, 0.13 - i * 0.015, Vector3(0, -0.3 - i * 0.1, -0.25 - i * 0.18), shell)
	_hand_weapon(r, p.arm_r, ["halberd", "#e0f0ff"], 1.3)


static func _pandora(r: CharacterRig) -> void:
	_person(r, {"scale": 1.02, "skin": "#e8c8a0", "hair": ["#e8c8a0", "none"], "top": "#c8a24a", "bottom": ["pants", "#6a5428"], "trim": "#2a2a2a", "cap": "#c8a24a", "eyes": "#000000"})
	var head: Node3D = r.parts.get("head")
	if head:
		for c in [Vector3(-0.05, 0.02, 0.13), Vector3(0.05, 0.02, 0.13), Vector3(0, -0.07, 0.13)]:
			B3.sphere(head, 0.03, c, B3.mat(Color(0.02, 0.02, 0.02), 1.0))


static func _hamsuke(r: CharacterRig, col: Color) -> void:
	var body := Node3D.new()
	body.name = "body"
	body.position.y = 1.0
	r.add_child(body)
	r.body_base = 1.0
	var fur := B3.noise_mat(col.darkened(0.15), col.lightened(0.15), 0.5, 0.95)
	B3.sphere(body, 1.0, Vector3.ZERO, fur, Vector3(1.0, 0.95, 1.05))
	B3.sphere(body, 0.6, Vector3(0, -0.1, 0.55), B3.mat(Color(0.95, 0.9, 0.82), 0.9), Vector3(1, 0.9, 0.5))
	for s in [-1.0, 1.0]:
		B3.sphere(body, 0.22, Vector3(0.45 * s, 0.85, 0.1), fur, Vector3(1, 1, 0.4))
		B3.sphere(body, 0.09, Vector3(0.32 * s, 0.35, 0.86), B3.mat(Color(0.05, 0.05, 0.05), 0.2))
	B3.sphere(body, 0.08, Vector3(0, 0.15, 0.98), B3.mat(Color(0.9, 0.5, 0.55), 0.7))
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.0, -0.95)
	body.add_child(tail)
	B3.cyl(tail, 0.06, 0.08, 1.5, Vector3(0, 0.3, -0.5), B3.mat(Color(0.25, 0.25, 0.3), 0.4, 0.6), false, 8).rotation_degrees.x = -60
	r.parts = {"body": body, "torso": body, "arm_r": tail}
	_mark_head(r, body, Vector3(0, 1.0, 0.3))


static func _victim(r: CharacterRig) -> void:
	var body := Node3D.new()
	body.name = "body"
	body.position.y = 1.6
	r.add_child(body)
	r.body_base = 1.6
	var m := B3.mat(Color(0.85, 0.8, 0.82), 0.7)
	B3.sphere(body, 0.35, Vector3.ZERO, m, Vector3(0.9, 1.1, 0.9))
	B3.sphere(body, 0.25, Vector3(0, 0.45, 0.05), m)
	var halo := TorusMesh.new()
	halo.inner_radius = 0.2
	halo.outer_radius = 0.24
	B3.mesh(body, halo, Vector3(0, 0.78, 0), B3.mat(Color(0.9, 0.75, 0.3), 0.3, 0.9))
	for s in [-1.0, 1.0]:
		B3.box(body, Vector3(0.7, 0.4, 0.03), Vector3(0.45 * s, 0.25, -0.2), B3.mat(Color(0.95, 0.95, 0.95), 0.8), false, Vector3(0, 20 * s, 15 * s))
	r.parts = {"body": body, "torso": body, "head": body}


static func _neuronist(r: CharacterRig, col: Color) -> void:
	var p := _skeleton(r, 1.1)
	var flesh := B3.mat(col, 0.8)
	B3.sphere(p.torso, 0.55, Vector3(0, 0.35, 0.05), flesh, Vector3(1.0, 1.0, 0.9))
	B3.sphere(p.torso, 0.22, Vector3(0, 0.95, 0.05), flesh)
	_mark_head(r, p.torso, Vector3(0, 0.95, 0))
	for i in 6:
		var a := TAU * i / 6.0
		B3.cyl(p.torso, 0.03, 0.05, 0.5, Vector3(cos(a) * 0.12, 0.7, 0.1 + sin(a) * 0.12), flesh, false, 6)
	for arm in [p.arm_r, p.arm_l]:
		_limb(arm, 0.7, 0.08, flesh)
	for leg in [p.leg_l, p.leg_r]:
		_limb(leg, 0.9, 0.12, flesh)
	B3.box(p.torso, Vector3(0.5, 0.6, 0.05), Vector3(0, 0.3, 0.45), B3.mat(Color(0.2, 0.1, 0.12), 0.6), false)


static func _platinum(r: CharacterRig, col: Color) -> void:
	var p := _skeleton(r, 1.15)
	var plat := B3.mat(col, 0.25, 0.55, col * 0.15, 0.6)
	B3.box(p.torso, Vector3(0.62, 0.65, 0.4), Vector3(0, 0.45, 0), plat, false)
	B3.box(p.torso, Vector3(0.32, 0.36, 0.34), Vector3(0, 1.08, 0), plat, false)
	_mark_head(r, p.torso, Vector3(0, 1.08, 0))
	B3.box(p.torso, Vector3(0.22, 0.03, 0.02), Vector3(0, 1.08, 0.18), B3.mat(Color(0.3, 0.7, 1.0), 1, 0, Color(0.3, 0.7, 1.0), 3), false)
	for s in [-1.0, 1.0]:
		B3.cone(p.torso, 0.06, 0.4, Vector3(0.36 * s, 0.75, 0), plat).rotation_degrees.z = -50.0 * s
		B3.cone(p.torso, 0.04, 0.3, Vector3(0.1 * s, 1.25, 0), plat).rotation_degrees.z = -20.0 * s
	for arm in [p.arm_r, p.arm_l]:
		_limb(arm, 0.75, 0.09, plat)
	for leg in [p.leg_l, p.leg_r]:
		_limb(leg, 1.0, 0.11, plat)
	_hand_weapon(r, p.arm_r, ["sword", "#e8f0f8"], 1.15)

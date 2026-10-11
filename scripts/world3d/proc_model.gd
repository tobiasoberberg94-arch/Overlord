class_name ProcModel
## Prozedurale Ersatzfiguren mit Gelenken (für CharacterRig), solange keine .glb-Modelle
## vorliegen: Ainz (Robe + Stab), Momon (schwarze Rüstung + zwei Großschwerter) und
## Gegner (Skelett, Todesritter, Ritter, Wolf, Engel, Golem).
## Aufbau: body (Hüfte, Drehpunkt) → torso → arm_r/arm_l (Schultergelenke), leg_l/leg_r.

const HIP := 0.95


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
	B3.cyl(torso, 0.34, 0.24, 0.35, Vector3(0, 0.83, -0.04), violet, false, 14)
	B3.sphere(torso, 0.19, Vector3(0, 1.03, 0.02), bone, Vector3(0.95, 1.05, 1.0))
	B3.sphere(torso, 0.12, Vector3(0, 0.91, 0.08), bone, Vector3(0.9, 0.7, 1.0))
	for s in [-1.0, 1.0]:
		B3.sphere(torso, 0.035, Vector3(0.07 * s, 1.04, 0.17), red)
	B3.sphere(torso, 0.26, Vector3(0, 1.05, -0.08), robe_m, Vector3(1.05, 1.1, 1.0))
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
	var plate := B3.mat(Color(0.06, 0.06, 0.07), 0.35, 0.85)
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

static func enemy(r: CharacterRig, kind: String, color: Color) -> void:
	match kind:
		"wolf": _wolf(r, color)
		"golem": _golem(r, color)
		_: _humanoid(r, kind, color)


static func _humanoid(r: CharacterRig, kind: String, color: Color) -> void:
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
		var halo := TorusMesh.new()
		halo.inner_radius = 0.18
		halo.outer_radius = 0.23
		B3.mesh(torso, halo, Vector3(0, 1.28, 0) * sc, B3.mat(Color(1, 0.9, 0.5), 1, 0, Color(1, 0.85, 0.4), 4))
		for s in [-1.0, 1.0]:
			B3.box(torso, Vector3(1.3, 0.9, 0.05) * sc, Vector3(0.7 * s, 0.7, -0.3) * sc, B3.mat(Color(1, 1, 1, 0.9), 0.4, 0, Color(1, 0.95, 0.8), 0.6), false, Vector3(0, 20 * s, 25 * s))
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

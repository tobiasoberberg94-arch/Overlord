class_name LocationBuilder
## Erzeugt die begehbaren Orte aus data/locations.json. Jede „kind“ hat ein eigenes
## Rezept (Thronsaal, Gletscher, Dorf, Stadt, Wald …). Rückgabe: Ankerpunkte für
## Spieler, Wächter, NPCs und Interaktionsobjekte.
##
## Rückgabe-Dictionary:
##   spawn: Vector3, yaw: float, gate: Vector3, board: Vector3 (optional),
##   slots: Array[Vector3] (Plätze für Figuren), keeper: Vector3,
##   throne/table/desk: Vector3 (nur Thronsaal)

const GOLD := Color(0.85, 0.66, 0.22)
const VIOLET := Color(0.55, 0.2, 0.95)

static var _rng := RandomNumberGenerator.new()


static func build(loc: Dictionary, root: Node3D) -> Dictionary:
	_rng.seed = hash(loc.id)
	# Vorlagen und Wind-Kopien des vorigen Ortes freigeben (sonst wächst der Grafikspeicher je Reise)
	ModelLib.release("locations", loc.id)
	_wind_cache.clear()
	# Ein komplettes Ortsmodell (assets/models/locations/<id>.glb) ersetzt das Rezept
	var scene := ModelLib.instance("locations", loc.id)
	var a: Dictionary
	if scene:
		a = _from_model(loc, root, scene)
		_gate(root, a.gate)
		return a
	match loc.kind:
		"throne": a = _throne(root)
		"tombs": a = _tombs(root)
		"glacier": a = _glacier(root)
		"jungle": a = _jungle(root)
		"lava": a = _lava(root)
		"royal": a = _royal(root)
		"library": a = _library(root)
		"treasury": a = _treasury(root)
		"village": a = _village(root)
		"city": a = _city(root, loc.get("style", "human"))
		"palace": a = _palace(root)
		"wall": a = _wall(root)
		"cathedral": a = _cathedral(root)
		"forest": a = _forest(root, loc.get("style", ""))
		"swamp": a = _swamp(root)
		"battlefield": a = _battlefield(root)
		"mountain": a = _mountain(root)
		"peaks": a = _peaks(root)
		_: a = _village(root)
	_gate(root, a.gate)
	return a


## Ortsmodell einsetzen. Ankerpunkte über benannte Knoten (Marker3D/Node3D):
##   Spawn, Gate, Throne, Table, Desk, Board, Keeper, Slot1…SlotN
## Fehlende Anker bekommen sinnvolle Standardwerte.
static func _from_model(loc: Dictionary, root: Node3D, scene: Node3D) -> Dictionary:
	root.add_child(scene)
	ModelLib.add_collision(scene)
	if HORIZON.has(loc.get("kind", "")) and loc.get("kind", "") != "glacier":
		PhProps.swap_rocks(scene, loc.get("kind", ""))
	if OS.get_environment("NO_PH") == "":
		PhProps.swap_props(scene)
		PhProps.spawn_markers(scene)
	_grass_on = _grass_field(loc, scene)
	_horizon(loc, scene)
	if not _grass_on:
		var df := DetailField.create(loc.get("kind", ""), null)
		if df:
			scene.add_child(df)
	AmbientLife.create(loc, scene)
	_scatter_instances(loc, scene)
	_ground_blend(scene, loc.get("kind", ""))
	_soft_cutouts(scene)
	_foliage_materials(scene)
	BuildingLook.apply(scene, loc)
	_wall_occluders(scene)
	_special_surfaces(scene)
	_auto_instance(scene)
	var spin: Array = scene.find_children("spin_*", "Node3D", true, false)
	if not spin.is_empty():
		var sp := Spinner.new()
		sp.nodes = spin
		scene.add_child(sp)
	# Lichter aus dem Modell (z. B. Lampen eines Unreal-Exports) haben fremde Einheiten:
	# auf spieltaugliche Werte bringen, Schatten nur bei hoher Grafikstufe.
	for l in scene.find_children("*", "OmniLight3D", true, false):
		var omni := l as OmniLight3D
		# Forward+: SDFGI verteilt das Licht zusätzlich. Je Ort einstellbar (preset „lamp“, „lamp_range“).
		var pr := preset(loc.kind)
		omni.light_energy = float(pr.get("lamp", 0.05)) if is_forward_plus() else float(pr.get("lamp", 0.05)) * 9.0
		omni.omni_range = clampf(omni.omni_range, 3.0, float(pr.get("lamp_range", 6.0)))
		omni.omni_attenuation = 1.5
		omni.shadow_enabled = false
	for l in scene.find_children("*", "SpotLight3D", true, false):
		(l as SpotLight3D).light_energy = 1.5
		(l as SpotLight3D).shadow_enabled = false
	var named := {}
	for n in scene.find_children("*", "Node3D", true, false):
		named[String(n.name).to_lower()] = n
	var at := func(key: String, fallback: Vector3) -> Vector3:
		return (named[key] as Node3D).global_position if named.has(key) else fallback
	var a := {"spawn": at.call("spawn", Vector3(0, 0.2, 10)), "yaw": 0.0, "gate": at.call("gate", Vector3(0, 0, 14))}
	for k in ["throne", "table", "desk", "board", "keeper"]:
		if named.has(k):
			a[k] = (named[k] as Node3D).global_position
	if loc.group == "world" and not a.has("board"):
		a["board"] = a.spawn + Vector3(3, 0, -4)
	var slots: Array = []
	for i in range(1, 20):
		if named.has("slot%d" % i):
			slots.append((named["slot%d" % i] as Node3D).global_position)
	a["slots"] = slots if not slots.is_empty() else _arc(a.spawn + Vector3(0, 0, -8), 5, 6, 60, 300)
	if named.has("spawn"):
		a["yaw"] = (named["spawn"] as Node3D).global_rotation.y
	if loc.group == "nazarick" and not a.has("keeper"):
		a["keeper"] = a.spawn + Vector3(0, 0, -10)
	_model_dressing(loc, root, named, a)
	B3.bounds(root, 120)
	return a



## Bäume mit drei Detailstufen (lod0 = Original, lod1/lod2 = ausgedünnte Blattkarten, tools/pipeline/loc_kit.py
## make_lod) als MultiMesh-Kacheln mit Sichtweiten; Kollision nur am Stamm (Zylinder).
const TREE_LODS := [[0.0, 22.0], [22.0, 70.0], [70.0, 900.0]]
const BUSH_LODS := [[0.0, 18.0], [18.0, 45.0], [45.0, 85.0]]
const FLOWER_LODS := [[0.0, 10.0], [10.0, 25.0], [25.0, 50.0]]

static func _lod_trees(scene: Node3D, base: String, mats: Array, templates: Dictionary, trunks: StaticBody3D, inv: Basis, keep: float) -> void:
	if not templates.has("lod0_" + base):
		return
	var aabb: AABB = (templates["lod0_" + base] as MeshInstance3D).mesh.get_aabb()
	var big := maxf(aabb.size.y, maxf(aabb.size.x, aabb.size.z))
	var ranges: Array = TREE_LODS if big >= 6.0 else (BUSH_LODS if big >= 1.5 else FLOWER_LODS)
	var solid := big >= 6.0                    # nur Bäume bekommen einen Stamm zum Anstoßen
	var tile := SCATTER_TILE * (3.0 if big >= 6.0 else 1.5)   # große Kacheln = wenige Draw Calls
	var tiles := {}
	var k := 0
	for m in mats:
		k += 1
		var b := Basis(Vector3(m[0], m[4], m[8]), Vector3(m[1], m[5], m[9]), Vector3(m[2], m[6], m[10]))
		var t := Transform3D(BLENDER_TO_GODOT * b * inv, BLENDER_TO_GODOT * Vector3(m[3], m[7], m[11]))
		var key := Vector2i(floori(t.origin.x / tile), floori(t.origin.z / tile))
		if not tiles.has(key):
			tiles[key] = []
		if keep < 1.0 and big < 6.0 and fmod(k * 0.618, 1.0) > keep:
			continue
		tiles[key].append(t)
		if not solid:
			continue
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		var sc := t.basis.get_scale().x
		cyl.radius = 0.35 * sc
		cyl.height = 5.0 * sc
		cs.shape = cyl
		cs.position = t.origin + Vector3(0, cyl.height * 0.5, 0)
		trunks.add_child(cs)
	var meshes: Array = []
	for lvl in 3:
		var tpl_key := "lod%d_%s" % [lvl, base]
		var src: MeshInstance3D = templates.get(tpl_key, templates["lod0_" + base])
		meshes.append(_wind_mesh(src.mesh, 0.012 if big >= 6.0 else (0.025 if big >= 1.5 else 0.06)))
	var fl := scene.get_node_or_null("FoliageLod") as FoliageLod
	if fl == null:
		fl = FoliageLod.new()
		fl.name = "FoliageLod"
		scene.add_child(fl)
	var r: Array = ranges.duplicate(true)
	if not Settings.particles:
		r[2] = [r[2][0], r[2][1] * 0.6]
	fl.add_group(meshes, tiles, r, Settings.particles and big >= 3.0)

static var _wind_cache: Dictionary = {}

## Kopie des Meshes, deren Materialien sich im Wind wiegen (Ausschlag wächst mit der Höhe).
## Das Standardmaterial wird in Shader-Code umgewandelt und im vertex()-Teil ergänzt.
static func _wind_mesh(mesh: Mesh, amount: float) -> Mesh:
	var key := "%d_%f" % [mesh.get_instance_id(), amount]
	if _wind_cache.has(key):
		return _wind_cache[key]
	var m := mesh.duplicate() as Mesh
	var h := mesh.get_aabb().end.y
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i) as BaseMaterial3D
		if mat:
			m.surface_set_material(i, _wind_material(mat, amount if Settings.particles else 0.0, h))
	_wind_cache[key] = m
	return m


## Mittlere Farbe einer Textur (nur deckende Pixel, data/tex_stats.json).
static func _texture_avg(t: Texture2D) -> Color:
	if t == null:
		return Color(0.5, 0.5, 0.5)
	return TexStats.color(t)


static func _wind_material(mat: BaseMaterial3D, amount: float, height: float = 6.0) -> Material:
	if mat.albedo_texture == null:
		return mat
	var mname := String(mat.resource_name).to_lower()
	var leafy := mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mname.contains("leaf") or mname.contains("leaves") 		or mname.contains("branch") or mname.contains("foliage") or mname.contains("needle") or mname.contains("grass")
	if mname.contains("bark") or mname.contains("trunk"):
		leafy = false
	var flower := mname.contains("flower") or mname.contains("blossom") or mname.contains("blume")
	var avg := _texture_avg(mat.albedo_texture)
	var lum := avg.r * 0.2126 + avg.g * 0.7152 + avg.b * 0.0722
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/foliage_wind.gdshader")
	sm.set_shader_parameter("albedo", mat.albedo_color)
	sm.set_shader_parameter("albedo_tex", mat.albedo_texture)
	sm.set_shader_parameter("use_normal", mat.normal_enabled and mat.normal_texture != null)
	sm.set_shader_parameter("normal_tex", mat.normal_texture)
	sm.set_shader_parameter("roughness", mat.roughness)
	sm.set_shader_parameter("alpha_cut", mat.alpha_scissor_threshold if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.35)
	sm.set_shader_parameter("wind", amount)
	sm.set_shader_parameter("leaf", 1.0 if leafy else 0.0)
	# stilisiertes Herbstlaub (orange/rot) → grün umfärben
	sm.set_shader_parameter("recolor", 1.0 if leafy and not flower and avg.r > avg.g * 1.18 and avg.r > avg.b * 1.6 else 0.0)
	# helle, graue Rinde (Birke) → meist abdunkeln
	var chroma := maxf(avg.r, maxf(avg.g, avg.b)) - minf(avg.r, minf(avg.g, avg.b))
	sm.set_shader_parameter("pale_bark", 1.0 if not leafy and lum > 0.45 and chroma < 0.15 else 0.0)
	sm.set_shader_parameter("height_hint", maxf(height, 0.5))
	sm.set_shader_parameter("grassy", 1.0 if leafy and not flower and (mname.contains("grass") or mname.contains("wheat")) else 0.0)
	# Laub auf natürliche Helligkeit/Sättigung bringen (grelles Lindgrün, helles Gelb dämpfen)
	if leafy and not flower:
		sm.set_shader_parameter("leaf_gain", clampf(0.2 / maxf(lum, 0.05), 0.5, 1.15))
		var sat_now := chroma / maxf(maxf(avg.r, maxf(avg.g, avg.b)), 0.01)
		sm.set_shader_parameter("leaf_sat", clampf(0.62 / maxf(sat_now, 0.1), 0.65, 1.1))
	if OS.get_environment("FOLIAGE_DEBUG") != "":
		print("LAUB %-26s avg(%.2f %.2f %.2f) blatt=%s umfaerben=%s birke=%s" % [String(mat.resource_name).substr(0, 26), avg.r, avg.g, avg.b, leafy,
			sm.get_shader_parameter("recolor"), sm.get_shader_parameter("pale_bark")])
	return sm


## Fest platzierte Bäume/Büsche des Ortsmodells (keine Streu-Instanzen) bekommen dasselbe Laubmaterial.
static func _foliage_materials(scene: Node3D) -> void:
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name).to_lower()
		if mi.mesh == null or nm.begins_with("nocol_mm_") or nm.begins_with("frost_") or nm.begins_with("ice_"):
			continue
		if not (nm.contains("tree") or nm.contains("spruce") or nm.contains("pine") or nm.contains("bush") or nm.contains("foliage") or nm.contains("palm")):
			continue
		var h := mi.mesh.get_aabb().end.y
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat:
				mi.set_surface_override_material(i, _wind_material(mat, 0.008 if Settings.particles else 0.0, h))


## Benannte Sonderflächen aus den Ortsmodellen: „…Lava…“ → fließender Lava-Shader (leuchtet, schadet nicht).
static func _special_surfaces(scene: Node3D) -> void:
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name).to_lower()
		if nm.contains("snowground") or nm.contains("icelake") or nm.begins_with("ice_") or nm.contains("_ice_") or nm.begins_with("frost_"):
			var sh: String = "snow" if nm.contains("snowground") else ("frost_overlay" if nm.begins_with("frost_") else "ice")
			var sm2 := ShaderMaterial.new()
			sm2.shader = load("res://assets/shaders/%s.gdshader" % sh)
			if sh == "snow":
				var sd := "res://assets/textures/terrain/snow_02/snow_02_"
				sm2.set_shader_parameter("snow_diff", load(sd + "diff.jpg"))
				sm2.set_shader_parameter("snow_nor", load(sd + "nor.jpg"))
				sm2.set_shader_parameter("snow_rough", load(sd + "rough.jpg"))
				sm2.set_shader_parameter("has_tex", true)
			if sh == "frost_overlay":
				mi.material_overlay = sm2
			else:
				for i in mi.mesh.get_surface_count():
					mi.set_surface_override_material(i, sm2)
			continue
		if nm.begins_with("water") or nm.contains("nocol_water"):
			var wm := ShaderMaterial.new()
			wm.shader = load("res://assets/shaders/water.gdshader")
			if nm.contains("river"):
				# Stadtfluss: klarer, dunkler, spiegelnd – kaum Entengrütze
				wm.set_shader_parameter("algae_amount", 0.12)
				wm.set_shader_parameter("shallow", Color(0.1, 0.13, 0.11))
				wm.set_shader_parameter("deep", Color(0.015, 0.03, 0.035))
				wm.set_shader_parameter("murk", 1.1)
			if nm.contains("creek"):
				# Waldbach unter Baumkronen: kaum Himmel im Wasser, dunkler, klar bis auf den Grund
				wm.set_shader_parameter("reflect", 0.35)
				wm.set_shader_parameter("shallow", Color(0.09, 0.11, 0.07))
				wm.set_shader_parameter("murk", 0.8)
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, wm)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for b in mi.find_children("*", "StaticBody3D", true, false):
				b.queue_free()   # Wasser ist begehbar (Waten), keine Kollision
			continue
		if nm.contains("goldpile"):
			var gp := ShaderMaterial.new()
			gp.shader = load("res://assets/shaders/gold_pile.gdshader")
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, gp)
			continue
		if nm.contains("lava"):
			var sm := ShaderMaterial.new()
			sm.shader = load("res://assets/shaders/lava.gdshader")
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, sm)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC


## Gleiche Meshes (Häuser, Zäune, Fässer, Fotoscans …) je Kachel zu MultiMeshes zusammenfassen: tausende
## Einzelobjekte kosten sonst je einen Draw Call – mal drei (Tiefen-, Schatten-, Farbpass). Die Knoten bleiben
## (Kollision, Verdecker als Kinder), nur ihr Mesh wandert in die Gruppe. Kleinkram blendet in der Ferne aus.
static var _inst_mesh_cache: Dictionary = {}

static func _auto_instance(scene: Node3D) -> void:
	if OS.get_environment("NO_INSTANCE") != "":
		return
	const TILE := 48.0
	var inv := scene.global_transform.affine_inverse()
	var groups := {}
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.material_override != null or mi.material_overlay != null:
			continue
		if mi.skin != null or mi.get_child_count() > 0 and mi.get_children().any(func(c): return c is Skeleton3D):
			continue
		var nm := String(mi.name).to_lower()
		if nm.begins_with("ground") or nm.begins_with("water") or nm.begins_with("spin_") or nm.contains("lava") 				or nm.contains("goldpile") or nm.begins_with("nocol_mm"):
			continue
		var key := str(mi.mesh.get_rid().get_id())
		for si in mi.mesh.get_surface_count():
			var om := mi.get_surface_override_material(si)
			key += "|" + (str(om.get_rid().get_id()) if om else "-")
		var p := mi.global_position
		key += "@%d_%d" % [floori(p.x / TILE), floori(p.z / TILE)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var made := 0
	var moved := 0
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 3:
			continue
		var first := list[0] as MeshInstance3D
		var mkey := String(key).get_slice("@", 0)
		var mesh: Mesh = _inst_mesh_cache.get(mkey)
		if mesh == null:
			mesh = first.mesh
			var over := false
			for si in mesh.get_surface_count():
				if first.get_surface_override_material(si) != null:
					over = true
			if over:
				mesh = first.mesh.duplicate()
				for si in mesh.get_surface_count():
					var om := first.get_surface_override_material(si)
					if om:
						mesh.surface_set_material(si, om)
			_inst_mesh_cache[mkey] = mesh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, inv * (list[k] as MeshInstance3D).global_transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "inst_" + String(first.name).get_slice("_", 0) + "_" + String(first.name).get_slice("_", 1)
		mmi.multimesh = mm
		mmi.cast_shadow = first.cast_shadow
		mmi.gi_mode = first.gi_mode
		var big := mesh.get_aabb().size.length() * first.global_transform.basis.get_scale().x
		if big < 1.5:
			mmi.visibility_range_end = 70.0
			mmi.visibility_range_end_margin = 10.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		elif big < 5.0:
			mmi.visibility_range_end = 150.0
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		scene.add_child(mmi)
		for m in list:
			(m as MeshInstance3D).mesh = null
		made += 1
		moved += list.size()
	_inst_mesh_cache.clear()
	print("Instanzgruppen: %d (%d Objekte)" % [made, moved])
	if OS.get_environment("INST_DEBUG") != "":
		var rest := {}
		for n in scene.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null:
				continue
			var k := gi.get_class() + ":" + String(gi.name).rstrip("0123456789").get_slice("_", 0) + "_" + String(gi.name).get_slice("_", 1)
			rest[k] = rest.get(k, 0) + 1
		var ks := rest.keys()
		ks.sort_custom(func(a, b): return rest[a] > rest[b])
		for k in ks.slice(0, 25):
			print("  REST ", k, " ", rest[k])


## Wände als Verdecker (Occlusion Culling): was hinter Mauern liegt, wird nicht gezeichnet.
## Box je Wandstück aus dessen AABB (nur flache, große Teile: Wände, Mauern).
static func _wall_occluders(scene: Node3D) -> void:
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var nm := String(mi.name).to_lower()
		if not (nm.begins_with("sm_wall") or nm.begins_with("sm_brick") or nm.contains("stonewall") or nm.contains("castlewall")):
			continue
		var aabb := mi.get_aabb()
		var sz := aabb.size
		var thin := minf(sz.x, minf(sz.y, sz.z))
		if thin > 1.2 or maxf(sz.x, sz.z) < 3.0 or sz.y < 2.5:
			continue
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = Vector3(sz.x, sz.y, sz.z) * 0.92 if thin == sz.y else sz * 0.92
		box.size = Vector3(maxf(box.size.x, 0.1), maxf(box.size.y, 0.1), maxf(box.size.z, 0.1))
		occ.occluder = box
		occ.position = aabb.get_center()
		mi.add_child(occ)
		n += 1
	if n > 0:
		print("Verdecker: ", n)


## Blätter/Gitter mit Alpha-Schnitt: Alpha-to-Coverage glättet die Kanten (wirkt mit MSAA).
static func _soft_cutouts(scene: Node3D) -> void:
	var seen := {}
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			if m and not seen.has(m) and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				seen[m] = true
				m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
				m.alpha_antialiasing_edge = 0.3
				m.cull_mode = BaseMaterial3D.CULL_DISABLED


## Gelände mit Wegmaske (Farbattribut): Gras- und Wegmaterial weich überblenden statt Treppenkanten.
static func _ground_blend(scene: Node3D, kind: String = "") -> void:
	var layers: Array = TERRAIN.get(kind, [])
	for n in scene.find_children("Ground*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue
		var masked: bool = mesh.get_surface_count() >= 2 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
		if not layers.is_empty():
			var gt: Dictionary = GRASS_TINT.get(kind, {})
			var gc: Color = (gt.get("lush_col", Color(0.11, 0.22, 0.045)) as Color).lerp(gt.get("tip_col", Color(0.2, 0.3, 0.07)), 0.45)
			var tm := _terrain_material(layers, masked, gc, masked and _has_dirt_mask(mesh))
			for i in mesh.get_surface_count():
				mi.set_surface_override_material(i, tm)
			continue
		if not masked:
			continue
		var grass := mesh.surface_get_material(0) as StandardMaterial3D
		var path := mesh.surface_get_material(1) as StandardMaterial3D
		if grass == null or path == null:
			continue
		var sm := ShaderMaterial.new()
		sm.shader = load("res://assets/shaders/ground_blend.gdshader")
		sm.set_shader_parameter("grass_tex", grass.albedo_texture)
		sm.set_shader_parameter("grass_nrm", grass.normal_texture)
		sm.set_shader_parameter("path_tex", path.albedo_texture)
		sm.set_shader_parameter("path_nrm", path.normal_texture if path.normal_texture else grass.normal_texture)
		for i in mesh.get_surface_count():
			mi.set_surface_override_material(i, sm)


## Fotoscan-Böden je Ortsart (assets/textures/terrain/<name>, Poly Haven CC0):
## [base, alt, path (Rot-Maske: Pflaster/Weg), rock, alt_amount, far_mix, dirt (Grün-Maske: Höfe, Gassen)]
const TERRAIN := {
	"grassland": ["forrest_ground_01", "leafy_grass", "grass_path_2", "mossy_rock", 0.35, 0.75, "stony_dirt_path"],
	"village": ["forrest_ground_01", "leafy_grass", "grass_path_2", "mossy_rock", 0.35, 0.7, "stony_dirt_path"],
	"wall": ["forrest_ground_01", "withered_grass", "mossy_cobblestone", "mossy_rock", 0.35, 0.65, "dirt"],
	"city": ["forrest_ground_01", "sparse_grass", "mossy_cobblestone", "mossy_rock", 0.3, 0.6, "dirt"],
	"palace": ["forrest_ground_01", "sparse_grass", "mossy_cobblestone", "mossy_rock", 0.3, 0.6, "dirt"],
	"cathedral": ["forrest_ground_01", "sparse_grass", "mossy_cobblestone", "mossy_rock", 0.3, 0.6, "dirt"],
	"forest": ["forrest_ground_01", "forest_leaves_02", "forest_ground_04", "mossy_rock", 0.45, 0.3, "forest_ground_04"],
	"jungle": ["leaves_forest_ground", "forrest_ground_01", "forest_ground_04", "mossy_rock", 0.45, 0.35, "forest_ground_04"],
	"swamp": ["brown_mud_leaves_01", "sparse_grass", "mud_forest", "mossy_rock", 0.5, 0.35, "mud_forest"],
	"cemetery": ["withered_grass", "dirt", "gravel_road", "mossy_rock", 0.45, 0.4, "dirt"],
	"battlefield": ["brown_mud_leaves_01", "withered_grass", "mud_forest", "rock_face", 0.45, 0.35, "mud_forest"],
	"mountain": ["rocky_terrain_02", "forrest_ground_01", "rocky_trail", "rock_face_03", 0.45, 0.3, "rocky_trail", Color(0.78, 0.86, 1.0)],
	"peaks": ["rocky_terrain_02", "withered_grass", "rocky_trail", "dark_rock_02", 0.4, 0.2, "rocky_trail", Color(1.5, 1.5, 1.55)],
	"lava": ["dark_rock_02", "rock_face", "stony_dirt_path", "dark_rock_02", 0.3, 0.0, "stony_dirt_path"],
}
static var _terrain_cache: Dictionary = {}


static func _terrain_material(layers: Array, masked: bool, grass_col: Color = Color(0.11, 0.2, 0.05), dirt := false) -> ShaderMaterial:
	var key := str(layers) + str(masked) + str(dirt)
	if _terrain_cache.has(key):
		return _terrain_cache[key]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/terrain_pbr.gdshader")
	var slot := ["base", "alt", "path", "rock"]
	for i in 4:
		var d := "res://assets/textures/terrain/%s/%s_" % [layers[i], layers[i]]
		sm.set_shader_parameter(slot[i] + "_diff", load(d + "diff.jpg"))
		sm.set_shader_parameter(slot[i] + "_nor", load(d + "nor.jpg"))
		if i < 3:
			sm.set_shader_parameter(slot[i] + "_rough", load(d + "rough.jpg"))
		if i == 0:
			sm.set_shader_parameter("base_ao", load(d + "ao.jpg"))
	if dirt and layers.size() > 6:
		var dd := "res://assets/textures/terrain/%s/%s_" % [layers[6], layers[6]]
		sm.set_shader_parameter("dirt_diff", load(dd + "diff.jpg"))
		sm.set_shader_parameter("dirt_nor", load(dd + "nor.jpg"))
		sm.set_shader_parameter("dirt_rough", load(dd + "rough.jpg"))
		sm.set_shader_parameter("use_dirt", true)
	if layers.size() > 7:
		sm.set_shader_parameter("rock_tint", layers[7])
	sm.set_shader_parameter("alt_amount", float(layers[4]))
	sm.set_shader_parameter("far_mix", float(layers[5]) if layers.size() > 5 else 0.0)
	sm.set_shader_parameter("use_mask", masked)
	sm.set_shader_parameter("far_col", grass_col)
	_terrain_cache[key] = sm
	return sm


## Trägt die Wegmaske einen eigenen Grün-Kanal (Höfe/Gassen, tools/pipeline/loc_kit.py dirt_fn)?
## Ältere Modelle haben Rot = Grün.
static func _has_dirt_mask(mesh: Mesh) -> bool:
	for si in mesh.get_surface_count():
		if (mesh.surface_get_format(si) & Mesh.ARRAY_FORMAT_COLOR) == 0:
			continue
		var cs: PackedColorArray = mesh.surface_get_arrays(si)[Mesh.ARRAY_COLOR]
		for i in range(0, cs.size(), 7):
			if absf(cs[i].g - cs[i].r) > 0.05:
				return true
	return false


## Gras, Blumen, Büsche (nocol_mm_<name> + <id>_scatter.json aus tools/pipeline/loc_kit.py) als
## MultiMesh-Kacheln: GPU-Instancing, jede Kachel blendet ab einer Entfernung aus.
const SCATTER_TILE := 40.0
const BLENDER_TO_GODOT := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

static var _grass_on := false

## Fernkulisse je Ortsart: Stil und Farbe des Kronendachs.
const HORIZON := {
	"grassland": ["forest", Color(0.17, 0.26, 0.1)], "forest": ["forest", Color(0.14, 0.22, 0.09)],
	"swamp": ["forest", Color(0.12, 0.17, 0.09)], "cemetery": ["forest", Color(0.08, 0.1, 0.08)],
	"village": ["plain", Color(0.18, 0.26, 0.11)], "city": ["plain", Color(0.18, 0.25, 0.11)],
	"palace": ["plain", Color(0.18, 0.26, 0.11)], "cathedral": ["plain", Color(0.2, 0.28, 0.12)],
	"wall": ["forest", Color(0.16, 0.24, 0.1)], "battlefield": ["plain", Color(0.24, 0.22, 0.14)],
	"mountain": ["mountain", Color(0.15, 0.2, 0.12)], "peaks": ["mountain", Color(0.2, 0.2, 0.16)],
	"glacier": ["mountain", Color(0.75, 0.8, 0.86)], "jungle": ["forest", Color(0.1, 0.22, 0.08)],
}


static func _horizon(loc: Dictionary, scene: Node3D) -> void:
	var h: Array = HORIZON.get(loc.get("kind", ""), [])
	if h.is_empty():
		return
	# Fernbäume: grobe Detailstufe (lod2) der großen Bäume des Ortes
	var trees: Array = []
	for t in scene.find_children("nocol_mm_lod2_*", "MeshInstance3D", true, false):
		var tm := (t as MeshInstance3D).mesh
		if tm and tm.get_aabb().size.y > 6.0 and trees.size() < 4:
			trees.append(_wind_mesh(tm, 0.0))
	for n in scene.find_children("*Ground*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh and mi.get_aabb().size.x > 60.0:
			Horizon.build(scene, mi, h[0], h[1], trees)
			return

## Farbe des Grases je Ortsart (Shader-Parameter von grass_field.gdshader).
const GRASS_TINT := {
	"grassland": {},
	"forest": {"tip_col": Color(0.2, 0.31, 0.075), "lush_col": Color(0.12, 0.23, 0.05), "dry_amount": 0.25, "density": 0.45},
	"palace": {"density": 0.4}, "cathedral": {"density": 0.4}, "wall": {"density": 0.55}, "city": {"density": 0.5},
	"village": {"density": 0.85},
	"mountain": {"tip_col": Color(0.23, 0.3, 0.1), "lush_col": Color(0.13, 0.22, 0.06), "dry_col": Color(0.36, 0.33, 0.2), "dry_amount": 0.6, "density": 0.45},
	"peaks": {"tip_col": Color(0.3, 0.3, 0.17), "lush_col": Color(0.17, 0.2, 0.09), "dry_col": Color(0.4, 0.37, 0.25), "dry_amount": 0.8, "density": 0.3},
	"battlefield": {"tip_col": Color(0.3, 0.29, 0.15), "lush_col": Color(0.18, 0.2, 0.08), "dry_col": Color(0.38, 0.33, 0.19), "dry_amount": 0.85, "density": 0.45},
	"swamp": {"tip_col": Color(0.2, 0.27, 0.08), "lush_col": Color(0.11, 0.2, 0.05), "dry_col": Color(0.3, 0.27, 0.13), "dry_amount": 0.5, "density": 0.6},
	"cemetery": {"tip_col": Color(0.2, 0.25, 0.09), "lush_col": Color(0.12, 0.18, 0.06), "dry_col": Color(0.32, 0.29, 0.16), "dry_amount": 0.7, "density": 0.7},
}


## Dichtes Grasfeld um die Kamera auf Kit-Gelände (Ground mit Wegmaske im Farbattribut).
static func _grass_field(loc: Dictionary, scene: Node3D) -> bool:
	if not GRASS_TINT.has(loc.get("kind", "")):
		return false
	for n in scene.find_children("Ground*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not (mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR):
			continue
		var gf := GrassField.create(mi, GRASS_TINT[loc.kind])
		if gf:
			scene.add_child(gf)
			var df := DetailField.create(loc.kind, gf)
			if df:
				scene.add_child(df)
			return true
	return false


static func _scatter_instances(loc: Dictionary, scene: Node3D) -> void:
	var file: String = ModelLib.model_config("locations", loc.id).get("file", loc.id)
	var f := FileAccess.open("res://assets/models/locations/%s_scatter.json" % file, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	var templates := {}
	for mi in scene.find_children("nocol_mm_*", "MeshInstance3D", true, false):
		templates[String(mi.name).substr(9).get_slice(".", 0)] = mi
		(mi as MeshInstance3D).visible = false
	var keep := 1.0 if Settings.particles else 0.45
	var inv := BLENDER_TO_GODOT.inverse()
	var trunks := StaticBody3D.new()
	trunks.name = "Baumstaemme"
	for name in data.instances:
		if String(name).begins_with("@lod:"):
			_lod_trees(scene, String(name).substr(5), data.instances[name], templates, trunks, inv, keep)
			continue
		var procedural := String(name).begins_with("@")
		if not procedural and not templates.has(name):
			continue
		if procedural and _grass_on:
			continue   # das GrassField übernimmt Gras und Blumen
		var mesh: Mesh = Grass.tuft(name == "@flower") if procedural else (templates[name] as MeshInstance3D).mesh
		var aabb := mesh.get_aabb()
		var big := maxf(aabb.size.y, maxf(aabb.size.x, aabb.size.z))
		var view_end := 60.0 if big < 1.2 else (95.0 if big < 3.0 else 150.0)
		if procedural:
			view_end = 55.0 if Settings.particles else 30.0
		var tiles := {}
		var i := 0
		for m in data.instances[name]:
			i += 1
			if keep < 1.0 and fmod(i * 0.618, 1.0) > keep:
				continue
			var b := Basis(Vector3(m[0], m[4], m[8]), Vector3(m[1], m[5], m[9]), Vector3(m[2], m[6], m[10]))
			var t := Transform3D(BLENDER_TO_GODOT * b * inv, BLENDER_TO_GODOT * Vector3(m[3], m[7], m[11]))
			var key := Vector2i(floori(t.origin.x / SCATTER_TILE), floori(t.origin.z / SCATTER_TILE))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(t)
		for key in tiles:
			var list: Array = tiles[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for k in list.size():
				mm.set_instance_transform(k, list[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "mm_%s_%d_%d" % [name, key.x, key.y]
			mmi.multimesh = mm
			mmi.visibility_range_end = view_end
			mmi.visibility_range_end_margin = 12.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			# Schatten nur von Büschen/Sträuchern ab 3 m – Gras und Blumen würden die Schattenkaskaden vervielfachen
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.particles and big >= 3.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			if not procedural:
				mmi.multimesh.mesh = _wind_mesh(mesh, 0.06 if big < 1.2 else 0.025)
			scene.add_child(mmi)
			mmi.transform = Transform3D.IDENTITY
	if trunks.get_child_count() > 0:
		scene.add_child(trunks)


# =====================================================================
#  Umgebung (Himmel, Nebel, Licht)
# =====================================================================

static func environment(root: Node3D, _loc: Dictionary, preset: Dictionary) -> void:
	var env := Environment.new()
	if preset.get("sky", true) and (preset.get("sky_ambient", false) or preset.has("clouds")):
		# Außenorte: Wolkenhimmel (assets/shaders/sky_clouds.gdshader) mit Sonne, Dunst und ggf. Sternen
		var sky := Sky.new()
		var sm := ShaderMaterial.new()
		sm.shader = load("res://assets/shaders/sky_clouds.gdshader")
		var top: Color = preset.get("sky_top", Color(0.2, 0.42, 0.78))
		var hor: Color = preset.get("fog", Color(0.6, 0.65, 0.72)).lerp(Color(0.75, 0.78, 0.84), 0.35)
		sm.set_shader_parameter("top_col", top)
		sm.set_shader_parameter("horizon_col", hor)
		sm.set_shader_parameter("ground_col", hor.darkened(0.55))
		sm.set_shader_parameter("coverage", float(preset.get("clouds", 0.45)))
		sm.set_shader_parameter("energy", float(preset.get("sky_energy", 1.0)))
		sm.set_shader_parameter("stars", float(preset.get("stars", 0.0)))
		sm.set_shader_parameter("cloud_col", preset.get("cloud_col", Color(1.0, 0.97, 0.93)))
		sm.set_shader_parameter("cloud_shade", preset.get("cloud_shade", hor.darkened(0.35)))
		sky.sky_material = sm
		sky.process_mode = Sky.PROCESS_MODE_REALTIME
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	elif preset.get("sky", true):
		# Prozeduraler Himmel (keine gemalten Bilder): Farben je Ort
		var sky := Sky.new()
		var pm := ProceduralSkyMaterial.new()
		var top: Color = preset.get("sky_top", Color(0.18, 0.2, 0.35))
		var hor: Color = preset.get("fog", Color(0.4, 0.4, 0.5)).lerp(Color(0.6, 0.6, 0.65), 0.3)
		pm.sky_top_color = top
		pm.sky_horizon_color = hor
		pm.ground_horizon_color = hor.darkened(0.3)
		pm.ground_bottom_color = hor.darkened(0.7)
		pm.sun_angle_max = 25.0
		pm.energy_multiplier = float(preset.get("sky_energy", 0.8))
		sky.sky_material = pm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = preset.get("bg", Color(0.02, 0.0, 0.04))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if preset.get("sky_ambient", false) else Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.get("ambient", Color(0.35, 0.3, 0.45))
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_energy = float(preset.get("ambient_energy", 0.6))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(preset.get("exposure", 1.0))
	env.fog_enabled = true
	env.fog_light_color = preset.get("fog", Color(0.08, 0.04, 0.12))
	env.fog_density = float(preset.get("fog_density", 0.02))
	env.fog_sky_affect = float(preset.get("fog_sky", 0.3))
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	if preset.has("saturation"):
		# Draußen: kräftigere Farben und etwas Kontrast (wie große RPGs, statt grauem Einheitslicht)
		env.adjustment_enabled = true
		env.adjustment_saturation = float(preset.saturation)
		env.adjustment_contrast = float(preset.get("contrast", 1.0))
	if is_forward_plus():
		_forward_plus_env(env, preset)
	if preset.has("hdri"):
		_outdoor_look(env, preset)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = preset.get("sun", Color(0.75, 0.7, 0.9))
	sun.light_energy = float(preset.get("sun_energy", 0.6))
	sun.rotation_degrees = preset.get("sun_rot", Vector3(-50, 35, 0))
	sun.shadow_enabled = Settings.particles and OS.get_environment("OVERLORD_NOSHADOW") == ""
	sun.directional_shadow_max_distance = minf(float(preset.get("shadow_dist", 60.0)), 70.0)
	# 2 Kaskaden statt 4: jede schattenwerfende Kachel wird je Kaskade erneut gezeichnet (Draw Calls/CPU)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.22
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_blur = 1.5
	sun.light_volumetric_fog_energy = 1.8
	sun.light_angular_distance = 0.6               # weiche, natürliche Schattenkanten
	root.add_child(sun)
	if preset.has("hdri"):
		var p2 := preset.duplicate()
		var sky_by_loc := {"baharuth": "sunflowers_puresky", "theokratie": "kloofendal_43d_clear_puresky",
			"re_capital": "kloofendal_38d_partly_cloudy_puresky", "drachen": "scythian_tombs_puresky"}
		if sky_by_loc.has(String(_loc.get("id", ""))):
			p2["hdri"] = sky_by_loc[_loc.id]
		HdriSky.apply(env, sun, p2)


static func is_forward_plus() -> bool:
	# Godot 4.3 kennt get_current_rendering_method() noch nicht: Einstellung prüfen und ob
	# wirklich ein RenderingDevice läuft (nicht bei Compatibility-Fallback/headless).
	return ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus" \
		and RenderingServer.get_rendering_device() != null


## Effekte, die nur der Forward+-Renderer kann: globale Beleuchtung (SDFGI),
## Umgebungsverdeckung (SSAO/SSIL), Bildschirmreflexionen und Volumennebel.
## Der Volumennebel übernimmt die Stimmung, der einfache Tiefennebel wird schwächer.
static func _forward_plus_env(env: Environment, preset: Dictionary) -> void:
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = float(preset.get("gi", 0.9))
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(preset.get("fog_density", 0.02)) * float(preset.get("vol_fog", 0.9))
	env.volumetric_fog_albedo = preset.get("fog", Color(0.08, 0.04, 0.12)).lightened(0.4)
	env.volumetric_fog_emission = preset.get("fog", Color(0.08, 0.04, 0.12)) * 0.15
	env.volumetric_fog_gi_inject = 0.8
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_anisotropy = 0.6          # Vorwärtsstreuung: Lichtstrahlen durch Kronen und Dunst
	env.fog_density *= 0.35
	# Umgebungslicht kommt jetzt teils aus SDFGI – Grundhelligkeit etwas zurücknehmen
	env.ambient_light_energy *= 0.7


## Bildwirkung im Freien (wie große Open-World-RPGs): ACES-Tonemapping mit Tiefe und Kontrast, Glow nur um helle
## Lichtquellen statt Schleier, Luftperspektive aus der Himmelsfarbe statt weißem Nebel, kräftige Umgebungsverdeckung.
static func _outdoor_look(env: Environment, preset: Dictionary) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = float(preset.get("exposure", 1.0)) * 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_density = float(preset.get("fog_density", 0.004)) * 0.28 * float(preset.get("haze", 1.0))
	env.fog_aerial_perspective = 0.8
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.12
	env.fog_height = -20.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = float(preset.get("saturation", 1.1)) * 0.98
	env.adjustment_contrast = float(preset.get("contrast", 1.05))
	env.adjustment_brightness = 1.0
	if env.ssao_enabled:
		env.ssao_radius = 1.6
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.ssao_light_affect = 0.15
		env.ssil_intensity = 0.7
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = float(preset.get("fog_density", 0.004)) * float(preset.get("vol_fog", 0.6)) * 0.45
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 96.0
		env.volumetric_fog_detail_spread = 1.5
		env.volumetric_fog_emission = Color(0, 0, 0)
		env.volumetric_fog_ambient_inject = 0.35
	env.sdfgi_energy = float(preset.get("gi", 1.0)) * 0.9


## Licht-/Nebelvorgaben je Ortstyp.
static func preset(kind: String) -> Dictionary:
	match kind:
		"throne": return {"sky": false, "bg": Color(0.015, 0.0, 0.03), "ambient": Color(0.5, 0.4, 0.65), "ambient_energy": 0.9, "fog": Color(0.1, 0.03, 0.16), "fog_density": 0.012, "sun_energy": 0.25}
		"tombs": return {"sky": false, "gi": 0.6, "vol_fog": 0.6, "bg": Color(0.01, 0.015, 0.02), "ambient": Color(0.32, 0.36, 0.45), "ambient_energy": 0.85, "fog": Color(0.05, 0.07, 0.09), "fog_density": 0.03, "sun_energy": 0.12, "saturation": 1.08, "contrast": 1.08}
		"glacier": return {"hdri": "kloofendal_48d_partly_cloudy_puresky", "sky_top": Color(0.28, 0.45, 0.72), "sky_energy": 1.0, "sky_ambient": true, "lamp": 0.5, "lamp_range": 10.0, "gi": 0.9, "vol_fog": 1.3, "ambient": Color(0.55, 0.68, 0.9), "ambient_energy": 0.8, "exposure": 0.78, "fog": Color(0.72, 0.82, 0.95), "fog_density": 0.012, "sun": Color(0.85, 0.92, 1.0), "sun_energy": 1.3, "sun_rot": Vector3(-30, 40, 0), "shadow_dist": 120.0, "saturation": 1.05, "contrast": 1.06}
		"jungle": return {"hdri": "kloofendal_48d_partly_cloudy_puresky", "sky_top": Color(0.2, 0.42, 0.72), "sky_energy": 1.0, "sky_ambient": true, "ambient": Color(0.5, 0.62, 0.45), "ambient_energy": 0.8, "fog": Color(0.42, 0.55, 0.4), "fog_density": 0.009, "vol_fog": 1.4, "sun": Color(1.0, 0.93, 0.75), "sun_energy": 1.6, "sun_rot": Vector3(-48, 30, 0), "shadow_dist": 120.0, "saturation": 1.18, "contrast": 1.05, "exposure": 1.1}
		"lava": return {"lamp": 0.9, "lamp_range": 14.0, "sky_top": Color(0.06, 0.012, 0.004), "sky_energy": 0.6, "ambient": Color(0.55, 0.24, 0.15), "ambient_energy": 0.6, "fog": Color(0.2, 0.055, 0.025), "fog_density": 0.016, "vol_fog": 1.0, "gi": 1.15, "sun": Color(1.0, 0.48, 0.28), "sun_energy": 0.55, "exposure": 1.25}
		"royal": return {"sky": false, "lamp": 0.9, "lamp_range": 9.0, "gi": 1.0, "vol_fog": 0.4, "bg": Color(0.03, 0.02, 0.03), "ambient": Color(0.75, 0.62, 0.5), "ambient_energy": 1.1, "fog": Color(0.12, 0.08, 0.06), "fog_density": 0.008, "sun_energy": 0.25, "saturation": 1.08, "contrast": 1.04}
		"library": return {"sky": false, "lamp": 0.7, "lamp_range": 10.0, "gi": 0.9, "vol_fog": 0.5, "bg": Color(0.02, 0.015, 0.01), "ambient": Color(0.7, 0.58, 0.42), "ambient_energy": 0.9, "fog": Color(0.1, 0.07, 0.04), "fog_density": 0.012, "sun_energy": 0.15, "saturation": 1.06, "contrast": 1.05}
		"treasury": return {"sky_top": Color(0.25, 0.32, 0.62), "sky_energy": 1.0, "sky_ambient": true, "lamp": 0.8, "lamp_range": 12.0, "gi": 1.0, "vol_fog": 1.2, "ambient": Color(0.85, 0.7, 0.45), "ambient_energy": 0.8, "fog": Color(0.85, 0.62, 0.35), "fog_density": 0.006, "sun": Color(1.0, 0.78, 0.5), "sun_energy": 1.7, "sun_rot": Vector3(-22, 160, 0), "shadow_dist": 120.0, "saturation": 1.12, "contrast": 1.06, "exposure": 1.0}
		"village": return {"hdri": "kloppenheim_06_puresky", "sky_top": Color(0.22, 0.45, 0.8), "sky_energy": 1.1, "sky_ambient": true, "ambient": Color(0.75, 0.68, 0.55), "ambient_energy": 0.7, "fog": Color(0.75, 0.68, 0.55), "fog_density": 0.006, "vol_fog": 1.4, "gi": 1.0, "sun": Color(1.0, 0.86, 0.66), "sun_energy": 1.6, "sun_rot": Vector3(-28, 55, 0), "shadow_dist": 140.0, "saturation": 1.15, "contrast": 1.06, "exposure": 1.05}
		"grassland": return {"hdri": "table_mountain_1_puresky", "sky_top": Color(0.2, 0.45, 0.82), "sky_energy": 1.15, "sky_ambient": true, "ambient": Color(0.7, 0.7, 0.6), "ambient_energy": 0.75, "fog": Color(0.7, 0.75, 0.78), "fog_density": 0.003, "vol_fog": 0.55, "gi": 1.0, "sun": Color(1.0, 0.93, 0.8), "sun_energy": 1.6, "sun_rot": Vector3(-42, 30, 0), "shadow_dist": 140.0, "saturation": 1.2, "contrast": 1.12, "clouds": 0.5}
		"cemetery": return {"hdri": "qwantani_night_puresky", "night": true, "hdri_energy": 0.6, "clouds": 0.35, "stars": 1.0, "cloud_col": Color(0.25, 0.28, 0.38), "sky_top": Color(0.03, 0.05, 0.12), "sky_energy": 0.35, "lamp": 0.9, "lamp_range": 11.0, "ambient": Color(0.3, 0.35, 0.5), "ambient_energy": 0.6, "fog": Color(0.18, 0.22, 0.3), "fog_density": 0.03, "vol_fog": 0.9, "gi": 0.8, "sun": Color(0.55, 0.65, 0.95), "sun_energy": 0.35, "sun_rot": Vector3(-35, 140, 0), "shadow_dist": 90.0, "saturation": 0.95, "contrast": 1.1, "exposure": 1.1}
		"city", "palace", "cathedral": return {"hdri": "citrus_orchard_road_puresky", "sky_top": Color(0.24, 0.44, 0.78), "sky_energy": 1.05, "sky_ambient": true, "ambient": Color(0.72, 0.68, 0.6), "ambient_energy": 0.7, "fog": Color(0.72, 0.68, 0.6), "fog_density": 0.004, "vol_fog": 0.6, "gi": 1.0, "sun": Color(1.0, 0.9, 0.74), "sun_energy": 1.5, "sun_rot": Vector3(-34, 35, 0), "shadow_dist": 140.0, "saturation": 1.12, "contrast": 1.1, "clouds": 0.4}
		"wall": return {"hdri": "qwantani_sunset_puresky", "sky_ambient": true, "ambient": Color(0.6, 0.55, 0.55), "ambient_energy": 0.7, "fog": Color(0.7, 0.55, 0.45), "fog_density": 0.004, "vol_fog": 0.3, "haze": 0.45, "hdri_energy": 0.7, "gi": 1.0, "lamp": 0.8, "lamp_range": 11.0, "sun_rot": Vector3(-12, 230, 0), "shadow_dist": 100.0, "saturation": 1.12, "contrast": 1.1}
		"forest": return {"hdri": "kloofendal_28d_misty_puresky", "sky_top": Color(0.22, 0.4, 0.62), "sky_energy": 0.9, "sky_ambient": true, "lamp": 0.6, "lamp_range": 10.0, "gi": 1.0, "vol_fog": 1.1, "ambient": Color(0.45, 0.55, 0.42), "ambient_energy": 0.75, "fog": Color(0.55, 0.62, 0.48), "fog_density": 0.012, "sun": Color(1.0, 0.9, 0.7), "sun_energy": 1.5, "sun_rot": Vector3(-38, 60, 0), "shadow_dist": 110.0, "saturation": 1.22, "contrast": 1.12, "exposure": 1.05}
		"swamp": return {"hdri": "evening_road_01_puresky", "sky_top": Color(0.32, 0.42, 0.48), "sky_energy": 0.85, "sky_ambient": true, "ambient": Color(0.5, 0.58, 0.48), "ambient_energy": 0.7, "fog": Color(0.55, 0.62, 0.52), "fog_density": 0.018, "vol_fog": 1.8, "gi": 1.0, "lamp": 0.7, "lamp_range": 9.0, "sun": Color(1.0, 0.86, 0.62), "sun_energy": 1.2, "sun_rot": Vector3(-22, 70, 0), "shadow_dist": 90.0, "saturation": 1.05, "contrast": 1.08, "exposure": 1.05}
		"battlefield": return {"hdri": "overcast_soil_puresky", "sky_top": Color(0.36, 0.38, 0.46), "sky_energy": 0.8, "sky_ambient": true, "ambient": Color(0.55, 0.55, 0.62), "ambient_energy": 0.7, "fog": Color(0.58, 0.58, 0.66), "fog_density": 0.014, "vol_fog": 1.5, "gi": 1.0, "lamp": 0.7, "lamp_range": 10.0, "sun": Color(0.92, 0.86, 0.82), "sun_energy": 1.0, "sun_rot": Vector3(-24, 130, 0), "shadow_dist": 90.0, "saturation": 0.8, "contrast": 1.1, "exposure": 0.82, "hdri_energy": 0.55, "haze": 1.6}
		"mountain", "peaks": return {"hdri": "farm_field_puresky", "sky_top": Color(0.18, 0.38, 0.72), "sky_energy": 1.1, "sky_ambient": true, "ambient": Color(0.62, 0.66, 0.74), "ambient_energy": 0.7, "exposure": 1.0, "fog": Color(0.7, 0.76, 0.86), "fog_density": 0.0025, "vol_fog": 0.35, "gi": 1.0, "lamp": 0.7, "lamp_range": 10.0, "sun": Color(1.0, 0.95, 0.88), "sun_energy": 1.7, "sun_rot": Vector3(-36, 50, 0), "shadow_dist": 100.0, "saturation": 1.12, "contrast": 1.12, "clouds": 0.35}
	return {}


# =====================================================================
#  Gemeinsame Elemente
# =====================================================================

## Gate-Licht: unter Forward+ verteilt SDFGI es im ganzen Raum – deutlich schwächer.
static func _gate_energy() -> float:
	return 0.6 if is_forward_plus() else 2.0


## Gate: magisches Portal (Teleport zwischen den Orten).
static func _gate(root: Node3D, pos: Vector3) -> void:
	if ModelLib.place_prop(root, "gate_portal", pos):
		B3.light(root, pos + Vector3(0, 2, 1), VIOLET, _gate_energy(), 7.0)
		return
	var g := Node3D.new()
	g.name = "GatePortal"
	g.position = pos
	root.add_child(g)
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.75
	tm.rings = 32
	var ring := B3.mesh(g, tm, Vector3(0, 2.0, 0), B3.mat(Color(0.2, 0.05, 0.3), 0.3, 0.6, VIOLET, 2.5), Vector3(90, 0, 0))
	ring.set_meta("spin", 0.4)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.02
	B3.mesh(g, disc, Vector3(0, 2.0, 0), B3.mat(Color(0.05, 0.0, 0.1, 0.85), 0.0, 0.0, Color(0.25, 0.05, 0.45), 1.5), Vector3(90, 0, 0))
	B3.cyl(g, 1.6, 1.8, 0.2, Vector3(0, 0.1, 0), B3.mat(Color(0.08, 0.06, 0.1), 0.6, 0.3), true, 20)
	B3.light(g, Vector3(0, 2, 1), VIOLET, _gate_energy(), 5.0 if is_forward_plus() else 7.0)
	B3.motes(g, Vector3(0, 2, 0), Vector3(1.2, 1.2, 0.2), Color(0.7, 0.4, 1.0), 30)
	# Leuchtender Ring/Scheibe nicht in die globale Beleuchtung (SDFGI) einspeisen,
	# sonst färbt das Portal ganze Räume violett.
	for mi in g.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED


## Verteilt n Plätze im Halbkreis (für Figuren).
static func _arc(center: Vector3, r: float, n: int, from_deg: float, to_deg: float) -> Array:
	var out: Array = []
	for i in n:
		var t := 0.5 if n == 1 else float(i) / (n - 1)
		var a := deg_to_rad(lerpf(from_deg, to_deg, t))
		out.append(center + Vector3(sin(a) * r, 0, cos(a) * r))
	return out


static func _scatter(n: int, half: float, keep_clear: Array, clear_r: float) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < n * 20:
		tries += 1
		var p := Vector3(_rng.randf_range(-half, half), 0, _rng.randf_range(-half, half))
		var ok := true
		for c in keep_clear:
			if Vector2(p.x - c.x, p.z - c.z).length() < clear_r:
				ok = false
				break
		if ok:
			out.append(p)
	return out


# =====================================================================
#  Nazarick
# =====================================================================

static func _throne(root: Node3D) -> Dictionary:
	var marble := B3.noise_mat(Color(0.05, 0.03, 0.08), Color(0.16, 0.1, 0.22), 0.05, 0.25)
	var stone := B3.noise_mat(Color(0.08, 0.06, 0.1), Color(0.2, 0.16, 0.24), 0.07, 0.6)
	var gold := B3.mat(GOLD, 0.3, 0.9)
	var w := 13.0
	var l := 30.0
	B3.ground(root, 40, marble)
	# Wände, Decke
	B3.box(root, Vector3(1, 16, l * 2), Vector3(-w, 8, 0), stone)
	B3.box(root, Vector3(1, 16, l * 2), Vector3(w, 8, 0), stone)
	B3.box(root, Vector3(w * 2, 16, 1), Vector3(0, 8, -l), stone)
	B3.box(root, Vector3(w * 2, 16, 1), Vector3(0, 8, l), stone)
	B3.box(root, Vector3(w * 2, 1, l * 2), Vector3(0, 16.5, 0), stone, false)
	# Roter Teppich und Säulenreihen mit den 41 Gildenbannern
	B3.box(root, Vector3(4, 0.04, l * 2 - 8), Vector3(0, 0.02, 2), B3.mat(Color(0.45, 0.02, 0.06), 0.9), false)
	B3.box(root, Vector3(4.4, 0.03, l * 2 - 8), Vector3(0, 0.015, 2), gold, false)
	var crest: Texture2D = Palette.icon("faction_nazarick")
	for i in 6:
		var z := -18.0 + i * 8.0
		for s in [-1.0, 1.0]:
			B3.pillar(root, Vector3(7.5 * s, 0, z), 15.5, 0.7, stone, gold)
			B3.banner(root, Vector3((w - 0.6) * s, 14, z + 4), Color(0.2, 0.04, 0.3), crest, 6.0, 90.0 * s)
			B3.crystal(root, Vector3((w - 1.5) * s, 0, z), VIOLET, 2.2)
	# Thronpodest mit Stufen
	var dais_z := -24.0
	B3.box(root, Vector3(12, 1.2, 8), Vector3(0, 0.6, dais_z - 1), marble)
	B3.stairs(root, Vector3(0, 0, dais_z + 4.5), 8, 3, 0.4, 0.6, marble)
	B3.box(root, Vector3(3.2, 1.0, 2.2), Vector3(0, 1.7, dais_z - 1.5), gold)
	B3.box(root, Vector3(3.4, 6.5, 0.6), Vector3(0, 4.4, dais_z - 2.6), gold)
	B3.box(root, Vector3(2.4, 5.5, 0.4), Vector3(0, 4.4, dais_z - 2.2), B3.mat(Color(0.1, 0.02, 0.15), 0.4))
	B3.crystal(root, Vector3(0, 7.6, dais_z - 2.6), Color(0.9, 0.1, 0.25), 1.6)
	for s in [-1.0, 1.0]:
		B3.box(root, Vector3(0.6, 1.8, 2.2), Vector3(1.6 * s, 2.3, dais_z - 1.5), gold)
		B3.brazier(root, Vector3(4.5 * s, 1.2, dais_z + 1))
	B3.light(root, Vector3(0, 9, dais_z), Color(0.8, 0.5, 1.0), 2.5, 16)
	# Riesiges Fenster aus Licht hinter dem Thron
	B3.box(root, Vector3(8, 10, 0.2), Vector3(0, 9, -l + 0.6), B3.mat(Color(0.3, 0.1, 0.5), 0.2, 0.0, Color(0.45, 0.15, 0.8), 1.6), false)
	# Kriegstisch mit der Weltkarte, Albedos Pult (Verwaltung & Wochenziele)
	var table := Vector3(-8.0, 0, 6.0)
	var desk := Vector3(8.0, 0, 6.0)
	_war_table(root, table)
	_desk(root, desk)
	B3.motes(root, Vector3(0, 6, 0), Vector3(10, 5, 25), Color(0.7, 0.5, 1.0), 80)
	B3.bounds(root, 40)
	var slots: Array = []
	for i in 5:
		slots.append(Vector3(-3.5, 0, -16.0 + i * 3.2))
		slots.append(Vector3(3.5, 0, -16.0 + i * 3.2))
	return {"spawn": Vector3(0, 0.2, 14), "yaw": 0.0, "gate": Vector3(0, 0, 25), "slots": slots,
		"throne": Vector3(0, 1.2, dais_z + 1.5), "table": table, "desk": desk, "keeper": Vector3(-2.5, 1.2, dais_z + 0.5)}


## Kriegstisch mit Reliefkarte und Spielfiguren.
## Teppichbahn: flacher Quader, UV über die Oberseite (u quer, v längs).
static func _carpet_mesh(w: float, l: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.02
	var corners := [Vector3(-w / 2, h, -l / 2), Vector3(w / 2, h, -l / 2), Vector3(w / 2, h, l / 2), Vector3(-w / 2, h, l / 2)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
	for side in [[0, 1], [1, 2], [2, 3], [3, 0]]:
		var a: Vector3 = corners[side[0]]
		var b: Vector3 = corners[side[1]]
		var n := (b - a).cross(Vector3.UP).normalized() * -1.0
		for p in [a, b, b - Vector3(0, h, 0), a, b - Vector3(0, h, 0), a - Vector3(0, h, 0)]:
			st.set_normal(n)
			st.set_uv(Vector2(0.02, 0.5))
			st.add_vertex(p)
	return st.commit()


static func _war_table(root: Node3D, table: Vector3) -> void:
	# Schwerer Eichentisch des Kriegsrats: dicke Platte, Zarge, gedrechselte Beine, Querstreben
	var oak := BuildingLook.photo_material("planks", "wood", Color(0.62, 0.48, 0.36))
	var dark := BuildingLook.photo_material("wood", "wood", Color(0.45, 0.34, 0.26))
	var size := Vector2(3.8, 2.4)
	var top_y := 0.96
	B3.box(root, Vector3(size.x, 0.1, size.y), table + Vector3(0, top_y - 0.05, 0), oak)
	B3.box(root, Vector3(size.x + 0.08, 0.04, size.y + 0.08), table + Vector3(0, top_y - 0.1, 0), dark, false)
	for sx in [-1, 1]:
		B3.box(root, Vector3(0.08, 0.16, size.y - 0.3), table + Vector3(sx * (size.x / 2 - 0.2), top_y - 0.18, 0), dark, false)
		B3.box(root, Vector3(size.x - 0.4, 0.16, 0.08), table + Vector3(0, top_y - 0.18, sx * (size.y / 2 - 0.15)), dark, false)
		for sz in [-1, 1]:
			var lp := table + Vector3(sx * (size.x / 2 - 0.22), 0, sz * (size.y / 2 - 0.18))
			B3.cyl(root, 0.08, 0.1, 0.12, lp + Vector3(0, 0.06, 0), dark, false, 12)
			B3.cyl(root, 0.06, 0.075, 0.42, lp + Vector3(0, 0.33, 0), dark, false, 12)
			B3.sphere(root, 0.085, lp + Vector3(0, 0.58, 0), dark, Vector3(1, 0.8, 1))
			B3.cyl(root, 0.075, 0.06, 0.2, lp + Vector3(0, 0.74, 0), dark, false, 12)
	B3.box(root, Vector3(size.x - 0.5, 0.07, 0.07), table + Vector3(0, 0.22, 0), dark, false)
	# Karte auf Pergament (prozedural), Ecken mit Bechern/Leuchtern beschwert
	var map_mat := StandardMaterial3D.new()
	map_mat.albedo_texture = _parchment_map()
	map_mat.roughness = 0.92
	map_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var map := B3.box(root, Vector3(3.3, 0.006, 2.0), table + Vector3(0, top_y + 0.004, 0), map_mat, false)
	map.rotation.y = deg_to_rad(1.5)
	# Figuren aus dem Schachspiel (Fotoscan) als Heeresmarken: zwei Farben, Gruppen
	var pieces: Array = PhProps.variants("chess_set")
	if pieces.size() > 2:
		var by_size := pieces.duplicate()
		by_size.sort_custom(func(a, b): return (a.size as Vector3).length() > (b.size as Vector3).length())
		by_size.remove_at(0)                                     # Brett
		for g in 7:
			var gp := table + Vector3(_rng.randf_range(-1.35, 1.35), top_y + 0.01, _rng.randf_range(-0.75, 0.75))
			for i in _rng.randi_range(1, 3):
				var v: Dictionary = by_size[_rng.randi() % by_size.size()]
				var mi := MeshInstance3D.new()
				mi.mesh = v.mesh
				var off := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12))
				mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 1.7), gp + off) * (v.xf as Transform3D)
				root.add_child(mi)
	for c in [Vector3(-1.55, 0, -0.9), Vector3(1.55, 0, 0.9)]:
		PhProps.attach(root, "brass_candleholders", Transform3D(Basis().scaled(Vector3.ONE * 0.6), table + c + Vector3(0, top_y, 0)))
		B3.light(root, table + c + Vector3(0, top_y + 0.7, 0), Color(1.0, 0.72, 0.42), 1.1, 5.5).set_meta("flicker", true)
	PhProps.attach(root, "brass_goblets", Transform3D(Basis(Vector3.UP, 0.4), table + Vector3(1.5, top_y, -0.85)))
	PhProps.attach(root, "book_encyclopedia_set_01", Transform3D(Basis(Vector3.UP, -0.2), table + Vector3(-1.45, top_y, 0.82)))
	B3.light(root, table + Vector3(0, 3, 0), Color(1, 0.85, 0.6), 1.2, 6)


static var _map_tex: ImageTexture
static var _carpet_tex: ImageTexture


## Alte Landkarte auf Pergament: Küsten (Tusche), Meer, Gebirge, Wälder, Flüsse, Grenzen, verbrannte Ränder.
static func _parchment_map() -> ImageTexture:
	if _map_tex:
		return _map_tex
	var W := 640
	var H := 388
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var land := FastNoiseLite.new()
	land.seed = 17
	land.frequency = 0.006
	land.fractal_octaves = 5
	var fine := FastNoiseLite.new()
	fine.seed = 5
	fine.frequency = 0.08
	var forest := FastNoiseLite.new()
	forest.seed = 9
	forest.frequency = 0.03
	var border := FastNoiseLite.new()
	border.seed = 23
	border.noise_type = FastNoiseLite.TYPE_CELLULAR
	border.frequency = 0.012
	border.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	for y in H:
		for x in W:
			var h := land.get_noise_2d(x, y) + 0.12 - 0.35 * pow(absf(float(x) / W - 0.5) * 2.0, 3.0)
			var g := fine.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Color(0.8, 0.7, 0.52).lerp(Color(0.7, 0.58, 0.4), g * 0.7)
			if h < -0.06:
				c = c.lerp(Color(0.5, 0.55, 0.5), 0.45 + 0.1 * g)                       # Meer
				if int(y) % 9 == 0 and h > -0.2 and fine.get_noise_2d(x * 3, y) > 0.0:
					c = c.darkened(0.12)                                                 # Wellenstriche
			elif h < -0.035:
				c = Color(0.22, 0.16, 0.1)                                               # Küstenlinie
			elif h > 0.34:
				c = c.lerp(Color(0.45, 0.35, 0.24), 0.55)                                # Gebirge
				if fine.get_noise_2d(x * 2.0, y * 2.0) > 0.35:
					c = c.darkened(0.35)
			elif forest.get_noise_2d(x, y) > 0.28:
				c = c.lerp(Color(0.42, 0.45, 0.28), 0.4)                                 # Wälder
				if fine.get_noise_2d(x * 2.5, y * 2.5) > 0.4:
					c = c.darkened(0.25)
			if h >= -0.035 and absf(border.get_noise_2d(x, y)) < 0.012 and (int(x / 3) + int(y / 3)) % 2 == 0:
				c = c.lerp(Color(0.55, 0.08, 0.06), 0.8)                                 # Reichsgrenzen (gestrichelt)
			var ex := minf(x, W - 1 - x) / float(W)
			var ey := minf(y, H - 1 - y) / float(H)
			var edge := clampf(minf(ex, ey * float(H) / W) * 14.0 + (g - 0.5) * 0.4, 0.0, 1.0)
			c = c.lerp(Color(0.2, 0.13, 0.07), (1.0 - edge) * 0.85)
			img.set_pixel(x, y, c)
	# Flüsse: von Gebirgen zur Küste (einfacher Abstieg über das Höhenfeld)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for r in 9:
		var p := Vector2(rng.randf_range(40, W - 40), rng.randf_range(40, H - 40))
		for step in 260:
			var hx := land.get_noise_2d(p.x, p.y)
			if hx < -0.04:
				break
			var gx := land.get_noise_2d(p.x + 2, p.y) - land.get_noise_2d(p.x - 2, p.y)
			var gy := land.get_noise_2d(p.x, p.y + 2) - land.get_noise_2d(p.x, p.y - 2)
			var d := -Vector2(gx, gy).normalized() + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
			p += d.normalized() * 1.5
			if p.x < 2 or p.y < 2 or p.x > W - 3 or p.y > H - 3:
				break
			img.set_pixel(int(p.x), int(p.y), Color(0.3, 0.38, 0.45))
	# Städte: kleine Burgsymbole (Kreise mit Punkt)
	for t in 11:
		var q := Vector2i(rng.randi_range(30, W - 30), rng.randi_range(30, H - 30))
		if land.get_noise_2d(q.x, q.y) < 0.0:
			continue
		for a in 24:
			var ang := a / 24.0 * TAU
			img.set_pixel(q.x + int(cos(ang) * 4), q.y + int(sin(ang) * 4), Color(0.2, 0.12, 0.08))
		img.set_pixel(q.x, q.y, Color(0.5, 0.06, 0.05))
	img.generate_mipmaps()
	_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


## Teppich des Thronsaals: tiefes Karmesin, Goldborte mit Muster, Rautenfeld in der Mitte, leicht abgetreten.
static func _carpet_texture() -> ImageTexture:
	if _carpet_tex:
		return _carpet_tex
	var N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var fine := FastNoiseLite.new()
	fine.seed = 31
	fine.frequency = 0.15
	var wear := FastNoiseLite.new()
	wear.seed = 2
	wear.frequency = 0.02
	for y in N:
		for x in N:
			var u := float(x) / N
			var v := float(y) / N
			var base := Color(0.36, 0.02, 0.05)
			var e := minf(u, 1.0 - u)
			var c := base
			if e < 0.035:
				c = Color(0.18, 0.01, 0.03)                                   # dunkler Rand
			elif e < 0.11:
				c = Color(0.62, 0.43, 0.13)                                   # Goldborte
				var m := absf(fmod(v * 16.0, 1.0) - 0.5) + absf((e - 0.0725) * 26.0)
				if m < 0.32:
					c = Color(0.3, 0.03, 0.06)                                # Muster in der Borte
			elif e < 0.125:
				c = Color(0.18, 0.01, 0.03)
			else:
				var du := absf((u - 0.5) * 2.0)
				var dv := absf(fmod(v * 2.0, 1.0) - 0.5) * 2.0
				var diamond := du * 1.3 + dv
				if absf(diamond - 0.7) < 0.035 or absf(diamond - 0.45) < 0.02:
					c = Color(0.62, 0.43, 0.13)
				elif diamond < 0.45:
					c = Color(0.26, 0.04, 0.12)                               # Medaillon (Violett-Ton)
					if absf(fmod(du * 6.0 + dv * 6.0, 1.0) - 0.5) < 0.1:
						c = Color(0.55, 0.36, 0.12)
			var n := fine.get_noise_2d(x, y) * 0.5 + 0.5
			c = c.darkened(0.12 * n) * (1.0 - 0.18 * maxf(0.0, wear.get_noise_2d(x, y * 3.0)))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_carpet_tex = ImageTexture.create_from_image(img)
	return _carpet_tex


## Albedos Pult: Schreibtisch mit Schubladen (Fotoscan), Bücherstapel, Leuchter, Kristallkugel auf Messingschale.
static func _desk(root: Node3D, desk: Vector3) -> void:
	var size := PhProps.attach(root, "WoodenTable_03", Transform3D(Basis().scaled(Vector3.ONE * 1.15), desk))
	var top_y: float = (size.y if size != Vector3.ZERO else 0.83) * 1.15
	if size == Vector3.ZERO:
		B3.box(root, Vector3(1.5, top_y, 0.7), desk + Vector3(0, top_y / 2, 0), BuildingLook.photo_material("wood"))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, top_y, 0.7)
	cs.shape = shape
	cs.position = desk + Vector3(0, top_y / 2, 0)
	body.add_child(cs)
	root.add_child(body)
	PhProps.attach(root, "book_encyclopedia_set_01", Transform3D(Basis(Vector3.UP, 0.25).scaled(Vector3.ONE * 0.8), desk + Vector3(-0.45, top_y, -0.05)))
	PhProps.attach(root, "wooden_candlestick", Transform3D(Basis(), desk + Vector3(0.55, top_y, 0.12)))
	B3.light(root, desk + Vector3(0.55, top_y + 0.35, 0.12), Color(1.0, 0.7, 0.4), 0.8, 4.0).set_meta("flicker", true)
	PhProps.attach(root, "brass_pot_01", Transform3D(Basis().scaled(Vector3(0.55, 0.3, 0.55)), desk + Vector3(0.15, top_y, -0.1)))
	var orb := StandardMaterial3D.new()
	orb.albedo_color = Color(0.55, 0.3, 0.85, 0.55)
	orb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb.roughness = 0.05
	orb.metallic_specular = 1.0
	orb.emission_enabled = true
	orb.emission = VIOLET
	orb.emission_energy_multiplier = 1.4
	orb.rim_enabled = true
	orb.rim = 0.6
	B3.sphere(root, 0.15, desk + Vector3(0.15, top_y + 0.22, -0.1), orb)
	for i in 5:                                                   # lose Blätter
		var paper := B3.box(root, Vector3(0.21, 0.002, 0.29), desk + Vector3(_rng.randf_range(-0.2, 0.3), top_y + 0.002 + i * 0.001, _rng.randf_range(0.0, 0.2)),
			B3.mat(Color(0.86, 0.82, 0.72), 0.9), false)
		paper.rotation.y = _rng.randf_range(-0.6, 0.6)
	B3.light(root, desk + Vector3(0, 2.5, 0), Color(0.9, 0.7, 1.0), 0.9, 5)


## Ausstattung eines Ortsmodells über benannte Anker:
##   Banner_n (Gildenbanner), Fire_n (Feuer), Lamp_n (warmes Licht), Violet_n (violettes Licht)
## Im Thronsaal zusätzlich roter Teppich zum Thron, Kriegstisch (Table) und Pult (Desk).
static func _model_dressing(loc: Dictionary, root: Node3D, named: Dictionary, a: Dictionary) -> void:
	var crest: Texture2D = Palette.icon("faction_nazarick")
	var walk: Array = []
	var idle: Array = []
	for key in named:
		var n := named[key] as Node3D
		if n is Light3D or n is MeshInstance3D:
			continue   # nur leere Ankerpunkte, keine Lampen/Meshes aus dem Modell (z. B. Lamp_n der Grabkammern)
		var p := n.global_position
		if key.begins_with("banner_"):
			B3.banner(root, p, Color(0.2, 0.04, 0.3), crest, 5.5, -90.0 * signf(p.x))
		elif key.begins_with("fire_"):
			B3.light(root, p + Vector3(0, 0.4, 0), Color(1.0, 0.55, 0.22), 2.2, 9.0).set_meta("flicker", true)
			B3.motes(root, p + Vector3(0, 0.8, 0), Vector3(0.4, 0.6, 0.4), Color(1.0, 0.6, 0.2), 16)
		elif key.begins_with("lamp_"):
			B3.light(root, p, Color(1.0, 0.78, 0.5), 2.6, 14.0)
		elif key.begins_with("violet_"):
			B3.light(root, p, VIOLET, 3.0, 14.0)
		elif key.begins_with("smoke_"):
			if Settings.particles or _rng.randf() < 0.3:
				B3.smoke(root, p)
		elif key.begins_with("walk_"):
			walk.append(p)
		elif key.begins_with("idle_"):
			idle.append(p)
	# Bewohner nur in Siedlungen; Städte voller als Dörfer
	var crowd := {"city": 40, "palace": 34, "cathedral": 34, "village": 22, "wall": 16}
	if (not walk.is_empty() or not idle.is_empty()) and crowd.has(loc.get("kind", "")):
		Townsfolk.spawn(root, walk, idle, hash(loc.id), int(crowd[loc.kind]))
	if loc.kind == "glacier":
		# Schneefall rund um den Spieler-Startbereich und über dem Tempel
		B3.motes(root, a.spawn + Vector3(0, 8, -20), Vector3(45, 8, 45), Color(0.95, 0.97, 1.0), 900 if Settings.particles else 250, 1.2)
	if loc.kind in ["village", "city", "jungle", "forest"] and Settings.particles:
		# Schwebende Pollen im Sonnenlicht, im Dschungel/Wald zusätzlich Glühwürmchen
		B3.motes(root, a.spawn + Vector3(0, 2.5, -15), Vector3(40, 2.5, 40), Color(1.0, 0.95, 0.7, 0.6), 140)
		if loc.kind in ["jungle", "forest"]:
			B3.motes(root, a.spawn + Vector3(0, 1.5, -10), Vector3(30, 1.5, 30), Color(0.7, 1.0, 0.4), 60)
	if loc.kind == "throne":
		if a.has("throne"):
			var start: Vector3 = a.gate
			var end: Vector3 = a.throne
			var mid := (start + end) / 2.0
			var length := end.distance_to(start) + 2.0
			var cm := StandardMaterial3D.new()
			cm.albedo_texture = _carpet_texture()
			cm.uv1_scale = Vector3(1.0, length / 3.6, 1.0)
			cm.uv1_triplanar = false
			cm.roughness = 0.97
			cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			var carpet := B3.mesh(root, _carpet_mesh(3.6, length), Vector3(mid.x, 0.035, mid.z), cm)
			carpet.rotation.y = atan2(end.x - start.x, end.z - start.z)
		if a.has("table"):
			_war_table(root, a.table)
		if a.has("desk"):
			_desk(root, a.desk)
		B3.motes(root, a.spawn + Vector3(0, 5, -20), Vector3(8, 4, 22), Color(0.7, 0.5, 1.0), 70)


## Gemeinsames Gerüst für die Ebenen: Boden, Begrenzung, Wächter-Platz.
static func _floor_base(root: Node3D, ground_mat: Material, half: float = 32.0) -> void:
	B3.ground(root, half, ground_mat)
	B3.bounds(root, half)


static func _tombs(root: Node3D) -> Dictionary:
	var stone := B3.noise_mat(Color(0.07, 0.08, 0.07), Color(0.2, 0.22, 0.2), 0.08, 0.8)
	_floor_base(root, stone)
	var coffin := B3.mat(Color(0.12, 0.08, 0.06), 0.7)
	var wall := B3.noise_mat(Color(0.06, 0.06, 0.06), Color(0.18, 0.18, 0.17), 0.12, 0.9)
	# Labyrinth aus Gruftwänden
	for i in 7:
		var x := -24.0 + i * 8.0
		B3.box(root, Vector3(1.2, 6, 20), Vector3(x, 3, -12 if i % 2 == 0 else 8), wall)
		for j in 3:
			B3.box(root, Vector3(1.0, 0.7, 2.4), Vector3(x + 2.5, 0.35, -16 + j * 10), coffin)
			B3.box(root, Vector3(1.1, 0.12, 2.5), Vector3(x + 2.5, 0.76, -16 + j * 10), B3.mat(Color(0.3, 0.25, 0.2), 0.6), false)
	for p in [Vector3(-20, 0, 0), Vector3(-4, 0, 14), Vector3(12, 0, -4), Vector3(22, 0, 10), Vector3(4, 0, -20)]:
		B3.brazier(root, p, Color(0.3, 1.0, 0.5))
	B3.box(root, Vector3(64, 1, 64), Vector3(0, 9, 0), wall, false)
	B3.motes(root, Vector3(0, 2, 0), Vector3(28, 2, 28), Color(0.4, 1.0, 0.6), 60)
	return {"spawn": Vector3(0, 0.2, 24), "yaw": 0.0, "gate": Vector3(0, 0, 28), "keeper": Vector3(0, 0, 4), "slots": _arc(Vector3(0, 0, 4), 4, 4, 120, 240)}


static func _glacier(root: Node3D) -> Dictionary:
	var ice := B3.noise_mat(Color(0.35, 0.5, 0.7), Color(0.65, 0.78, 0.92), 0.04, 0.15)
	_floor_base(root, ice, 40)
	var spike := B3.mat(Color(0.6, 0.85, 1.0, 0.9), 0.05, 0.1, Color(0.25, 0.5, 0.9), 1.2)
	for p in _scatter(40, 36, [Vector3.ZERO, Vector3(0, 0, 30)], 9.0):
		B3.cone(root, _rng.randf_range(0.6, 1.6), _rng.randf_range(2.5, 9.0), p, spike, true)
	# Cocytus' Eispalast
	B3.box(root, Vector3(14, 10, 8), Vector3(0, 5, -26), B3.mat(Color(0.7, 0.85, 1.0, 0.95), 0.05, 0.1, Color(0.2, 0.45, 0.8), 0.8))
	for s in [-1.0, 1.0]:
		B3.cone(root, 2.0, 16, Vector3(7 * s, 0, -26), spike, true)
	B3.light(root, Vector3(0, 6, -18), Color(0.5, 0.75, 1.0), 3.0, 18)
	B3.motes(root, Vector3(0, 8, 0), Vector3(36, 6, 36), Color(0.9, 0.95, 1.0), 160, 0.6)
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 32), "keeper": Vector3(0, 0, -14), "slots": _arc(Vector3(0, 0, -14), 5, 4, 140, 220)}


static func _jungle(root: Node3D) -> Dictionary:
	var grass := B3.noise_mat(Color(0.08, 0.16, 0.06), Color(0.2, 0.32, 0.12), 0.06, 0.95)
	_floor_base(root, grass, 45)
	var trunk := B3.mat(Color(0.18, 0.12, 0.08))
	var leaves := B3.noise_mat(Color(0.05, 0.2, 0.06), Color(0.15, 0.38, 0.12), 0.2, 0.9)
	# Amphitheater: Ringe aus Stufen
	var stone := B3.noise_mat(Color(0.35, 0.32, 0.28), Color(0.55, 0.5, 0.44), 0.1, 0.8)
	for i in 4:
		var r := 14.0 + i * 1.6
		var tm := TorusMesh.new()
		tm.inner_radius = r
		tm.outer_radius = r + 1.6
		tm.rings = 48
		B3.mesh(root, tm, Vector3(0, 0.4 + i * 0.8, -6), stone, Vector3.ZERO, Vector3(1, 1.0 + i * 0.6, 1))
	B3.ground(root, 12, B3.noise_mat(Color(0.45, 0.38, 0.25), Color(0.6, 0.52, 0.36), 0.15, 0.95), 0.02)
	for p in _scatter(70, 42, [Vector3(0, 0, -6), Vector3(0, 0, 34)], 21.0):
		B3.tree(root, p, _rng.randf_range(7, 14), trunk, leaves)
	B3.motes(root, Vector3(0, 3, 0), Vector3(40, 3, 40), Color(0.8, 1.0, 0.4), 120)
	return {"spawn": Vector3(0, 0.2, 30), "yaw": 0.0, "gate": Vector3(0, 0, 36), "keeper": Vector3(-2, 0, -4), "slots": _arc(Vector3(0, 0, -6), 6, 6, 120, 240)}


static func _lava(root: Node3D) -> Dictionary:
	var rockm := B3.noise_mat(Color(0.06, 0.03, 0.02), Color(0.22, 0.1, 0.06), 0.09, 0.8)
	_floor_base(root, rockm, 40)
	var lava := B3.noise_mat(Color(1.0, 0.3, 0.02), Color(1.0, 0.75, 0.2), 0.08, 1.0, Color(1.0, 0.4, 0.05))
	# Lavaflüsse (leicht abgesenkt, nicht begehbar)
	for z in [-16.0, 6.0]:
		B3.box(root, Vector3(80, 0.1, 5), Vector3(0, 0.03, z), lava, false)
		for s in [-1.0, 1.0]:
			B3.wall_invisible(root, Vector3(38, 4, 5), Vector3(21.2 * s, 2, z))
		B3.light(root, Vector3(-15, 1.5, z), Color(1, 0.4, 0.1), 3.0, 14)
		B3.light(root, Vector3(15, 1.5, z), Color(1, 0.4, 0.1), 3.0, 14)
		# Brücke
		B3.box(root, Vector3(4, 0.4, 7), Vector3(0, 0.2, z), B3.mat(Color(0.15, 0.08, 0.05), 0.7))
		for s in [-1.0, 1.0]:
			B3.box(root, Vector3(0.3, 1.0, 7), Vector3(2 * s, 0.7, z), B3.mat(Color(0.15, 0.08, 0.05), 0.7))
	# Teufelspalast
	var dark := B3.mat(Color(0.12, 0.04, 0.04), 0.6, 0.2)
	B3.box(root, Vector3(16, 9, 8), Vector3(0, 4.5, -28), dark)
	for s in [-1.0, 0.0, 1.0]:
		B3.cone(root, 1.6, 14 if s == 0.0 else 10, Vector3(6 * s, 9, -28), dark)
	for p in _scatter(18, 36, [Vector3(0, 0, -16), Vector3(0, 0, 6), Vector3(0, 0, 30), Vector3(0, 0, -28)], 7.0):
		B3.cone(root, _rng.randf_range(1, 2.5), _rng.randf_range(3, 8), p, rockm, true)
	B3.motes(root, Vector3(0, 4, 0), Vector3(36, 4, 36), Color(1.0, 0.45, 0.1), 140)
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 32), "keeper": Vector3(0, 0, -20), "slots": _arc(Vector3(0, 0, -20), 5, 4, 130, 230)}


static func _royal(root: Node3D) -> Dictionary:
	var marble := B3.noise_mat(Color(0.75, 0.7, 0.62), Color(0.95, 0.92, 0.85), 0.05, 0.2)
	var wall := B3.noise_mat(Color(0.18, 0.08, 0.1), Color(0.3, 0.14, 0.16), 0.1, 0.6)
	var gold := B3.mat(GOLD, 0.3, 0.9)
	_floor_base(root, marble, 22)
	for s in [-1.0, 1.0]:
		B3.box(root, Vector3(1, 10, 44), Vector3(21 * s, 5, 0), wall)
		B3.box(root, Vector3(44, 10, 1), Vector3(0, 5, 21 * s), wall)
	B3.box(root, Vector3(44, 1, 44), Vector3(0, 10.5, 0), wall, false)
	B3.box(root, Vector3(10, 0.03, 30), Vector3(0, 0.02, 0), B3.mat(Color(0.35, 0.05, 0.12), 0.95), false)
	# Kronleuchter
	for z in [-10.0, 0.0, 10.0]:
		B3.cyl(root, 1.2, 0.5, 0.6, Vector3(0, 8.5, z), gold, false)
		B3.light(root, Vector3(0, 7.8, z), Color(1, 0.85, 0.6), 2.5, 14)
		B3.sphere(root, 0.25, Vector3(0, 8.0, z), B3.mat(Color(1, 0.9, 0.7), 1, 0, Color(1, 0.85, 0.5), 4))
	# Sitzgruppen, Bar, Bad
	for p in [Vector3(-12, 0, -10), Vector3(12, 0, -10), Vector3(-12, 0, 8)]:
		B3.box(root, Vector3(3, 0.6, 1.2), p + Vector3(0, 0.3, 0), B3.mat(Color(0.35, 0.08, 0.15), 0.9))
		B3.box(root, Vector3(1.6, 0.8, 1.6), p + Vector3(0, 0.4, 2.2), gold)
	B3.box(root, Vector3(8, 1.2, 1.2), Vector3(12, 0.6, 10), B3.mat(Color(0.2, 0.1, 0.06), 0.4))
	B3.box(root, Vector3(6, 0.2, 6), Vector3(-12, 0.05, -2), B3.mat(Color(0.3, 0.6, 0.9, 0.8), 0.05, 0.0, Color(0.1, 0.3, 0.5), 0.6), false)
	return {"spawn": Vector3(0, 0.2, 14), "yaw": 0.0, "gate": Vector3(0, 0, 18), "keeper": Vector3(0, 0, -12), "slots": _arc(Vector3(0, 0, -6), 6, 4, 130, 230)}


static func _library(root: Node3D) -> Dictionary:
	var wood := B3.noise_mat(Color(0.16, 0.09, 0.05), Color(0.3, 0.18, 0.09), 0.2, 0.7)
	var floor_m := B3.noise_mat(Color(0.1, 0.07, 0.05), Color(0.2, 0.14, 0.09), 0.08, 0.5)
	_floor_base(root, floor_m, 26)
	var books := [Color(0.5, 0.1, 0.1), Color(0.1, 0.2, 0.45), Color(0.15, 0.35, 0.15), Color(0.45, 0.35, 0.1), Color(0.3, 0.1, 0.35)]
	for row in 6:
		for s in [-1.0, 1.0]:
			var x: float = s * (5.0 + row * 3.4)
			B3.box(root, Vector3(1.0, 7, 30), Vector3(x, 3.5, -2), wood)
			for k in 5:
				B3.box(root, Vector3(1.05, 0.9, 28), Vector3(x, 0.8 + k * 1.3, -2), B3.mat(books[(row + k) % books.size()], 0.8), false)
	for z in [-12.0, 0.0, 12.0]:
		B3.sphere(root, 0.3, Vector3(0, 4, z), B3.mat(Color(1, 0.9, 0.6), 1, 0, Color(1, 0.8, 0.4), 4))
		B3.light(root, Vector3(0, 4, z), Color(1, 0.8, 0.5), 2.0, 12)
	B3.motes(root, Vector3(0, 3, 0), Vector3(20, 3, 20), Color(1.0, 0.85, 0.5), 80)
	return {"spawn": Vector3(0, 0.2, 18), "yaw": 0.0, "gate": Vector3(0, 0, 22), "keeper": Vector3(0, 0, -14), "slots": _arc(Vector3(0, 0, -10), 3, 3, 150, 210)}


static func _treasury(root: Node3D) -> Dictionary:
	var floor_m := B3.noise_mat(Color(0.2, 0.15, 0.05), Color(0.45, 0.35, 0.1), 0.08, 0.4)
	_floor_base(root, floor_m, 26)
	var gold := B3.mat(GOLD, 0.25, 1.0)
	for p in _scatter(26, 22, [Vector3.ZERO, Vector3(0, 0, 20)], 7.0):
		var s := _rng.randf_range(1.5, 4.0)
		B3.sphere(root, s, p, gold, Vector3(1.4, 0.45, 1.2), true)
	for p in _scatter(12, 18, [Vector3.ZERO, Vector3(0, 0, 20)], 6.0):
		B3.box(root, Vector3(1.4, 0.9, 0.9), p + Vector3(0, 0.45, 0), B3.mat(Color(0.25, 0.12, 0.05), 0.6))
		B3.crystal(root, p + Vector3(0, 0.9, 0), [VIOLET, Color(1, 0.2, 0.3), Color(0.2, 0.6, 1)][_rng.randi() % 3], 0.8)
	B3.light(root, Vector3(0, 8, 0), Color(1, 0.85, 0.5), 3.0, 30)
	B3.motes(root, Vector3(0, 3, 0), Vector3(20, 3, 20), Color(1.0, 0.85, 0.3), 120)
	return {"spawn": Vector3(0, 0.2, 16), "yaw": 0.0, "gate": Vector3(0, 0, 21), "keeper": Vector3(0, 0, -3), "slots": _arc(Vector3(0, 0, -3), 3, 3, 150, 210)}


# =====================================================================
#  Die Neue Welt
# =====================================================================

static func _village(root: Node3D) -> Dictionary:
	var grass := B3.noise_mat(Color(0.2, 0.3, 0.1), Color(0.35, 0.45, 0.18), 0.05, 0.95)
	B3.ground(root, 50, grass)
	B3.bounds(root, 48)
	B3.box(root, Vector3(4, 0.04, 90), Vector3(0, 0.02, 0), B3.noise_mat(Color(0.35, 0.27, 0.16), Color(0.5, 0.4, 0.25), 0.2, 1.0), false)
	var wall := B3.noise_mat(Color(0.55, 0.45, 0.32), Color(0.7, 0.6, 0.45), 0.2, 0.9)
	var roof := B3.noise_mat(Color(0.45, 0.35, 0.15), Color(0.6, 0.5, 0.25), 0.3, 1.0)
	var spots := [Vector3(-8, 0, -6), Vector3(8, 0, -10), Vector3(-9, 0, 8), Vector3(9, 0, 6), Vector3(-16, 0, -16), Vector3(16, 0, -2), Vector3(-7, 0, -22), Vector3(10, 0, -24)]
	for p in spots:
		B3.house(root, p, Vector3(5, 3, 4), wall, roof, 90.0 if p.x < 0 else -90.0)
	var trunk := B3.mat(Color(0.25, 0.17, 0.1))
	var leaves := B3.noise_mat(Color(0.12, 0.3, 0.1), Color(0.25, 0.45, 0.15), 0.2)
	for p in _scatter(40, 46, [Vector3.ZERO, Vector3(0, 0, 30)], 26.0):
		B3.tree(root, p, _rng.randf_range(6, 11), trunk, leaves)
	# Palisade und Wachturm
	for i in 24:
		B3.cyl(root, 0.18, 0.2, 2.6, Vector3(-24 + i * 2.0, 1.3, -30), trunk, true, 6)
	B3.box(root, Vector3(2.4, 6, 2.4), Vector3(18, 3, -28), B3.mat(Color(0.3, 0.2, 0.12)))
	# Brunnen (Dorfplatz)
	B3.cyl(root, 1.2, 1.3, 0.9, Vector3(0, 0.45, -2), B3.noise_mat(Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6), 0.3), true)
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 33), "board": Vector3(3.5, 0, 2), "slots": _arc(Vector3(0, 0, -2), 5, 6, 60, 300)}


static func _city(root: Node3D, _style: String) -> Dictionary:
	var paving := B3.noise_mat(Color(0.32, 0.3, 0.28), Color(0.5, 0.48, 0.45), 0.25, 0.9)
	B3.ground(root, 60, B3.noise_mat(Color(0.22, 0.3, 0.14), Color(0.32, 0.4, 0.2), 0.05))
	B3.ground(root, 30, paving, 0.01)
	B3.bounds(root, 58)
	var stone := B3.noise_mat(Color(0.45, 0.43, 0.4), Color(0.62, 0.6, 0.56), 0.1, 0.9)
	var roof := B3.noise_mat(Color(0.25, 0.1, 0.08), Color(0.4, 0.18, 0.12), 0.3)
	B3.city_wall(root, 30, 9, stone, B3.mat(Color(0.2, 0.22, 0.35), 0.7))
	var wall_m := B3.noise_mat(Color(0.6, 0.55, 0.45), Color(0.78, 0.72, 0.6), 0.2)
	var crest: Texture2D = Palette.icon("faction_kingdom")
	for gx in range(-3, 4):
		for gz in range(-3, 3):
			if absi(gx) <= 1 and gz >= -1:
				continue  # Marktplatz und Hauptstraße frei
			var p := Vector3(gx * 7.5, 0, gz * 7.5 - 4)
			B3.house(root, p, Vector3(5, _rng.randf_range(4, 8), 5), wall_m, roof, [0.0, 90.0, 180.0][_rng.randi() % 3])
	# Rathaus/Gilde am Platz
	B3.box(root, Vector3(10, 9, 6), Vector3(0, 4.5, -18), stone)
	B3.prism(root, Vector3(11, 4, 7), Vector3(0, 11, -18), roof)
	B3.tower(root, Vector3(0, 0, -22), 2.0, 16, stone, roof)
	for s in [-1.0, 1.0]:
		B3.banner(root, Vector3(3.5 * s, 8, -14.9), Color(0.15, 0.2, 0.45), crest, 4.0)
	B3.cyl(root, 2.0, 2.2, 1.0, Vector3(0, 0.5, -3), stone, true)
	B3.sphere(root, 0.6, Vector3(0, 2.0, -3), B3.mat(Color(0.5, 0.7, 1.0), 0.1, 0.0, Color(0.3, 0.5, 0.9), 1.5))
	B3.brazier(root, Vector3(-5, 0, 6))
	B3.brazier(root, Vector3(5, 0, 6))
	return {"spawn": Vector3(0, 0.2, 40), "yaw": 0.0, "gate": Vector3(0, 0, 46), "board": Vector3(4, 0, -9), "slots": _arc(Vector3(0, 0, -3), 6, 6, 60, 300)}


static func _palace(root: Node3D) -> Dictionary:
	var a := _city(root, "empire")
	var marble := B3.noise_mat(Color(0.75, 0.72, 0.68), Color(0.92, 0.9, 0.86), 0.08, 0.4)
	var roof := B3.mat(Color(0.7, 0.25, 0.1), 0.6)
	B3.box(root, Vector3(22, 12, 8), Vector3(0, 6, -26), marble)
	B3.cyl(root, 4, 4, 6, Vector3(0, 15, -26), marble, false, 20)
	B3.sphere(root, 4.2, Vector3(0, 18, -26), B3.mat(GOLD, 0.3, 0.9), Vector3(1, 0.7, 1))
	for s in [-1.0, 1.0]:
		B3.tower(root, Vector3(11 * s, 0, -26), 2.2, 18, marble, roof)
		B3.banner(root, Vector3(5 * s, 11, -21.9), Color(0.55, 0.08, 0.06), null, 6.0)
	return a


static func _wall(root: Node3D) -> Dictionary:
	var grass := B3.noise_mat(Color(0.35, 0.33, 0.2), Color(0.5, 0.46, 0.3), 0.05)
	B3.ground(root, 55, grass)
	B3.bounds(root, 53)
	var stone := B3.noise_mat(Color(0.65, 0.63, 0.58), Color(0.82, 0.8, 0.75), 0.1, 0.9)
	B3.box(root, Vector3(110, 18, 5), Vector3(0, 9, -30), stone)
	for x in range(-50, 51, 12):
		B3.tower(root, Vector3(x, 0, -30), 3, 23, stone, B3.mat(Color(0.25, 0.3, 0.55), 0.7))
	# Feldlager mit Zelten
	var cloth := B3.mat(Color(0.85, 0.82, 0.75), 0.95)
	for p in _scatter(14, 30, [Vector3.ZERO, Vector3(0, 0, 30)], 9.0):
		if p.z < -24:
			continue
		B3.prism(root, Vector3(4, 2.6, 4), p + Vector3(0, 1.3, 0), cloth, Vector3(0, _rng.randf_range(0, 90), 0))
	for p in [Vector3(-6, 0, 0), Vector3(6, 0, 4), Vector3(0, 0, -10)]:
		B3.brazier(root, p)
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 35), "board": Vector3(4, 0, -4), "slots": _arc(Vector3(0, 0, -4), 6, 5, 70, 290)}


static func _cathedral(root: Node3D) -> Dictionary:
	var a := _city(root, "holy")
	var white := B3.noise_mat(Color(0.88, 0.88, 0.85), Color(1, 1, 0.97), 0.1, 0.5)
	B3.box(root, Vector3(14, 16, 12), Vector3(0, 8, -24), white)
	B3.prism(root, Vector3(15, 7, 13), Vector3(0, 19.5, -24), B3.mat(Color(0.8, 0.7, 0.4), 0.4, 0.6))
	for s in [-1.0, 1.0]:
		B3.tower(root, Vector3(8 * s, 0, -19), 2.5, 26, white, B3.mat(GOLD, 0.3, 0.9))
	B3.box(root, Vector3(4, 6, 0.2), Vector3(0, 9, -17.9), B3.mat(Color(1, 0.95, 0.7), 1, 0, Color(1, 0.9, 0.5), 2.0), false)
	return a


static func _forest(root: Node3D, style: String) -> Dictionary:
	var elf := style == "elf"
	var moss := B3.noise_mat(Color(0.06, 0.12, 0.05), Color(0.16, 0.24, 0.1), 0.07)
	B3.ground(root, 50, moss)
	B3.bounds(root, 48)
	var trunk := B3.noise_mat(Color(0.12, 0.08, 0.06), Color(0.24, 0.17, 0.12), 0.3)
	var leaves := B3.noise_mat(Color(0.04, 0.14, 0.05), Color(0.1, 0.28, 0.1), 0.25)
	if elf:
		leaves = B3.noise_mat(Color(0.05, 0.2, 0.12), Color(0.2, 0.45, 0.3), 0.25, 0.9, Color(0.05, 0.2, 0.1))
	for p in _scatter(90 if not elf else 50, 46, [Vector3.ZERO, Vector3(0, 0, 30), Vector3(0, 0, 15)], 7.0):
		B3.tree(root, p, _rng.randf_range(9, 16) * (1.8 if elf else 1.0), trunk, leaves, not elf and _rng.randf() < 0.4)
	if elf:
		# Baumpalast: riesiger Stamm mit leuchtenden Plattformen
		B3.cyl(root, 3, 4, 40, Vector3(0, 20, -24), trunk, true, 16)
		for i in 3:
			B3.cyl(root, 7 - i, 7 - i, 0.4, Vector3(0, 8 + i * 9, -24), B3.mat(Color(0.3, 0.22, 0.12)), false, 20)
			B3.light(root, Vector3(0, 9 + i * 9, -20), Color(0.5, 1.0, 0.6), 2.0, 12)
		B3.motes(root, Vector3(0, 4, 0), Vector3(40, 4, 40), Color(0.6, 1.0, 0.7), 140)
	else:
		B3.motes(root, Vector3(0, 2, 0), Vector3(40, 2, 40), Color(0.9, 1.0, 0.5), 60)
	for p in _scatter(16, 40, [Vector3.ZERO, Vector3(0, 0, 30)], 8.0):
		B3.rock(root, p, _rng.randf_range(0.6, 1.5), B3.noise_mat(Color(0.25, 0.27, 0.25), Color(0.4, 0.42, 0.38), 0.3))
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 34), "board": Vector3(4, 0, 2), "slots": _arc(Vector3.ZERO, 5, 5, 60, 300)}


static func _swamp(root: Node3D) -> Dictionary:
	var mud := B3.noise_mat(Color(0.12, 0.13, 0.08), Color(0.25, 0.26, 0.15), 0.08)
	B3.ground(root, 48, mud)
	B3.bounds(root, 46)
	var water := B3.mat(Color(0.12, 0.2, 0.18, 0.8), 0.05, 0.1)
	for p in _scatter(10, 38, [Vector3.ZERO, Vector3(0, 0, 30)], 12.0):
		B3.cyl(root, _rng.randf_range(4, 9), _rng.randf_range(4, 9), 0.05, p + Vector3(0, 0.04, 0), water, false, 20)
	var reed := B3.mat(Color(0.35, 0.4, 0.2))
	for p in _scatter(80, 44, [Vector3.ZERO], 5.0):
		B3.cyl(root, 0.02, 0.05, _rng.randf_range(1.2, 2.4), p + Vector3(0, 0.9, 0), reed, false, 4)
	# Pfahlhütten der Echsenmenschen
	var wood := B3.mat(Color(0.3, 0.22, 0.12))
	for p in [Vector3(-10, 0, -8), Vector3(10, 0, -12), Vector3(-4, 0, -20), Vector3(14, 0, 4)]:
		for c in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			B3.cyl(root, 0.15, 0.15, 2, p + c + Vector3(0, 1, 0), wood, true, 6)
		B3.box(root, Vector3(4, 0.3, 4), p + Vector3(0, 2.1, 0), wood, false)
		B3.cone(root, 3, 2.5, p + Vector3(0, 2.2, 0), B3.mat(Color(0.5, 0.45, 0.25)))
	var trunk := B3.mat(Color(0.15, 0.12, 0.08))
	for p in _scatter(20, 44, [Vector3.ZERO, Vector3(0, 0, 30)], 10.0):
		B3.tree(root, p, _rng.randf_range(6, 10), trunk, B3.noise_mat(Color(0.15, 0.2, 0.1), Color(0.25, 0.3, 0.15), 0.2))
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 32), "board": Vector3(3, 0, 0), "slots": _arc(Vector3.ZERO, 5, 5, 60, 300)}


static func _battlefield(root: Node3D) -> Dictionary:
	var dirt := B3.noise_mat(Color(0.12, 0.1, 0.1), Color(0.26, 0.22, 0.2), 0.06)
	B3.ground(root, 55, dirt)
	B3.bounds(root, 53)
	var stone := B3.noise_mat(Color(0.2, 0.18, 0.2), Color(0.35, 0.32, 0.34), 0.15)
	# Ruinen
	for p in _scatter(14, 45, [Vector3.ZERO, Vector3(0, 0, 32)], 10.0):
		var h := _rng.randf_range(2, 8)
		B3.box(root, Vector3(_rng.randf_range(2, 6), h, 1.2), p + Vector3(0, h / 2.0, 0), stone, true, Vector3(0, _rng.randf_range(0, 180), 0))
	# Gräber, Knochen, zerbrochene Waffen
	var bone := B3.mat(Color(0.8, 0.78, 0.7))
	for p in _scatter(40, 45, [Vector3(0, 0, 32)], 4.0):
		B3.box(root, Vector3(0.12, 1.4, 0.12), p + Vector3(0, 0.7, 0), B3.mat(Color(0.35, 0.33, 0.33), 0.4, 0.8), false, Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20)))
		B3.sphere(root, 0.18, p + Vector3(0.5, 0.15, 0.3), bone)
	B3.motes(root, Vector3(0, 1.5, 0), Vector3(50, 1.5, 50), Color(0.6, 0.5, 0.8), 120)
	for p in [Vector3(-12, 0, -8), Vector3(10, 0, -16), Vector3(16, 0, 10)]:
		B3.brazier(root, p, Color(0.6, 0.3, 1.0))
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 34), "board": Vector3(4, 0, 0), "slots": _arc(Vector3(0, 0, -2), 6, 6, 60, 300)}


static func _mountain(root: Node3D) -> Dictionary:
	var snow := B3.noise_mat(Color(0.55, 0.58, 0.64), Color(0.82, 0.85, 0.9), 0.05, 0.6)
	B3.ground(root, 55, snow)
	B3.bounds(root, 50)
	var rockm := B3.noise_mat(Color(0.3, 0.3, 0.33), Color(0.5, 0.5, 0.52), 0.12)
	for p in _scatter(16, 52, [Vector3.ZERO, Vector3(0, 0, 30), Vector3(0, 0, -26)], 18.0):
		B3.cone(root, _rng.randf_range(8, 16), _rng.randf_range(18, 35), p, rockm, true)
	# Zwergentor im Fels mit glühenden Runen
	B3.box(root, Vector3(30, 22, 10), Vector3(0, 11, -32), rockm)
	B3.box(root, Vector3(8, 10, 1), Vector3(0, 5, -26.6), B3.mat(Color(0.2, 0.2, 0.22), 0.4, 0.8))
	for i in 5:
		B3.box(root, Vector3(0.6, 0.9, 0.1), Vector3(-3 + i * 1.5, 8, -26.0), B3.mat(Color(0.3, 0.8, 1.0), 1, 0, Color(0.3, 0.8, 1.0), 4), false)
	for s in [-1.0, 1.0]:
		B3.brazier(root, Vector3(6 * s, 0, -24), Color(1.0, 0.6, 0.2))
	B3.motes(root, Vector3(0, 8, 0), Vector3(45, 6, 45), Color(1, 1, 1), 180, 0.8)
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 34), "board": Vector3(4, 0, -16), "slots": _arc(Vector3(0, 0, -16), 6, 5, 70, 290)}


static func _peaks(root: Node3D) -> Dictionary:
	var a := _mountain(root)
	# Drachenhort: gewaltige Klauenfelsen und ein Ring aus Platin
	var plat := B3.mat(Color(0.85, 0.9, 0.95), 0.2, 1.0)
	for i in 8:
		var ang := TAU * i / 8.0
		B3.cone(root, 1.2, 9, Vector3(cos(ang) * 11, 0, sin(ang) * 11 - 6), plat, true)
	B3.light(root, Vector3(0, 6, -6), Color(0.7, 0.85, 1.0), 3.0, 20)
	return a

class_name B3
## Baukasten für die begehbaren 3D-Orte: Materialien, Primitive mit Kollision,
## Lichter, Feuer, Bäume, Häuser, Mauern … alles prozedural, ohne externe Modelle.

static var _mats: Dictionary = {}
static var _fx_tex: Dictionary = {}


## Weiche Partikel-Textur aus assets/textures/fx: fx_dot = runder Lichtpunkt, fx_smoke = 2×2-Atlas weicher Schwaden,
## fx_streak = Schliere. Ohne Textur zeichnen Partikel harte Quadrate.
static func fx_tex(name: String) -> Texture2D:
	if not _fx_tex.has(name):
		_fx_tex[name] = load("res://assets/textures/fx/%s.png" % name)
	return _fx_tex[name]


# =====================================================================
#  Materialien
# =====================================================================

static func mat(color: Color, rough: float = 0.85, metal: float = 0.0, emission: Color = Color.BLACK, energy: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), rough, metal, emission.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## Material mit Rauschtextur (Stein, Erde, Gras, Eis …) – kachelt über die Welt.
static func noise_mat(a: Color, b: Color, scale: float = 0.08, rough: float = 0.9, emission: Color = Color.BLACK, uv_scale: float = 1.0) -> StandardMaterial3D:
	var key := "n|%s|%s|%.3f|%s|%.2f" % [a.to_html(), b.to_html(), scale, emission.to_html(), uv_scale]
	if _mats.has(key):
		return _mats[key]
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = scale
	n.fractal_octaves = 4
	tex.noise = n
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	tex.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.25 * uv_scale
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_texture = tex
	_mats[key] = m
	return m


static func tex_mat(tex: Texture2D, unshaded: bool = true, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# =====================================================================
#  Grundkörper
# =====================================================================

static func mesh(parent: Node, m: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Quader mit Kollision.
static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, solid: bool = true, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := mesh(parent, bm, pos, material, rot)
	if solid:
		_collider(mi, BoxShape3D.new(), size)
	return mi


static func cyl(parent: Node, r_top: float, r_bottom: float, h: float, pos: Vector3, material: Material, solid: bool = true, segs: int = 16) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = segs
	var mi := mesh(parent, cm, pos, material)
	if solid:
		var s := CylinderShape3D.new()
		s.radius = maxf(r_top, r_bottom)
		s.height = h
		_collider(mi, s, Vector3.ZERO)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, material: Material, scl: Vector3 = Vector3.ONE, solid: bool = false) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	var mi := mesh(parent, sm, pos, material, Vector3.ZERO, scl)
	if solid:
		var s := SphereShape3D.new()
		s.radius = r * maxf(scl.x, scl.z)
		_collider(mi, s, Vector3.ZERO)
	return mi


static func prism(parent: Node, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = size
	return mesh(parent, pm, pos, material, rot)


static func cone(parent: Node, r: float, h: float, pos: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	return cyl(parent, 0.0, r, h, pos + Vector3(0, h / 2.0, 0), material, solid, 10)


static func _collider(mi: MeshInstance3D, shape: Shape3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	if shape is BoxShape3D:
		(shape as BoxShape3D).size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


## Unsichtbare Begrenzung (Weltrand).
static func wall_invisible(parent: Node, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	body.add_child(cs)
	parent.add_child(body)


static func bounds(parent: Node, half: float, height: float = 12.0) -> void:
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var size := Vector3(1, height, half * 2) if d.x != 0 else Vector3(half * 2, height, 1)
		wall_invisible(parent, size, d * (half + 0.5) + Vector3(0, height / 2, 0))


static func ground(parent: Node, half: float, material: Material, y: float = 0.0) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(half * 2, half * 2)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	mesh(parent, pm, Vector3(0, y, 0), material)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(half * 2, 1, half * 2)
	cs.shape = s
	cs.position = Vector3(0, y - 0.5, 0)
	body.add_child(cs)
	parent.add_child(body)


# =====================================================================
#  Licht & Effekte
# =====================================================================

static func light(parent: Node, pos: Vector3, color: Color, energy: float = 1.5, rng: float = 8.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	parent.add_child(l)
	return l


## Bewegte Objekte (Figuren, Projektile) aus der globalen Beleuchtung (SDFGI,
## nur Forward+) nehmen: ihre Meshes würden sonst als statische Geometrie samt
## Leuchtfarben in den Raum eingerechnet, ihre Lichter würden mitgestreut.
static func exclude_from_gi(root: Node) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for n in root.find_children("*", "Light3D", true, false):
		(n as Light3D).light_bake_mode = Light3D.BAKE_DISABLED


## Feuerschale mit flackerndem Licht und Funken.
static func brazier(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.55, 0.2), solid: bool = true) -> void:
	if ModelLib.place_prop(parent, "brazier", pos, 0.0, 1.0, solid):
		B3.light(parent, pos + Vector3(0, 1.8, 0), color, 2.2, 9.0).set_meta("flicker", true)
		return
	cyl(parent, 0.35, 0.15, 1.1, pos + Vector3(0, 0.55, 0), mat(Color(0.12, 0.1, 0.1), 0.6, 0.6), solid, 10)
	cyl(parent, 0.5, 0.3, 0.25, pos + Vector3(0, 1.2, 0), mat(Color(0.75, 0.58, 0.2), 0.35, 0.9), false, 12)
	sphere(parent, 0.3, pos + Vector3(0, 1.33, 0), coal_mat(color), Vector3(1, 0.22, 1))
	var l := light(parent, pos + Vector3(0, 1.8, 0), color, 2.2, 9.0)
	l.set_meta("flicker", true)
	fire(parent, pos + Vector3(0, 1.45, 0), color)


static var _coal_mats: Dictionary = {}


## Glimmende Kohlen in der Farbe des Feuers: kleine dunkle Brocken mit glühenden Fugen, pulsierend (Lava-Shader).
static func coal_mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _coal_mats.has(key):
		return _coal_mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/lava.gdshader")
	m.set_shader_parameter("scale", 3.2)
	m.set_shader_parameter("wobble", 0.0)
	m.set_shader_parameter("speed", 0.012)
	m.set_shader_parameter("glow", 1.8)
	m.set_shader_parameter("hot", color)
	m.set_shader_parameter("core", color.lightened(0.55))
	_coal_mats[key] = m
	return m


static var _flame_mats: Dictionary = {}


## Flammenmaterial je Farbe (assets/shaders/fx/flame.gdshader): Kern hell, Rand gesättigt; gecacht.
static func _flame_mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _flame_mats.has(key):
		return _flame_mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/fx/flame.gdshader")
	m.set_shader_parameter("noise_tex", fx_tex("fx_noise"))
	m.set_shader_parameter("col_core", color.lightened(0.55))
	m.set_shader_parameter("col_outer", color)
	_flame_mats[key] = m
	return m


## Feuer: ein bis drei flackernde Flammenzungen (Shader auf Quads, drehen sich zur Kamera), Größe nach amount
## (10 ≈ Fackel, 24 ≈ Feuerschale, 40 ≈ Kamin), dazu aufsteigende Funken. Rückgabe: die Funken.
static func fire(parent: Node, pos: Vector3, color: Color, amount: int = 24) -> CPUParticles3D:
	var h := clampf(0.35 + amount * 0.02, 0.4, 1.3)
	var n := 1 if amount < 12 else (2 if amount < 26 else 3)
	for i in n:
		var hh := h * (1.0 if i == 0 else randf_range(0.68, 0.85))
		var q := QuadMesh.new()
		q.size = Vector2(hh * 0.72, hh)
		var mi := MeshInstance3D.new()
		mi.name = "Flame"
		mi.mesh = q
		mi.material_override = _flame_mat(color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)) * h
		mi.position = pos + off + Vector3(0, hh * 0.46, 0)
		parent.add_child(mi)
		mi.set_instance_shader_parameter("seed", randf() * 10.0)
	return _sparks(parent, pos + Vector3(0, h * 0.35, 0), color, maxi(3, amount / 5))


## Funken: wenige kleine, weiche Lichtpunkte, die aufsteigen und verglimmen.
static func _sparks(parent: Node, pos: Vector3, color: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 1.0
	p.direction = Vector3.UP
	p.spread = 24.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.018
	p.scale_amount_max = 0.035
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = fx_tex("fx_dot")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# Partikel-Billboards verwerfen ohne keep_scale die Partikelgröße (sonst wird jeder Funke 1 m groß)
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	qm.material = m
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(color.lightened(0.4), 0.0))
	g.add_point(0.1, Color(color.lightened(0.35), 0.9))
	g.set_color(g.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	return p


## Schwebende Lichtpartikel (Staub, Glühwürmchen, Schnee, Asche); nahe der Kamera blenden sie aus (sonst blühen
## sie zu großen, verschwommenen Kugeln auf).
static func motes(parent: Node, center: Vector3, extent: Vector3, color: Color, amount: int = 60, fall: float = 0.0) -> void:
	var p := _sparks(parent, center, color, amount)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.lifetime = 6.0
	p.direction = Vector3.DOWN if fall > 0 else Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.05 + fall
	p.initial_velocity_max = 0.25 + fall
	p.gravity = Vector3(0, -fall * 0.5, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	var dim := Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a * 0.8)
	var g := Gradient.new()
	g.set_color(0, Color(dim, 0.0))
	g.add_point(0.2, dim)
	g.add_point(0.8, dim)
	g.set_color(g.get_point_count() - 1, Color(dim, 0.0))
	p.color_ramp = g
	var m := (p.mesh as QuadMesh).material as StandardMaterial3D
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.8
	m.distance_fade_max_distance = 3.2
	if fall > 0.0:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX


static var _crystal_mats: Dictionary = {}


## Kristallgruppe: eine hohe Nadel und drei bis vier kleinere, sechskantig mit Spitze, leicht geneigt; Eis-Shader in
## der Farbe des Kristalls (innen tief, Kanten hell, schwaches Glimmen) – vorher zwei grell leuchtende Prismen, die wie
## Lichtsäulen wirkten.
static func crystal(parent: Node, pos: Vector3, color: Color, h: float = 1.6) -> void:
	if ModelLib.place_prop(parent, "crystal", pos, 0.0, h / 1.6, false):
		light(parent, pos + Vector3(0, h * 0.6, 0), color, 0.9, 4.5)
		return
	var key := color.to_html()
	if not _crystal_mats.has(key):
		var cm := ShaderMaterial.new()
		cm.shader = load("res://assets/shaders/ice.gdshader")
		cm.set_shader_parameter("deep", color.darkened(0.82))
		cm.set_shader_parameter("surf", color.lightened(0.25))
		cm.set_shader_parameter("snow_cover", 0.0)
		cm.set_shader_parameter("crystal", 1.0)
		cm.set_shader_parameter("glow", 0.22)
		_crystal_mats[key] = cm
	var m: ShaderMaterial = _crystal_mats[key]
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = fposmod(pos.x * 2.7 + pos.z * 1.3, TAU)
	parent.add_child(holder)
	var shards := [[0.0, 0.0, 1.0, 0.0, 0.0], [0.34, 0.08, 0.58, 0.32, 0.1], [-0.28, 0.2, 0.5, -0.36, 0.05],
		[0.06, -0.33, 0.42, 0.1, -0.38], [-0.12, -0.18, 0.3, -0.2, -0.3]]
	for s in shards:
		var sh: float = h * float(s[2])
		var r: float = clampf(h * 0.13, 0.07, 0.4) * (0.6 + 0.4 * float(s[2]))
		var piv := Node3D.new()
		piv.position = Vector3(float(s[0]), -0.05, float(s[1])) * clampf(h * 0.45, 0.3, 1.2)
		piv.rotation = Vector3(float(s[4]), 0.0, -float(s[3]))
		holder.add_child(piv)
		var body := CylinderMesh.new()
		body.top_radius = r * 0.62
		body.bottom_radius = r
		body.height = sh * 0.78
		body.radial_segments = 6
		body.rings = 1
		mesh(piv, body, Vector3(0, sh * 0.39, 0), m)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = r * 0.62
		tip.height = sh * 0.24
		tip.radial_segments = 6
		tip.rings = 1
		mesh(piv, tip, Vector3(0, sh * 0.9, 0), m)
	light(parent, pos + Vector3(0, h * 0.5, 0), color, 0.45, 3.5)


# =====================================================================
#  Architektur & Natur
# =====================================================================

static func pillar(parent: Node, pos: Vector3, h: float, r: float, stone: Material, gold: Material) -> void:
	if ModelLib.place_prop(parent, "pillar", pos, 0.0, h / 15.5):
		return
	cyl(parent, r, r, h, pos + Vector3(0, h / 2.0, 0), stone, true, 12)
	box(parent, Vector3(r * 2.6, 0.35, r * 2.6), pos + Vector3(0, 0.17, 0), gold, false)
	box(parent, Vector3(r * 2.6, 0.35, r * 2.6), pos + Vector3(0, h - 0.17, 0), gold, false)


## Banner mit Wappen-Textur (Fraktions-Icon) oder Farbe.
static func banner(parent: Node, pos: Vector3, color: Color, emblem: Texture2D = null, h: float = 3.0, rot_y: float = 0.0) -> void:
	if ModelLib.place_prop(parent, "banner", pos, rot_y, h / 3.0, false):
		return
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	parent.add_child(holder)
	box(holder, Vector3(1.4, h, 0.05), Vector3(0, -h / 2.0, 0), mat(color, 0.9), false)
	prism(holder, Vector3(1.4, 0.6, 0.05), Vector3(0, -h - 0.3, 0), mat(color, 0.9), Vector3(0, 0, 180))
	box(holder, Vector3(1.7, 0.08, 0.08), Vector3(0, 0.02, 0), mat(Color(0.8, 0.62, 0.2), 0.3, 0.9), false)
	if emblem:
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 1.1)
		mesh(holder, q, Vector3(0, -h * 0.45, 0.04), tex_mat(emblem, true, true))


static func tree(parent: Node, pos: Vector3, h: float, trunk: Material, leaves: Material, conifer: bool = false) -> void:
	if ModelLib.place_prop(parent, "tree_conifer" if conifer else "tree", pos, pos.x * 37.0, h / 10.0):
		return
	cyl(parent, h * 0.04, h * 0.07, h * 0.5, pos + Vector3(0, h * 0.25, 0), trunk, true, 7)
	if conifer:
		cone(parent, h * 0.3, h * 0.55, pos + Vector3(0, h * 0.3, 0), leaves)
		cone(parent, h * 0.22, h * 0.45, pos + Vector3(0, h * 0.55, 0), leaves)
	else:
		sphere(parent, h * 0.28, pos + Vector3(0, h * 0.62, 0), leaves, Vector3(1, 0.8, 1))
		sphere(parent, h * 0.2, pos + Vector3(h * 0.15, h * 0.78, h * 0.05), leaves)


static func house(parent: Node, pos: Vector3, size: Vector3, wall: Material, roof: Material, rot_y: float = 0.0) -> void:
	if ModelLib.place_prop(parent, "house", pos, rot_y, size.y / 3.0):
		return
	var h := Node3D.new()
	h.position = pos
	h.rotation_degrees.y = rot_y
	parent.add_child(h)
	box(h, size, Vector3(0, size.y / 2.0, 0), wall)
	prism(h, Vector3(size.x + 0.4, size.y * 0.7, size.z + 0.4), Vector3(0, size.y + size.y * 0.35, 0), roof)
	box(h, Vector3(0.8, 1.4, 0.06), Vector3(0, 0.7, size.z / 2.0 + 0.02), mat(Color(0.18, 0.11, 0.06)), false)
	# warmes Fensterlicht
	box(h, Vector3(0.5, 0.45, 0.06), Vector3(size.x * 0.28, size.y * 0.6, size.z / 2.0 + 0.02), mat(Color(1, 0.8, 0.4), 1.0, 0.0, Color(1, 0.7, 0.3), 2.0), false)


static func tower(parent: Node, pos: Vector3, r: float, h: float, stone: Material, roof: Material) -> void:
	if ModelLib.place_prop(parent, "tower", pos, 0.0, h / 12.0):
		return
	cyl(parent, r, r * 1.05, h, pos + Vector3(0, h / 2.0, 0), stone, true, 12)
	cone(parent, r * 1.25, r * 2.4, pos + Vector3(0, h, 0), roof)


## Stadtmauer-Ring (Rechteck) mit Türmen und einem Tor an der Südseite.
static func city_wall(parent: Node, half: float, h: float, stone: Material, roof: Material, gate_w: float = 6.0) -> void:
	var t := 1.6
	box(parent, Vector3(half * 2, h, t), Vector3(0, h / 2, -half), stone)
	box(parent, Vector3(t, h, half * 2), Vector3(-half, h / 2, 0), stone)
	box(parent, Vector3(t, h, half * 2), Vector3(half, h / 2, 0), stone)
	var seg := half - gate_w / 2.0
	box(parent, Vector3(seg, h, t), Vector3(-half + seg / 2.0, h / 2, half), stone)
	box(parent, Vector3(seg, h, t), Vector3(half - seg / 2.0, h / 2, half), stone)
	box(parent, Vector3(gate_w + 2, 2.0, t + 0.4), Vector3(0, h - 1.0, half), stone)
	for c in [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(-half, 0, half), Vector3(half, 0, half),
			Vector3(-gate_w / 2 - 1.2, 0, half), Vector3(gate_w / 2 + 1.2, 0, half)]:
		tower(parent, c, 1.8, h + 3.0, stone, roof)


static func rock(parent: Node, pos: Vector3, s: float, material: Material) -> void:
	if ModelLib.place_prop(parent, "rock", pos, pos.x * 37.0, s):
		return
	sphere(parent, s, pos, material, Vector3(1.3, 0.7, 1.0), true).rotation_degrees.y = pos.x * 37.0


static func stairs(parent: Node, pos: Vector3, width: float, steps: int, step_h: float, step_d: float, material: Material, dir: float = -1.0) -> void:
	for i in steps:
		box(parent, Vector3(width, step_h * (i + 1), step_d), pos + Vector3(0, step_h * (i + 1) / 2.0, dir * i * step_d), material)


static var _smoke_mat: StandardMaterial3D


## Rauch: weiche Wolken aus dem Rauch-Atlas (2 × 2 Bilder, je Wolke zufällig, langsam drehend), wachsen beim Aufsteigen
## und vergehen; vom Licht des Ortes getönt (in der Lavahöhle rötlich-dunkel, nicht grellweiß), weicher Übergang an
## Wänden und Boden, blendet vor der Kamera aus.
static func smoke(parent: Node, pos: Vector3, amount: int = 14) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.direction = Vector3(0.25, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.12, 0.08, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = curve
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -9.0
	p.angular_velocity_max = 9.0
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	if _smoke_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = fx_tex("fx_smoke")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_receive_shadows = true
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.7
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 0.8
		m.distance_fade_max_distance = 3.2
		_smoke_mat = m
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	qm.material = _smoke_mat
	p.mesh = qm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.48, 0.46, 0.0))
	g.add_point(0.18, Color(0.55, 0.53, 0.5, 0.3))
	g.add_point(0.6, Color(0.6, 0.58, 0.56, 0.16))
	g.set_color(g.get_point_count() - 1, Color(0.65, 0.64, 0.62, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	return p

class_name MapTable3D
extends SubViewportContainer
## Die Weltkarte als 3D-Kriegstisch: Reliefgelände, Regionen als kleine Burgen,
## Nazarick als Pyramide, Wege, eigene Legionen (violette Figuren) und feindliche
## Heere (rote Figuren), die entlang ihrer Marschroute gleiten.
## Gleiche Schnittstelle wie die frühere 2D-Karte:
##   Signale region_clicked(id), army_clicked(uid) · Eigenschaften selected_region, selected_army, anim_frac

signal region_clicked(id: String)
signal army_clicked(uid: String)

const W := 22.0     ## Breite des Tisches (X)
const D := 15.0     ## Tiefe des Tisches (Z)

var selected_region := "":
	set(v):
		selected_region = v
		_dirty = true
var selected_army := "":
	set(v):
		selected_army = v
		_dirty = true
var anim_frac := 0.0

var _vp := SubViewport.new()
var _cam := Camera3D.new()
var _markers := Node3D.new()
var _tokens := Node3D.new()
var _noise := FastNoiseLite.new()
var _dirty := true
var _hover := ""
var _t := 0.0
var _yaw := 0.0
var _zoom := 1.0
var _army_nodes: Dictionary = {}     ## uid → Node3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	_noise.seed = 1337
	_noise.frequency = 0.09
	_noise.fractal_octaves = 4
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.0, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	_vp.add_child(sun)
	for c in [Vector3(-W / 2, 4, -D / 2), Vector3(W / 2, 4, D / 2)]:
		B3.light(_vp, c, Color(1.0, 0.7, 0.4), 1.2, 18.0)
	_cam.fov = 42.0
	_vp.add_child(_cam)
	_build_table()
	_vp.add_child(_markers)
	_vp.add_child(_tokens)
	_place_camera()
	Game.state_changed.connect(func(): _dirty = true)


# =====================================================================
#  Aufbau
# =====================================================================

func height_at(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z)
	var h := maxf(0.0, n) * 1.6
	# Gebirge im Norden (Azerlisia), Drachenlande im Nordosten
	h += _bump(x, z, map_pos("azerlisia"), 3.5, 1.6) + _bump(x, z, map_pos("drachen"), 3.0, 1.8)
	return h


func _bump(x: float, z: float, c: Vector3, r: float, amp: float) -> float:
	var d := Vector2(x - c.x, z - c.z).length()
	return amp * maxf(0.0, 1.0 - d / r) ** 2


func _build_table() -> void:
	# Holztisch mit Goldrand
	B3.box(_vp, Vector3(W + 1.6, 0.6, D + 1.6), Vector3(0, -0.45, 0), B3.noise_mat(Color(0.14, 0.08, 0.05), Color(0.25, 0.15, 0.08), 0.3, 0.6), false)
	B3.box(_vp, Vector3(W + 1.7, 0.08, D + 1.7), Vector3(0, -0.12, 0), B3.mat(Color(0.8, 0.62, 0.22), 0.3, 0.9), false)
	# Reliefgelände aus Rauschen, eingefärbt nach Höhe
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 88
	var nz := 60
	for iz in nz:
		for ix in nx:
			var quad := [Vector2(ix, iz), Vector2(ix + 1, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz + 1)]
			for q in quad:
				var x: float = -W / 2 + q.x / nx * W
				var z: float = -D / 2 + q.y / nz * D
				var h := height_at(x, z)
				st.set_color(_terrain_color(h, x, z))
				st.add_vertex(Vector3(x, h * 0.6, z))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	_vp.add_child(mi)
	# Wasserfläche
	var water := PlaneMesh.new()
	water.size = Vector2(W, D)
	B3.mesh(_vp, water, Vector3(0, 0.05, 0), B3.mat(Color(0.12, 0.22, 0.35, 0.75), 0.1, 0.2))


func _terrain_color(h: float, x: float, z: float) -> Color:
	if h < 0.05:
		return Color(0.32, 0.36, 0.22).lerp(Color(0.26, 0.3, 0.2), absf(_noise.get_noise_2d(x * 3, z * 3)))
	if h < 0.6:
		return Color(0.24, 0.32, 0.16).lerp(Color(0.18, 0.26, 0.12), h)
	if h < 1.3:
		return Color(0.38, 0.35, 0.32)
	return Color(0.85, 0.87, 0.92)


## Normierte Kartenposition (regions.json → pos) in Tischkoordinaten.
func map_pos(id: String) -> Vector3:
	var p: Array = World.region(id).get("pos", [0.5, 0.5])
	return Vector3((float(p[0]) - 0.5) * W, 0.0, (float(p[1]) - 0.5) * D)


func ground_pos(id: String) -> Vector3:
	var p := map_pos(id)
	p.y = maxf(0.08, height_at(p.x, p.z) * 0.6)
	return p


func _rebuild() -> void:
	_dirty = false
	for c in _markers.get_children():
		c.queue_free()
	# Wege
	for l in Content.region_links:
		var known: bool = World.rs(l[0]).discovered or World.rs(l[1]).discovered
		if not known:
			continue
		var a := ground_pos(l[0]) + Vector3.UP * 0.05
		var b := ground_pos(l[1]) + Vector3.UP * 0.05
		var segs := int(a.distance_to(b) / 0.5)
		for i in segs:
			if i % 2 == 1:
				continue
			var p := a.lerp(b, (i + 0.5) / segs)
			var seg := B3.box(_markers, Vector3(0.08, 0.04, 0.32), p, B3.mat(Color(0.85, 0.66, 0.22), 0.4, 0.8), false)
			seg.look_at_from_position(p, b, Vector3.UP)
	for r in Content.regions:
		_region_marker(r)


func _region_marker(r: Dictionary) -> void:
	var st := World.rs(r.id)
	var root := Node3D.new()
	root.position = ground_pos(r.id)
	_markers.add_child(root)
	var sel: bool = r.id == selected_region
	var hov: bool = r.id == _hover
	if not st.discovered:
		# Unerforscht: Nebelschwade
		B3.sphere(root, 0.7, Vector3(0, 0.3, 0), B3.mat(Color(0.6, 0.6, 0.7, 0.35), 1.0), Vector3(1.3, 0.5, 1.0))
		if hov or sel:
			_label(root, "?", Palette.MUTED, 0.9)
		return
	var fac: Dictionary = Diplomacy.faction(r.get("faction", "")) if r.has("faction") else {}
	var col := Color(fac.get("color", "#d4af37")) if not fac.is_empty() else Palette.GOLD
	var infl := float(st.influence) / 100.0
	# Einflussring (violett = Nazarick)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.66
	B3.mesh(root, ring, Vector3(0, 0.03, 0), B3.mat(Color(0.25, 0.25, 0.3), 0.6))
	if infl > 0.0:
		var ring2 := TorusMesh.new()
		ring2.inner_radius = 0.56
		ring2.outer_radius = 0.56 + 0.1 + infl * 0.18
		B3.mesh(root, ring2, Vector3(0, 0.05, 0), B3.mat(Color(0.6, 0.25, 1.0), 0.3, 0.0, Color(0.55, 0.2, 1.0), 1.0 + infl * 2.0))
	if r.get("home", false):
		# Das Große Grab: dunkle Pyramide mit violettem Leuchten
		B3.prism(root, Vector3(1.0, 0.9, 1.0), Vector3(0, 0.45, 0), B3.mat(Color(0.12, 0.08, 0.16), 0.5, 0.3, Color(0.3, 0.1, 0.5), 0.6))
		B3.light(root, Vector3(0, 1.2, 0), Color(0.6, 0.3, 1.0), 1.5, 3.0)
	else:
		var stone := B3.mat(col.lerp(Color(0.6, 0.6, 0.6), 0.5), 0.6)
		B3.cyl(root, 0.18, 0.2, 0.55, Vector3(0, 0.28, 0), stone, false, 8)
		B3.cone(root, 0.24, 0.3, Vector3(0, 0.55, 0), B3.mat(col, 0.5))
		for s in [-1.0, 1.0]:
			B3.cyl(root, 0.11, 0.12, 0.35, Vector3(0.28 * s, 0.18, 0.1), stone, false, 8)
		# Fahne in Fraktionsfarbe bzw. violett bei Kontrolle
		var flag := B3.mat(Color(0.5, 0.15, 0.9) if st.influence >= 60 else col, 0.8)
		B3.box(root, Vector3(0.02, 0.35, 0.02), Vector3(0, 0.95, 0), B3.mat(Color(0.2, 0.15, 0.1)), false)
		B3.box(root, Vector3(0.22, 0.13, 0.01), Vector3(0.11, 1.05, 0), flag, false)
	if int(st.unrest) >= 40:
		B3.motes(root, Vector3(0, 0.8, 0), Vector3(0.3, 0.3, 0.3), Color(0.5, 0.5, 0.5), 12)
	for t in Game.state.get("threats", []):
		if t.region == r.id:
			var l := B3.light(root, Vector3(0, 1.0, 0), Color(1, 0.1, 0.1), 2.0, 2.5)
			l.set_meta("pulse", true)
			_label(root, "⚠", Palette.DANGER, 1.65)
	var name_col := Palette.GOLD_BRIGHT if sel else (Palette.PARCHMENT if hov else Color(Palette.PARCHMENT, 0.85))
	_label(root, r.short, name_col, 1.3, 40 if sel or hov else 34)
	if sel:
		var sr := TorusMesh.new()
		sr.inner_radius = 0.8
		sr.outer_radius = 0.88
		var m := B3.mesh(root, sr, Vector3(0, 0.08, 0), B3.mat(Palette.GOLD_BRIGHT, 0.2, 0.5, Palette.GOLD_BRIGHT, 2.0))
		m.set_meta("spin", 1.0)


func _label(parent: Node3D, text: String, col: Color, y: float, size: int = 34) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = NazarickTheme.display_font(700)
	l.font_size = size
	l.outline_size = 8
	l.modulate = col
	l.pixel_size = 0.008
	l.position.y = y
	l.no_depth_test = true
	parent.add_child(l)


# =====================================================================
#  Armeen
# =====================================================================

func army_pos(a: Dictionary) -> Vector3:
	var here := ground_pos(a.location)
	var path: Array = a.get("path", [])
	if path.is_empty():
		return here
	var t := Military.leg_progress(a, anim_frac)
	return here.lerp(ground_pos(path[0]), t)


func _sync_armies() -> void:
	var seen := {}
	var i := 0
	for a in Game.state.get("armies", []):
		seen[a.uid] = true
		var n := _token(a.uid, Color(0.55, 0.25, 0.95), a.uid == selected_army, str(Military.strength(a)))
		n.position = army_pos(a) + Vector3(-0.35 - (i % 2) * 0.25, 0, 0.25)
		i += 1
	for e in Game.state.get("enemy_armies", []):
		var key: String = "e_" + str(e.get("uid", e.name))
		seen[key] = true
		var n := _token(key, Color(0.85, 0.1, 0.15), false, str(int(e.strength)))
		n.position = army_pos(e) + Vector3(0.35, 0, -0.2)
	for k in _army_nodes.keys():
		if not seen.has(k):
			(_army_nodes[k] as Node3D).queue_free()
			_army_nodes.erase(k)


func _token(key: String, col: Color, selected: bool, strength: String) -> Node3D:
	if _army_nodes.has(key):
		var existing: Node3D = _army_nodes[key]
		existing.scale = Vector3.ONE * (1.25 if selected else 1.0)
		(existing.get_meta("label") as Label3D).text = strength
		return existing
	var n := Node3D.new()
	_tokens.add_child(n)
	var m := B3.mat(col, 0.3, 0.6, col * 0.5, 0.8)
	B3.cyl(n, 0.16, 0.2, 0.08, Vector3(0, 0.04, 0), m, false, 12)
	B3.cyl(n, 0.08, 0.13, 0.32, Vector3(0, 0.24, 0), m, false, 10)
	B3.sphere(n, 0.1, Vector3(0, 0.46, 0), m)
	var l := Label3D.new()
	l.text = strength
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 30
	l.outline_size = 8
	l.pixel_size = 0.008
	l.modulate = col.lightened(0.4)
	l.position.y = 0.75
	l.no_depth_test = true
	n.add_child(l)
	n.set_meta("label", l)
	_army_nodes[key] = n
	return n


# =====================================================================
#  Kamera & Eingabe
# =====================================================================

func _place_camera() -> void:
	var dist := 15.5 * _zoom
	var pitch := deg_to_rad(58.0)
	var pos := Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch)) * dist + Vector3(0, 0, 0.8)
	_cam.look_at_from_position(pos, Vector3(0, 0, 0.4), Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	if _dirty:
		_rebuild()
	_sync_armies()
	for n in _markers.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("spin"):
			n.rotate_y(delta)
	for l in _markers.find_children("*", "OmniLight3D", true, false):
		if l.has_meta("pulse"):
			l.light_energy = 1.5 + sin(_t * 5.0) * 1.0


func _pick(screen: Vector2) -> Dictionary:
	var scale_f := Vector2(_vp.size) / size if size.x > 0 else Vector2.ONE
	var p := screen * scale_f
	var from := _cam.project_ray_origin(p)
	var dir := _cam.project_ray_normal(p)
	if absf(dir.y) < 0.001:
		return {}
	var hit := from + dir * ((0.3 - from.y) / dir.y)
	var best := {}
	var best_d := 0.9
	for a in Game.state.get("armies", []):
		var d := Vector2(hit.x, hit.z).distance_to(Vector2(army_pos(a).x - 0.35, army_pos(a).z + 0.25))
		if d < 0.45 and d < best_d:
			best_d = d
			best = {"army": a.uid}
	if not best.is_empty():
		return best
	for r in Content.regions:
		var rp := map_pos(r.id)
		var d := Vector2(hit.x, hit.z).distance_to(Vector2(rp.x, rp.z))
		if d < best_d:
			best_d = d
			best = {"region": r.id}
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _pick(event.position)
		var h: String = hit.get("region", "")
		if h != _hover:
			_hover = h
			_dirty = true
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_yaw -= event.relative.x * 0.006
			_place_camera()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom = maxf(0.55, _zoom - 0.08)
				_place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = minf(1.3, _zoom + 0.08)
				_place_camera()
			MOUSE_BUTTON_LEFT:
				var hit := _pick(event.position)
				if hit.has("army"):
					army_clicked.emit(hit.army)
				elif hit.has("region"):
					region_clicked.emit(hit.region)

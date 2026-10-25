extends RefCounted
## Draufsicht des Ortes für Minikarte und Ortskarte (Taste L): nach dem Laden einmal senkrecht von oben aufgenommen
## (orthografisch, Norden = −Z oben, eigene schlichte Beleuchtung ohne Nebel). In Hallen und Innenräumen sitzt die
## Kamera knapp über dem Boden – alles darüber (Decken, Kronleuchter, obere Wände) wird abgeschnitten, Wände
## erscheinen als dunkle Linien wie in einem Grundriss.

const RES := 1024
## Hallen mit Decke (Kamera unter der Decke), dazu alle Innenräume
const INDOOR_KINDS := ["throne", "tombs", "royal", "library"]


## Ausschnitt in Weltkoordinaten als Rect2(x, z, Breite, Tiefe): der Boden des Ortsmodells („Ground…“), sonst alle
## Meshes im Umkreis von 200 m um den Startpunkt (ohne Horizont); quadratisch, 30 … 420 m.
static func bounds(level: Node3D, spawn: Vector3) -> Rect2:
	var box := AABB()
	var first := true
	for mi in level.find_children("Ground*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var gb: AABB = m.global_transform * m.get_aabb()
		box = gb if first else box.merge(gb)
		first = false
	if first:
		for mi in level.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null or not m.is_visible_in_tree():
				continue
			var nm := String(m.name).to_lower()
			if nm.contains("horizont") or nm.contains("sky") or nm.begins_with("nocol_mm"):
				continue
			var gb: AABB = m.global_transform * m.get_aabb()
			if gb.size.x > 400.0 or gb.size.z > 400.0 or gb.get_center().distance_to(spawn) > 200.0:
				continue
			box = gb if first else box.merge(gb)
			first = false
	if first:
		return Rect2(spawn.x - 40.0, spawn.z - 40.0, 80.0, 80.0)
	var side := clampf(maxf(box.size.x, box.size.z), 30.0, 420.0)
	var c := box.get_center()
	return Rect2(c.x - side * 0.5, c.z - side * 0.5, side, side)


## Aufnahme der Draufsicht über `rect`. indoor: Kamera 3 m über `floor_y` (Grundriss), sonst hoch über dem Ort.
## Partikel (Regen, Funken) werden für die Aufnahme ausgeblendet. Rückgabe null, wenn kein Bild entstand.
static func capture(host: Node, level: Node3D, rect: Rect2, floor_y: float, indoor: bool, exposure: float = 1.0) -> ImageTexture:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return null
	var hidden: Array = []
	for p in host.get_tree().root.find_children("*", "GPUParticles3D", true, false) + host.get_tree().root.find_children("*", "CPUParticles3D", true, false):
		var g := p as GeometryInstance3D
		if g.visible:
			g.visible = false
			hidden.append(g)
	# Sonnenschatten aus: die Schattenreichweite endet sonst mitten im Bild (heller Streifen dahinter)
	var suns: Array = []
	for l in level.find_children("*", "DirectionalLight3D", true, false):
		var dl := l as DirectionalLight3D
		if dl.shadow_enabled:
			dl.shadow_enabled = false
			suns.append(dl)
	var vp := SubViewport.new()
	vp.size = Vector2i(RES, RES)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.world_3d = level.get_world_3d()
	vp.msaa_3d = Viewport.MSAA_2X
	host.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = rect.size.y
	var top := floor_y + (3.0 if indoor else 160.0)
	cam.near = 0.05
	cam.far = (top - floor_y) + 40.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.028, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.9, 0.86)
	env.ambient_light_energy = 1.0 if indoor else 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure          # Schnee und Eis: dunkler, sonst ist die Karte nur weiß
	cam.environment = env
	vp.add_child(cam)
	var c := rect.get_center()
	cam.look_at_from_position(Vector3(c.x, top, c.y), Vector3(c.x, floor_y - 10.0, c.y), Vector3(0, 0, -1))
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	for g in hidden:
		if is_instance_valid(g):
			(g as GeometryInstance3D).visible = true
	for dl in suns:
		if is_instance_valid(dl):
			(dl as DirectionalLight3D).shadow_enabled = true
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Weltpunkt → Anteil (0…1) im Kartenbild
static func to_uv(rect: Rect2, p: Vector3) -> Vector2:
	return Vector2((p.x - rect.position.x) / rect.size.x, (p.z - rect.position.y) / rect.size.y)

extends Node
## Portrait-Studio: rendert jede Figur einmal als 3D-Bild (Oberkörper, Studiolicht)
## und liefert es als Textur für Dialoge, Menüs und Karten. So zeigt auch die
## Benutzeroberfläche ausschließlich die 3D-Figuren des Spiels – keine 2D-Zeichnungen.
## Varianten: love/angry/sad färben das Kantenlicht, battle zeigt die Kampfhaltung.
## Hinweis: Pro Bild wird ein eigener SubViewport erzeugt – der Compatibility-Renderer
## liefert beim Wiederverwenden eines Render-Targets sonst ein zwischengespeichertes Bild.

signal baked(key: String)

const SIZE := Vector2i(360, 480)

var _cache: Dictionary = {}       ## "cid|variant" → Texture2D
var _queue: Array = []
var _busy := false


func can_render() -> bool:
	return DisplayServer.get_name() != "headless"


## Fertiges Bild oder null (dann wird es im Hintergrund erzeugt und `baked` gesendet).
func get_texture(cid: String, variant: String = "") -> Texture2D:
	if cid == "":
		return null
	var key := cid + "|" + variant
	if _cache.has(key):
		return _cache[key]
	if not can_render():
		return null
	if not key in _queue:
		_queue.append(key)
		if not _busy:
			_busy = true
			_bake_next.call_deferred()
	return null


func _bake_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	var key: String = _queue.pop_front()
	var parts := key.split("|")
	var cid := parts[0]
	var variant := parts[1] if parts.size() > 1 else ""
	var vp := _make_studio(variant, cid)
	add_child(vp)
	var rig := CharacterRig.create(cid, func(r): ProcModel.figure(r, cid))
	vp.add_child(rig)
	rig.rotation.y = deg_to_rad(-20.0)
	if not rig.has_model:
		rig.pose(Fighter.S.BLOCK if variant == "battle" else Fighter.S.IDLE, "", 0.0, 0.0)
	# Bildausschnitt: Kopf bis Hüfte, Höhe aus der Figur
	var h := _figure_height(rig)
	var cam: Camera3D = vp.get_node("Cam")
	cam.look_at_from_position(Vector3(0.25 * h, h * 0.85, h * 1.55 + 0.7), Vector3(0, h * 0.66, 0))
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		_cache[key] = ImageTexture.create_from_image(img)
		baked.emit(key)
	vp.queue_free()
	_bake_next()


func _make_studio(variant: String, cid: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.62)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.4, 2.4, -1.6)
	rim.omni_range = 7.0
	rim.light_energy = 2.2
	rim.light_color = {"love": Color(1, 0.4, 0.75), "angry": Color(1, 0.15, 0.1), "sad": Color(0.35, 0.5, 1.0), "battle": Color(1, 0.7, 0.3)}.get(variant, Content.char_color(cid))
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true
	return vp


func _figure_height(rig: CharacterRig) -> float:
	var head: Node3D = rig.parts.get("head")
	if head:
		return head.global_position.y + 0.22
	var top := 1.8
	var found := false
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var y: float = (m.global_transform * m.get_aabb().end).y
		if not found or y > top:
			top = y
			found = true
	return clampf(top, 0.8, 3.2)

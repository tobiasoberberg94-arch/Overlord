extends Node3D
## Kontaktbogen der Animationen einer Figur: je Animation 4 Zeitpunkte nebeneinander.
##   MODEL=res://assets/models/characters/ainz.glb ANIMS=dodge_fwd,dodge_back godot --path . res://tools/anim_preview.tscn
## Ergebnis: tools/screenshots3d/anim_<datei>.png

func _ready() -> void:
	var path := OS.get_environment("MODEL")
	var scene: PackedScene = load(path) if path.begins_with("res://") else null
	var m: Node3D
	if scene:
		m = scene.instantiate()
	else:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_file(path, st)
		m = doc.generate_scene(st)
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 400)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	vp.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	var names: Array = OS.get_environment("ANIMS").split(",") if OS.get_environment("ANIMS") != "" else Array(ap.get_animation_list())
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.25, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor.mesh = pm
	vp.add_child(floor)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(2.6, 1.5, 2.6), Vector3(0, 0.95, 0))
	cam.fov = 50.0
	cam.current = true
	await get_tree().process_frame
	var cols := 4
	var tile := Vector2i(360, 400)
	var sheet := Image.create(tile.x * cols, tile.y * names.size(), false, Image.FORMAT_RGB8)
	for r in names.size():
		var n: String = names[r]
		if not ap.has_animation(n):
			print("ANIM fehlt: ", n)
			continue
		var len := ap.get_animation(n).length
		for c in cols:
			ap.play(n)
			ap.seek(len * (c + 0.5) / cols, true)
			ap.pause()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(tile.x, tile.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
		print("ANIM ", n, " Länge ", snappedf(len, 0.01), " s")
	var out := "res://tools/screenshots3d/anim_%s.png" % path.get_file().get_basename()
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2)
	sheet.save_png(ProjectSettings.globalize_path(out))
	print("ANIM Bogen ", out)
	get_tree().quit()

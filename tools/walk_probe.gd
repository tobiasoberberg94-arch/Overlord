extends Node
## Begehbarkeits-Karte: Flutfüllung ab dem Spawn mit dem echten Spieler-Kollisionskörper (Kapsel,
## Stufen bis 0,4 m). Ergebnis als Bild tools/screenshots3d/walk_<ort>.png:
##   weiß = erreichbar · rot = Boden vorhanden, aber nicht erreichbar · schwarz = kein Boden
## Dazu die Objekte, die am häufigsten den Weg versperren (Grenze erreichbar → unerreichbar).
##   LOC=throne HALF=60 CELL=0.5 godot --headless --path . res://tools/walk_probe.tscn

var p: CharacterBody3D
var space: PhysicsDirectSpaceState3D


func _env(k: String, d: float) -> float:
	return float(OS.get_environment(k)) if OS.get_environment(k) != "" else d


func _ready() -> void:
	Settings.tutorial_done = true
	Game.new_game()
	Game.state.dispatches.clear()
	var w: Node = load("res://scenes/world_3d.tscn").instantiate()
	get_tree().root.add_child.call_deferred(w)
	await get_tree().create_timer(2.0).timeout
	var id := OS.get_environment("LOC")
	if id == "":
		id = "throne"
	if w.loc.get("id", "") != id:
		await w.load_location(id)
	await get_tree().create_timer(0.5).timeout
	for c in w.overlay_layer.get_children():
		c.queue_free()
	p = w.player
	if OS.get_environment("MODE") == "walk":
		await _walk(w)
		get_tree().quit()
		return
	p.set_physics_process(false)
	for a in (w.actors if OS.get_environment("ACTORS") == "" else []):   # Figuren aus dem Weg
		a.process_mode = Node.PROCESS_MODE_DISABLED
		for cs in a.find_children("*", "CollisionShape3D", true, false):
			cs.disabled = true
	for e in w.enemies:
		e.queue_free()
	for i in 5:
		await get_tree().physics_frame
	space = p.get_world_3d().direct_space_state
	var dbg := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 10, 0), p.global_position + Vector3(0, -10, 0))
	print("SONDE-DEBUG Spieler ", p.global_position, " Treffer ", space.intersect_ray(dbg))
	var half := _env("HALF", 60.0)
	var cell := _env("CELL", 0.5)
	var n := int(half * 2 / cell)
	var origin: Vector3 = w.anchors.spawn + Vector3(0.23, 0, 0.17)   # nicht genau auf eine Kachelfuge
	var c0 := Vector3(origin.x - half, 0, origin.z - half)
	# Boden je Zelle (höchste begehbare Fläche unterhalb Kopfhöhe des Nachbarn) – lazy
	var floor_y := {}
	var state := PackedByteArray()
	state.resize(n * n)              # 0 unbekannt, 1 erreichbar, 2 kein Boden
	var start := Vector2i(n / 2, n / 2)
	var g0: Variant = _ground(Vector3(origin.x, origin.y + 1.5, origin.z), 4.0)
	if g0 == null:
		var rq := PhysicsRayQueryParameters3D.create(origin + Vector3(0, 1.5, 0), origin + Vector3(0, -6, 0))
		rq.exclude = [p.get_rid()]
		print("SONDE: kein Boden am Spawn ", origin, " ", space.intersect_ray(rq), " Körper: ", w.level.find_children("*", "StaticBody3D", true, false).size())
		get_tree().quit()
		return
	floor_y[start] = g0
	state[start.y * n + start.x] = 1
	var queue: Array[Vector2i] = [start]
	var blockers := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var steps := 0
	while not queue.is_empty() and steps < 400000:
		steps += 1
		var c: Vector2i = queue.pop_front()
		var y: float = floor_y[c]
		var here := Vector3(c0.x + (c.x + 0.5) * cell, y, c0.z + (c.y + 0.5) * cell)
		for d in dirs:
			var nb: Vector2i = c + d
			if nb.x < 0 or nb.y < 0 or nb.x >= n or nb.y >= n or state[nb.y * n + nb.x] == 1:
				continue
			var there := Vector3(c0.x + (nb.x + 0.5) * cell, y, c0.z + (nb.y + 0.5) * cell)
			var gy: Variant = _ground(there + Vector3(0, 1.2, 0), 3.0)
			if gy == null or absf(float(gy) - y) > 1.0:
				if gy == null:
					state[nb.y * n + nb.x] = 2
				continue
			# Kapsel 0,4 m angehoben verschieben (Stufen), dann muss dort Boden sein
			var t := Transform3D(Basis(), here + Vector3(0, _env("LIFT", 0.45) + 1.0, 0))
			var col := KinematicCollision3D.new()
			if p.test_move(t, there - here, col, 0.001, true):
				var nm := _name_of(col.get_collider())
				blockers[nm] = int(blockers.get(nm, 0)) + 1
				continue
			floor_y[nb] = float(gy)
			state[nb.y * n + nb.x] = 1
			queue.append(nb)
	# Bild
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var reach := 0
	var lost := 0
	for zz in n:
		for xx in n:
			var s := state[zz * n + xx]
			var col := Color.BLACK
			if s == 1:
				col = Color.WHITE
				reach += 1
			else:
				var gy: Variant = _ground(Vector3(c0.x + (xx + 0.5) * cell, origin.y + _env("TOP", 3.0), c0.z + (zz + 0.5) * cell), 8.0)
				if gy != null:
					col = Color(0.85, 0.15, 0.15)
					lost += 1
			img.set_pixel(xx, zz, col)
	img.set_pixel(start.x, start.y, Color(0, 1, 0))
	var out := "res://tools/screenshots3d/walk_%s.png" % id
	img.resize(n * 2, n * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(out))
	print("SONDE %s: erreichbar %.0f m² · Boden aber unerreichbar %.0f m² · Bild %s" % [id, reach * cell * cell, lost * cell * cell, out])
	var arr := []
	for k in blockers:
		arr.append([blockers[k], k])
	arr.sort_custom(func(a, b): return a[0] > b[0])
	for e in arr.slice(0, 25):
		print("  %5d  %s" % [e[0], e[1]])
	get_tree().quit()


## Höhe der begehbaren Fläche unter `from` (oder null).
func _ground(from: Vector3, depth: float) -> Variant:
	var rq := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth)
	rq.exclude = [p.get_rid()]
	var r := space.intersect_ray(rq)
	if r.is_empty() or r.normal.y < 0.7:
		return null
	return r.position.y


func _name_of(o: Object) -> String:
	if o == null:
		return "?"
	var nd := o as Node
	var path := String(nd.name)
	var par := nd.get_parent()
	if par:
		path = String(par.name) + "/" + path
		if par.get_parent():
			path = String(par.get_parent().name) + "/" + path
	return path


## Echtes Laufen mit simulierten Tasten; protokolliert, wo Ainz stecken bleibt.
func _walk(w: Node) -> void:
	var start: Vector3 = w.player.global_position
	for test in [["move_right", 0.0], ["move_left", 0.0], ["move_right", PI * 0.25], ["move_forward", 0.0]]:
		for o in w.overlay_layer.get_children():
			o.queue_free()
		w._time_running = false
		w.player.global_position = start
		w.player.velocity = Vector3.ZERO
		w.player.cam_yaw = test[1]
		await get_tree().create_timer(0.4).timeout
		Input.action_press(test[0])
		var last: Vector3 = w.player.global_position
		var line := "LAUF %s yaw %.2f:" % [test[0], test[1]]
		for i in 12:
			await get_tree().create_timer(0.35).timeout
			var now: Vector3 = w.player.global_position
			line += " (%.1f,%.1f,%.1f)" % [now.x, now.y, now.z]
			if now.distance_to(last) < 0.05:
				var hit := ""
				for k in w.player.get_slide_collision_count():
					var c: KinematicCollision3D = w.player.get_slide_collision(k)
					hit += " " + _name_of(c.get_collider()) + " n=" + str(c.get_normal().snapped(Vector3(0.01, 0.01, 0.01)))
				line += " STECKT an" + hit
				break
			last = now
		Input.action_release(test[0])
		print(line)

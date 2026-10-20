class_name CombatIndicators
extends Control
## Richtungsanzeigen im Kampf (über der 3D-Welt, unter den Fenstern):
##   • rote Bögen um die Bildmitte – aus dieser Richtung wurde Ainz getroffen
##   • Warnpfeile am Bildschirmrand, wenn ein Gegner außerhalb des Blickfelds ausholt
##     (orange = blockbar/parierbar, rot = nur ausweichen)

var player: Node3D
var hits: Array = []                  ## {pos, t, s}
var warns: Array = []                 ## {e, t, dur, red}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit_from(world_pos: Vector3, strength: float = 1.0) -> void:
	hits.append({"pos": world_pos, "t": 0.0, "s": clampf(strength, 0.4, 1.4)})
	if hits.size() > 6:
		hits.pop_front()


func warn(e: Node3D, dur: float, red: bool) -> void:
	for w in warns:
		if w.e == e:
			w.t = 0.0
			w.dur = dur
			w.red = red
			return
	warns.append({"e": e, "t": 0.0, "dur": dur, "red": red})


func _process(delta: float) -> void:
	if hits.is_empty() and warns.is_empty():
		return
	for h in hits:
		h.t = float(h.t) + delta
	hits = hits.filter(func(h): return float(h.t) < 1.1)
	for w in warns:
		w.t = float(w.t) + delta
	warns = warns.filter(func(w): return float(w.t) < float(w.dur) and is_instance_valid(w.e) and w.e.state == Fighter.S.ATTACK)
	queue_redraw()


## Blickwinkel einer Weltposition relativ zur Kamera (0 = vorn/oben, positiv = rechts).
func _rel_angle(world_pos: Vector3) -> float:
	var yaw: float = player.get("cam_yaw") if player else 0.0
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var right := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	var d := world_pos - player.global_position
	d.y = 0.0
	return atan2(d.dot(right), d.dot(fwd))


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.27
	for h in hits:
		var a := _rel_angle(h.pos)
		var k := 1.0 - float(h.t) / 1.1
		var col := Color(1.0, 0.12, 0.08, 0.75 * k * k)
		var span := 0.42 * float(h.s)
		var pts := PackedVector2Array()
		for i in 17:
			var t := a - span * 0.5 + span * i / 16.0
			pts.append(c + Vector2(sin(t), -cos(t)) * r)
		draw_polyline(pts, col, 9.0 * float(h.s), true)
		var pts2 := PackedVector2Array()
		for i in 17:
			var t := a - span * 0.35 + span * 0.7 * i / 16.0
			pts2.append(c + Vector2(sin(t), -cos(t)) * (r + 10.0))
		draw_polyline(pts2, Color(col, col.a * 0.5), 4.0, true)
	var cam := get_viewport().get_camera_3d()
	for w in warns:
		var e: Node3D = w.e
		var at := e.global_position + Vector3.UP * 1.4
		var on_screen := false
		if cam and not cam.is_position_behind(at):
			var sp := cam.unproject_position(at)
			on_screen = Rect2(Vector2(40, 40), size - Vector2(80, 80)).has_point(sp)
		if on_screen:
			continue
		var a := _rel_angle(at)
		var dir := Vector2(sin(a), -cos(a))
		# Pfeil auf einer Ellipse knapp innerhalb des Rands
		var edge := c + Vector2(dir.x * (size.x * 0.5 - 70.0), dir.y * (size.y * 0.5 - 70.0))
		var pulse := 0.6 + 0.4 * sin(float(w.t) * 22.0)
		var col: Color = Color(1.0, 0.15, 0.1, 0.9 * pulse) if w.red else Color(1.0, 0.62, 0.15, 0.9 * pulse)
		var n := Vector2(-dir.y, dir.x)
		var tip := edge + dir * 26.0
		draw_colored_polygon(PackedVector2Array([tip, edge - dir * 6.0 + n * 18.0, edge - dir * 6.0 - n * 18.0]), col)
		draw_polyline(PackedVector2Array([tip, edge - dir * 6.0 + n * 18.0, edge - dir * 6.0 - n * 18.0, tip]), Color(0, 0, 0, 0.6), 2.0, true)
		var font := NazarickTheme.display_font(800)
		var s := "‼" if w.red else "!"
		draw_string_outline(font, edge - dir * 30.0 + Vector2(-8, 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0, 0.85))
		draw_string(font, edge - dir * 30.0 + Vector2(-8, 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)

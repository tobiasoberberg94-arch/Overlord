class_name SoulOrbs
extends Node3D
## Seelen besiegter Gegner: violette Lichter lösen sich aus dem Körper, steigen auf, kreisen kurz und fliegen dann
## in einem Bogen zu Ainz. Jede Ankunft klingt hell und zählt im Zauberbuch – der Zähler im HUD steigt sichtbar mit.

const COL := Color(0.66, 0.36, 1.0)
static var _last_chime := 0.0

var _orbs: Array = []          ## {node, vel, t, souls}
var _target: Node3D


static func spawn(parent: Node, at: Vector3, target: Node3D, souls: int) -> void:
	if parent == null or not is_instance_valid(parent) or target == null or not is_instance_valid(target) or souls <= 0:
		return
	if not CombatFX.enabled:
		Progress.add_souls(souls)
		return
	var s := SoulOrbs.new()
	s.name = "SoulOrbs"
	parent.add_child(s)
	s._target = target
	var n := clampi(int(ceil(souls / 3.0)), 1, 14)
	var per := souls / n
	var rest := souls - per * n
	for i in n:
		var orb := SpellFX._mesh(s, SpellFX._sphere(), SpellFX._orb_mat("soft"), at, Vector3.ONE * randf_range(0.16, 0.22))
		orb.set_instance_shader_parameter("core_col", Color(0.95, 0.85, 1.0))
		orb.set_instance_shader_parameter("rim_col", COL)
		orb.set_instance_shader_parameter("energy", 3.2)
		orb.global_position = at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
		var tr := CombatFX.emitter(orb, "trail_motes", COL)
		if tr:
			tr.amount = 10
		var a := randf() * TAU
		var vel := Vector3(cos(a) * randf_range(1.2, 2.8), randf_range(3.0, 5.2), sin(a) * randf_range(1.2, 2.8))
		s._orbs.append({"node": orb, "vel": vel, "t": -i * 0.05, "souls": per + (1 if i < rest else 0), "trail": tr})
	CombatFX.sound("soul_burst", at, 0.55, 0.05)
	CombatFX.burst(parent, "motes", at, COL, Vector3.UP, 0.9)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		for o in _orbs:
			Progress.add_souls(int(o.souls))
		queue_free()
		return
	var tp := _target.global_position + Vector3.UP * 1.25
	for o in _orbs.duplicate():
		o.t = float(o.t) + delta
		var node: Node3D = o.node
		if float(o.t) < 0.0:
			continue
		var to := tp - node.global_position
		var d := to.length()
		# erst aufsteigen und ausschwingen, dann immer zielstrebiger zu Ainz
		var homing := clampf((float(o.t) - 0.38) * 2.0, 0.0, 1.0)
		var want := to.normalized() * (7.0 + float(o.t) * 16.0)
		var vel: Vector3 = o.vel
		vel = vel.lerp(want, clampf(homing * delta * 7.0, 0.0, 1.0))
		vel.y -= 3.0 * delta * (1.0 - homing)
		o.vel = vel
		node.global_position += vel * delta
		node.scale = Vector3.ONE * (0.19 + 0.04 * sin(float(o.t) * 18.0))
		if d < 0.5 or float(o.t) > 3.2:
			_arrive(o)


func _arrive(o: Dictionary) -> void:
	_orbs.erase(o)
	var node: Node3D = o.node
	var at := node.global_position
	Progress.add_souls(int(o.souls))
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_chime > 0.07:
		_last_chime = now
		CombatFX.sound("soul", at, 0.4, 0.04)
	CombatFX.burst(get_parent(), "flash_soft", at, COL, Vector3.UP, 0.35)
	if _target and is_instance_valid(_target) and _target.get("rig"):
		var rig: CharacterRig = _target.rig
		if rig:
			rig.flash(COL, 0.18, 0.06)
	var tr: Variant = o.get("trail")
	if tr is GPUParticles3D and is_instance_valid(tr):
		CombatFX.stop(tr)
	node.queue_free()
	if _orbs.is_empty():
		queue_free()

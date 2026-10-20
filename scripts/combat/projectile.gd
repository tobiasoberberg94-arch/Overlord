class_name Projectile
extends Area3D
## Fliegendes Geschoss (Feuerkugel, Eisspeer, Blutlanze, Pfeil, geworfenes Schwert …): folgt optional einem Ziel
## (homing), fällt optional (Pfeile), trifft die erste Hurtbox der Gegenseite oder zerplatzt an der Welt.
## Aussehen und Einschlag je Element kommen aus SpellFX.

var info: Dictionary = {}
var source: Fighter
var velocity := Vector3.ZERO
var life := 3.0
var color := Color(1, 0.5, 0.2)
var element := "fire"
var homing: Fighter                     ## Ziel, dem das Geschoss nachlenkt
var turn := 0.0                         ## Lenkrate (rad/s)
var drop := 0.0                         ## Pfeile fallen leicht (m/s²)
var _speed := 20.0
var _spinner: Node3D
var _done := false


static func spawn(parent: Node, from: Fighter, pos: Vector3, dir: Vector3, speed: float, damage_info: Dictionary, col: Color, el: String = "") -> Projectile:
	var p := Projectile.new()
	p.source = from
	p.info = damage_info.duplicate()
	p.info["ranged"] = true
	p._speed = speed
	p.velocity = dir.normalized() * speed
	p.color = col
	p.element = el if el != "" else "fire"
	p.collision_layer = 0
	p.collision_mask = 1 | (Hitbox.LAYER_ENEMY_HURT if from.is_player else Hitbox.LAYER_PLAYER_HURT)
	p.monitoring = true
	p.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.32 if p.element != "arrow" else 0.18
	cs.shape = sh
	p.add_child(cs)
	parent.add_child(p)
	p.global_position = pos
	if p.element == "arrow":
		p.drop = 3.5
	SpellFX.projectile_look(p, p.element, col)
	for c in p.get_children():
		if c is Node3D and c.has_meta("spin"):
			p._spinner = c
	p._orient()
	p.area_entered.connect(p._on_area)
	p.body_entered.connect(p._on_body)
	return p


func _physics_process(delta: float) -> void:
	if _done:
		return
	if homing and is_instance_valid(homing) and homing.state != Fighter.S.DEAD and turn > 0.0:
		var want := (homing.global_position + Vector3.UP * homing.body_height * 0.6 - global_position).normalized()
		var v := velocity.normalized()
		var a := v.angle_to(want)
		if a > 0.001 and a < PI * 0.6:
			velocity = v.slerp(want, minf(1.0, turn * delta / a)) * _speed
	velocity.y -= drop * delta
	global_position += velocity * delta
	_orient()
	if _spinner:
		_spinner.rotate_object_local(Vector3.RIGHT, 22.0 * delta)
	life -= delta
	if life <= 0.0:
		_burst()


func _orient() -> void:
	if velocity.length() < 0.1 or not is_inside_tree():
		return
	var up := Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT
	look_at(global_position + velocity, up)


func _on_area(a: Area3D) -> void:
	if _done:
		return
	if a is Hurtbox and is_instance_valid(a.fighter) and a.fighter != source and a.fighter.state != Fighter.S.DEAD:
		a.fighter.take_hit(info, self)
		_burst()


func _on_body(b: Node) -> void:
	if _done or b == source or b is Fighter:
		return
	_burst()


func _burst() -> void:
	if _done or is_queued_for_deletion():
		return
	_done = true
	var parent := get_parent()
	SpellFX.projectile_burst(parent, global_position, element, color, 1.0)
	# Schweife vom Geschoss lösen und auslaufen lassen
	for c in get_children():
		if c is GPUParticles3D:
			CombatFX.stop(c)
	queue_free()

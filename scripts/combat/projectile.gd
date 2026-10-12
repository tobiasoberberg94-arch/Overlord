class_name Projectile
extends Area3D
## Fliegender Zauber (z. B. Feuerkugel): trifft die erste Hurtbox der Gegenseite
## oder zerplatzt an der Welt.

var info: Dictionary = {}
var source: Fighter
var velocity := Vector3.ZERO
var life := 3.0
var color := Color(1, 0.5, 0.2)


static func spawn(parent: Node, from: Fighter, pos: Vector3, dir: Vector3, speed: float, damage_info: Dictionary, col: Color) -> Projectile:
	var p := Projectile.new()
	p.source = from
	p.info = damage_info
	p.velocity = dir.normalized() * speed
	p.color = col
	p.collision_layer = 0
	p.collision_mask = 1 | (Hitbox.LAYER_ENEMY_HURT if from.is_player else Hitbox.LAYER_PLAYER_HURT)
	p.monitoring = true
	p.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	cs.shape = sh
	p.add_child(cs)
	parent.add_child(p)
	p.global_position = pos
	B3.sphere(p, 0.22, Vector3.ZERO, B3.mat(col, 1, 0, col, 5.0))
	var l := B3.light(p, Vector3.ZERO, col, 2.5, 6.0)
	l.shadow_enabled = false
	var trail := B3.fire(p, Vector3.ZERO, col, 30)
	trail.local_coords = false
	trail.lifetime = 0.5
	p.area_entered.connect(p._on_area)
	p.body_entered.connect(p._on_body)
	return p


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area(a: Area3D) -> void:
	if a is Hurtbox and is_instance_valid(a.fighter) and a.fighter != source:
		a.fighter.take_hit(info, self)
		_burst()


func _on_body(b: Node) -> void:
	if b == source or b is Fighter:
		return
	_burst()


func _burst() -> void:
	if is_queued_for_deletion():
		return
	var fx := B3.fire(get_parent(), global_position, color, 40)
	fx.one_shot = true
	fx.explosiveness = 0.9
	fx.spread = 180.0
	fx.initial_velocity_max = 4.0
	fx.get_tree().create_timer(1.5).timeout.connect(fx.queue_free)
	queue_free()

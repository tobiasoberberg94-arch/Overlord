class_name Hurtbox
extends Area3D
## Trefferfläche eines Kämpfers (Kapsel um den Körper). Wird von Hitboxen und
## Projektilen gefunden; der eigentliche Schaden läuft über fighter.take_hit().

var fighter: Fighter


func _init(owner_fighter: Fighter, is_player: bool, radius: float = 0.55, height: float = 2.0) -> void:
	fighter = owner_fighter
	monitoring = false
	monitorable = true
	collision_layer = Hitbox.LAYER_PLAYER_HURT if is_player else Hitbox.LAYER_ENEMY_HURT
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	cs.shape = cap
	cs.position.y = height / 2.0
	add_child(cs)

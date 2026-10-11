class_name Hitbox
extends Area3D
## Angriffs-Hitbox: Kugel vor dem Angreifer. Nur während der aktiven Phase eines
## Angriffs scharf; jedes Ziel wird pro Angriff höchstens einmal getroffen.
## Ein optionaler Bogen (arc, Grad) begrenzt die Trefferzone vor dem Angreifer.

const LAYER_PLAYER_HURT := 4    ## Physik-Ebene 3
const LAYER_ENEMY_HURT := 8     ## Physik-Ebene 4

var fighter: Fighter
var active := false
var info: Dictionary = {}
var arc := 360.0
var _hit: Array = []
var _offset := 0.0
var _shape := SphereShape3D.new()


func _init(owner_fighter: Fighter, hits_player: bool) -> void:
	fighter = owner_fighter
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = LAYER_PLAYER_HURT if hits_player else LAYER_ENEMY_HURT
	var cs := CollisionShape3D.new()
	_shape.radius = 1.5
	cs.shape = _shape
	add_child(cs)


## Scharf schalten: Reichweite = Radius um einen Punkt vor dem Angreifer.
func activate(damage_info: Dictionary, reach: float, arc_deg: float) -> void:
	info = damage_info
	arc = arc_deg
	_shape.radius = maxf(0.6, reach * (0.6 if arc_deg < 360.0 else 1.0))
	_offset = reach * 0.5 if arc_deg < 360.0 else 0.0
	position = fighter.facing * _offset + Vector3.UP
	_hit.clear()
	active = true


func deactivate() -> void:
	active = false


func _physics_process(_delta: float) -> void:
	if not active or not is_instance_valid(fighter):
		return
	position = fighter.facing * _offset + Vector3.UP
	for a in get_overlapping_areas():
		if a is Hurtbox and not a in _hit and is_instance_valid(a.fighter) and a.fighter != fighter:
			if arc < 360.0 and not fighter.is_facing(a.fighter.global_position, arc):
				continue
			_hit.append(a)
			a.fighter.take_hit(info, fighter)

class_name HeadLook
extends SkeletonModifier3D
## Dreht Kopf (und anteilig Hals) einer Figur nach der Animation zu einem Ziel – begrenzt auf
## natürliche Winkel und weich ein-/ausgeblendet. Ziel und Stärke setzt Actor3D.

var target := Vector3.ZERO        ## Weltposition (Augenhöhe des Spielers)
var weight := 0.0                 ## 0…1, vom Actor geblendet
var forward_local := Vector3(0, 0, 1)   ## Blickrichtung des Modells im Raum des Rigs
var rig: Node3D
const MAX_YAW := deg_to_rad(70.0)
const MAX_PITCH := deg_to_rad(30.0)
var _head := -1
var _neck := -1


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		if n.ends_with("head") and _head < 0:
			_head = i
		elif n.ends_with("neck") and _neck < 0:
			_neck = i


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _head < 0 or weight <= 0.001 or rig == null:
		return
	var inv := sk.global_transform.affine_inverse()
	var head_pose := sk.get_bone_global_pose(_head)
	var to_t: Vector3 = (inv * target) - head_pose.origin
	if to_t.length() < 0.05:
		return
	# Blickrichtung des Körpers im Skelettraum
	var fwd: Vector3 = (inv.basis * (rig.global_transform.basis * forward_local)).normalized()
	var up: Vector3 = (inv.basis * rig.global_transform.basis.y).normalized()
	var d := to_t.normalized()
	# Gieren/Nicken begrenzen
	var flat := (d - up * d.dot(up)).normalized()
	var yaw := clampf(fwd.signed_angle_to(flat, up), -MAX_YAW, MAX_YAW)
	var side := fwd.cross(up).normalized()
	var pitch := clampf(asin(clampf(d.dot(up), -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
	var q := Quaternion(up, yaw * weight) * Quaternion(side, -pitch * weight)
	var parts := [[_neck, 0.35], [_head, 0.65]] if _neck >= 0 else [[_head, 1.0]]
	for pr in parts:
		var idx: int = pr[0]
		var share: float = pr[1]
		var gp := sk.get_bone_global_pose(idx)
		var qs := Quaternion.IDENTITY.slerp(q, share)
		sk.set_bone_global_pose(idx, Transform3D(Basis(qs) * gp.basis, gp.origin))

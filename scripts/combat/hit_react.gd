class_name HitReact
extends SkeletonModifier3D
## Federnde Trefferreaktion für Modelle mit Skelett (Mixamo-Benennung): Rumpf und Kopf knicken vom Treffer weg und
## federn zurück. Läuft nach der Animation und verändert nur die Pose des aktuellen Bildes – die Animation selbst
## bleibt unberührt. Ausschlag und Achse setzt CharacterRig (Feder-Dämpfer-Rechnung in _process).

const BONES := [["mixamorig_Spine", 0.2], ["mixamorig_Spine1", 0.26], ["mixamorig_Spine2", 0.3], ["mixamorig_Neck", 0.18], ["mixamorig_Head", 0.32]]

var axis := Vector3.RIGHT          ## Drehachse in Weltkoordinaten
var angle := 0.0                   ## aktueller Ausschlag in Bogenmaß
var bend_axis := Vector3.RIGHT     ## Verbeugen/Knien: feste Neigung nach vorn (Szenen)
var bend := 0.0
const BEND_W := [0.32, 0.3, 0.24, 0.08, 0.14]
## Knien auf einem Knie: linkes Bein vorn aufgestellt, rechtes Knie am Boden (Winkel um die Querachse,
## positiv = nach hinten). Die Hüfte sinkt um die Unterschenkellänge.
const KNEEL := [["mixamorig_LeftUpLeg", -1.5], ["mixamorig_LeftLeg", 1.55], ["mixamorig_LeftFoot", -0.05],
	["mixamorig_RightUpLeg", 0.12], ["mixamorig_RightLeg", 1.6], ["mixamorig_RightFoot", 1.3]]
var kneel := 0.0                    ## 0 = stehen, 1 = kniet
var _ids: Array = []
var _kneel_ids: Array = []
var _hips := -1
var _shin := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in BONES:
		var id := sk.find_bone(String(b[0]))
		if id >= 0:
			_ids.append([id, float(b[1])])
	for b in KNEEL:
		var id := sk.find_bone(String(b[0]))
		if id >= 0:
			_kneel_ids.append([id, float(b[1])])
	_hips = sk.find_bone("mixamorig_Hips")
	var knee := sk.find_bone("mixamorig_RightLeg")
	var foot := sk.find_bone("mixamorig_RightFoot")
	if knee >= 0 and foot >= 0:
		_shin = sk.get_bone_global_rest(knee).origin.distance_to(sk.get_bone_global_rest(foot).origin)


func _process_modification() -> void:
	if (absf(angle) < 0.0005 and absf(bend) < 0.0005 and kneel < 0.0005) or _ids.is_empty():
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var inv := sk.global_basis.orthonormalized().inverse()
	var sk_axis := (inv * axis).normalized()
	var sk_bend := (inv * bend_axis).normalized()
	for k in _ids.size():
		var e: Array = _ids[k]
		var id: int = e[0]
		var par := sk.get_bone_parent(id)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
		var pinv := pg.inverse()
		var q := sk.get_bone_pose_rotation(id)
		if absf(bend) > 0.0005 and sk_bend.length() > 0.5:
			var bw: float = BEND_W[k] if k < BEND_W.size() else 0.1
			q = Quaternion((pinv * sk_bend).normalized(), bend * bw) * q
		if absf(angle) > 0.0005 and sk_axis.length() > 0.5:
			q = Quaternion((pinv * sk_axis).normalized(), angle * float(e[1])) * q
		sk.set_bone_pose_rotation(id, q)
	if kneel > 0.0005 and sk_bend.length() > 0.5 and not _kneel_ids.is_empty():
		for e in _kneel_ids:
			var id: int = e[0]
			var par := sk.get_bone_parent(id)
			var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
			var q := sk.get_bone_pose_rotation(id)
			q = Quaternion((pg.inverse() * sk_bend).normalized(), float(e[1]) * kneel) * q
			sk.set_bone_pose_rotation(id, q)
		if _hips >= 0 and _shin > 0.0:
			var hp := sk.get_bone_parent(_hips)
			var down := (inv * Vector3.DOWN).normalized()
			if hp >= 0:
				down = (sk.get_bone_global_pose(hp).basis.orthonormalized().inverse() * down).normalized()
			sk.set_bone_pose_position(_hips, sk.get_bone_pose_position(_hips) + down * _shin * 0.97 * kneel)

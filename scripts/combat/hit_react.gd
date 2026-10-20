class_name HitReact
extends SkeletonModifier3D
## Federnde Trefferreaktion für Modelle mit Skelett (Mixamo-Benennung): Rumpf und Kopf knicken vom Treffer weg und
## federn zurück. Läuft nach der Animation und verändert nur die Pose des aktuellen Bildes – die Animation selbst
## bleibt unberührt. Ausschlag und Achse setzt CharacterRig (Feder-Dämpfer-Rechnung in _process).

const BONES := [["mixamorig_Spine", 0.2], ["mixamorig_Spine1", 0.26], ["mixamorig_Spine2", 0.3], ["mixamorig_Neck", 0.18], ["mixamorig_Head", 0.32]]

var axis := Vector3.RIGHT          ## Drehachse in Weltkoordinaten
var angle := 0.0                   ## aktueller Ausschlag in Bogenmaß
var _ids: Array = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in BONES:
		var id := sk.find_bone(String(b[0]))
		if id >= 0:
			_ids.append([id, float(b[1])])


func _process_modification() -> void:
	if absf(angle) < 0.0005 or _ids.is_empty():
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var sk_axis := (sk.global_basis.orthonormalized().inverse() * axis).normalized()
	if sk_axis.length() < 0.5:
		return
	for e in _ids:
		var id: int = e[0]
		var par := sk.get_bone_parent(id)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
		var local_axis := (pg.inverse() * sk_axis).normalized()
		sk.set_bone_pose_rotation(id, Quaternion(local_axis, angle * float(e[1])) * sk.get_bone_pose_rotation(id))

class_name Spinner
extends Node
## Dreht Teile eines Ortsmodells (Knoten „spin_…“, z. B. Windmühlenflügel) um ihre eigene Achse.
## Die Drehachse ist die lokale Z-Achse (in Blender: lokales Y = dünnste Seite der Flügel).

var nodes: Array = []
var speed := 0.35


func _process(delta: float) -> void:
	for n in nodes:
		(n as Node3D).rotate_object_local(Vector3(0, 0, 1), speed * delta)

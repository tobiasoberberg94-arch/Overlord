class_name ModelLib
## Findet und lädt echte 3D-Modelle (.glb / .gltf / .tscn).
##
## Suchreihenfolge je Modell (kind = characters | props | locations):
##   1. res://assets/models/<kind>/<id>.glb|.gltf|.tscn|.scn   (beim Export eingebettet)
##   2. <Spielordner>/models/<kind>/<id>.glb|.gltf             (zur Laufzeit, ohne Neu-Export)
##   3. user://models/<kind>/<id>.glb|.gltf                    (zur Laufzeit)
## Fehlt ein Modell, nutzen die Aufrufer ihren prozeduralen Ersatz.
## Feineinstellungen (Skalierung, Drehung, Höhenversatz, Animationsnamen) stehen in data/models.json.

const KINDS := ["characters", "props", "locations"]
const RES_EXT := ["glb", "gltf", "tscn", "scn"]
const RUNTIME_EXT := ["glb", "gltf"]

static var _cache: Dictionary = {}     ## "kind/id" → PackedScene | Node3D (Vorlage) | null
static var _config: Dictionary = {}


static func config() -> Dictionary:
	if _config.is_empty():
		var f := FileAccess.open("res://data/models.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_config = parsed
		if _config.is_empty():
			_config = {"characters": {}, "props": {}, "locations": {}, "animation_aliases": {}}
	return _config


static func model_config(kind: String, id: String) -> Dictionary:
	return config().get(kind, {}).get(id, {})


static func runtime_dirs() -> PackedStringArray:
	var dirs := PackedStringArray()
	if not OS.has_feature("editor"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("models"))
	dirs.append(ProjectSettings.globalize_path("user://models"))
	return dirs


static func has(kind: String, id: String) -> bool:
	return _template(kind, id) != null


## Neue Instanz des Modells oder null.
static func instance(kind: String, id: String) -> Node3D:
	var t: Variant = _template(kind, id)
	if t == null:
		return null
	var n: Node
	if t is PackedScene:
		n = (t as PackedScene).instantiate()
	else:
		n = (t as Node).duplicate()
	var root := n as Node3D
	if root == null:
		var wrap := Node3D.new()
		wrap.add_child(n)
		root = wrap
	var cfg := model_config(kind, id)
	root.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	root.rotation_degrees.y = float(cfg.get("rot_y", 0.0))
	root.position.y = float(cfg.get("y", 0.0))
	return root


## Setzt ein Requisit (props/<id>) mit Kollision. false = kein Modell vorhanden.
static func place_prop(parent: Node, id: String, pos: Vector3, rot_y: float = 0.0, scl: float = 1.0, solid: bool = true) -> bool:
	var m := instance("props", id)
	if m == null:
		return false
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	holder.scale = Vector3.ONE * scl
	holder.add_child(m)
	parent.add_child(holder)
	if solid:
		add_collision(m)
	return true


## Erzeugt statische Kollision für alle Meshes eines Modells.
static func add_collision(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		# Gras, Blumen, Laub und Kleinkram (nocol_…) bekommen keine Kollision und werfen
		# keine Schatten auf niedriger Stufe; die Namen kommen aus tools/pipeline/loc_kit.py
		if String(m.name).begins_with("nocol_") or String(m.get_parent().name).begins_with("nocol_"):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not Settings.particles else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			continue
		m.create_trimesh_collision()
	if root is MeshInstance3D:
		(root as MeshInstance3D).create_trimesh_collision()


## Liste aller erwarteten Modelle mit Status (für README/Debug).
static func report() -> Array:
	var out: Array = []
	for kind in ["characters", "props", "locations"]:
		for id in config().get("expected", {}).get(kind, []):
			out.append([kind, id, has(kind, id)])
	return out


static func _template(kind: String, id: String) -> Variant:
	var key := kind + "/" + id
	if _cache.has(key):
		return _cache[key]
	var result: Variant = null
	var file: String = model_config(kind, id).get("file", id)
	for ext in RES_EXT:
		var p := "res://assets/models/%s/%s.%s" % [kind, file, ext]
		if ResourceLoader.exists(p):
			result = load(p)
			break
	if result == null:
		for dir in runtime_dirs():
			for ext in RUNTIME_EXT:
				var p := dir.path_join(kind).path_join("%s.%s" % [file, ext])
				if FileAccess.file_exists(p):
					result = _load_runtime(p)
					if result != null:
						break
			if result != null:
				break
	_cache[key] = result
	return result


## Lädt eine .glb/.gltf zur Laufzeit (ohne Import) über GLTFDocument.
static func _load_runtime(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK:
		push_warning("ModelLib: %s konnte nicht geladen werden (%d)" % [path, err])
		return null
	var scene := doc.generate_scene(st)
	return scene as Node3D


static func clear_cache() -> void:
	_cache.clear()

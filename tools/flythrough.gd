extends Node3D
## Kamerafahrt durch einen Ort, zum Aufnehmen mit Godots Movie Maker:
##   LOC=carne godot --path . --write-movie carne.avi --fixed-fps 30 --resolution 1920x1080 res://tools/flythrough.tscn
## Keyframes in Blender-Koordinaten des Ortsskripts (x, y, Höhe über Boden) → im Spiel (x, h, -y).

const PATHS := {
	"carne": {"secs": 48.0, "cam": [
		[-7, -84, 9.0, 0, -30, 3], [7, -62, 3.0, 2, -20, 3], [6, -34, 2.8, 3, 5, 2], [13, -6, 4.0, 3, 5, 1.2],
		[12, 14, 6.0, 0, 28, 2], [-12, 22, 11.0, 2, 52, 6], [-30, 0, 24.0, 4, 12, 0], [-52, -34, 38.0, 5, 15, 0]]},
	"jungle": {"secs": 44.0, "cam": [
		[0, -72, 10.0, 0, -20, 4], [0, -46, 2.6, 0, 0, 3], [0, -24, 3.2, 0, 2, 1.5], [13, -11, 5.0, 0, 0, 0.8],
		[13, 12, 8.0, 0, 0, 0.5], [-14, 13, 11.0, 0, 0, 0.5], [-20, -12, 18.0, 0, 0, 0], [-48, -48, 42.0, 0, 0, 0]]},
}

var _cam := Camera3D.new()
var _keys: Array = []
var _secs := 40.0
var _t := 0.0
var _rigs: Array = []


func _ready() -> void:
	Settings.tutorial_done = true
	var id := OS.get_environment("LOC")
	if not PATHS.has(id):
		id = "carne"
	var loc: Dictionary = Content.location_by_id[id]
	LocationBuilder.environment(self, loc, LocationBuilder.preset(loc.kind))
	var a := LocationBuilder.build(loc, self)
	_secs = PATHS[id].secs
	_keys = PATHS[id].cam
	_cast(id, a)
	_cam.fov = 60.0
	_cam.far = 400.0
	add_child(_cam)
	_cam.current = true
	Audio.play_music(loc.get("music", "title"))


## Figuren für die Szene: Ainz mit Gefolge (nur vorhandene Modelle).
func _cast(id: String, a: Dictionary) -> void:
	var slots: Array = a.get("slots", [])
	var ids := ["ainz", "albedo", "demiurge", "lupusregina"] if id == "carne" else ["ainz", "albedo", "demiurge", "lupusregina", "skeleton", "skeleton"]
	for i in mini(ids.size(), slots.size()):
		var cid: String = ids[i]
		var r := CharacterRig.create(cid, func(rr): ProcModel.figure(rr, cid))
		r.position = slots[i]
		add_child(r)
		r.look_at(Vector3(a.spawn.x, r.position.y, a.spawn.z) if id == "carne" else Vector3(0, r.position.y, 0), Vector3.UP, true)
		_rigs.append(r)


func _ground(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -50, z))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if hit else 0.0


func _sample(u: float, off: int) -> Vector3:
	# Catmull-Rom über die Keyframes (off 0 = Kamera, 3 = Blickziel)
	var n := _keys.size()
	var f := clampf(u, 0.0, 0.9999) * (n - 1)
	var i := int(f)
	var t := f - i
	var p := []
	for k in [i - 1, i, i + 1, i + 2]:
		var key: Array = _keys[clampi(k, 0, n - 1)]
		p.append(Vector3(key[off], key[off + 2], -key[off + 1]))
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p[1]) + (-p[0] + p[2]) * t + (2.0 * p[0] - 5.0 * p[1] + 4.0 * p[2] - p[3]) * t2 + (-p[0] + 3.0 * p[1] - 3.0 * p[2] + p[3]) * t3)


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.5:          # Szene einschwingen lassen (Schatten, GI, Partikel)
		_t_place(0.0)
		return
	var u := smoothstep(0.0, 1.0, (_t - 1.5) / _secs)
	_t_place(u)
	for r in _rigs:
		(r as CharacterRig).pose(Fighter.S.IDLE, "", 0.0, 0.0)
	if _t > _secs + 2.5:
		get_tree().quit()


func _t_place(u: float) -> void:
	var c := _sample(u, 0)
	var l := _sample(u, 3)
	c.y += _ground(c.x, c.z)
	l.y += _ground(l.x, l.z)
	_cam.position = c
	_cam.look_at(l)

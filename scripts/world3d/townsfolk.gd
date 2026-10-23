class_name Townsfolk
extends Node3D
## Bewohner, die einen Ort beleben: laufen zwischen den Walk_n-Ankern des Ortsmodells hin und her,
## bleiben an Idle_n-Ankern stehen und plaudern. Keine Kollision, keine Kampflogik.
## Gestalt: prozedurale Personen mit zufälliger Kleidung (oder ein Modell „townsfolk_n“, falls vorhanden).

const SKIN := ["#f0d5c0", "#e2bfa3", "#c99a78", "#a8775a", "#f5ddc8"]
const HAIR := ["#2a1d14", "#5a3a20", "#8a6a3a", "#c9a25a", "#3a3a3a", "#b9b0a5", "#7a2f1a"]
const CLOTH := ["#6b4a2e", "#7a6a4a", "#4a5a3a", "#8a3a2a", "#3a4a6a", "#9a8a6a", "#5a3a4a", "#a07a4a", "#4a3a2a"]
const STYLES := ["short", "long", "bun", "short", "bald"]

var _walk: Array = []          ## Vector3-Wegpunkte
var _people: Array = []        ## {rig, pos, target, speed, wait, talk}
var _rng := RandomNumberGenerator.new()


## Erzeugt die Bewohner. count = 0 → automatisch nach Anzahl Wegpunkte.
## style = "adventurer": Rüstung, Helme, Waffen und Umhänge (Gäste der Abenteurergilde) statt Dorftracht.
static func spawn(parent: Node3D, walk: Array, idle: Array, seed_v: int, count: int = 0, style: String = "") -> Townsfolk:
	var t := Townsfolk.new()
	t.name = "Townsfolk"
	parent.add_child(t)
	t._rng.seed = seed_v
	t._walk = walk
	t._style = style
	var n := count if count > 0 else clampi(walk.size() + idle.size(), 6, 28)
	if not Settings.particles:
		n = mini(n, 8)
	for i in n:
		var standing := i < idle.size() and (walk.is_empty() or t._rng.randf() < 0.8)
		var p: Vector3 = idle[i] if standing else walk[t._rng.randi() % walk.size()] if not walk.is_empty() else Vector3.ZERO
		t._add(p, standing)
	return t


var _style := ""
const ARMOR := ["#8a8f98", "#6a6e78", "#a8aeb8", "#5a4a3a"]
const CAPE := ["#5a1414", "#1a3a5a", "#2a4a2a", "#3a2a4a", "#6a5a2a"]


func _add(pos: Vector3, standing: bool) -> void:
	var f := {
		"skin": SKIN[_rng.randi() % SKIN.size()],
		"hair": [HAIR[_rng.randi() % HAIR.size()], STYLES[_rng.randi() % STYLES.size()]],
		"top": CLOTH[_rng.randi() % CLOTH.size()],
		"bottom": ["dress" if _rng.randf() < 0.4 else "pants", CLOTH[_rng.randi() % CLOTH.size()]],
		"trim": CLOTH[_rng.randi() % CLOTH.size()],
		"apron": _rng.randf() < 0.25,
		"scale": _rng.randf_range(0.88, 1.04),
	}
	if _style == "adventurer":
		f["bottom"] = ["pants", CLOTH[_rng.randi() % CLOTH.size()]]
		f["apron"] = false
		f["scale"] = _rng.randf_range(0.94, 1.06)
		f["armor"] = _rng.randf() < 0.6
		if _rng.randf() < 0.3:
			f["helmet"] = ARMOR[_rng.randi() % ARMOR.size()]
		if _rng.randf() < 0.4:
			f["cape"] = CAPE[_rng.randi() % CAPE.size()]
		if _rng.randf() < 0.35:
			f["tabard"] = CAPE[_rng.randi() % CAPE.size()]
		var weapons := [["sword", "#c8c8d0"], ["sword", "#c8c8d0"], ["bow", "#5a3a20"], ["sword_shield", "#d0d0d8"], ["staff", "#9fe070"], ["axe", "#9a9a9a"]]
		f["weapon"] = weapons[_rng.randi() % weapons.size()]
	var rig := CharacterRig.create("", func(r: CharacterRig) -> void: ProcModel._person(r, f))
	add_child(rig)
	rig.position = pos
	rig.rotation.y = _rng.randf() * TAU
	_people.append({"rig": rig, "target": pos, "speed": _rng.randf_range(1.0, 1.6),
		"wait": _rng.randf_range(0.0, 6.0) if not standing else 1e9, "talk": standing})


func _process(delta: float) -> void:
	for p in _people:
		var rig: CharacterRig = p.rig
		if p.talk:
			# Gesprächsgruppe: leicht wippen und sich gelegentlich umdrehen
			rig.pose(Fighter.S.IDLE, "", 0.0, 0.0)
			if _rng.randf() < delta * 0.08:
				rig.rotation.y += _rng.randf_range(-0.8, 0.8)
			continue
		var to: Vector3 = p.target - rig.position
		to.y = 0.0
		if to.length() < 0.4:
			p.wait -= delta
			rig.pose(Fighter.S.IDLE, "", 0.0, 0.0)
			if p.wait <= 0.0 and not _walk.is_empty():
				p.target = _next_point(rig.position)
				p.wait = _rng.randf_range(2.0, 9.0)
			continue
		var dir := to.normalized()
		rig.position += dir * p.speed * delta
		rig.position.y = lerpf(rig.position.y, _ground_y(p.target, rig.position), 0.2)
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.z), delta * 5.0)
		rig.pose(Fighter.S.MOVE, "", 0.0, p.speed / 4.0)


## Nächster Wegpunkt: zufällig unter den nahen Punkten (läuft so die Straßen entlang).
func _next_point(from: Vector3) -> Vector3:
	var near: Array = []
	for w in _walk:
		var d := (w as Vector3).distance_to(from)
		if d > 1.0 and d < 22.0:
			near.append(w)
	if near.is_empty():
		return _walk[_rng.randi() % _walk.size()]
	return near[_rng.randi() % near.size()]


func _ground_y(target: Vector3, at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 3, 0), at + Vector3(0, -6, 0))
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if hit else target.y

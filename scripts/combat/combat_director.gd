class_name CombatDirector
## Regie für Gruppenkämpfe: Nur wenige Gegner dürfen gleichzeitig zuschlagen („Angriffsrechte“), die übrigen
## kreisen auf Abstand, verteilen sich rund um das Ziel (Tiere bevorzugt im Rücken), warten auf eine Lücke
## oder schießen aus der zweiten Reihe. Dazu Alarm (Nachbarn ziehen mit) und ein Maß für Ausrufe und Warnrufe,
## damit nicht zehn Gegner gleichzeitig brüllen.

const MELEE_BUDGET := 2
const RANGED_BUDGET := 2
const TOKEN_TIMEOUT := 4.5

static var _melee := {}          ## Ziel-ID → {Gegner-ID: Zeitpunkt}
static var _ranged := {}
static var _engaged := {}        ## Ziel-ID → [Gegner]
static var _last_bark := -100.0
static var _last_alert := -100.0


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _prune(d: Dictionary) -> void:
	var now := _now()
	for k in d.keys():
		var o := instance_from_id(k)
		var e := o as Enemy3D
		if e == null or not is_instance_valid(e) or e.state == Fighter.S.DEAD or now - float(d[k]) > TOKEN_TIMEOUT:
			d.erase(k)


## Angriffsrecht anfragen (true = darf angreifen). Bosse dürfen immer.
static func request(e: Enemy3D, target: Node, ranged: bool = false) -> bool:
	if e == null or target == null:
		return false
	var pool := _ranged if ranged else _melee
	var tid := target.get_instance_id()
	if not pool.has(tid):
		pool[tid] = {}
	var d: Dictionary = pool[tid]
	_prune(d)
	var eid := e.get_instance_id()
	if d.has(eid):
		d[eid] = _now()
		return true
	if e.data.get("boss", false):
		d[eid] = _now()
		return true
	var budget := RANGED_BUDGET if ranged else MELEE_BUDGET
	# Bosse belegen keinen Platz der Gefolgsleute
	var used := 0
	for k in d:
		var o := instance_from_id(k) as Enemy3D
		if o and not o.data.get("boss", false):
			used += 1
	if used < budget:
		d[eid] = _now()
		return true
	return false


static func release(e: Enemy3D) -> void:
	if e == null:
		return
	var eid := e.get_instance_id()
	for pool in [_melee, _ranged]:
		for tid in pool:
			(pool[tid] as Dictionary).erase(eid)


static func engage(e: Enemy3D, target: Node) -> void:
	var tid := target.get_instance_id()
	if not _engaged.has(tid):
		_engaged[tid] = []
	var list: Array = _engaged[tid]
	if not e in list:
		list.append(e)


static func disengage(e: Enemy3D) -> void:
	release(e)
	for tid in _engaged:
		(_engaged[tid] as Array).erase(e)


## Alle lebenden Gegner, die gerade gegen `target` kämpfen.
static func engaged(target: Node) -> Array:
	if target == null:
		return []
	var tid := target.get_instance_id()
	if not _engaged.has(tid):
		return []
	var list: Array = _engaged[tid]
	var alive: Array = []
	for e in list:
		if is_instance_valid(e) and e.state != Fighter.S.DEAD and e.is_inside_tree():
			alive.append(e)
	_engaged[tid] = alive
	return alive


## Platz auf dem Kreis um das Ziel: Richtung vom Ziel zur gewünschten Position. Gegner schieben sich auseinander,
## Rudeltiere drängen in den Rücken des Ziels.
static func slot_dir(e: Enemy3D, target: Fighter, flank: bool) -> Vector3:
	var tp := target.global_position
	var a := atan2(e.global_position.x - tp.x, e.global_position.z - tp.z)
	var others := engaged(target)
	var n := maxi(1, others.size())
	var min_sep := clampf(TAU / n * 0.85, deg_to_rad(38.0), deg_to_rad(110.0))
	var push := 0.0
	for o in others:
		if o == e:
			continue
		var oa := atan2(o.global_position.x - tp.x, o.global_position.z - tp.z)
		var d := wrapf(a - oa, -PI, PI)
		if absf(d) < min_sep:
			push += signf(d if absf(d) > 0.001 else (1.0 if e.get_instance_id() > o.get_instance_id() else -1.0)) * (min_sep - absf(d)) * 0.6
	if flank:
		var back := atan2(-target.facing.x, -target.facing.z)
		push += wrapf(back - a, -PI, PI) * 0.2
	var want := a + clampf(push, -0.9, 0.9)
	return Vector3(sin(want), 0.0, cos(want))


## Abstoßung von nahen Verbündeten (kein Klumpen, kein Durchlaufen).
static func separation(e: Enemy3D, radius: float = 1.7) -> Vector3:
	var push := Vector3.ZERO
	for o in e.get_tree().get_nodes_in_group("enemies"):
		if o == e or not o is Fighter or (o as Fighter).state == Fighter.S.DEAD:
			continue
		var d: Vector3 = e.global_position - (o as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		if l < radius and l > 0.01:
			push += d / l * (radius - l) / radius
	return push


## Alarm: Gegner im Umkreis von `at` bemerken `target` und ziehen mit in den Kampf.
static func alarm(target: Fighter, radius: float, at: Vector3 = Vector3.INF) -> void:
	if target == null or not target.is_inside_tree():
		return
	var c := target.global_position if at == Vector3.INF else at
	for o in target.get_tree().get_nodes_in_group("enemies"):
		var e := o as Enemy3D
		if e and e.state != Fighter.S.DEAD and e.global_position.distance_to(c) <= radius:
			e.notice(target)


static func can_bark() -> bool:
	if _now() - _last_bark < 3.5:
		return false
	_last_bark = _now()
	return true


static func can_alert_sound() -> bool:
	if _now() - _last_alert < 1.2:
		return false
	_last_alert = _now()
	return true


static func reset() -> void:
	_melee.clear()
	_ranged.clear()
	_engaged.clear()

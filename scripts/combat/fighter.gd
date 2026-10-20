class_name Fighter
extends CharacterBody3D
## Basisklasse für alle Kämpfer (Spieler und Gegner).
##
## Zustandsautomat:
##   IDLE/MOVE → ATTACK (Wind-up → Aktiv → Recovery) → IDLE
##   DODGE (i-Frames) · BLOCK (Parierfenster am Anfang) · CAST · STAGGER · STUN · DEAD
## Werte: Leben, Ausdauer, Mana, Rüstung, Widerstände, Haltung (Poise), Statuseffekte.
## Schaden läuft immer über take_hit(info, angreifer) – auch für Zauber und Projektile.
## Treffergefühl (CombatFX.on_struck): Trefferstopp (freeze), Zurückzucken (react), Funken/Blut/Splitter je Stoff.
## Kritische Treffer, Rückentreffer, Konter (Gegner in der Erholung) und Treffer gegen Wehrlose zählen mehr.

signal died(f: Fighter)
signal damaged(f: Fighter, amount: int, kind: String)
signal struck(f: Fighter, result: String, info: Dictionary, dealt: float)

enum S { IDLE, MOVE, ATTACK, DODGE, BLOCK, CAST, STAGGER, STUN, DEAD }
const STATE_NAMES := ["Bereit", "Bewegung", "Angriff", "Ausweichen", "Block", "Zauber", "Taumeln", "Gelähmt", "Tot"]

var display_name := ""
var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var max_mana := 0.0
var mana := 0.0
var armor := 0.0
var resist: Dictionary = {}            ## Schadensart → Multiplikator
var max_poise := 40.0
var poise := 40.0
var move_speed := 4.0
var is_player := false
var team := 1                          ## 0 = Nazarick (Ainz und Verbündete), 1 = Feinde
var body_height := 1.85                ## für Trefferpunkt, Zahlen, Effekte
var body_radius := 0.45
var fx_material := "flesh"             ## Stoff für Treffereffekte (CombatFX.MATERIALS)
var crit_chance := 0.0                 ## Chance auf kritische Treffer (×1,6)
var undying := false                   ## überlebt den ersten tödlichen Treffer mit 1 LP (Todesritter)
var hp_floor := 0.0                    ## tiefer fällt das Leben nicht (Story-Bosse, die vorher aufgeben)
var _undying_used := false
var _freeze := 0.0
var _status_fx := {}

var state: int = S.IDLE
var state_time := 0.0
var attack: Dictionary = {}            ## laufender Angriff
var phase := ""                        ## windup | active | recovery
var block_time := 0.0
var invulnerable := false
var shield_time := 0.0                 ## Schutzbarriere (absorbiert einen Treffer)
var status: Dictionary = {}            ## burn/chill/stun → verbleibende Sekunden
var facing := Vector3.FORWARD          ## Blickrichtung (Welt, flach)
var knock := Vector3.ZERO              ## Rückstoß, klingt ab
var stamina_delay := 0.0
var hitbox: Hitbox
var hurtbox: Hurtbox
var rig: CharacterRig

var parry_window := 0.22
var block_stamina_mult := 0.6
var stamina_regen := 20.0
var mana_regen := 0.0
var _burn_tick := 0.0


func setup_combat(is_pl: bool, team_id: int = -1) -> void:
	is_player = is_pl
	team = team_id if team_id >= 0 else (0 if is_pl else 1)
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	hurtbox = Hurtbox.new(self, team == 0)
	add_child(hurtbox)
	hitbox = Hitbox.new(self, team == 1)
	add_child(hitbox)


# =====================================================================
#  Bewegung mit Stufen
# =====================================================================

const STEP_HEIGHT := 0.55

## move_and_slide mit Treppensteigen: blockiert eine niedrige Kante (Teppichrand, Stufe, Schwelle)
## die Bewegung, wird geprüft, ob der Körper STEP_HEIGHT höher frei weiterkommt und dort Boden findet.
func move_with_steps(delta: float) -> void:
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var was_floor := is_on_floor()
	var before := global_position
	move_and_slide()
	if not was_floor or horiz.length() < 0.2:
		return
	# Nur bei einer Kante auf Fußhöhe (nicht bei echten Wänden, die sind höher)
	var low_wall := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < 0.75 and c.get_position().y - before.y < STEP_HEIGHT and c.get_normal().dot(horiz) < 0.0:
			low_wall = true
			break
	if not low_wall:
		return
	var t := Transform3D(global_transform.basis, before)
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(t, up):
		return
	t.origin += up
	var fwd := horiz.normalized() * maxf(horiz.length() * delta, 0.12)
	if test_move(t, fwd):
		return
	t.origin += fwd
	var col := KinematicCollision3D.new()
	if not test_move(t, -up - Vector3(0, 0.05, 0), col) or col.get_normal().y < 0.7:
		return
	var land := t.origin + col.get_travel()
	if land.y - before.y < 0.01:
		return   # keine Stufe, nur flach daneben
	global_position = land
	apply_floor_snap()


# =====================================================================
#  Zustände
# =====================================================================

func set_state(s: int) -> void:
	if state == S.DEAD:
		return
	if state == S.ATTACK and s != S.ATTACK:
		hitbox.deactivate()
	state = s
	state_time = 0.0
	invulnerable = false
	if s == S.BLOCK:
		block_time = 0.0
	_on_state(s)


## Für Unterklassen (Animation, Sounds).
func _on_state(_s: int) -> void:
	pass


func can_act() -> bool:
	return state in [S.IDLE, S.MOVE] and not has_status("stun")


func busy() -> bool:
	return state in [S.ATTACK, S.DODGE, S.CAST, S.STAGGER, S.STUN, S.DEAD]


## Startet einen Angriff (Daten aus combat.json). Liefert false bei zu wenig Ausdauer.
func start_attack(a: Dictionary) -> bool:
	var cost := float(a.get("stamina", 0))
	if cost > 0.0 and stamina < cost * 0.5:
		return false
	use_stamina(cost)
	attack = a
	phase = "windup"
	set_state(S.ATTACK)
	return true


## Trefferstopp: Zustandszeit und Animation stehen still (victim = Getroffener bebt dazu).
func freeze(secs: float, victim: bool = false) -> void:
	if state == S.DEAD and not victim:
		return
	_freeze = maxf(_freeze, secs)
	if rig:
		rig.time_mult = 0.0
		if victim:
			rig.jitter(secs, 0.035)


func frozen() -> bool:
	return _freeze > 0.0


func tick_combat(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta
		if _freeze <= 0.0 and rig:
			rig.time_mult = 1.0
		return
	state_time += delta
	_tick_status(delta)
	if shield_time > 0.0:
		shield_time -= delta
	# Ausdauer/Mana regenerieren (nicht beim Blocken/Angreifen)
	if stamina_delay > 0.0:
		stamina_delay -= delta
	elif state != S.BLOCK:
		stamina = minf(max_stamina, stamina + stamina_regen * delta * (0.5 if state == S.ATTACK else 1.0))
	mana = minf(max_mana, mana + mana_regen * delta)
	poise = minf(max_poise, poise + max_poise * 0.25 * delta)
	knock = knock.move_toward(Vector3.ZERO, 25.0 * delta)
	match state:
		S.ATTACK: _tick_attack(delta)
		S.BLOCK: block_time += delta
		S.STAGGER:
			if state_time >= 0.75:
				set_state(S.IDLE)
		S.STUN:
			if not has_status("stun"):
				set_state(S.IDLE)


func _tick_attack(delta: float) -> void:
	var w := float(attack.get("windup", 0.4))
	var act := float(attack.get("active", 0.15))
	var rec := float(attack.get("recovery", 0.5))
	if phase == "windup" and state_time >= w:
		phase = "active"
		_on_attack_active()
		# Fern-, Flächen- und Beschwörungsangriffe treffen über eigene Wege, nicht über die Nahkampfzone
		if not String(attack.get("kind", "melee")) in ["projectile", "aoe", "summon"]:
			hitbox.activate(_attack_info(attack), float(attack.get("range", 2.0)), float(attack.get("arc", 120)))
	elif phase == "active":
		# Vorwärtsschub während des Schlags
		var lunge := float(attack.get("lunge", 0.0))
		if lunge > 0.0:
			velocity.x = facing.x * lunge / maxf(act, 0.05) * 0.5
			velocity.z = facing.z * lunge / maxf(act, 0.05) * 0.5
		if state_time >= w + act:
			phase = "recovery"
			hitbox.deactivate()
	elif phase == "recovery" and state_time >= w + act + rec:
		phase = ""
		_on_attack_end()
		set_state(S.IDLE)


func _on_attack_active() -> void:
	pass


func _on_attack_end() -> void:
	pass


func _attack_info(a: Dictionary) -> Dictionary:
	return {
		"amount": float(a.get("damage", 10)), "type": a.get("type", "physical"),
		"stagger": float(a.get("stagger", 20)), "knockback": float(a.get("knockback", 2.0)),
		"unblockable": a.get("unblockable", false), "status": a.get("status", {}), "name": a.get("name", ""),
		"kind": a.get("kind", "light"), "guard_mult": float(a.get("guard_mult", 2.0 if a.get("kind", "") == "heavy" else 1.0)),
	}


func use_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(-20.0, stamina - amount)
	stamina_delay = 0.8


# =====================================================================
#  Treffer
# =====================================================================

## Ergebnis: "dodge" | "parry" | "block" | "guardbreak" | "shield" | "hit" | "kill" | "none"
func take_hit(info_in: Dictionary, from: Node3D) -> String:
	if state == S.DEAD:
		return "none"
	var info := info_in.duplicate()
	var res := _resolve_hit(info, from)
	var dealt := float(info.get("_dealt", 0.0))
	CombatFX.on_struck(self, from, info, res, dealt)
	struck.emit(self, res, info, dealt)
	return res


func _resolve_hit(info: Dictionary, from: Node3D) -> String:
	if invulnerable:
		_feedback("Ausgewichen", Color(0.7, 0.85, 1.0))
		return "dodge"
	var src := from.global_position if from and is_instance_valid(from) else global_position + facing
	var atk := CombatFX.attacker_of(from)
	info["_src"] = src
	# Blocken / Parieren (nur von vorn, nicht gegen rote Angriffe)
	if state == S.BLOCK and is_facing(src, 150.0) and not info.get("unblockable", false):
		if block_time <= parry_window:
			_feedback("PARIERT!", Palette.GOLD_BRIGHT)
			stamina = minf(max_stamina, stamina + 15.0)
			if atk and not info.get("ranged", false):
				atk.stagger(1.0, global_position)
			_on_parry()
			return "parry"
		use_stamina(float(info.amount) * block_stamina_mult * float(info.get("guard_mult", 1.0)))
		if stamina <= 0.0:
			_feedback("Deckung gebrochen", Palette.DANGER)
			info["_dealt"] = _apply_damage(float(info.amount) * 0.5, info, src)
			stagger(1.0, src)
			return "guardbreak"
		_feedback("Geblockt", Color(0.8, 0.8, 0.9))
		info["_dealt"] = _apply_damage(float(info.amount) * 0.1, info, src, false)
		knock = (global_position - src).normalized() * 2.0
		_on_block()
		return "block"
	if shield_time > 0.0:
		shield_time = 0.0
		_feedback("Barriere absorbiert", Palette.GOLD_BRIGHT)
		_on_shield_break(src)
		return "shield"
	# Wucht-Zuschläge: Rücken, Konter (Gegner in der Erholung), wehrlos (taumelt/gelähmt), kritischer Treffer
	var flags: Array = []
	var mult := 1.0
	if not info.get("ranged", false) and atk and not is_facing(atk.global_position, 220.0):
		flags.append("back")
		mult *= 1.35
	if state == S.ATTACK and phase == "recovery":
		flags.append("punish")
	if state in [S.STAGGER, S.STUN]:
		flags.append("helpless")
		mult *= 1.3
	var cc := (atk.crit_chance if atk else 0.0) + float(info.get("crit_bonus", 0.0))
	if cc > 0.0 and randf() < cc:
		flags.append("crit")
		mult *= 1.6
	info["flags"] = flags
	var dealt := _apply_damage(float(info.amount) * mult, info, src)
	info["_dealt"] = dealt
	# Haltung: genug Wucht lässt den Gegner taumeln – außer er holt gerade unaufhaltsam aus
	var armored: bool = state == S.ATTACK and phase == "windup" and attack.get("armor", false)
	if not armored:
		poise -= float(info.get("stagger", 0.0)) * (1.25 if "crit" in flags else 1.0)
	var st: Dictionary = info.get("status", {})
	if hp > 0.0 or (undying and not _undying_used):
		for k in st:
			add_status(k, float(st[k]))
	if hp <= 0.0:
		if undying and not _undying_used:
			_undying_used = true
			hp = 1.0
			_feedback("Unbeugsam!", Color(0.8, 0.5, 1.0))
			_on_undying()
			stagger(1.0, src)
			return "hit"
		die()
		return "kill"
	if poise <= 0.0 and state != S.STUN:
		poise = max_poise
		stagger(1.0, src)
	elif dealt > 0.0:
		_on_hurt()
	return "hit"


## Trefferpunkt am Körper (Brusthöhe, zur Quelle hin) – dort entstehen Funken, Blut und Splitter.
func hit_point(src: Vector3) -> Vector3:
	var d := src - global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.05 else facing
	return global_position + Vector3.UP * body_height * 0.6 + d * body_radius * 0.8


## Zurückzucken (Feder auf Rumpf/Kopf), dir = Schlagrichtung.
func react(dir: Vector3, strength: float) -> void:
	if rig and state != S.DEAD:
		rig.hit_react(dir, strength)


func _apply_damage(amount: float, info: Dictionary, src: Vector3, show_number: bool = true) -> float:
	var t: String = info.get("type", "physical")
	var mult := float(resist.get(t, 1.0))
	if t == "physical":
		mult *= 100.0 / (100.0 + armor)
	else:
		mult *= 100.0 / (100.0 + armor * 0.3)
	if state == S.ATTACK and phase == "recovery":
		mult *= 1.25    # Wer nach einem Fehlschlag offen steht, nimmt mehr Schaden (Konter)
	var dmg := maxf(0.0, amount * mult)
	hp = maxf(hp_floor, hp - dmg)
	var kb := float(info.get("knockback", 0.0))
	if kb > 0.0:
		var dir := (global_position - src)
		dir.y = 0.0
		knock = dir.normalized() * kb
	if show_number and dmg > 0.0:
		damaged.emit(self, roundi(dmg), t)
	return dmg


func stagger(_strength: float, src: Vector3) -> void:
	if state == S.DEAD:
		return
	var dir := global_position - src
	dir.y = 0.0
	knock = dir.normalized() * 4.0
	set_state(S.STAGGER)


func die() -> void:
	hp = 0.0
	_clear_status_fx()
	hitbox.deactivate()
	state = S.DEAD
	state_time = 0.0
	hurtbox.set_deferred("monitorable", false)
	_on_state(S.DEAD)
	died.emit(self)


# =====================================================================
#  Statuseffekte
# =====================================================================

func add_status(k: String, secs: float) -> void:
	status[k] = maxf(float(status.get(k, 0.0)), secs)
	_status_visual(k, true)
	if k == "stun" and state != S.DEAD:
		hitbox.deactivate()
		set_state(S.STUN)
	_feedback({"burn": "Brennt", "chill": "Unterkühlt", "stun": "Gelähmt"}.get(k, k), {"burn": Color(1, 0.55, 0.2), "chill": Color(0.6, 0.85, 1), "stun": Color(0.7, 0.9, 1)}.get(k, Color.WHITE))


func has_status(k: String) -> bool:
	return float(status.get(k, 0.0)) > 0.0


func speed_mult() -> float:
	return 0.5 if has_status("chill") else 1.0


func _tick_status(delta: float) -> void:
	for k in status.keys():
		status[k] = float(status[k]) - delta
		if float(status[k]) <= 0.0:
			status.erase(k)
			_status_visual(k, false)
	if has_status("burn") and state != S.DEAD:
		_burn_tick += delta
		if _burn_tick >= 0.5:
			_burn_tick = 0.0
			hp = maxf(hp_floor, hp - 4.0)
			damaged.emit(self, 4, "fire")
			CombatFX.float_text(get_parent(), global_position + Vector3(randf_range(-0.3, 0.3), body_height + 0.3, 0), "4", Color(1.0, 0.55, 0.2), 30)
			if hp <= 0.0:
				die()


## Sichtbare Zustände: Flammen bei Brand, Frosthauch bei Kälte, kreisende Funken bei Lähmung.
func _status_visual(k: String, on: bool) -> void:
	if on and not _status_fx.has(k) and is_inside_tree() and state != S.DEAD:
		var e: GPUParticles3D = null
		match k:
			"burn":
				e = CombatFX.emitter(self, "burning", Color(1.0, 0.5, 0.15))
				if e:
					e.position = Vector3.UP * body_height * 0.5
			"chill":
				e = CombatFX.emitter(self, "aura", Color(0.6, 0.85, 1.0))
			"stun":
				e = CombatFX.emitter(self, "trail_motes", Color(0.7, 0.9, 1.0))
				if e:
					e.position = Vector3.UP * (body_height + 0.25)
		if e:
			_status_fx[k] = e
	elif not on and _status_fx.has(k):
		CombatFX.stop(_status_fx[k])
		_status_fx.erase(k)


func _clear_status_fx() -> void:
	for k in _status_fx.keys():
		CombatFX.stop(_status_fx[k])
	_status_fx.clear()


# =====================================================================
#  Hilfen
# =====================================================================

func is_facing(point: Vector3, arc_deg: float) -> bool:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.3:
		return true
	return rad_to_deg(facing.angle_to(to.normalized())) <= arc_deg / 2.0


func face_towards(point: Vector3, weight: float = 1.0) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() > 0.05:
		facing = facing.slerp(to.normalized(), clampf(weight, 0.0, 1.0)).normalized()


## Kurze schwebende Rückmeldung (Text über dem Kopf) – Unterklassen reichen sie weiter.
func _feedback(_text: String, _color: Color) -> void:
	pass


func _on_parry() -> void:
	pass


func _on_hurt() -> void:
	pass


func _on_shield_break(_src: Vector3 = Vector3.ZERO) -> void:
	pass


func _on_block() -> void:
	pass


func _on_undying() -> void:
	pass

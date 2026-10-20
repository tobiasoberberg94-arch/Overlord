class_name CharacterRig
extends Node3D
## Sichtbare Gestalt einer Figur: echtes 3D-Modell (.glb mit AnimationPlayer) oder
## prozeduraler Ersatz aus Primitiven. Beide werden über dieselbe Schnittstelle animiert:
##   pose(state, phase, progress, move_ratio, attack_kind)  – jedes Bild aufrufen
##   flash(color, secs)                                      – Treffer/Telegraf-Leuchten
##   hit_react(dir, strength)                                – Zurückzucken (Feder auf Rumpf und Kopf)
##   time_mult / jitter(secs)                                – Trefferstopp: Animation anhalten, Körper bebt
##   hand_anchor(right)                                      – Punkt an der Hand (Zauberlicht, Waffen)
## Für .glb-Modelle werden Animationsnamen über data/models.json → animation_aliases
## zugeordnet (idle, walk, run, attack_light, attack_heavy, dodge, block, hit, death, cast).

const ANIM_KEYS := ["idle", "walk", "run", "attack_light", "attack_heavy", "dodge", "block", "hit", "death", "cast", "stagger",
	"dodge_fwd", "dodge_back", "dodge_left", "dodge_right", "cast_projectile", "cast_area", "cast_self", "cast_target", "cast_heavy"]
## Nutzbarer Abschnitt der Mixamo-Clips aus der Animationsbibliothek (Sekunden): die Rolle selbst ohne
## Anlauf/Aufstehen; rel = Anteil, an dem der Zauber „losgeht“ (fällt auf das Ende der Wirkzeit).
const SEGMENTS := {
	"dodge_fwd": [0.78, 2.05], "dodge_back": [0.3, 1.6], "dodge_left": [0.05, 0.95], "dodge_right": [0.05, 0.95],
	"dodge": [0.2, 1.4],
}
const CAST_RELEASE := {"cast_projectile": 0.45, "cast_area": 0.5, "cast_self": 0.45, "cast_target": 0.42, "cast_heavy": 0.62, "cast": 0.45}

var dodge_key := "dodge"            ## vom Kämpfer gesetzt (Richtung)
var cast_key := "cast"              ## vom Kämpfer gesetzt (Zauberart)
var _oneshot_left := 0.0           ## Ausschwingen eines Zaubers nach der Wirkzeit

var model_id := ""
var has_model := false
var anim: AnimationPlayer
var anim_map: Dictionary = {}          ## Schlüssel → Animationsname im Modell
var parts: Dictionary = {}             ## prozedural: Name → Node3D (Gelenke)
var body_base := 0.0                   ## Höhe des Körper-Drehpunkts (Hüfte)
var _current := ""
var _t := 0.0
var _overlay := StandardMaterial3D.new()        ## Leuchten (additiv): Warnungen, Zauber
var _flash_mat := StandardMaterial3D.new()      ## Trefferblitz (mischend): überstrahlt helle Figuren nicht
var _glow_on := false
var _flash_time := 0.0
var _flash_len := 0.0
var _flash_a := 0.4
var time_mult := 1.0:                  ## 0 = angehalten (Trefferstopp)
	set(v):
		time_mult = v
		if anim:
			anim.speed_scale = _speed * time_mult
var _speed := 1.0                      ## Abspielgeschwindigkeit der laufenden Animation
var _jitter := 0.0
var _jitter_amp := 0.03
var _hr: HitReact                      ## Trefferreaktion am Skelett (nur Modelle)
var _hr_axis := Vector3.RIGHT
var _hr_angle := 0.0
var _hr_vel := 0.0
var _anchors := {}
var _torso_base := Vector3.ZERO
var _model: Node3D                     ## Wurzel des .glb-Modells (für Absenken beim Knien)
var _model_y := 0.0
var kneel := 0.0                       ## Knien (Szenen): 0 = stehen, 1 = auf einem Knie
var _kneel_cur := 0.0
var bend := 0.0                        ## Verbeugen/Knien (Szenen): Neigung nach vorn …
var sink := 0.0                        ## … und Absenken des Körpers
var _bend_cur := 0.0
var _sink_cur := 0.0


## Erzeugt das Rig: Modell, falls vorhanden, sonst baut fallback(rig) die Ersatzfigur.
static func create(id: String, fallback: Callable) -> CharacterRig:
	var r := CharacterRig.new()
	r.model_id = id
	var m := ModelLib.instance("characters", id)
	if m:
		r.has_model = true
		r.add_child(m)
		r._model = m
		r._model_y = m.position.y
		r._find_animations(m)
	elif fallback.is_valid():
		fallback.call(r)
	B3.exclude_from_gi(r)
	# Figuren auf Sichtebene 2: Bodenmarken (Blut, Brand) und die Partikel-Bodenkollision lassen sie aus
	for gi in r.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).layers = 2
	var sk := r.skeleton()
	if sk and sk.find_bone("mixamorig_Spine") >= 0:
		r._hr = HitReact.new()
		r._hr.name = "HitReact"
		sk.add_child(r._hr)
	r._overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r._overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r._overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r._overlay.albedo_color = Color(0, 0, 0, 0)
	r._flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r._flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r._flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	r._flash_mat.albedo_color = Color(0, 0, 0, 0)
	return r


func _find_animations(m: Node) -> void:
	var players := m.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	anim = players[0]
	var names := anim.get_animation_list()
	var aliases: Dictionary = ModelLib.config().get("animation_aliases", {})
	var custom: Dictionary = ModelLib.model_config("characters", model_id).get("anims", {})
	for key in ANIM_KEYS:
		var wanted: Array = []
		if custom.has(key):
			wanted.append(custom[key])
		wanted += aliases.get(key, [key])
		for w in wanted:
			for n in names:
				if String(n).to_lower() == String(w).to_lower() or String(n).to_lower().contains(String(w).to_lower()):
					anim_map[key] = n
					break
			if anim_map.has(key):
				break
	for key in ["idle", "walk", "run", "block"]:
		if anim_map.has(key):
			var a := anim.get_animation(anim_map[key])
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
	play("idle")


func play(key: String, speed: float = 1.0, restart: bool = false) -> void:
	if anim == null:
		return
	var n: String = anim_map.get(key, anim_map.get("idle", ""))
	if n == "":
		return
	# Geschwindigkeit nur über speed_scale (play() mit eigener Geschwindigkeit würde sich damit multiplizieren)
	_speed = speed
	if n != _current or restart:
		anim.play(n, 0.15, 1.0)
		_current = n
	anim.speed_scale = _speed * time_mult


## Spielt den Abschnitt [a, b] eines Clips in `duration` Sekunden ab.
func play_segment(key: String, duration: float) -> void:
	if anim == null or not anim_map.has(key):
		return
	var n: String = anim_map[key]
	var seg: Array = SEGMENTS.get(key, [0.0, anim_length(key)])
	var b := minf(float(seg[1]), anim_length(key))
	var a := minf(float(seg[0]), b - 0.05)
	_speed = (b - a) / maxf(duration, 0.05)
	if n != _current:
		anim.play(n, 0.08, 1.0)
		anim.seek(a, true)
		_current = n
	anim.speed_scale = _speed * time_mult


## Zauber: Clip so schnell abspielen, dass der Auslösemoment auf `cast_time` fällt, danach ausschwingen.
func play_cast(key: String, cast_time: float) -> void:
	if anim == null:
		return
	if not anim_map.has(key):
		key = "cast"
	if not anim_map.has(key):
		return
	var rel: float = CAST_RELEASE.get(key, 0.45)
	var l := anim_length(key)
	var speed := clampf(l * rel / maxf(cast_time, 0.1), 0.8, 3.5)
	_speed = speed
	if anim_map[key] != _current:
		anim.play(anim_map[key], 0.1, 1.0)
		_current = anim_map[key]
		_oneshot_left = l * (1.0 - rel) / speed + cast_time
	anim.speed_scale = _speed * time_mult


func anim_length(key: String) -> float:
	if anim == null or not anim_map.has(key):
		return 0.0
	return anim.get_animation(anim_map[key]).length


func flash(color: Color, secs: float = 0.2, strength: float = 0.4) -> void:
	_flash_mat.albedo_color = Color(color, strength)
	_flash_time = secs
	_flash_len = secs
	_flash_a = strength
	_set_overlay(_flash_mat)


func _set_overlay(m: Material) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = m


## Dauerhaftes Leuchten (z. B. Wind-up eines Gegners). alpha 0 = aus.
func glow(color: Color, alpha: float) -> void:
	_overlay.albedo_color = Color(color, alpha)
	var on := alpha > 0.01
	if on == _glow_on and _flash_time <= 0.0:
		return
	_glow_on = on
	if _flash_time <= 0.0:
		_set_overlay(_overlay if on else null)


func _process(delta: float) -> void:
	_t += delta * time_mult
	_oneshot_left = maxf(0.0, _oneshot_left - delta * time_mult)
	# Trefferstopp: Körper bebt kurz auf der Stelle
	if _jitter > 0.0:
		_jitter -= delta
		position = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * _jitter_amp if _jitter > 0.0 else Vector3.ZERO
	# Zurückzucken: gedämpfte Feder (läuft erst nach dem Trefferstopp los)
	if time_mult > 0.0 and (absf(_hr_angle) > 0.0005 or absf(_hr_vel) > 0.0005):
		var dt := minf(delta, 0.05)
		_hr_vel += (-130.0 * _hr_angle - 12.0 * _hr_vel) * dt
		_hr_angle += _hr_vel * dt
		if absf(_hr_angle) < 0.0005 and absf(_hr_vel) < 0.01:
			_hr_angle = 0.0
			_hr_vel = 0.0
	# Verbeugen/Knien weich ein- und ausblenden
	if absf(_bend_cur - bend) > 0.0005 or absf(_sink_cur - sink) > 0.0005 or absf(_kneel_cur - kneel) > 0.0005:
		_bend_cur = move_toward(_bend_cur, bend, delta * 1.6)
		_sink_cur = move_toward(_sink_cur, sink, delta * 1.2)
		_kneel_cur = move_toward(_kneel_cur, kneel, delta * 2.2)
		if _model:
			_model.position.y = _model_y - _sink_cur
	if _hr:
		_hr.axis = _hr_axis
		_hr.angle = _hr_angle
		_hr.bend = _bend_cur
		_hr.kneel = _kneel_cur
		_hr.bend_axis = Vector3.UP.cross(global_basis.z.normalized()).normalized()
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_mat.albedo_color.a = _flash_a * maxf(0.0, _flash_time / maxf(_flash_len, 0.01))
		if _flash_time <= 0.0:
			_set_overlay(_overlay if _glow_on else null)


## Szenen: nach vorn neigen (Bogenmaß) und absenken (Meter) – Verbeugung.
func set_bend(angle: float, down: float) -> void:
	bend = angle
	sink = down


## Szenen: auf ein Knie gehen (1) oder aufstehen (0) – mit gebeugten Beinen, nicht nur abgesenkt.
func set_kneel(k: float) -> void:
	kneel = clampf(k, 0.0, 1.0)


## Zurückzucken vom Treffer weg: dir = Schlagrichtung (Welt), strength ≈ 0.3 (leicht) … 1.5 (schwer).
func hit_react(dir: Vector3, strength: float) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01:
		d = -global_basis.z
	d = d.normalized()
	# Drehachse so, dass der Oberkörper in Schlagrichtung wegkippt
	_hr_axis = Vector3.UP.cross(d).normalized()
	_hr_vel += 10.0 * clampf(strength, 0.0, 2.0)


## Trefferstopp: Körper bebt `secs` lang.
func jitter(secs: float, amp: float = 0.03) -> void:
	_jitter = maxf(_jitter, secs)
	_jitter_amp = amp


func skeleton() -> Skeleton3D:
	var list := find_children("*", "Skeleton3D", true, false)
	return list[0] if not list.is_empty() else null


## Punkt an der Hand, der der Animation folgt (Zauberlicht, gehaltene Waffen). Ohne Skelett: Ende des Arms.
func hand_anchor(right: bool = true) -> Node3D:
	var key := "r" if right else "l"
	if _anchors.has(key) and is_instance_valid(_anchors[key]):
		return _anchors[key]
	var a: Node3D = null
	var sk := skeleton()
	var bone := "mixamorig_RightHand" if right else "mixamorig_LeftHand"
	if sk and sk.find_bone(bone) >= 0:
		var ba := BoneAttachment3D.new()
		ba.bone_name = bone
		sk.add_child(ba)
		a = Node3D.new()
		a.name = "hand_" + key
		ba.add_child(a)
	if a == null:
		var arm: Node3D = parts.get("arm_r" if right else "arm_l")
		if arm:
			a = Node3D.new()
			a.position = Vector3(0, -0.78, 0.06)
			arm.add_child(a)
	if a == null:
		a = Node3D.new()
		a.position = Vector3(-0.3 if right else 0.3, 1.3, 0.4)
		add_child(a)
	_anchors[key] = a
	return a


## Hängt ein Objekt an einen Knochen (z. B. Bogen an die linke Hand). false = kein passender Knochen.
func attach_to_bone(bone: String, node: Node3D) -> bool:
	var sk := skeleton()
	if sk == null or sk.find_bone(bone) < 0:
		return false
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	ba.add_child(node)
	# Skelette aus Mixamo sind oft skaliert (cm): Waffe auf Weltmaß der Figur bringen
	if ba.is_inside_tree():
		var s_b := ba.global_basis.get_scale()
		var s_r := global_basis.get_scale()
		node.scale = Vector3(s_r.x / maxf(s_b.x, 0.0001), s_r.y / maxf(s_b.y, 0.0001), s_r.z / maxf(s_b.z, 0.0001))
	return true


## Haupt-Animationssteuerung. state = Fighter.S, progress 0…1 innerhalb der Phase.
func pose(state: int, phase: String, progress: float, move_ratio: float, attack_kind: String = "light", total: float = 1.0) -> void:
	if has_model:
		_pose_model(state, move_ratio, attack_kind, total)
	else:
		_pose_proc(state, phase, progress, move_ratio, attack_kind)


func _pose_model(state: int, move_ratio: float, attack_kind: String, total: float) -> void:
	match state:
		Fighter.S.ATTACK:
			var key := "attack_heavy" if attack_kind == "heavy" else "attack_light"
			var l := anim_length(key)
			play(key, l / maxf(total, 0.1) if l > 0.0 else 1.0)
		Fighter.S.DODGE:
			if dodge_key == "leap":
				# Sprungangriff: schwerer Schlag über die ganze Flugzeit
				var lh := anim_length("attack_heavy")
				play("attack_heavy", lh / maxf(total, 0.1) if lh > 0.0 else 1.0)
			elif dodge_key == "step":
				# Ausweichschritt der Gegner: kurzer Satz statt Rolle
				if anim_map.has("dodge_back"):
					play_segment("dodge_back", total)
				else:
					play("run", 1.8)
			else:
				play_segment(dodge_key if anim_map.has(dodge_key) else "dodge", total)
		Fighter.S.BLOCK: play("block")
		Fighter.S.CAST: play_cast(cast_key, total)
		Fighter.S.STAGGER, Fighter.S.STUN: play("stagger" if anim_map.has("stagger") else "hit")
		Fighter.S.DEAD: play("death")
		_:
			# Zauber schwingt aus, solange Ainz nicht losläuft
			if _oneshot_left > 0.0 and move_ratio < 0.15:
				return
			_oneshot_left = 0.0
			if move_ratio > 0.6:
				play("run")
			elif move_ratio > 0.08:
				play("walk", 0.6 + move_ratio)
			else:
				play("idle")


## Prozedurale Animation über Gelenke: arm_r, arm_l, leg_l, leg_r, torso, body.
func _pose_proc(state: int, phase: String, p: float, move_ratio: float, attack_kind: String) -> void:
	var body: Node3D = parts.get("body", self)
	var arm_r: Node3D = parts.get("arm_r")
	var arm_l: Node3D = parts.get("arm_l")
	var leg_l: Node3D = parts.get("leg_l")
	var leg_r: Node3D = parts.get("leg_r")
	var torso: Node3D = parts.get("torso")
	var walk := sin(_t * (7.0 + move_ratio * 6.0)) * move_ratio
	var ar := Vector3(walk * -0.6, 0, 0)
	var al := Vector3(walk * 0.6, 0, 0)
	var tor := Vector3.ZERO
	var b_rot := Vector3.ZERO
	var b_y := sin(_t * 1.6) * 0.015 + absf(walk) * 0.05
	if leg_l:
		leg_l.rotation.x = lerpf(walk * 0.7, -0.9, _kneel_cur)
	if leg_r:
		leg_r.rotation.x = lerpf(-walk * 0.7, 0.45, _kneel_cur)
	var heavy := attack_kind == "heavy"
	match state:
		Fighter.S.ATTACK:
			var raise := 2.5 if heavy else 2.0   # Arm nach oben/hinten (Ausholen)
			match phase:
				"windup":
					ar = Vector3(lerpf(0.0, raise, ease(p, 0.5)), 0, lerpf(0.0, -0.4, p))
					tor = Vector3(lerpf(0, -0.15, p), lerpf(0.0, 0.5, p), 0)
					if heavy:
						al = Vector3(lerpf(0.0, raise, p), 0, 0)
				"active":
					ar = Vector3(lerpf(raise, -1.1, ease(p, 0.3)), 0, lerpf(-0.4, 0.3, p))
					tor = Vector3(lerpf(-0.15, 0.25, p), lerpf(0.5, -0.6, p), 0)
					if heavy:
						al = Vector3(lerpf(raise, -1.1, p), 0, 0)
				_:
					ar = Vector3(lerpf(-1.1, 0.0, p), 0, 0)
					tor = Vector3(lerpf(0.25, 0.0, p), lerpf(-0.6, 0.0, p), 0)
					if heavy:
						al = Vector3(lerpf(-1.1, 0.0, p), 0, 0)
		Fighter.S.DODGE:
			if dodge_key == "leap":
				# beide Arme/Waffen hoch über dem Kopf, zum Aufschlag nach vorn
				var k := clampf(p * 1.3, 0.0, 1.0)
				ar = Vector3(lerpf(2.6, -1.0, smoothstep(0.6, 1.0, k)), 0, 0)
				al = ar
				tor = Vector3(lerpf(-0.25, 0.3, smoothstep(0.55, 1.0, k)), 0, 0)
				b_y = 0.0
			elif dodge_key == "step":
				tor = Vector3(-0.25, 0, 0.2)
				b_y = sin(p * PI) * 0.18
				ar = Vector3(-0.6, 0, 0.5)
			else:
				b_rot.x = p * TAU
				b_y = sin(p * PI) * 0.3 - 0.4 * sin(p * PI)
		Fighter.S.BLOCK:
			ar = Vector3(-1.4, 0, 0.5)
			al = Vector3(-1.5, 0, -0.5)
		Fighter.S.CAST:
			ar = Vector3(-1.7, 0, 0)
			tor.x = -0.1
		Fighter.S.STAGGER:
			tor.x = -0.35 * (1.0 - p)
			ar = Vector3(-0.8, 0, 0.6)
		Fighter.S.STUN:
			tor = Vector3(0.25, sin(_t * 3.0) * 0.2, sin(_t * 2.0) * 0.15)
		Fighter.S.DEAD:
			b_rot.x = lerpf(0.0, -PI / 2.0, minf(1.0, p * 2.0))
			b_y = -0.2
	if arm_r:
		arm_r.rotation = arm_r.rotation.lerp(ar, 0.45 if state == Fighter.S.ATTACK else 0.2)
	if arm_l:
		arm_l.rotation = arm_l.rotation.lerp(al, 0.3)
	if torso:
		_torso_base = _torso_base.lerp(tor, 0.3)
		var flinch := Vector3.ZERO
		if absf(_hr_angle) > 0.0005:
			flinch = (global_basis.orthonormalized().inverse() * _hr_axis).normalized() * _hr_angle * 0.9
		torso.rotation = _torso_base + flinch + Vector3(_bend_cur, 0, 0)
	body.rotation.x = b_rot.x if state in [Fighter.S.DODGE, Fighter.S.DEAD] else lerpf(body.rotation.x, 0.0, 0.3)
	body.position.y = body_base + b_y - _sink_cur - body_base * 0.4 * _kneel_cur

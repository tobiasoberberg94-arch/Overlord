class_name CharacterRig
extends Node3D
## Sichtbare Gestalt einer Figur: echtes 3D-Modell (.glb mit AnimationPlayer) oder
## prozeduraler Ersatz aus Primitiven. Beide werden über dieselbe Schnittstelle animiert:
##   pose(state, phase, progress, move_ratio, attack_kind)  – jedes Bild aufrufen
##   flash(color, secs)                                      – Treffer/Telegraf-Leuchten
## Für .glb-Modelle werden Animationsnamen über data/models.json → animation_aliases
## zugeordnet (idle, walk, run, attack_light, attack_heavy, dodge, block, hit, death, cast).

const ANIM_KEYS := ["idle", "walk", "run", "attack_light", "attack_heavy", "dodge", "block", "hit", "death", "cast", "stagger"]

var model_id := ""
var has_model := false
var anim: AnimationPlayer
var anim_map: Dictionary = {}          ## Schlüssel → Animationsname im Modell
var parts: Dictionary = {}             ## prozedural: Name → Node3D (Gelenke)
var body_base := 0.0                   ## Höhe des Körper-Drehpunkts (Hüfte)
var _current := ""
var _t := 0.0
var _overlay := StandardMaterial3D.new()
var _flash_time := 0.0
var _flash_len := 0.0


## Erzeugt das Rig: Modell, falls vorhanden, sonst baut fallback(rig) die Ersatzfigur.
static func create(id: String, fallback: Callable) -> CharacterRig:
	var r := CharacterRig.new()
	r.model_id = id
	var m := ModelLib.instance("characters", id)
	if m:
		r.has_model = true
		r.add_child(m)
		r._find_animations(m)
	elif fallback.is_valid():
		fallback.call(r)
	r._overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r._overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r._overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r._overlay.albedo_color = Color(0, 0, 0, 0)
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
	if n != _current or restart:
		anim.play(n, 0.15, speed)
		_current = n
	else:
		anim.speed_scale = speed


func anim_length(key: String) -> float:
	if anim == null or not anim_map.has(key):
		return 0.0
	return anim.get_animation(anim_map[key]).length


func flash(color: Color, secs: float = 0.2) -> void:
	_overlay.albedo_color = Color(color, 0.55)
	_flash_time = secs
	_flash_len = secs
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _overlay


## Dauerhaftes Leuchten (z. B. Wind-up eines Gegners). alpha 0 = aus.
func glow(color: Color, alpha: float) -> void:
	_overlay.albedo_color = Color(color, alpha)
	var on := alpha > 0.01
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _overlay if on else null


func _process(delta: float) -> void:
	_t += delta
	if _flash_time > 0.0:
		_flash_time -= delta
		_overlay.albedo_color.a = 0.55 * maxf(0.0, _flash_time / maxf(_flash_len, 0.01))
		if _flash_time <= 0.0:
			for mi in find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = null


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
		Fighter.S.DODGE: play("dodge", 1.4)
		Fighter.S.BLOCK: play("block")
		Fighter.S.CAST: play("cast")
		Fighter.S.STAGGER, Fighter.S.STUN: play("stagger" if anim_map.has("stagger") else "hit")
		Fighter.S.DEAD: play("death")
		_:
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
		leg_l.rotation.x = walk * 0.7
	if leg_r:
		leg_r.rotation.x = -walk * 0.7
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
		torso.rotation = torso.rotation.lerp(tor, 0.3)
	body.rotation.x = b_rot.x if state in [Fighter.S.DODGE, Fighter.S.DEAD] else lerpf(body.rotation.x, 0.0, 0.3)
	body.position.y = body_base + b_y

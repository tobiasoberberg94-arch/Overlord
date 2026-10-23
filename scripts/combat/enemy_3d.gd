class_name Enemy3D
extends Fighter
## Gegner mit Charakter und klar lesbaren Angriffen (Werte und Angriffe aus data/combat.json → enemies).
##
## Verhalten (archetype, data.ai): grunt · duelist (blockt, kontert) · brute (unaufhaltsame schwere Schläge) ·
## beast (Rudel, flankiert, springt an und zieht sich zurück) · skirmisher (zuschlagen und ausweichen) ·
## archer / caster (Abstand halten, schießen, Flächenzauber, Beschwörungen) · boss (Phasen bei Lebensschwellen).
## Gruppenregie (CombatDirector): nur wenige greifen gleichzeitig an, die anderen kreisen, flankieren, lauern.
## Warnungen: Leuchten + Zeichen über dem Kopf (orange = blockbar, rot = nur ausweichen!), Bodenwarnung bei
## schweren Schlägen und Flächenangriffen, ein Aufblitzen kurz vor dem Treffer (Zeitpunkt für die Parade).
## Angriffsarten (attack.kind): melee (Trefferzone) · projectile · aoe (Kreis am Ziel) · summon.

signal defeated(e: Enemy3D)
signal telegraphed(e: Enemy3D, attack: Dictionary)

const ARCH := {
	"grunt": {"ring": 3.4, "strafe": 0.45, "block": 0.0, "dodge": 0.05, "retreat": 0.1, "cd": [1.0, 2.2]},
	"duelist": {"ring": 3.1, "strafe": 0.55, "block": 0.45, "parry": 0.1, "dodge": 0.12, "counter": 0.6, "retreat": 0.2, "cd": [0.7, 1.6]},
	"brute": {"ring": 3.8, "strafe": 0.3, "block": 0.0, "dodge": 0.0, "retreat": 0.0, "cd": [1.3, 2.5]},
	"beast": {"ring": 4.6, "strafe": 0.9, "block": 0.0, "dodge": 0.35, "retreat": 0.75, "flank": true, "cd": [0.8, 1.8]},
	"skirmisher": {"ring": 4.0, "strafe": 0.8, "block": 0.1, "dodge": 0.4, "retreat": 0.6, "cd": [0.8, 1.6]},
	"archer": {"ring": 11.0, "strafe": 0.6, "block": 0.0, "dodge": 0.3, "kite": 6.0, "ranged": true, "cd": [1.6, 2.8]},
	"caster": {"ring": 10.0, "strafe": 0.5, "block": 0.0, "dodge": 0.2, "kite": 6.5, "ranged": true, "cd": [2.0, 3.2]},
	"boss": {"ring": 3.2, "strafe": 0.55, "block": 0.35, "parry": 0.12, "dodge": 0.2, "counter": 0.7, "retreat": 0.15, "cd": [0.6, 1.4]},
}
const DEFAULT_AI := {"skeleton": "grunt", "death_knight": "brute", "soldier": "duelist", "wolf": "beast", "golem": "brute", "angel": "brute"}
const DEFAULT_MAT := {"skeleton": "bone", "death_knight": "dark_armor", "soldier": "armor", "wolf": "beast", "golem": "stone", "angel": "holy"}
const DEFAULT_HEIGHT := {"wolf": 1.05, "golem": 2.6, "death_knight": 2.3, "angel": 2.4, "skeleton": 1.85}
## Ausrufe je Gegnerart (überschreibbar mit data.barks)
const BARKS := {
	"soldier": {"alert": ["Für die Sechs Götter!", "Ein Untoter! Vernichtet ihn!", "Formation halten!"], "hurt": ["Er ist zu stark …", "Haltet stand!"], "death": ["Vergebt mir, Götter …"]},
	"angel": {"alert": ["Im Namen der Götter.", "Unreines wird geläutert."]},
	"mercenary": {"alert": ["Da ist er! Schnappt ihn euch!", "Für die Todesschwerter!"], "hurt": ["Verdammt!"], "death": ["Das … war's …"]},
	"eight_fingers": {"alert": ["Hier hast du nichts verloren!", "Macht ihn fertig!"], "hurt": ["Was bist du?!"]},
	"adventurer": {"alert": ["Ein Untoter in der Stadt!", "Ruft die Gilde!"], "hurt": ["Mithril reicht nicht …"]},
	"elf": {"alert": ["Für den König des Waldes!", "Eindringling!"], "death": ["Der Wald … weint …"]},
	"elf_archer": {"alert": ["Bogen spannen!", "Er kommt näher!"]},
	"lizard": {"alert": ["Für den Stamm!", "Die Grüne Klaue kämpft!"]},
	"zaryusu": {"alert": ["Ich bin Zaryusu Shasha. Ich fordere dich!"], "hurt": ["Frostschmerz, gib mir Kraft!"]},
	"brain": {"alert": ["Zeig mir deine Stärke!", "Endlich ein würdiger Gegner!"], "hurt": ["Unmöglich … so schnell?!"]},
	"gagaran": {"alert": ["Na komm schon, Knochenmann!"], "hurt": ["Hah! Das kitzelt!"]},
	"succulent": {"alert": ["Siehst du mich … oder doch nicht?"], "hurt": ["Wie kannst du durch die Illusion sehen?"]},
	"decem": {"alert": ["Ein Untoter wagt es, meinen Wald zu betreten?"], "hurt": ["Unverschämt!"]},
	"sunlit_caster": {"alert": ["Beschwört die Engel!", "Ein Ungeheuer – alle Zauber auf ihn!"], "hurt": ["Unsere Magie … wirkungslos?!"]},
	"scripture_archer": {"alert": ["Bogen! Zielt auf den Kopf!"]},
	"bandit_archer": {"alert": ["Pfeile los!"]},
}

static var spawner: Callable           ## world_3d.spawn_enemy (für Beschwörungen)
static var ally_spawner: Callable      ## world_3d.spawn_ally (Ainz' Beschwörungen)
static var hold := false               ## Filmszene: alle Kämpfer ruhen (keine KI, Angriffe brechen ab, Animation läuft)

var type_id := ""
var data: Dictionary = {}
var ally := false                      ## kämpft für Nazarick (Todesritter, Wächter in Szenen-Einsätzen)
var target: Fighter
var _retarget := 0.0
var home := Vector3.ZERO
var aggro := 14.0
var arch: Dictionary = {}
var role := "melee"                    ## melee | ranged
var engaged := false
var _alert_t := 0.0
var _cooldown := 1.0
var _strafe_dir := 1.0
var _think := 0.0
var _token := false
var _token_t := 0.0
var _block_t := 0.0
var _react_cd := 0.0
var _retreat_t := 0.0
var _dodge_dir := Vector3.ZERO
var _aoe_at := Vector3.ZERO
var _mark: GroundMark
var _phase_i := 0
var _summons: Array = []
var _last_hit := -100.0
var _dissolve := false
var _attack_cds := {}
var _speed_mult := 1.0
var _cd_mult := 1.0
var _extra: Array = []
var _hooked := false
var _hpbar: MeshInstance3D
var _hpbar_bg: MeshInstance3D
var _poisebar: MeshInstance3D
var _label: Label3D
var _fx_label: Label3D
var _bark_label: Label3D
var _fx_time := 0.0
var _bark_time := 0.0
var _tele_col := Color.WHITE
var _tele_a := 0.0
var yielded := false                   ## hat aufgegeben (Story): kniet, kämpft nicht mehr, ist unverwundbar
var summoned := false                  ## beschworen (Skelette eines Lichs …): wenig Seelen, keine Beute
var _emitters: Array = []


class AoeSource extends Node3D:
	var source: Fighter


static func create(id: String, ally: bool = false) -> Enemy3D:
	var e := Enemy3D.new()
	e.type_id = id
	e.data = Content.combat.enemies[id]
	e.ally = ally or String(e.data.get("team", "")) == "ally"
	return e


func _ready() -> void:
	setup_combat(false, 0 if ally else 1)
	add_to_group("allies" if ally else "enemies")
	display_name = data.name
	max_hp = float(data.hp)
	hp = max_hp
	armor = float(data.get("armor", 0))
	resist = data.get("resist", {})
	max_poise = float(data.get("poise", 30))
	poise = max_poise
	move_speed = float(data.get("speed", 3.5))
	max_stamina = 100.0
	stamina = 100.0
	aggro = float(data.get("aggro", 14))
	home = global_position
	var model: String = data.get("model", type_id)
	arch = ARCH.get(String(data.get("ai", DEFAULT_AI.get(model, "grunt"))), ARCH.grunt)
	role = "ranged" if arch.get("ranged", false) else "melee"
	parry_window = float(arch.get("parry", 0.0))
	fx_material = String(data.get("material", DEFAULT_MAT.get(model, "flesh")))
	body_height = float(data.get("height", DEFAULT_HEIGHT.get(model, 1.9)))
	body_radius = 0.8 if model == "golem" else 0.5
	undying = bool(data.get("undying", false))
	crit_chance = float(data.get("crit", 0.0))
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5 if model != "golem" else 0.8
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	var c := Color(data.get("color", "#cccccc"))
	var weapon := String(data.get("weapon", ""))
	if data.has("figure"):
		var fig := String(data.figure)
		rig = CharacterRig.create(String(data.get("model", ProcModel.model_of(fig))), func(r): ProcModel.figure(r, fig))
	else:
		rig = CharacterRig.create(model, func(r): ProcModel.enemy(r, model, c, weapon))
	add_child(rig)
	if data.has("figure"):
		ProcModel.accessories(rig, String(data.figure))
	if rig.has_model and weapon != "":
		ProcModel.attach_weapon(rig, weapon, c)
	if float(data.get("scale", 1.0)) != 1.0:
		rig.scale = Vector3.ONE * float(data.scale)
	if data.has("tint"):
		rig.glow(Color(data.tint), 0.12)
	# Dauereffekte (Flammenleib eines Elementars, Blutnebel …): [art, farbe, höhe (Anteil der Körpergröße)]
	for em in data.get("emit", []):
		var pe := CombatFX.emitter(self, String(em[0]), Color(String(em[1])))
		if pe:
			pe.position = Vector3.UP * body_height * (float(em[2]) if em.size() > 2 else 0.5)
			_emitters.append(pe)
	if data.has("light"):
		var lc: Array = data.light
		var ol := OmniLight3D.new()
		ol.light_color = Color(String(lc[0]))
		ol.light_energy = float(lc[1]) if lc.size() > 1 else 2.0
		ol.omni_range = float(lc[2]) if lc.size() > 2 else 7.0
		ol.shadow_enabled = false
		ol.position = Vector3.UP * body_height * 0.6
		add_child(ol)
		_emitters.append(ol)
	_build_bars()
	if rig.has_model:
		rig.play("idle")
		if rig.anim:
			rig.anim.advance(0.0)
	facing = Vector3.BACK
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_cooldown = randf_range(0.8, 1.8)


func _build_bars() -> void:
	var h := body_height + 0.55
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = NazarickTheme.display_font(700)
	_label.font_size = 36
	_label.outline_size = 8
	_label.pixel_size = 0.005
	_label.modulate = Color(1, 0.78, 0.74) if not data.get("elite", false) else Palette.GOLD_BRIGHT
	_label.outline_modulate = Color(0.05, 0.0, 0.02, 0.9)
	_label.text = ("◆ " + display_name + " ◆") if data.get("elite", false) else display_name
	_label.position.y = h + 0.25
	_label.visible = false
	add_child(_label)
	var bg := QuadMesh.new()
	bg.size = Vector2(1.2, 0.1)
	var m_bg := B3.mat(Color(0, 0, 0, 0.7))
	m_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m_bg.no_depth_test = true
	_hpbar_bg = B3.mesh(self, bg, Vector3(0, h, 0), m_bg)
	var fg := QuadMesh.new()
	fg.size = Vector2(1.16, 0.07)
	var m_fg := StandardMaterial3D.new()
	m_fg.albedo_color = Color(0.25, 0.85, 0.4) if ally else Color(0.9, 0.15, 0.2)
	m_fg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_fg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m_fg.billboard_keep_scale = true
	m_fg.no_depth_test = true
	_hpbar = B3.mesh(self, fg, Vector3(0, h, 0), m_fg)
	_hpbar.visible = false
	_hpbar_bg.visible = false
	if data.get("elite", false) or data.get("boss", false):
		# Haltung: wann bricht die Deckung? (gelb, unter dem Lebensbalken)
		var pq := QuadMesh.new()
		pq.size = Vector2(1.16, 0.035)
		var m_p := StandardMaterial3D.new()
		m_p.albedo_color = Color(1.0, 0.82, 0.3)
		m_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m_p.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m_p.billboard_keep_scale = true
		m_p.no_depth_test = true
		_poisebar = B3.mesh(self, pq, Vector3(0, h - 0.085, 0), m_p)
		_poisebar.visible = false
	_fx_label = Label3D.new()
	_fx_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_fx_label.font = NazarickTheme.display_font(800)
	_fx_label.font_size = 48
	_fx_label.outline_size = 10
	_fx_label.pixel_size = 0.006
	_fx_label.position.y = h + 0.7
	_fx_label.no_depth_test = true
	add_child(_fx_label)
	_bark_label = Label3D.new()
	_bark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark_label.font = NazarickTheme.italic_font(600)
	_bark_label.font_size = 30
	_bark_label.outline_size = 8
	_bark_label.pixel_size = 0.005
	_bark_label.modulate = Palette.PARCHMENT
	_bark_label.outline_modulate = Color(0, 0, 0, 0.9)
	_bark_label.position.y = h + 1.15
	_bark_label.no_depth_test = true
	_bark_label.width = 600
	_bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark_label.visible = false
	add_child(_bark_label)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# =====================================================================
#  Ablauf
# =====================================================================

func _physics_process(delta: float) -> void:
	tick_combat(delta)
	if state == S.DEAD:
		velocity = Vector3.ZERO
		_pose(delta)
		return
	if frozen():
		velocity = Vector3.ZERO
		_pose(delta)
		return
	if hold:
		if state in [S.ATTACK, S.BLOCK, S.DODGE, S.STAGGER, S.CAST]:
			set_state(S.IDLE)
		if _mark and is_instance_valid(_mark):
			_mark.release()
			_mark = null
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
		move_with_steps(delta)
		# alle blicken zum Geschehen: Feinde zu ihrem Ziel (meist Ainz), Verbündete zu ihrem Gegner
		if target and is_instance_valid(target) and target.state != S.DEAD and not yielded:
			face_towards(target.global_position, 5.0 * delta)
		_pose(delta)
		return
	if yielded:
		invulnerable = true
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
		move_with_steps(delta)
		_pose(delta)
		return
	_react_cd -= delta
	for k in _attack_cds.keys():
		_attack_cds[k] = float(_attack_cds[k]) - delta
	if state == S.DODGE:
		_tick_dodge()
	else:
		_ai(delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	velocity += knock
	move_with_steps(delta)
	velocity -= Vector3(knock.x, 0, knock.z)
	_pose(delta)


## Wahrnehmung: Gegner bemerkt das Ziel, ruft, zieht Nachbarn mit.
func notice(t: Fighter = null) -> void:
	if state == S.DEAD or engaged:
		return
	if t:
		target = t
	if target == null:
		return
	engaged = true
	_alert_t = randf_range(0.25, 0.6)
	CombatDirector.engage(self, target)
	_hook_target()
	_show_fx("!", Color(1, 0.8, 0.3), 0.9)
	if CombatDirector.can_alert_sound():
		CombatFX.sound(String(data.get("alert_sound", "enemy_alert")), global_position + Vector3.UP * body_height, 0.7)
	_bark("alert")
	CombatDirector.alarm(target, 12.0, global_position)


## Aufgeben (Story): Waffe sinkt, auf die Knie, keine Angriffe mehr – die Entscheidung liegt bei Ainz.
func surrender(text: String = "Gibt auf") -> void:
	if state == S.DEAD or yielded:
		return
	yielded = true
	if _mark and is_instance_valid(_mark):
		_mark.release()
	_mark = null
	_disengage()
	hitbox.deactivate()
	status.clear()
	_clear_status_fx()
	set_state(S.IDLE)
	invulnerable = true
	attack = {}
	phase = ""
	if rig:
		rig.glow(Color.WHITE, 0.0)
		rig.set_bend(0.3, 0.0)
		rig.set_kneel(1.0)
	_show_fx(text, Color(0.92, 0.88, 0.75), 2.4)
	CombatFX.sound("block", global_position + Vector3.UP, 0.6)


func _disengage() -> void:
	engaged = false
	_drop_token()
	CombatDirector.disengage(self)


func _hook_target() -> void:
	if _hooked or target == null or not is_instance_valid(target):
		return
	_hooked = true
	if target.has_signal("attack_started"):
		target.attack_started.connect(_on_threat)
	if target.has_signal("spell_cast"):
		target.spell_cast.connect(_on_spell_threat)


## Gegner der eigenen Seite: Verbündete jagen Feinde, Feinde wählen zwischen Ainz und seinen Verbündeten.
func _choose_target(delta: float) -> void:
	_retarget -= delta
	var valid := target != null and is_instance_valid(target) and target.state != S.DEAD
	if valid and _retarget > 0.0:
		return
	_retarget = randf_range(1.0, 1.8)
	var best: Fighter = target if valid else null
	var best_d := INF if not valid else global_position.distance_to(target.global_position) * 0.8
	var pool: Array = get_tree().get_nodes_in_group("enemies" if ally else "allies")
	if not ally:
		pool = pool + [Actor3D.player] if Actor3D.player is Fighter else pool
	for o in pool:
		var f := o as Fighter
		if f == null or f == self or f.state == S.DEAD or not f.is_inside_tree():
			continue
		var d := global_position.distance_to(f.global_position)
		if f.is_player:
			d *= 0.85                      # Ainz bleibt das Hauptziel
		if d < best_d:
			best_d = d
			best = f
	if best != target and best != null:
		if target and is_instance_valid(target):
			_drop_token()
			CombatDirector.disengage(self)
			engaged = false
			_hooked = false
		target = best
	elif best == null and not valid:
		target = null


func _ai(delta: float) -> void:
	if ally or get_tree().get_nodes_in_group("allies").size() > 0:
		_choose_target(delta)
	if target == null or not is_instance_valid(target) or target.state == S.DEAD:
		if engaged:
			_disengage()
		_idle(delta)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if not engaged:
		if dist < aggro or hp < max_hp:
			notice(target)
		else:
			_idle(delta)
			return
	# Leine: weit weg vom Posten und das Ziel außer Sicht → zurück
	if dist > aggro * 2.6 and global_position.distance_to(home) > aggro * 1.5 and _now() - _last_hit > 6.0:
		_disengage()
		return
	if _alert_t > 0.0:
		_alert_t -= delta
		face_towards(target.global_position, 8.0 * delta)
		_move(Vector3.ZERO, delta)
		return
	_check_phase()
	match state:
		S.ATTACK:
			_steer_attack(delta)
			return
		S.BLOCK:
			_tick_block(delta)
			return
	if busy():
		_move(Vector3.ZERO, delta)
		return
	_cooldown -= delta
	if role == "ranged":
		_ranged_ai(delta, to, dist)
	else:
		_melee_ai(delta, to, dist)


func _idle(delta: float) -> void:
	if ally and Actor3D.player is Fighter and is_instance_valid(Actor3D.player):
		_follow(delta, Actor3D.player)
		return
	var back := home - global_position
	back.y = 0.0
	_move(back.normalized() if back.length() > 1.0 else Vector3.ZERO, delta, 0.5)
	if back.length() > 1.0:
		face_towards(home, 4.0 * delta)


## Verbündete ohne Gegner bleiben bei Ainz: seitlich hinter ihm, laufen nach, wenn er sich entfernt.
func _follow(delta: float, p: Fighter) -> void:
	var side := 1.0 if get_instance_id() % 2 == 0 else -1.0
	var f := p.facing
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var spot := p.global_position - f * 2.6 + f.cross(Vector3.UP) * side * 2.4
	home = spot
	var to := spot - global_position
	to.y = 0.0
	var d := to.length()
	if d > 1.2:
		_move(to.normalized(), delta, 1.0 if d > 6.0 else 0.6)
		face_towards(spot, 6.0 * delta)
	else:
		_move(Vector3.ZERO, delta)
		face_towards(global_position + f, 3.0 * delta)


func _melee_ai(delta: float, to: Vector3, dist: float) -> void:
	face_towards(target.global_position, 6.0 * delta)
	var dirn := to.normalized() if dist > 0.01 else facing
	# nach dem eigenen Angriff kurz zurückweichen (Tiere, Plänkler)
	if _retreat_t > 0.0:
		_retreat_t -= delta
		_move((-dirn + dirn.cross(Vector3.UP) * _strafe_dir * 0.5 + CombatDirector.separation(self)).limit_length(1.0), delta, 0.85)
		return
	if _cooldown <= 0.0 and not _token:
		_token = CombatDirector.request(self, target)
		_token_t = 0.0
	if _token:
		_token_t += delta
		var a := _pick_attack(dist, "melee")
		if a.is_empty():
			a = _pick_attack(dist, "")
		if not a.is_empty():
			_begin_attack(a)
			return
		var reach := _max_range()
		_move((dirn + CombatDirector.separation(self) * 0.6).normalized(), delta, 1.15 if dist > reach + 2.0 else 0.9)
		if _token_t > 3.5:
			_drop_token()
			_cooldown = randf_range(0.4, 1.0)
		return
	# Kreisen und lauern auf dem eigenen Platz rund ums Ziel
	var slot := CombatDirector.slot_dir(self, target, arch.get("flank", false))
	var goal := target.global_position + slot * float(arch.ring)
	var g := goal - global_position
	g.y = 0.0
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(1.0, 2.4)
		if randf() < 0.45:
			_strafe_dir = -_strafe_dir
	var mv: Vector3
	if g.length() > 0.8:
		mv = g.normalized() * clampf(g.length() / 2.5, 0.35, 1.0)
	else:
		mv = dirn.cross(Vector3.UP) * _strafe_dir * float(arch.strafe)
	if dist < float(arch.ring) * 0.55:
		mv -= dirn * 0.7
	mv += CombatDirector.separation(self) * 0.9
	_move(mv.limit_length(1.0), delta, 0.62)
	# Lücke nutzen: taumelt das Ziel, schlagen Bosse auch ohne Angriffsrecht zu
	if data.get("boss", false) and _cooldown <= 0.0 and target.state in [S.STAGGER, S.STUN] and dist < _max_range() + 0.4:
		var a := _pick_attack(dist, "melee")
		if not a.is_empty():
			_begin_attack(a)


func _ranged_ai(delta: float, to: Vector3, dist: float) -> void:
	face_towards(target.global_position, 7.0 * delta)
	var dirn := to.normalized() if dist > 0.01 else facing
	var kite := float(arch.get("kite", 6.0))
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(1.2, 2.6)
		if randf() < 0.5:
			_strafe_dir = -_strafe_dir
	var mv: Vector3
	if dist < kite:
		mv = -dirn + dirn.cross(Vector3.UP) * _strafe_dir * 0.5
	elif dist > float(arch.ring) + 3.0:
		mv = dirn
	else:
		mv = dirn.cross(Vector3.UP) * _strafe_dir * float(arch.strafe)
	mv += CombatDirector.separation(self) * 0.9
	_move(mv.limit_length(1.0), delta, 0.85 if dist < kite else 0.6)
	if _cooldown > 0.0:
		return
	if dist < 2.8:
		var m := _pick_attack(dist, "melee")
		if not m.is_empty():
			_begin_attack(m)
			return
	if _line_of_sight() and CombatDirector.request(self, target, true):
		var a := _pick_attack(dist, "ranged")
		if not a.is_empty():
			_token = true
			_begin_attack(a)


func _line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * body_height * 0.8, target.global_position + Vector3.UP * target.body_height * 0.6, 1)
	return space.intersect_ray(q).is_empty()


func _attacks() -> Array:
	return data.attacks + _extra


func _attack_by_id(id: String) -> Dictionary:
	for a in _attacks():
		if String(a.get("id", "")) == id:
			return a
	return {}


func _max_range() -> float:
	var r := 1.5
	for a in _attacks():
		if String(a.get("kind", "melee")) == "melee":
			r = maxf(r, float(a.range))
	return r


## Angriff wählen (gewichtet): filter "melee", "ranged" (alles außer Nahkampf) oder "" (alles).
func _pick_attack(dist: float, filter: String) -> Dictionary:
	var options: Array = []
	var total := 0.0
	for a in _attacks():
		var k := String(a.get("kind", "melee"))
		if filter == "melee" and k != "melee":
			continue
		if filter == "ranged" and k == "melee":
			continue
		if float(_attack_cds.get(String(a.get("id", "")), 0.0)) > 0.0:
			continue
		if dist < float(a.get("min_range", 0.0)):
			continue
		if k == "summon" and _alive_summons() >= int(a.get("max", 2)):
			continue
		if dist > float(a.range) + (0.4 if k == "melee" else 0.0):
			continue
		var w := float(a.get("weight", 1.0))
		options.append([a, w])
		total += w
	if options.is_empty():
		return {}
	var r := randf() * total
	for o in options:
		r -= float(o[1])
		if r <= 0.0:
			return o[0]
	return options[-1][0]


func _alive_summons() -> int:
	_summons = _summons.filter(func(s): return is_instance_valid(s) and s.state != S.DEAD)
	return _summons.size()


func _begin_attack(a: Dictionary) -> void:
	if a.is_empty() or not start_attack(a.duplicate()):
		return
	var cd: Array = arch.get("cd", [1.0, 2.0])
	_cooldown = randf_range(float(cd[0]), float(cd[1])) * _cd_mult
	if a.has("cooldown"):
		_attack_cds[String(a.id)] = float(a.cooldown)
	_on_windup()


func _drop_token() -> void:
	if _token:
		_token = false
		CombatDirector.release(self)


func _move(dir: Vector3, delta: float, mult: float = 1.0) -> void:
	var sp := move_speed * mult * speed_mult() * _speed_mult
	velocity.x = move_toward(velocity.x, dir.x * sp, 18 * delta)
	velocity.z = move_toward(velocity.z, dir.z * sp, 18 * delta)


# =====================================================================
#  Angriffe
# =====================================================================

func _steer_attack(delta: float) -> void:
	var k := String(attack.get("kind", "melee"))
	if phase == "windup":
		var w := float(attack.windup)
		if k == "melee":
			# bis kurz vor Ende des Ausholens zielen, danach Richtung festhalten (Ausweichen lohnt sich!)
			if state_time < w * 0.7:
				face_towards(target.global_position, 8.0 * delta)
				if _mark and is_instance_valid(_mark) and _mark.fill_time > 0.0 and float(attack.get("arc", 120)) < 359.0:
					_mark.global_position = global_position
					_mark.rotation.y = atan2(-facing.x, -facing.z)
		else:
			face_towards(target.global_position, 10.0 * delta)
	if phase != "active":
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)


func _on_windup() -> void:
	var red: bool = attack.get("unblockable", false)
	var k := String(attack.get("kind", "melee"))
	var col := Color(1, 0.12, 0.1) if red else Color(1, 0.6, 0.15)
	if ally:
		col = Color(0.35, 0.8, 1.0)        # Verbündete: blau – keine Gefahr für Ainz
	var w := float(attack.windup)
	var lvl := get_parent()
	_tele_col = col
	_tele_a = 0.32 if red else 0.2
	if ally:
		_tele_a = 0.12
	rig.glow(col, _tele_a)
	if not ally:
		_show_fx("‼" if red else "!", Color(1, 0.2, 0.2) if red else Color(1, 0.7, 0.2), w)
	match k:
		"aoe":
			var lead := Vector3(target.velocity.x, 0, target.velocity.z) * minf(w * 0.35, 0.5)
			_aoe_at = target.global_position + lead
			var g := CombatFX._ground_below(lvl, _aoe_at + Vector3.UP * 1.5)
			if g != Vector3.INF:
				_aoe_at = g
			_mark = GroundMark.telegraph(lvl, _aoe_at, float(attack.get("radius", 3.0)), 360.0, 0.0, col, w)
			if float(attack.get("cast_circle", 1.0)) > 0.0:
				GroundMark.rune(lvl, global_position, 1.6, Color(attack.get("color", "#ffd070")), w + 0.3, "b", self, 1.2)
		"summon":
			GroundMark.rune(lvl, global_position, 2.2, Color(attack.get("color", "#b070ff")), w + 0.5, "b", self, 0.9)
			CombatFX.sound("cast_big", global_position + Vector3.UP, 0.7)
		"projectile":
			var hand := rig.hand_anchor(true)
			if hand:
				CombatFX.burst(lvl, "flash_soft", hand.global_position, Color(attack.get("color", "#ffd890")), Vector3.UP, 0.5)
		_:
			var arc := float(attack.get("arc", 120))
			var lunge := float(attack.get("lunge", 0.0))
			if red or w >= 0.85 or arc >= 359.0:
				var yaw := atan2(-facing.x, -facing.z)
				if lunge >= 3.0 and arc <= 90.0:
					_mark = GroundMark.telegraph_line(lvl, global_position, yaw, float(attack.range) + lunge * 0.6, 0.75, col, w)
				else:
					_mark = GroundMark.telegraph(lvl, global_position, float(attack.range) + lunge * 0.35, arc, yaw, col, w)
	# Aufblitzen kurz vor dem Treffer: jetzt blocken = Parade, rot = jetzt ausweichen
	var glint_at := maxf(0.05, w - 0.3)
	get_tree().create_timer(glint_at, false).timeout.connect(func():
		if is_instance_valid(self) and state == S.ATTACK and phase == "windup" and is_inside_tree() and not ally:
			var head := global_position + Vector3.UP * (body_height * 0.88) + facing * 0.2
			CombatFX.burst(get_parent(), "flash", head, col, Vector3.UP, 0.55)
			CombatFX.sound("telegraph_red" if red else "telegraph", head, 0.55, 0.03))
	telegraphed.emit(self, attack)


func _on_attack_active() -> void:
	rig.glow(Color.WHITE, 0.0)
	if data.has("tint"):
		rig.glow(Color(data.tint), 0.12)
	if _mark and is_instance_valid(_mark):
		_mark.release()
	_mark = null
	var k := String(attack.get("kind", "melee"))
	match k:
		"projectile":
			_shoot()
		"aoe":
			_aoe_strike()
		"summon":
			_summon()
		_:
			var red: bool = attack.get("unblockable", false)
			var col := Color(1.0, 0.35, 0.3) if red else (Color(attack.color) if attack.has("color") else Color(0.95, 0.9, 0.82))
			SlashFX.spawn(self, attack, col, 2.6 if red else 1.8)
			CombatFX.sound("swing_heavy" if float(attack.get("damage", 10)) >= 25.0 else "swing_light", global_position + Vector3.UP * 1.2, 0.75)


func _shoot() -> void:
	if target == null or not is_instance_valid(target):
		return
	var lvl := get_parent()
	var el := String(attack.get("fx", SpellFX.ELEMENT_OF_TYPE.get(String(attack.get("type", "physical")), "arrow")))
	var col := Color(attack.get("color", "#e8d8b0"))
	var origin := (rig.hand_anchor(true).global_position if rig.hand_anchor(true) else global_position + Vector3.UP * 1.5) + facing * 0.4
	var aim := target.global_position + Vector3.UP * target.body_height * 0.6
	var speed := float(attack.get("speed", 24.0))
	var t := origin.distance_to(aim) / maxf(speed, 1.0)
	aim += Vector3(target.velocity.x, 0, target.velocity.z) * t * 0.6
	if el == "arrow":
		aim.y += t * t * 3.5 * 0.5
	var info := _attack_info(attack)
	var n := int(attack.get("count", 1))
	for i in n:
		var dir := (aim - origin).normalized()
		if n > 1:
			dir = dir.rotated(Vector3.UP, deg_to_rad(lerpf(-float(attack.get("spread", 16)) * 0.5, float(attack.get("spread", 16)) * 0.5, float(i) / (n - 1))))
		var p := Projectile.spawn(lvl, self, origin, dir, speed, info, col, el)
		if float(attack.get("homing", 0.0)) > 0.0:
			p.homing = target
			p.turn = float(attack.homing)
	CombatFX.sound({"arrow": "arrow_shot", "lightning": "lightning", "steel": "swing_light", "sword": "swing_heavy"}.get(el, el + "_launch"), origin, 0.75)


## Flächenangriff am markierten Ort: Lichtsäule, Feuerball, Schattenimplosion oder Eisdornen – dann Schaden.
func _aoe_strike() -> void:
	var lvl := get_parent()
	var r := float(attack.get("radius", 3.0))
	var el := String(attack.get("fx", SpellFX.ELEMENT_OF_TYPE.get(String(attack.get("type", "physical")), "steel")))
	var col := Color(attack.get("color", "#ffd070"))
	match el:
		"holy":
			SpellFX.pillar(lvl, _aoe_at - Vector3.UP * 0.5, r * 0.55, 18.0, col, 0.3, 7.0)
			SpellFX.explosion(lvl, _aoe_at + Vector3.UP * 0.6, r * 0.6, "holy", col)
			CombatFX.sound("holy_impact", _aoe_at + Vector3.UP, 1.1)
		"fire":
			SpellFX.explosion(lvl, _aoe_at + Vector3.UP * 0.6, r * 0.7, "fire", col)
			CombatFX.decal(lvl, _aoe_at, "scorch", r * 2.0, 14.0, Color(1, 1, 1), 3.0)
			CombatFX.sound("fire_explode", _aoe_at + Vector3.UP, 1.1)
		"dark":
			SpellFX.implosion(lvl, _aoe_at + Vector3.UP * 0.8, r * 0.6, col)
			CombatFX.burst(lvl, "wisps", _aoe_at + Vector3.UP * 0.5, Color(0.1, 0.0, 0.15), Vector3.UP, 2.5, Color(col, 0.8))
			CombatFX.sound("dark_impact", _aoe_at + Vector3.UP, 1.0)
		"ice":
			for i in 7:
				var a := TAU * i / 7.0
				SpellFX.ice_spike(lvl, _aoe_at + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.2, 0.75), randf_range(0.9, 1.6), col, i * 0.02)
			CombatFX.sound("ice_shatter", _aoe_at + Vector3.UP, 1.0)
		"lightning":
			for i in 3:
				var top := _aoe_at + Vector3(randf_range(-1.5, 1.5), 14.0, randf_range(-1.5, 1.5))
				SpellFX.bolt(lvl, top, _aoe_at + Vector3(randf_range(-r, r) * 0.4, 0.2, randf_range(-r, r) * 0.4), col, 0.35, 0.4)
			CombatFX.burst(lvl, "sparks", _aoe_at + Vector3.UP * 0.3, col, Vector3.UP, 1.6)
			CombatFX.flash(lvl, _aoe_at + Vector3.UP * 2.0, col, 6.0, r * 3.0, 0.3)
			CombatFX.decal(lvl, _aoe_at, "scorch", r * 1.4, 12.0, Color(0.7, 0.8, 1.0), 1.5)
			CombatFX.sound("lightning", _aoe_at + Vector3.UP, 1.1)
		_:
			CombatFX.burst(lvl, "dust_ring", _aoe_at + Vector3.UP * 0.1, Color(0.56, 0.52, 0.46), Vector3.UP, 1.4)
			CombatFX.burst(lvl, "stone", _aoe_at + Vector3.UP * 0.3, Color(0.5, 0.47, 0.43), Vector3.UP, 1.4)
			CombatFX.decal(lvl, _aoe_at, "crack", r * 1.6, 14.0)
			CombatFX.sound("leap_land", _aoe_at + Vector3.UP, 1.0)
	GroundMark.ring(lvl, _aoe_at, r * 1.1, col, 0.5)
	CombatFX.shake(0.35, _aoe_at)
	var src := AoeSource.new()
	src.source = self
	lvl.add_child(src)
	src.global_position = _aoe_at
	var info := _attack_info(attack)
	for f in _opponents():
		if f and is_instance_valid(f) and f.state != S.DEAD:
			var d := Vector2(f.global_position.x - _aoe_at.x, f.global_position.z - _aoe_at.z).length()
			if d <= r:
				f.take_hit(info, src)
	src.queue_free()


## Alle Kämpfer der Gegenseite (für Flächenangriffe).
func _opponents() -> Array:
	var out: Array = []
	if ally:
		out = get_tree().get_nodes_in_group("enemies")
	else:
		out = get_tree().get_nodes_in_group("allies")
		if Actor3D.player is Fighter:
			out.append(Actor3D.player)
		elif target:
			out.append(target)
	return out


func _summon() -> void:
	var lvl := get_parent()
	var id := String(attack.get("summon", "skeleton"))
	var n := int(attack.get("count", 2))
	var col := Color(attack.get("color", "#b070ff"))
	for i in n:
		var a := TAU * (i + 0.5) / n + randf() * 0.4
		var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 3.2)
		var g := CombatFX._ground_below(lvl, p + Vector3.UP * 2.0)
		if g != Vector3.INF:
			p = g
		GroundMark.rune(lvl, p, 1.3, col, 1.6, "b", null, 1.6)
		CombatFX.burst(lvl, "motes", p + Vector3.UP * 0.5, col, Vector3.UP, 1.2)
		CombatFX.burst(lvl, "wisps", p + Vector3.UP * 0.3, Color(0.12, 0.05, 0.16), Vector3.UP, 1.0, Color(col, 0.6))
		var at := p
		get_tree().create_timer(0.35 + i * 0.12, false).timeout.connect(func():
			if not is_instance_valid(self) or not is_instance_valid(lvl):
				return
			var e: Enemy3D = _spawn_direct(id, at + Vector3.UP * 0.1) if ally or not spawner.is_valid() else spawner.call(id, at + Vector3.UP * 0.1)
			if e:
				e.summoned = true
				_summons.append(e)
				e.notice(target)
				CombatFX.burst(lvl, "flash_soft", at + Vector3.UP, col)
				CombatFX.flash(lvl, at + Vector3.UP, col, 3.0, 5.0, 0.4))
	CombatFX.sound("summon", global_position + Vector3.UP, 0.9)


func _spawn_direct(id: String, at: Vector3) -> Enemy3D:
	var e := Enemy3D.create(id, ally)
	e.position = at
	e.target = target
	get_parent().add_child(e)
	return e


func _on_attack_end() -> void:
	# Kombo: Folgeangriff mit Wahrscheinlichkeit
	var nxt := String(attack.get("next", ""))
	if nxt != "" and randf() < float(attack.get("next_chance", 0.6)) and target and is_instance_valid(target):
		var a := _attack_by_id(nxt)
		if not a.is_empty() and global_position.distance_to(target.global_position) <= float(a.range) + 1.0:
			call_deferred("_begin_attack", a)
			return
	_drop_token()
	if randf() < float(arch.get("retreat", 0.0)):
		_retreat_t = randf_range(0.6, 1.2)


# =====================================================================
#  Reaktionen: Blocken, Ausweichen, Kontern
# =====================================================================

## Ainz holt aus – je nach Art blocken, ausweichen oder stur stehen bleiben.
func _on_threat(a: Dictionary) -> void:
	if not engaged or state not in [S.IDLE, S.MOVE] or _react_cd > 0.0 or target == null or not is_instance_valid(target):
		return
	var d := global_position.distance_to(target.global_position)
	if d > float(a.get("range", 2.0)) + 2.2 or not target.is_facing(global_position, 110.0):
		return
	_react_cd = 0.9
	var heavy: bool = a.get("kind", "") == "heavy"
	var block_p := float(arch.get("block", 0.0)) * (0.6 if heavy else 1.0)
	var dodge_p := float(arch.get("dodge", 0.0)) * (1.3 if heavy else 1.0)
	var r := randf()
	var delay := randf_range(0.06, 0.2)
	if r < block_p:
		get_tree().create_timer(delay, false).timeout.connect(func():
			if is_instance_valid(self) and state in [S.IDLE, S.MOVE]:
				set_state(S.BLOCK)
				_block_t = randf_range(0.6, 1.1))
	elif r < block_p + dodge_p:
		get_tree().create_timer(delay, false).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(target):
				_dodge(target.global_position))


## Zauber auf Ainz' Seite: Geschossen ausweichen.
func _on_spell_threat(id: String) -> void:
	if not engaged or _react_cd > 0.0 or target == null or not is_instance_valid(target):
		return
	var sp: Dictionary = Content.combat.spells.get(id, {})
	if String(sp.get("kind", "")) != "projectile" or not target.is_facing(global_position, 50.0):
		return
	if global_position.distance_to(target.global_position) > 25.0:
		return
	_react_cd = 1.0
	if randf() < float(arch.get("dodge", 0.0)) * 0.8:
		get_tree().create_timer(randf_range(0.18, 0.32), false).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(target):
				_dodge(target.global_position))


func _dodge(away_from: Vector3) -> void:
	if state not in [S.IDLE, S.MOVE]:
		return
	var to := global_position - away_from
	to.y = 0.0
	to = to.normalized() if to.length() > 0.01 else -facing
	var side := to.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	_dodge_dir = (side * 0.85 + to * 0.45).normalized()
	if rig:
		rig.dodge_key = "step"
	set_state(S.DODGE)
	CombatFX.sound("dodge", global_position + Vector3.UP, 0.5)
	CombatFX.burst(get_parent(), "dust_puff", global_position + Vector3.UP * 0.15, Color(0.6, 0.56, 0.5), Vector3.UP, 0.5)


func _tick_dodge() -> void:
	var t := state_time / 0.38
	invulnerable = state_time > 0.04 and state_time < 0.26
	var sp := 7.5 * (1.0 - t * 0.7)
	velocity.x = _dodge_dir.x * sp
	velocity.z = _dodge_dir.z * sp
	face_towards(target.global_position if target and is_instance_valid(target) else global_position + facing, 0.3)
	if state_time >= 0.38:
		invulnerable = false
		set_state(S.IDLE)


func _tick_block(delta: float) -> void:
	if target and is_instance_valid(target):
		face_towards(target.global_position, 10.0 * delta)
	_move(Vector3.ZERO, delta)
	_block_t -= delta
	if _block_t <= 0.0:
		set_state(S.IDLE)


## Erfolgreich geblockt: Konter (Riposte) ohne auf ein Angriffsrecht zu warten.
func _on_block() -> void:
	if randf() < float(arch.get("counter", 0.0)) and target and is_instance_valid(target):
		var d := global_position.distance_to(target.global_position)
		var a := _pick_attack(d, "melee")
		if not a.is_empty():
			_block_t = 0.0
			set_state(S.IDLE)
			_show_fx("⚔", Color(1, 0.75, 0.3), 0.6)
			call_deferred("_begin_attack", a)


func _on_undying() -> void:
	rig.flash(Color(0.7, 0.3, 1.0), 0.8)
	CombatFX.burst(get_parent(), "wisps", global_position + Vector3.UP, Color(0.15, 0.0, 0.2), Vector3.UP, 2.0, Color(0.7, 0.3, 1.0, 0.8))
	CombatFX.sound("dark_impact", global_position + Vector3.UP, 0.9)


# =====================================================================
#  Bosse: Phasen
# =====================================================================

func _check_phase() -> void:
	var ph: Array = data.get("phases", [])
	while _phase_i < ph.size() and hp / max_hp <= float(ph[_phase_i].get("at", 0.5)):
		var p: Dictionary = ph[_phase_i]
		_phase_i += 1
		_speed_mult *= float(p.get("speed", 1.0))
		_cd_mult *= float(p.get("cd", 1.0))
		_extra += p.get("add", [])
		poise = max_poise
		if p.has("say"):
			_bark_text(String(p.say), 3.2)
		var lvl := get_parent()
		rig.flash(Color(1, 0.35, 0.2), 0.7)
		CombatFX.burst(lvl, "sparks_big", global_position + Vector3.UP, Color(1.0, 0.5, 0.25), Vector3.UP, 1.2)
		GroundMark.ring(lvl, global_position, 5.0, Color(1.0, 0.45, 0.2), 0.6)
		CombatFX.sound("roar", global_position + Vector3.UP * 1.5, 1.0)
		CombatFX.shake(0.3, global_position)
		if p.has("summon"):
			var s: Array = p.summon
			var fake := {"summon": s[0], "count": int(s[1]), "color": p.get("color", "#b070ff")}
			var keep := attack
			attack = fake
			_summon()
			attack = keep


# =====================================================================
#  Zustände, Tod, Darstellung
# =====================================================================

func _on_state(s: int) -> void:
	if s != S.ATTACK and rig:
		rig.glow(Color.WHITE, 0.0)
		if data.has("tint"):
			rig.glow(Color(data.tint), 0.12)
	if s != S.ATTACK and _mark and is_instance_valid(_mark):
		_mark.release()
		_mark = null
	if s in [S.STAGGER, S.STUN]:
		_drop_token()
	if s == S.DEAD:
		_hpbar.visible = false
		_hpbar_bg.visible = false
		if _poisebar:
			_poisebar.visible = false
		_label.visible = false
		set_collision_layer_value(2, false)
		_drop_token()
		CombatDirector.disengage(self)
		CombatFX.sound("bone_collapse" if fx_material in ["bone", "undead_lord"] else "death_body", global_position + Vector3.UP, 0.9)
		_bark("death")
		remove_from_group("enemies")
		remove_from_group("allies")
		for pe in _emitters:
			if pe is GPUParticles3D:
				CombatFX.stop(pe)
			elif is_instance_valid(pe):
				var tw := (pe as Node).create_tween()
				tw.tween_property(pe, "light_energy", 0.0, 1.2)
		_emitters.clear()
		defeated.emit(self)


func _pose(delta: float) -> void:
	var move := Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1)
	var prog := 0.0
	var total := 1.0
	var st := state
	if state == S.ATTACK and not attack.is_empty():
		var w := float(attack.windup)
		var a := float(attack.active)
		var r := float(attack.recovery)
		total = w + a + r
		match phase:
			"windup": prog = state_time / w
			"active": prog = (state_time - w) / a
			_: prog = (state_time - w - a) / r
		if String(attack.get("kind", "melee")) != "melee":
			st = S.CAST
			rig.cast_key = "cast_projectile" if String(attack.get("kind", "")) == "projectile" else "cast_area"
	elif state == S.DEAD:
		prog = state_time
	elif state == S.STAGGER:
		prog = state_time / 0.75
	elif state == S.DODGE:
		prog = state_time / 0.38
		total = 0.38
	rig.pose(st, phase, clampf(prog, 0.0, 1.0), clampf(move, 0.0, 1.0), "heavy" if float(attack.get("damage", 0)) >= 30 else "light", total)
	if state == S.ATTACK and phase == "windup" and _tele_a > 0.0:
		rig.glow(_tele_col, _tele_a * (0.65 + 0.35 * sin(state_time * 18.0)))
	rig.rotation.y = atan2(facing.x, facing.z)
	# Lebensbalken und Haltung (nicht in Filmszenen)
	var show := hp < max_hp and state != S.DEAD and not hold
	_hpbar.visible = show
	_hpbar_bg.visible = show
	if _poisebar:
		_poisebar.visible = show
		_poisebar.scale.x = maxf(0.001, poise / maxf(max_poise, 1.0))
	# Namensschild nur für das fixierte Ziel und für Elite-Gegner in der Nähe (kein Schilderwald)
	var locked: bool = target != null and is_instance_valid(target) and target.get("lock") == self
	var near: bool = target != null and is_instance_valid(target) and global_position.distance_to(target.global_position) < 14.0
	_label.visible = state != S.DEAD and not hold and (locked or (data.get("elite", false) and near))
	_hpbar.scale.x = maxf(0.001, hp / max_hp)
	if state == S.DEAD:
		if state_time > 1.9 and not _dissolve:
			_dissolve = true
			_death_dissolve()
		if state_time > 2.9:
			queue_free()
	if _fx_time > 0.0:
		_fx_time -= delta
		if _fx_time <= 0.0:
			_fx_label.text = ""
	if _bark_time > 0.0:
		_bark_time -= delta
		_bark_label.modulate.a = clampf(_bark_time / 0.4, 0.0, 1.0)
		if _bark_time <= 0.0:
			_bark_label.visible = false


## Zerfall nach dem Tod: Staub, Asche oder Lichtfunken je Stoff, der Körper sinkt in den Boden.
func _death_dissolve() -> void:
	var lvl := get_parent()
	var at := global_position + Vector3.UP * 0.4
	match fx_material:
		"bone", "undead_lord":
			CombatFX.burst(lvl, "dust_puff", at, Color(0.78, 0.74, 0.64), Vector3.UP, 2.2)
			CombatFX.burst(lvl, "bone", at + Vector3.UP * 0.3, Color(0.86, 0.82, 0.7), Vector3.UP, 0.8)
		"dark_armor":
			CombatFX.burst(lvl, "wisps", at, Color(0.1, 0.0, 0.14), Vector3.UP, 2.4, Color(0.6, 0.25, 1.0, 0.8))
		"holy":
			CombatFX.burst(lvl, "motes", at + Vector3.UP * 0.6, Color(1.0, 0.88, 0.5), Vector3.UP, 2.5)
		"stone":
			CombatFX.burst(lvl, "stone", at, Color(0.55, 0.52, 0.48), Vector3.UP, 1.6)
			CombatFX.burst(lvl, "dust_puff", at, Color(0.6, 0.57, 0.52), Vector3.UP, 2.0)
		"fire":
			CombatFX.burst(lvl, "embers", at + Vector3.UP * 0.6, Color(1.0, 0.5, 0.15), Vector3.UP, 3.0)
			CombatFX.burst(lvl, "flame_puff", at + Vector3.UP * 0.8, Color(1.0, 0.55, 0.2), Vector3.UP, 2.0)
			CombatFX.burst(lvl, "smoke", at + Vector3.UP, Color(0.16, 0.13, 0.12), Vector3.UP, 1.6, Color(1.0, 0.35, 0.05, 0.6))
		"plate":
			CombatFX.burst(lvl, "sparks_big", at + Vector3.UP * 0.8, Color(0.9, 0.95, 1.0), Vector3.UP, 1.4)
			CombatFX.burst(lvl, "motes", at + Vector3.UP * 0.8, Color(0.75, 0.9, 1.0), Vector3.UP, 2.0)
		_:
			CombatFX.burst(lvl, "dust_puff", at, Color(0.45, 0.42, 0.4), Vector3.UP, 1.4)
			CombatFX.burst(lvl, "wisps", at + Vector3.UP * 0.3, Color(0.3, 0.3, 0.32), Vector3.UP, 0.8)
	if rig:
		var tw := rig.create_tween()
		tw.tween_property(rig, "position:y", -1.6, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _show_fx(text: String, color: Color, secs: float = 0.8) -> void:
	_fx_label.text = text
	_fx_label.modulate = color
	_fx_time = secs


func _bark(kind: String) -> void:
	var b: Dictionary = data.get("barks", BARKS.get(type_id, BARKS.get(String(data.get("model", "")), {})))
	var list: Array = b.get(kind, [])
	if list.is_empty() or not CombatDirector.can_bark():
		return
	_bark_text(String(list.pick_random()), 2.6)


func _bark_text(t: String, secs: float) -> void:
	_bark_label.text = "»" + t + "«"
	_bark_label.visible = true
	_bark_label.modulate.a = 1.0
	_bark_time = secs


func _feedback(text: String, color: Color) -> void:
	_show_fx(text, color, 0.8)


func _on_hurt() -> void:
	_last_hit = _now()
	rig.flash(Color(1, 0.85, 0.75), 0.12, 0.32)
	if not engaged and target:
		notice(target)
	if hp < max_hp * 0.35 and randf() < 0.3:
		_bark("hurt")


func _on_parry() -> void:
	rig.flash(Palette.GOLD_BRIGHT, 0.25, 0.35)

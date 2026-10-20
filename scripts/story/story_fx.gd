class_name StoryFX
## Effekte für Filmszenen: das Gate (Portal aus Finsternis), Erweckung Untoter, Negative Burst,
## das Herz beim Herzgriff ohne Kampfziele.

## Gate: ovales Portal aus wirbelnder Schwärze mit violettem Rand; öffnet sich, steht `secs`, schließt sich.
static func gate(parent: Node, at: Vector3, secs: float = 4.0, facing: Vector3 = Vector3.BACK) -> void:
	if parent == null or not CombatFX.enabled:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	var f := facing
	f.y = 0.0
	if f.length() > 0.01:
		root.global_basis = Basis.looking_at(f.normalized(), Vector3.UP)
	var disc := SpellFX._mesh(root, SpellFX._sphere(), SpellFX._dark_mat(), Vector3.ZERO, Vector3(0.05, 0.05, 0.05))
	disc.set_instance_shader_parameter("rim_col", Color(0.62, 0.25, 1.0))
	disc.set_instance_shader_parameter("energy", 3.2)
	disc.position = Vector3.ZERO
	var halo := SpellFX._mesh(root, SpellFX._sphere(), SpellFX._orb_mat("soft"), Vector3.ZERO, Vector3(0.05, 0.05, 0.05))
	halo.position = Vector3.ZERO
	halo.set_instance_shader_parameter("core_col", Color(0.25, 0.05, 0.4))
	halo.set_instance_shader_parameter("rim_col", Color(0.62, 0.25, 1.0))
	halo.set_instance_shader_parameter("energy", 1.6)
	var ring := GroundMark.floating(parent, at, 1.9, Color(0.62, 0.3, 1.0), secs + 0.6, "a", null, 0.0)
	if ring:
		ring.global_basis = root.global_basis * Basis(Vector3.RIGHT, PI * 0.5)
		ring.spin_speed = 0.8
	var l := SpellFX._light(root, Vector3(0, 0, 0.4), Color(0.6, 0.25, 1.0), 0.0, 9.0)
	var motes := CombatFX.emitter(root, "aura", Color(0.65, 0.3, 1.0))
	if motes:
		motes.position = Vector3(0, -1.5, 0)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(disc, "scale", Vector3(1.5, 2.3, 0.12), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(halo, "scale", Vector3(1.75, 2.55, 0.06), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "light_energy", 3.5, 0.5)
	tw.chain().tween_interval(secs)
	tw.chain().tween_property(disc, "scale", Vector3(0.02, 0.02, 0.02), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(halo, "scale", Vector3(0.02, 0.02, 0.02), 0.45)
	tw.parallel().tween_property(l, "light_energy", 0.0, 0.4)
	tw.chain().tween_callback(func():
		if motes:
			CombatFX.stop(motes)
		root.queue_free())
	CombatFX.burst(parent, "wisps", at, Color(0.08, 0.0, 0.12), Vector3.UP, 1.6, Color(0.6, 0.25, 1.0, 0.8))
	CombatFX.sound("summon", at, 1.0, 0.0)


## Erweckung eines Untoten: Runenkreis, schwarzer Nebel, Implosion, aufsteigende Asche.
static func summon_undead(parent: Node, at: Vector3, col: Color = Color(0.55, 0.2, 0.9)) -> void:
	GroundMark.rune(parent, at, 2.4, col, 3.0, "b", null, 1.2)
	CombatFX.burst(parent, "wisps", at + Vector3.UP * 0.4, Color(0.08, 0.0, 0.12), Vector3.UP, 3.0, Color(col, 0.8))
	CombatFX.burst(parent, "motes", at + Vector3.UP * 0.6, col, Vector3.UP, 2.0)
	SpellFX.implosion(parent, at + Vector3.UP * 1.0, 1.8, col)
	CombatFX.burst(parent, "dust_ring", at + Vector3.UP * 0.1, Color(0.3, 0.28, 0.3), Vector3.UP, 1.2)
	CombatFX.sound("summon", at, 1.0, 0.0)
	CombatFX.sound("dark_impact", at, 0.8)


## Negative Burst: eine Kugel negativer Energie dehnt sich bis `radius` aus und vergeht.
static func negative_burst(parent: Node, at: Vector3, radius: float = 14.0) -> void:
	var col := Color(0.62, 0.2, 1.0)
	var m := SpellFX._mesh(parent, SpellFX._sphere(), SpellFX._dark_mat(), at + Vector3.UP, Vector3.ONE * 0.5)
	m.set_instance_shader_parameter("rim_col", col)
	m.set_instance_shader_parameter("energy", 4.0)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.0, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, 1.0).set_delay(0.25)
	tw.chain().tween_callback(m.queue_free)
	SpellFX.distortion(parent, at + Vector3.UP, radius * 1.2, 0.08, 0.9)
	for i in 3:
		GroundMark.ring(parent, at, radius * (0.6 + i * 0.25), col, 0.7 + i * 0.2, 0.08)
	CombatFX.burst(parent, "wisps", at + Vector3.UP, Color(0.08, 0.0, 0.12), Vector3.UP, 4.0, Color(col, 0.9))
	CombatFX.flash(parent, at + Vector3.UP * 2.0, col, 9.0, radius * 3.0, 1.0)
	SpellFX.screen_flash(Color(0.25, 0.0, 0.4, 0.55), 0.8)
	CombatFX.sound("shockwave", at, 1.2, 0.0)
	CombatFX.sound("dark_impact", at, 1.2, 0.0)
	CombatFX.shake(0.6)


## Herzgriff für Szenen: Herz erscheint bei `from`, schlägt `secs` lang, zerplatzt; Blut bei `to`.
static func heart_on(parent: Node, from: Vector3, to: Vector3, secs: float = 1.4) -> void:
	var heart := SpellFX._mesh(parent, SpellFX._heart_mesh(), SpellFX._orb_mat("heart"), from, Vector3.ONE * 0.01)
	heart.set_instance_shader_parameter("core_col", Color(0.85, 0.06, 0.12))
	heart.set_instance_shader_parameter("rim_col", Color(0.4, 0.0, 0.05))
	heart.set_instance_shader_parameter("energy", 2.3)
	SpellFX._light(heart, Vector3.ZERO, Color(1.0, 0.1, 0.15), 2.5, 4.0)
	var tw := heart.create_tween()
	tw.tween_property(heart, "scale", Vector3.ONE * 0.24, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var beats := maxi(2, int(secs / 0.32))
	for i in beats:
		tw.tween_callback(func():
			if is_instance_valid(heart):
				heart.set_instance_shader_parameter("pulse", 1.0)
				CombatFX.sound("heart_beat", heart.global_position, 0.8, 0.0))
		tw.tween_property(heart, "scale", Vector3.ONE * 0.29, 0.06)
		tw.tween_property(heart, "scale", Vector3.ONE * 0.24, 0.14)
		tw.tween_method(func(v: float): heart.set_instance_shader_parameter("pulse", v), 1.0, 0.0, maxf(0.05, secs / beats - 0.2))
	tw.tween_property(heart, "scale", Vector3(0.36, 0.05, 0.36), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var at := heart.global_position
		CombatFX.burst(parent, "blood", at, Color(0.45, 0.01, 0.03), Vector3.UP, 2.0)
		CombatFX.burst(parent, "blood_mist", at, Color(0.55, 0.02, 0.05), Vector3.UP, 2.0)
		CombatFX.burst(parent, "flash", at, Color(1.0, 0.2, 0.3))
		CombatFX.burst(parent, "blood", to, Color(0.4, 0.01, 0.02), Vector3.UP, 1.6)
		CombatFX.sound("heart_crush", at, 1.0, 0.0)
		SpellFX.screen_flash(Color(0.7, 0.0, 0.05, 0.35), 0.45)
		heart.queue_free())


## Großbrand (brennende Häuser, Karren): hohe Flammen, Rauchsäule, Funkenflug, flackerndes Licht.
## secs = 0: brennt, bis extinguish() es löscht (oder der Ort verlassen wird).
static func blaze(parent: Node, at: Vector3, secs: float = 0.0, size: float = 1.0) -> Node3D:
	if parent == null or not CombatFX.enabled:
		return null
	var root := Node3D.new()
	root.name = "Blaze"
	parent.add_child(root)
	root.global_position = at
	var fl := CombatFX.emitter(root, "blaze", Color(1.0, 0.55, 0.2))
	if fl:
		fl.amount = int(fl.amount * clampf(size, 0.5, 2.0))
	var sm := CombatFX.emitter(root, "smoke_column", Color(0.13, 0.115, 0.105), Color(1.0, 0.38, 0.08, 0.55))
	if sm:
		sm.position = Vector3.UP * 1.6
		sm.visibility_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 34, 28))
	CombatFX.emitter(root, "ash", Color(1.0, 0.5, 0.15))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.omni_range = 11.0 * size
	l.shadow_enabled = false
	l.position = Vector3.UP * 1.4
	root.add_child(l)
	var base := 3.2 * size
	var ph := randf() * 10.0
	var tw := root.create_tween().set_loops()
	tw.tween_method(func(_v: float):
		var t := Time.get_ticks_msec() * 0.001
		l.light_energy = base * (0.8 + 0.12 * sin(t * 11.0 + ph) + 0.08 * sin(t * 27.0 + ph * 3.0)), 0.0, 1.0, 1.0)
	root.set_meta("light", l)
	if secs > 0.0:
		root.get_tree().create_timer(secs, false).timeout.connect(func(): extinguish(root))
	return root


## Brand verlöschen lassen (Flammen und Licht klingen aus, Rauch zieht ab).
static func extinguish(root: Node3D) -> void:
	if root == null or not is_instance_valid(root) or root.has_meta("out"):
		return
	root.set_meta("out", true)
	for c in root.get_children():
		if c is GPUParticles3D:
			CombatFX.stop(c)
	var l: OmniLight3D = root.get_meta("light", null)
	var tw := root.create_tween()
	if l and is_instance_valid(l):
		tw.tween_property(l, "light_energy", 0.0, 2.0)
	tw.tween_interval(6.0)
	tw.tween_callback(root.queue_free)


## Schutzkuppel (Antilife Cocoon) über einem Ort.
static func dome(parent: Node, at: Vector3, radius: float, col: Color, secs: float) -> void:
	if parent == null or not CombatFX.enabled:
		return
	var m := SpellFX._mesh(parent, SpellFX._sphere(), SpellFX._shield_mat(), at + Vector3.UP * radius * 0.3, Vector3.ONE * radius * 1.2)
	m.set_instance_shader_parameter("tint", col)
	m.set_instance_shader_parameter("fade", 0.0)
	var tw := m.create_tween()
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 0.0, 1.0, 0.5)
	tw.parallel().tween_property(m, "scale", Vector3.ONE * radius * 2.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, secs))
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.9)
	tw.tween_callback(m.queue_free)
	GroundMark.rune(parent, at, radius, col, secs + 1.4, "a", null, 0.3)
	CombatFX.burst(parent, "motes", at + Vector3.UP * 0.8, col, Vector3.UP, 1.4)
	CombatFX.sound("shield_up", at + Vector3.UP, 0.9, 0.0)


## Teleport (Ainz verschwindet oder erscheint): Runenkreis, Implosion, Lichtblitz.
static func teleport(parent: Node, at: Vector3, col: Color = Color(0.62, 0.3, 1.0)) -> void:
	if parent == null or not CombatFX.enabled:
		return
	GroundMark.rune(parent, at, 1.4, col, 1.3, "a", null, 2.4)
	CombatFX.burst(parent, "motes", at + Vector3.UP, col, Vector3.UP, 1.8)
	CombatFX.burst(parent, "flash", at + Vector3.UP * 1.1, col)
	SpellFX.implosion(parent, at + Vector3.UP * 1.0, 1.2, col)
	CombatFX.flash(parent, at + Vector3.UP * 1.2, col, 4.5, 7.0, 0.4)
	CombatFX.sound("cast_small", at + Vector3.UP, 1.0, 0.0)


## Heiltrank: rote Lichtfunken steigen auf, sanfter Schein.
static func heal(parent: Node, at: Vector3, col: Color = Color(1.0, 0.25, 0.3)) -> void:
	if parent == null or not CombatFX.enabled:
		return
	CombatFX.burst(parent, "motes", at + Vector3.UP * 0.6, col, Vector3.UP, 1.6)
	CombatFX.burst(parent, "flash_soft", at + Vector3.UP * 1.0, col)
	GroundMark.ring(parent, at, 1.2, col, 0.8)
	CombatFX.flash(parent, at + Vector3.UP, col, 2.5, 4.0, 0.6)
	CombatFX.sound("holy_impact", at + Vector3.UP, 0.5, 0.0)


## Tageszeit eines Einsatzes: anderer Fotohimmel (Abendrot, Nacht) mit passender Sonne, Umgebungslicht und Nebel.
const MOODS := {
	"dusk": {"hdri": "qwantani_sunset_puresky", "hdri_energy": 0.75, "sun_scale": 0.8, "exposure": 1.0},
	"night": {"hdri": "qwantani_night_puresky", "night": true, "hdri_energy": 0.7, "exposure": 1.45, "ambient": 1.7},
	"fog_night": {"hdri": "qwantani_night_puresky", "night": true, "hdri_energy": 0.65, "exposure": 1.45, "ambient": 1.7, "fog": 1.5},
}


static func mood(level: Node, kind: String) -> void:
	var m: Dictionary = MOODS.get(kind, {})
	if m.is_empty() or level == null:
		return
	var env: Environment = null
	var sun: DirectionalLight3D = null
	for c in level.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D and sun == null:
			sun = c
	if env == null or sun == null:
		return
	var p := m.duplicate()
	p["sun_rot"] = sun.rotation_degrees
	if not HdriSky.apply(env, sun, p):
		return
	env.tonemap_exposure *= float(m.get("exposure", 1.0))
	env.ambient_light_energy *= float(m.get("ambient", 1.0))
	env.fog_density *= float(m.get("fog", 1.0))
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density *= float(m.get("fog", 1.0))


## Schwarzes Loch: eine Kugel aus Finsternis verschlingt alles in ihrer Nähe und fällt in sich zusammen.
static func black_hole(parent: Node, at: Vector3, radius: float = 3.0) -> void:
	if parent == null or not CombatFX.enabled:
		return
	var col := Color(0.55, 0.2, 1.0)
	var m := SpellFX._mesh(parent, SpellFX._sphere(), SpellFX._dark_mat(), at, Vector3.ONE * 0.1)
	m.set_instance_shader_parameter("rim_col", col)
	m.set_instance_shader_parameter("energy", 3.5)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		CombatFX.burst(parent, "flash", at, col)
		CombatFX.flash(parent, at, col, 8.0, radius * 4.0, 0.5)
		CombatFX.sound("shockwave", at, 1.1, 0.0)
		CombatFX.shake(0.5)
		m.queue_free())
	for i in 3:
		SpellFX.implosion(parent, at, radius * (1.2 - i * 0.25), col)
	SpellFX.distortion(parent, at, radius * 2.2, 0.1, 1.6)
	CombatFX.burst(parent, "wisps", at, Color(0.06, 0.0, 0.1), Vector3.UP, 3.0, Color(col, 0.9))
	CombatFX.sound("dark_impact", at, 1.2, 0.0)
	CombatFX.sound("summon", at, 0.9, 0.0)

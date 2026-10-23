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
static func negative_burst(parent: Node, at: Vector3, radius: float = 14.0, sphere: float = 2.0) -> void:
	var col := Color(0.62, 0.2, 1.0)
	var m := SpellFX._mesh(parent, SpellFX._sphere(), SpellFX._dark_mat(), at + Vector3.UP, Vector3.ONE * 0.5)
	m.set_instance_shader_parameter("rim_col", col)
	m.set_instance_shader_parameter("energy", 4.0)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * radius * sphere, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
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
	_flicker_light(root, Vector3.UP * 1.4, Color(1.0, 0.5, 0.2), 3.2 * size, 11.0 * size)
	if secs > 0.0:
		root.get_tree().create_timer(secs, false).timeout.connect(func(): extinguish(root))
	return root


## Brand verlöschen lassen (Flammen und Licht klingen aus, Rauch zieht ab).
static func extinguish(root: Node3D) -> void:
	if root == null or not is_instance_valid(root) or root.has_meta("out"):
		return
	root.set_meta("out", true)
	if root.has_meta("freeze_mats"):
		# Eis taut sofort (Aufräumen nach dem Einsatz, Bild ist ausgeblendet)
		for m in root.get_meta("freeze_mats"):
			if is_instance_valid(m):
				(m as ShaderMaterial).set_shader_parameter("freeze_radius", 0.0)
		root.queue_free()
		return
	for c in root.find_children("*", "GPUParticles3D", true, false):
		CombatFX.stop(c)
	var tw := root.create_tween().set_parallel(true)
	for l in root.find_children("*", "OmniLight3D", true, false):
		tw.tween_property(l, "light_energy", 0.0, 2.0)
	var fm: ShaderMaterial = root.get_meta("flame_mat") if root.has_meta("flame_mat") else null
	if fm:
		tw.tween_method(func(v: float): fm.set_shader_parameter("grow", v), 1.0, 0.0, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_interval(6.0)
	tw.chain().tween_callback(root.queue_free)


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
	"gehenna": {"hdri": "qwantani_night_puresky", "night": true, "hdri_energy": 0.8, "exposure": 1.05, "ambient": 3.2},
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
	GraphicsQuality.tune(env, sun)            # neuer Himmel → neuer Sonnenwinkel für die Schatten
	env.tonemap_exposure *= float(m.get("exposure", 1.0))
	env.ambient_light_energy *= float(m.get("ambient", 1.0))
	env.fog_density *= float(m.get("fog", 1.0))
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density *= float(m.get("fog", 1.0))


## Schwarzes Loch: eine Kugel aus Finsternis verschlingt alles in ihrer Nähe und fällt in sich zusammen.
static func black_hole(parent: Node, at: Vector3, radius: float = 3.0, hold: float = 0.9) -> void:
	if parent == null or not CombatFX.enabled:
		return
	var col := Color(0.55, 0.2, 1.0)
	var m := SpellFX._mesh(parent, SpellFX._sphere(), SpellFX._dark_mat(), at, Vector3.ONE * 0.1)
	m.set_instance_shader_parameter("rim_col", col)
	m.set_instance_shader_parameter("energy", 3.5)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
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


## Flackerndes Feuerlicht (ohne Schatten) als Kind von `root`.
static func _flicker_light(root: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.shadow_enabled = false
	l.position = pos
	root.add_child(l)
	var ph := randf() * 10.0
	var tw := l.create_tween().set_loops()
	tw.tween_method(func(_v: float):
		if root.has_meta("out"):
			return
		var t := Time.get_ticks_msec() * 0.001
		l.light_energy = energy * (0.8 + 0.12 * sin(t * 11.0 + ph) + 0.08 * sin(t * 27.0 + ph * 3.0)), 0.0, 1.0, 1.0)
	return l


## Frost über dem Sumpf: alles Wasser des Ortes gefriert in einer Welle, die von `at` ausläuft (water.gdshader,
## freeze_center/freeze_radius) – Eisnebel und Splitter auf der Frostfront, Knacken und Krachen des Eises.
## Gibt einen Knoten zurück: extinguish() taut das Eis wieder auf (Aufräumen nach dem Einsatz).
static func freeze(level: Node, at: Vector3, radius: float = 240.0, dur: float = 7.0) -> Node3D:
	if level == null:
		return null
	var mats: Array = []
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name).to_lower()
		if not (nm.begins_with("water") or nm.contains("nocol_water")):
			continue
		for i in (mi as MeshInstance3D).get_surface_override_material_count():
			var m := (mi as MeshInstance3D).get_surface_override_material(i) as ShaderMaterial
			if m and not m in mats:
				mats.append(m)
	var root := Node3D.new()
	root.name = "Frost"
	level.add_child(root)
	root.global_position = at
	root.set_meta("freeze_mats", mats)
	for m in mats:
		(m as ShaderMaterial).set_shader_parameter("freeze_center", at)
		(m as ShaderMaterial).set_shader_parameter("freeze_radius", 0.01)
	var tw := root.create_tween()
	tw.tween_method(func(r: float):
		for m in mats:
			if is_instance_valid(m):
				(m as ShaderMaterial).set_shader_parameter("freeze_radius", r), 0.01, radius, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Frostfront: Eisnebel und Splitter auf dem wachsenden Ring (nur im sichtbaren Umkreis)
	var col := Color(0.7, 0.9, 1.0)
	for k in range(1, 9):
		var f := float(k) / 9.0
		var r := radius * (1.0 - pow(1.0 - f, 2.0))
		if r > 70.0:
			break
		var t := dur * f
		root.get_tree().create_timer(t, false).timeout.connect(func():
			if not is_instance_valid(root):
				return
			for j in 7:
				var a := TAU * (j + randf() * 0.6) / 7.0
				var p := at + Vector3(cos(a), 0.0, sin(a)) * r
				var g := CombatFX._ground_below(level, p + Vector3.UP * 8.0)
				if g != Vector3.INF:
					p.y = g.y
				CombatFX.burst(level, "frost_mist", p + Vector3.UP * 0.3, col, Vector3.UP, 1.4)
				if j % 2 == 0:
					CombatFX.burst(level, "ice_shards", p + Vector3.UP * 0.2, col, Vector3.UP, 0.9)
			CombatFX.sound("ice_shatter", at + Vector3(r * 0.3, 1.0, 0.0), clampf(1.1 - f, 0.25, 1.0), 0.0))
	GroundMark.ring(level, at, 6.0, col, 0.9, 0.1)
	CombatFX.burst(level, "frost_mist", at + Vector3.UP * 0.5, col, Vector3.UP, 3.0)
	CombatFX.flash(level, at + Vector3.UP * 2.0, Color(0.6, 0.85, 1.0), 6.0, 40.0, 1.2)
	CombatFX.sound("ice_launch", at, 1.2, 0.0)
	CombatFX.sound("freeze_spread", at, 1.0, 0.0)
	SpellFX.screen_flash(Color(0.75, 0.9, 1.0, 0.35), 0.8)
	return root


## Gehenna-Flamme: haushohe Feuerwand von `a` nach `b` (zwei versetzte Lagen, Funken am Fuß, flackerndes Licht).
## Steigt in ~2 s aus dem Boden; extinguish() lässt sie wieder in sich zusammensinken.
static func flame_wall(parent: Node, a: Vector3, b: Vector3, height: float = 24.0) -> Node3D:
	if parent == null:
		return null
	var root := Node3D.new()
	root.name = "GehennaFlamme"
	parent.add_child(root)
	root.global_position = a
	var dir := b - a
	dir.y = 0.0
	var length := dir.length()
	if length < 0.5:
		return root
	dir /= length
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/gehenna_flame.gdshader")
	mat.set_shader_parameter("height_m", height)
	mat.set_shader_parameter("grow", 0.0)
	root.set_meta("flame_mat", mat)
	var seg := 9.0
	var n := maxi(1, ceili(length / seg))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var yaw := atan2(dir.x, dir.z) + PI * 0.5
	for layer in 2:
		for i in n:
			var u := length * float(i) / n
			var w := length / n
			var q := QuadMesh.new()
			q.size = Vector2(w + 0.4, height)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			root.add_child(mi)
			var c := a + dir * (u + w * 0.5) + side * (layer * 0.9 - 0.45)
			var g := CombatFX._ground_below(parent, c + Vector3.UP * 20.0)
			c.y = (g.y if g != Vector3.INF else a.y) + height * 0.5 - 0.4
			mi.global_position = c
			mi.global_rotation = Vector3(0.0, yaw, 0.0)
			mi.set_instance_shader_parameter("u0", u)
			mi.set_instance_shader_parameter("u_len", w)
			mi.set_instance_shader_parameter("layer", float(layer))
	# Fuß der Wand: Funken, Glut und Licht in regelmäßigen Abständen
	var k := 0.0
	while k <= length:
		var p := a + dir * k
		var g := CombatFX._ground_below(parent, p + Vector3.UP * 20.0)
		if g != Vector3.INF:
			p.y = g.y
		var holder := Node3D.new()
		root.add_child(holder)
		holder.global_position = p
		CombatFX.emitter(holder, "ash", Color(1.0, 0.45, 0.12))
		if int(k / 7.0) % 2 == 0:
			var fl := CombatFX.emitter(holder, "blaze", Color(1.0, 0.45, 0.15))
			if fl:
				fl.amount = int(fl.amount * 0.6)
		_flicker_light(holder, Vector3.UP * 3.0 + side * 2.0, Color(1.0, 0.42, 0.12), 4.0, 22.0)
		k += 14.0
	var tw := root.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("grow", v), 0.0, 1.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	CombatFX.sound("fire_wall", a + dir * length * 0.5, 1.2, 0.0)
	CombatFX.sound("roar", a + dir * length * 0.5, 0.6, 0.0)
	return root


## Superrang-Magie: drei gewaltige Zauberkreise am Boden (gegenläufig drehend), schwebende Ringe darüber,
## Lichtsäule und aufsteigende Funken, solange die Zauberzeit läuft.
static func super_circle(parent: Node, at: Vector3, radius: float = 14.0, col: Color = Color(0.85, 0.75, 1.0), secs: float = 4.0) -> void:
	if parent == null or not CombatFX.enabled:
		return
	GroundMark.rune(parent, at, radius, col, secs, "a", null, 0.35)
	GroundMark.rune(parent, at + Vector3.UP * 0.05, radius * 0.72, col.lerp(Color(1.0, 0.85, 0.4), 0.5), secs, "b", null, -0.6)
	GroundMark.rune(parent, at + Vector3.UP * 0.1, radius * 0.42, Color(1.0, 0.9, 0.55), secs, "a", null, 1.1)
	for i in 3:
		var fr := GroundMark.floating(parent, at + Vector3.UP * (4.0 + i * 3.5), radius * (0.55 - i * 0.12), col, secs, "b", null, 0.0)
		if fr:
			fr.spin_speed = 0.5 * (1.0 if i % 2 == 0 else -1.0)
	SpellFX.pillar(parent, at, radius * 0.18, 60.0, col, secs * 0.8, 3.0)
	CombatFX.burst(parent, "motes", at + Vector3.UP * 0.5, col, Vector3.UP, radius * 0.4)
	CombatFX.flash(parent, at + Vector3.UP * 3.0, col, 6.0, radius * 3.0, secs)
	CombatFX.sound("super_charge", at, 1.3, 0.0)


## Die Sanduhr aus dem Item-Shop: überspringt die Zauberzeit der Superrang-Magie – zerspringt golden.
static func hourglass(parent: Node, at: Vector3) -> void:
	if parent == null or not CombatFX.enabled:
		return
	var gold := Color(1.0, 0.82, 0.35)
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	var glass := B3.mat(Color(0.85, 0.95, 1.0, 0.35), 0.05, 0.0, Color(1.0, 0.9, 0.6), 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var frame := B3.mat(gold, 0.25, 1.0, gold * 0.3, 0.6)
	B3.cone(root, 0.16, 0.22, Vector3(0, 0.11, 0), glass).rotation_degrees.x = 180.0
	B3.cone(root, 0.16, 0.22, Vector3(0, -0.11, 0), glass)
	B3.cyl(root, 0.2, 0.2, 0.03, Vector3(0, 0.24, 0), frame, false, 16)
	B3.cyl(root, 0.2, 0.2, 0.03, Vector3(0, -0.24, 0), frame, false, 16)
	root.scale = Vector3.ONE * 0.01
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.4, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "rotation:y", TAU, 1.0)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		CombatFX.burst(parent, "ice_shards", root.global_position, gold, Vector3.UP, 1.4)
		CombatFX.burst(parent, "sparks", root.global_position, gold, Vector3.UP, 1.2)
		CombatFX.flash(parent, root.global_position, gold, 6.0, 10.0, 0.5)
		CombatFX.sound("hourglass", root.global_position, 1.0, 0.0)
		root.queue_free())


## Schwarzer Wind (»Iä Shub-Niggurath«): eine Wand aus schwarzem Nebel rollt von `at` aus über die Ebene;
## `on_radius` erhält laufend den aktuellen Radius (z. B. für das Heer, das unter ihr zusammenbricht).
static func black_wind(parent: Node, at: Vector3, radius: float = 220.0, dur: float = 5.0, on_radius: Callable = Callable()) -> void:
	if parent == null:
		return
	var dark := Color(0.04, 0.0, 0.05)
	var rim := Color(0.45, 0.15, 0.6)
	var tw := parent.create_tween()
	tw.tween_method(func(r: float):
		if on_radius.is_valid():
			on_radius.call(r), 0.0, radius, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for k in range(1, 13):
		var f := float(k) / 12.0
		var r := radius * (0.5 - 0.5 * cos(PI * f))
		parent.get_tree().create_timer(dur * f, false).timeout.connect(func():
			if not is_instance_valid(parent):
				return
			GroundMark.ring(parent, at, r, rim, 0.8, 0.12)
			var n := clampi(int(r / 6.0), 6, 22)
			for j in n:
				var a := TAU * (j + randf() * 0.5) / n
				var p := at + Vector3(cos(a), 0.0, sin(a)) * r
				var g := CombatFX._ground_below(parent, p + Vector3.UP * 30.0)
				if g == Vector3.INF:
					continue
				CombatFX.burst(parent, "wisps", g + Vector3.UP * 0.8, dark, Vector3.UP, 3.5, Color(rim, 0.6))
				if j % 3 == 0:
					CombatFX.burst(parent, "smoke", g + Vector3.UP * 0.5, dark, Vector3.UP, 3.0))
	SpellFX.distortion(parent, at + Vector3.UP, 30.0, 0.1, 1.2)
	SpellFX.screen_flash(Color(0.06, 0.0, 0.1, 0.6), 1.2)
	CombatFX.sound("black_wind", at, 1.4, 0.0)
	CombatFX.sound("dark_impact", at, 1.2, 0.0)
	CombatFX.shake(0.7)


## Kulissen für Szenen (werden am Ende des Einsatzes entfernt). "elf_throne": Thron aus lebendem Holz.
static func prop(parent: Node, kind: String, at: Vector3, yaw: float) -> Node3D:
	match kind:
		"elf_throne":
			return _elf_throne(parent, at, yaw)
	return null


## Zylinder von a nach b (für Wurzeln, Äste, gewundene Stämme).
static func _limb_between(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var seg := B3.cyl(parent, r1, r0, a.distance_to(b), (a + b) * 0.5, mat, false, 8)
	seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return seg


## Thron des Elfenkönigs: Wurzelwerk, Sitz aus Holz und Moos, eine Lehne aus gewundenen Stämmen, die sich oben zu
## einer Blätterkrone schließen, Glühwürmchen und ein grüngoldenes Licht. Vorderseite = lokales +Z.
static func _elf_throne(parent: Node, at: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Elfenthron"
	parent.add_child(root)
	root.global_position = at
	root.rotation.y = yaw
	var bark := B3.noise_mat(Color(0.17, 0.12, 0.08), Color(0.34, 0.26, 0.17), 0.5, 0.92)
	var moss := B3.noise_mat(Color(0.1, 0.2, 0.06), Color(0.22, 0.36, 0.12), 0.8, 0.95)
	var leaf := B3.mat(Color(0.2, 0.42, 0.14), 0.75, 0.0, Color(0.08, 0.25, 0.04), 0.35)
	var bloom := B3.mat(Color(0.95, 0.9, 0.6), 0.5, 0.0, Color(1.0, 0.85, 0.4), 2.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1771
	# Wurzeln, die sich in den Boden krallen
	for i in 11:
		var a := TAU * i / 11.0 + rng.randf_range(-0.15, 0.15)
		var d := Vector3(cos(a), 0.0, sin(a))
		var p0 := d * 0.5 + Vector3.UP * 0.5
		var p1 := d * rng.randf_range(1.4, 1.9) + Vector3.UP * 0.12
		var p2 := d * rng.randf_range(2.4, 3.2) + Vector3.UP * -0.15
		_limb_between(root, p0, p1, 0.22, 0.15, bark)
		_limb_between(root, p1, p2, 0.15, 0.05, bark)
	# Sitz mit Moospolster
	B3.box(root, Vector3(1.3, 0.62, 1.0), Vector3(0, 0.36, 0.1), bark, false)
	B3.box(root, Vector3(1.16, 0.09, 0.86), Vector3(0, 0.71, 0.14), moss, false)
	# Armlehnen: zwei Äste, die vorn in Knospen enden
	for s in [-1.0, 1.0]:
		var q0 := Vector3(0.66 * s, 0.6, -0.35)
		var q1 := Vector3(0.74 * s, 1.05, 0.15)
		var q2 := Vector3(0.68 * s, 0.98, 0.7)
		_limb_between(root, q0, q1, 0.12, 0.1, bark)
		_limb_between(root, q1, q2, 0.1, 0.07, bark)
		B3.sphere(root, 0.09, q2 + Vector3(0, 0.05, 0.04), bloom)
	# Lehne: gewundene Stämme, die sich oben nach innen neigen und eine Krone bilden
	var tops: Array = []
	for i in 7:
		var u := (i - 3) / 3.0
		var base := Vector3(u * 0.62, 0.55, -0.42 - absf(u) * 0.1)
		var prev := base
		var h := 4.2 - absf(u) * 1.1
		for k in range(1, 7):
			var t := k / 6.0
			var p := Vector3(base.x * (1.0 - t * 0.55) + sin(t * 5.0 + i) * 0.12, 0.55 + h * t, base.z - sin(t * PI) * 0.35 + cos(t * 4.0 + i * 1.7) * 0.08)
			_limb_between(root, prev, p, lerpf(0.13, 0.05, t - 1.0 / 6.0), lerpf(0.13, 0.05, t), bark)
			prev = p
		tops.append(prev)
	# Blätterkrone und Blüten
	for p in tops:
		for k in 3:
			B3.sphere(root, rng.randf_range(0.32, 0.5), p + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.35), rng.randf_range(-0.3, 0.2)), leaf)
		B3.sphere(root, 0.06, p + Vector3(rng.randf_range(-0.2, 0.2), 0.35, 0.25), bloom)
	B3.sphere(root, 0.7, Vector3(0, 4.3, -0.55), leaf, Vector3(1.4, 0.7, 1.0))
	var l := B3.light(root, Vector3(0, 3.2, 0.6), Color(0.75, 1.0, 0.55), 1.4, 7.0)
	l.shadow_enabled = false
	var motes := CombatFX.emitter(root, "aura", Color(0.85, 1.0, 0.5))
	if motes:
		motes.position = Vector3(0, 1.4, 0.2)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return root

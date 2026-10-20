class_name SpellFX
## Inszenierung der Zauber und Techniken – die Spiellogik (Schaden, Ziele) bleibt bei Player3D/Enemy3D, hier entsteht
## alles Sichtbare und Hörbare:
##   Wirken      Runenkreis unter dem Zaubernden, Licht in der Hand, zusammenströmende Funken (große Zauber)
##   Geschosse   Feuerkern mit Flammenschweif, Eisspeer, Blutlanze, Kugel negativer Energie, Lichtkugel, Pfeil, Schwert
##   Einschläge  Explosion mit Druckwelle und Brandfleck, Eissplitter mit Raureif, Schattenimplosion, Lichtsäule …
##   Wellen      Druckwelle (Bildverzerrung), Schwerterwirbel, Frostdornen, Höllenfeuerwand, Ruf der Bestien
##   Sonderfälle Kettendrachenblitz, Herzgriff, Superrang-Magie „Fallen Down“, Sprünge mit Nachbildern, Barriere

const ELEMENT_OF_TYPE := {"fire": "fire", "ice": "ice", "negative": "dark", "holy": "holy", "physical": "steel", "lightning": "lightning"}

static var _mats := {}
static var _meshes := {}
static var _flash_layer: CanvasLayer
static var _flash_rect: ColorRect


static func element(sp: Dictionary) -> String:
	return String(sp.get("fx", ELEMENT_OF_TYPE.get(String(sp.get("type", "physical")), "steel")))


# =====================================================================
#  Wirken
# =====================================================================

## Beginn eines Zaubers: liefert Griffe, die cast_end() wieder aufräumt.
static func cast_begin(c: Fighter, sp: Dictionary) -> Dictionary:
	var h := {}
	if not CombatFX.enabled or c == null or not c.is_inside_tree():
		return h
	var parent := c.get_parent()
	var col := Color(sp.get("color", "#ffffff"))
	var cast := float(sp.get("cast", 0.3))
	var magic := String(sp.get("cost_type", "mana")) == "mana"
	var big := cast >= 0.6
	if magic:
		h.circle = GroundMark.rune(parent, c.global_position, 2.3 if big else 1.6, col, cast + 0.55, "a" if c.is_player else "b", c, 0.9 if big else 1.6)
		var hand := c.rig.hand_anchor(true) if c.rig else null
		if hand:
			h.light = _light(hand, Vector3.ZERO, col, 0.0, 3.5)
			var tw := (h.light as OmniLight3D).create_tween()
			tw.tween_property(h.light, "light_energy", 3.0 if big else 1.8, cast * 0.8)
			var e := CombatFX.emitter(hand, "trail_motes", col)
			if e:
				h.motes = e
		if big:
			CombatFX.burst(parent, "implode", _hand_pos(c), col)
			CombatFX.sound("cast_big", c.global_position + Vector3.UP, 0.8)
		else:
			CombatFX.sound("cast_small", c.global_position + Vector3.UP, 0.55)
	else:
		CombatFX.burst(parent, "dust_puff", c.global_position + Vector3.UP * 0.15, Color(0.62, 0.58, 0.52), Vector3.UP, 0.9)
		CombatFX.sound("tech_charge", c.global_position + Vector3.UP, 0.6)
	return h


static func cast_end(h: Dictionary) -> void:
	if h.has("circle") and is_instance_valid(h.circle):
		(h.circle as GroundMark).release()
	if h.has("light") and is_instance_valid(h.light):
		var l: OmniLight3D = h.light
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.3)
		tw.tween_callback(l.queue_free)
	if h.has("motes") and is_instance_valid(h.motes):
		CombatFX.stop(h.motes)


static func _hand_pos(c: Fighter) -> Vector3:
	if c.rig:
		var a := c.rig.hand_anchor(true)
		if a:
			return a.global_position
	return c.global_position + Vector3.UP * 1.35 + c.facing * 0.6


# =====================================================================
#  Geschosse
# =====================================================================

## Aussehen eines Geschosses nach Element; das Geschoss (Projectile) trägt alle Teile als Kinder.
static func projectile_look(p: Node3D, el: String, col: Color) -> void:
	match el:
		"fire":
			var core := _mesh(p, _sphere(), _orb_mat("fire"), Vector3.ZERO, Vector3.ONE * 0.55)
			core.set_instance_shader_parameter("core_col", Color(1.0, 0.82, 0.42))
			core.set_instance_shader_parameter("rim_col", Color(1.0, 0.32, 0.05))
			core.set_instance_shader_parameter("energy", 3.6)
			_trail(p, "trail_fire", col)
			_trail(p, "trail_smoke", Color(0.16, 0.13, 0.12))
			_light(p, Vector3.ZERO, col, 3.2, 7.0)
		"ice":
			var spear := _mesh(p, _spike(1.3, 0.13), _orb_mat("lance"), Vector3.ZERO, Vector3.ONE)
			spear.set_instance_shader_parameter("core_col", Color(0.92, 0.98, 1.0))
			spear.set_instance_shader_parameter("rim_col", col)
			spear.set_instance_shader_parameter("energy", 3.0)
			_trail(p, "trail_motes", col)
			_light(p, Vector3.ZERO, col, 2.0, 5.0)
		"blood":
			var lance := _mesh(p, _spike(1.6, 0.12), _orb_mat("lance"), Vector3.ZERO, Vector3.ONE)
			lance.set_instance_shader_parameter("core_col", Color(1.0, 0.45, 0.45))
			lance.set_instance_shader_parameter("rim_col", Color(0.55, 0.0, 0.05))
			lance.set_instance_shader_parameter("energy", 3.5)
			_trail(p, "trail_motes", col)
			_trail(p, "trail_wisps", Color(0.35, 0.0, 0.02))
			_light(p, Vector3.ZERO, col, 2.2, 5.0)
		"dark":
			var orb := _mesh(p, _sphere(), _dark_mat(), Vector3.ZERO, Vector3.ONE * 0.46)
			orb.set_instance_shader_parameter("rim_col", col)
			_trail(p, "trail_wisps", Color(0.12, 0.0, 0.18), Color(col, 1.0))
			_trail(p, "trail_motes", col)
			_light(p, Vector3.ZERO, col, 2.0, 5.0)
		"holy":
			var orb := _mesh(p, _sphere(), _orb_mat("soft"), Vector3.ZERO, Vector3.ONE * 0.42)
			orb.set_instance_shader_parameter("core_col", Color(1.0, 1.0, 0.92))
			orb.set_instance_shader_parameter("rim_col", col)
			orb.set_instance_shader_parameter("energy", 4.0)
			_trail(p, "trail_motes", col)
			_light(p, Vector3.ZERO, col, 3.0, 6.0)
		"lightning":
			var orb := _mesh(p, _sphere(), _orb_mat("soft"), Vector3.ZERO, Vector3.ONE * 0.3)
			orb.set_instance_shader_parameter("core_col", Color(0.95, 0.98, 1.0))
			orb.set_instance_shader_parameter("rim_col", col)
			orb.set_instance_shader_parameter("energy", 5.0)
			_trail(p, "trail_motes", col)
			_trail(p, "sparks", col)
			_light(p, Vector3.ZERO, col, 3.0, 6.0)
		"arrow":
			_arrow(p)
			_trail(p, "trail_motes", Color(col, 0.35))
		"sword":
			var s := _sword(p)
			s.set_meta("spin", true)
			_trail(p, "trail_motes", col)
		_:
			var orb := _mesh(p, _sphere(), _orb_mat("soft"), Vector3.ZERO, Vector3.ONE * 0.4)
			orb.set_instance_shader_parameter("core_col", col.lightened(0.5))
			orb.set_instance_shader_parameter("rim_col", col)
			_trail(p, "trail_motes", col)
			_light(p, Vector3.ZERO, col, 2.0, 5.0)


static func _trail(p: Node3D, kind: String, col: Color, glow: Color = Color(0, 0, 0, 0)) -> void:
	var e := CombatFX.emitter(p, kind, col, glow)
	if e:
		e.set_meta("trail", true)


## Einschlag eines Geschosses (Treffer oder Wand).
static func projectile_burst(parent: Node, at: Vector3, el: String, col: Color, power: float = 1.0) -> void:
	if not CombatFX.enabled or parent == null:
		return
	match el:
		"fire":
			explosion(parent, at, 1.1 + power * 0.6, "fire", col)
			CombatFX.burst(parent, "sparks", at, Color(1.0, 0.6, 0.2), Vector3.UP, 1.2)
			CombatFX.burst(parent, "embers", at, col, Vector3.UP, 1.4)
			CombatFX.burst(parent, "smoke", at, Color(0.17, 0.14, 0.12), Vector3.UP, 0.9, Color(1.0, 0.35, 0.05, 0.6))
			_scorch(parent, at, 1.6 + power)
			CombatFX.sound("fire_explode", at, 1.0)
			CombatFX.shake(0.32 * power, at)
		"ice":
			CombatFX.burst(parent, "ice_shards", at, Color(0.75, 0.92, 1.0), Vector3.UP, 1.6)
			CombatFX.burst(parent, "frost_mist", at, Color(0.8, 0.9, 1.0), Vector3.UP, 1.2)
			CombatFX.burst(parent, "flash_soft", at, col)
			CombatFX.flash(parent, at, col, 3.0, 6.0, 0.35)
			var g := CombatFX._ground_below(parent, at)
			if g != Vector3.INF:
				CombatFX.decal(parent, g, "frost", 2.2, 10.0)
			CombatFX.sound("ice_shatter", at, 1.0)
			CombatFX.shake(0.2 * power, at)
		"blood":
			CombatFX.burst(parent, "blood", at, Color(0.4, 0.01, 0.02), Vector3.UP, 1.6)
			CombatFX.burst(parent, "blood_mist", at, Color(0.5, 0.02, 0.04), Vector3.UP, 1.4)
			CombatFX.burst(parent, "motes", at, col, Vector3.UP, 0.8)
			CombatFX.flash(parent, at, col, 3.0, 5.0, 0.3)
			CombatFX.sound("blood_impact", at, 0.9)
			CombatFX.shake(0.18 * power, at)
		"dark":
			implosion(parent, at, 1.4, col)
			CombatFX.burst(parent, "wisps", at, Color(0.12, 0.0, 0.18), Vector3.UP, 1.6, Color(col, 0.9))
			CombatFX.burst(parent, "motes", at, col, Vector3.UP, 1.2)
			CombatFX.sound("dark_impact", at, 1.0)
			CombatFX.shake(0.2 * power, at)
		"holy":
			CombatFX.burst(parent, "motes", at, col, Vector3.UP, 1.8)
			CombatFX.burst(parent, "flash", at, col)
			CombatFX.flash(parent, at, col, 5.0, 7.0, 0.4)
			GroundMark.ring(parent, at - Vector3(0, 1.0, 0), 2.4, col, 0.5)
			CombatFX.sound("holy_impact", at, 0.9)
			CombatFX.shake(0.2 * power, at)
		"lightning":
			for i in 2:
				bolt(parent, at + Vector3(randf_range(-0.8, 0.8), randf_range(1.6, 2.6), randf_range(-0.8, 0.8)), at, col, 0.14, 0.22)
			CombatFX.burst(parent, "sparks", at, col, Vector3.UP, 1.4)
			CombatFX.burst(parent, "flash", at, col)
			CombatFX.flash(parent, at, col, 4.0, 6.0, 0.25)
			CombatFX.sound("lightning", at, 0.8)
			CombatFX.shake(0.15 * power, at)
		"arrow":
			CombatFX.burst(parent, "dust_puff", at, Color(0.6, 0.55, 0.48), Vector3.UP, 0.5)
			CombatFX.sound("arrow_hit", at, 0.8)
		"sword":
			CombatFX.burst(parent, "sparks", at, Color(1.0, 0.7, 0.35), Vector3.UP, 1.3)
			CombatFX.burst(parent, "dust_puff", at, Color(0.6, 0.55, 0.48), Vector3.UP, 1.0)
			CombatFX.sound("hit_armor", at, 1.0)
			CombatFX.shake(0.22 * power, at)
		_:
			CombatFX.burst(parent, "motes", at, col, Vector3.UP, 1.2)
			CombatFX.burst(parent, "flash_soft", at, col)
			CombatFX.sound("dark_impact", at, 0.7)


# =====================================================================
#  Explosion, Implosion, Druckwelle
# =====================================================================

static func explosion(parent: Node, at: Vector3, radius: float, el: String = "fire", col: Color = Color(1, 0.5, 0.15)) -> void:
	var m := _mesh(parent, _sphere(), _explosion_mat(), at, Vector3.ONE * radius * 0.5)
	var pal: Array = {
		"fire": [Color(1.0, 0.95, 0.75), Color(1.0, 0.52, 0.1), Color(0.55, 0.08, 0.02), Color(0.11, 0.09, 0.08)],
		"holy": [Color(1.0, 1.0, 0.95), Color(1.0, 0.88, 0.5), Color(0.9, 0.62, 0.25), Color(0.5, 0.45, 0.38)],
		"ice": [Color(0.95, 1.0, 1.0), Color(0.55, 0.85, 1.0), Color(0.2, 0.45, 0.8), Color(0.55, 0.62, 0.7)],
		"dark": [Color(0.9, 0.7, 1.0), Color(0.55, 0.15, 0.95), Color(0.2, 0.02, 0.35), Color(0.05, 0.02, 0.07)],
	}.get(el, [col.lightened(0.6), col, col.darkened(0.5), Color(0.1, 0.1, 0.1)])
	m.set_instance_shader_parameter("hot", pal[0])
	m.set_instance_shader_parameter("mid", pal[1])
	m.set_instance_shader_parameter("cool", pal[2])
	m.set_instance_shader_parameter("smoke", pal[3])
	m.set_instance_shader_parameter("seed", randf() * 10.0)
	var dur := 0.55 + radius * 0.08
	var tw := m.create_tween().set_parallel(true)
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("t", v), 0.0, 1.0, dur)
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(m.queue_free)
	distortion(parent, at, radius * 2.4, 0.045, 0.45)
	CombatFX.flash(parent, at, pal[1], 7.0, radius * 6.0, 0.5)
	var g := CombatFX._ground_below(parent, at)
	if g != Vector3.INF and at.y - g.y < radius * 1.5:
		GroundMark.ring(parent, g, radius * 2.6, pal[1], 0.55)
		CombatFX.burst(parent, "dust_ring", g + Vector3.UP * 0.1, Color(0.55, 0.5, 0.45), Vector3.UP, 0.8)


## Schattenkugel, die sich zusammenzieht und dann aufplatzt.
static func implosion(parent: Node, at: Vector3, radius: float, col: Color) -> void:
	var m := _mesh(parent, _sphere(), _dark_mat(), at, Vector3.ONE * radius)
	m.set_instance_shader_parameter("rim_col", col)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * radius * 0.25, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.2, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.22)
	tw.tween_callback(m.queue_free)
	CombatFX.flash(parent, at, col, 4.0, 6.0, 0.4)
	distortion(parent, at, radius * 3.0, 0.05, 0.4)


## Bildverzerrende Kugel, die sich ausdehnt (Hitze, Druckwelle).
static func distortion(parent: Node, at: Vector3, radius: float, strength: float = 0.04, secs: float = 0.5) -> void:
	if not Settings.particles:
		return
	var m := _mesh(parent, _sphere(), _distort_mat(), at, Vector3.ONE * radius * 0.2)
	m.set_instance_shader_parameter("strength", strength)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, secs)
	tw.chain().tween_callback(m.queue_free)


## Welle/Kegel-Zauber um den Zaubernden: Druckwelle, Schwerterwirbel, Frostaura, Höllenfeuerwand, Ruf der Bestien.
static func wave(c: Fighter, sp: Dictionary) -> void:
	if not CombatFX.enabled:
		return
	var parent := c.get_parent()
	var col := Color(sp.get("color", "#ffffff"))
	var rng := float(sp.get("range", 5.0))
	var arc := float(sp.get("arc", 360.0))
	var el := element(sp)
	var feet := c.global_position + Vector3.UP * 0.1
	var chest := c.global_position + Vector3.UP * 1.1
	var fwd := c.facing
	match el:
		"dark":
			distortion(parent, chest, rng, 0.06, 0.5)
			CombatFX.burst(parent, "wisps", chest + fwd * 1.0, Color(0.1, 0.0, 0.16), fwd, 2.2, Color(col, 0.8))
			CombatFX.burst(parent, "motes", chest + fwd * 0.8, col, fwd, 1.5)
			for k in 2:
				var cone := GroundMark.spawn(parent, c.global_position, Vector2(rng, rng), GroundMark.Mode.CONEWAVE, col, 0.5 + k * 0.12, atan2(-fwd.x, -fwd.z), true)
				if cone:
					cone.grow = Vector2(0.08, 1.0)
					cone.fade_in = 0.02
					cone.fade_out = 0.3
					cone.set_instance_shader_parameter("arc", arc)
					cone.set_instance_shader_parameter("width", 0.1 if k == 0 else 0.05)
					cone.set_instance_shader_parameter("energy", 2.6)
			CombatFX.burst(parent, "dust_ring", feet, Color(0.5, 0.46, 0.42), Vector3.UP, 1.0)
			# Staubwand, die mit der Welle nach vorn rollt
			for i in 4:
				var k := float(i + 1) / 4.0
				parent.get_tree().create_timer(0.06 * i, false).timeout.connect(func():
					if not is_instance_valid(parent):
						return
					for s in [-1.0, 0.0, 1.0]:
						var d := fwd.rotated(Vector3.UP, deg_to_rad(s * arc * 0.35))
						CombatFX.burst(parent, "dust_puff", feet + d * rng * k * 0.85, Color(0.55, 0.5, 0.45), d + Vector3.UP * 0.4, 0.8))
			CombatFX.sound("shockwave", chest, 1.0)
			CombatFX.shake(0.3, chest)
			if c.is_player:
				CombatFX.fov_kick(3.0)
		"ice":
			var n := 10 if arc >= 359.0 else 6
			for i in n:
				var a := TAU * i / n + randf() * 0.3
				var d := Vector3(cos(a), 0, sin(a))
				if arc < 359.0:
					d = fwd.rotated(Vector3.UP, deg_to_rad(randf_range(-arc * 0.5, arc * 0.5)))
				ice_spike(parent, c.global_position + d * randf_range(rng * 0.45, rng * 0.85), randf_range(0.9, 1.7), col, i * 0.025)
			CombatFX.burst(parent, "frost_mist", feet + Vector3.UP * 0.3, Color(0.82, 0.92, 1.0), Vector3.UP, 2.4)
			GroundMark.ring(parent, c.global_position, rng, col, 0.6)
			var g := CombatFX._ground_below(parent, chest)
			if g != Vector3.INF:
				CombatFX.decal(parent, g, "frost", rng * 1.6, 12.0)
			CombatFX.sound("ice_shatter", chest, 1.0)
			CombatFX.shake(0.25, chest)
		"fire":
			var steps := 6
			for i in steps:
				var k := float(i + 1) / steps
				var t := parent.get_tree().create_timer(0.05 * i, false)
				t.timeout.connect(func():
					if not is_instance_valid(parent):
						return
					for s in [-1.0, 0.0, 1.0]:
						var d := fwd.rotated(Vector3.UP, deg_to_rad(s * arc * 0.33))
						var at := c.global_position + d * rng * k if is_instance_valid(c) else feet
						CombatFX.burst(parent, "flame_puff", at + Vector3.UP * 0.3, col, Vector3.UP, 2.2)
						CombatFX.burst(parent, "embers", at, col, Vector3.UP, 0.6)
					if i == steps - 1:
						CombatFX.burst(parent, "smoke", c.global_position + fwd * rng * 0.7 + Vector3.UP, Color(0.15, 0.12, 0.1), Vector3.UP, 1.2, Color(1, 0.3, 0.05, 0.5)))
			GroundMark.ember(parent, c.global_position + fwd * rng * 0.55, rng * 0.6, col, 2.4)
			distortion(parent, chest + fwd * rng * 0.5, rng * 0.8, 0.03, 0.6)
			CombatFX.sound("fire_wall", chest + fwd * 2.0, 1.0)
			CombatFX.shake(0.22, chest)
		_:
			# Waffen- und Körpertechniken: zwei kreisende Hiebspuren, Staubring, Windstoß
			SlashFX.spawn(c, {"range": rng, "arc": 360.0, "active": 0.22, "fx": {"slash": "ring"}}, col, 3.2, 0)
			var t2 := parent.get_tree().create_timer(0.11, false)
			t2.timeout.connect(func():
				if is_instance_valid(c):
					SlashFX.spawn(c, {"range": rng * 0.92, "arc": 360.0, "active": 0.2, "fx": {"slash": "ring"}}, col.lightened(0.2), 2.6, 1))
			CombatFX.burst(parent, "dust_ring", feet, Color(0.58, 0.54, 0.48), Vector3.UP, 1.2)
			GroundMark.ring(parent, c.global_position, rng, col, 0.45)
			if String(sp.get("id", "")) == "beast_call" or String(sp.get("name", "")).contains("Bestien"):
				CombatFX.burst(parent, "sparks_big", chest, col, Vector3.UP, 1.0)
				CombatFX.sound("roar", chest, 1.0)
			else:
				CombatFX.sound("whirl", chest, 1.0)
			CombatFX.shake(0.22, chest)


## Eisdorn, der aus dem Boden schießt und nach kurzer Zeit zerspringt.
static func ice_spike(parent: Node, at: Vector3, h: float, col: Color, delay: float = 0.0) -> void:
	var g := CombatFX._ground_below(parent, at + Vector3.UP)
	var base := g if g != Vector3.INF else at
	var m := _mesh(parent, _spike(1.0, 0.22), _orb_mat("lance"), base - Vector3.UP * 0.1, Vector3(1.0, 1.0, 0.01))
	m.rotation = Vector3(PI * 0.5 + deg_to_rad(randf_range(-14, 14)), randf() * TAU, deg_to_rad(randf_range(-14, 14)))
	m.set_instance_shader_parameter("core_col", Color(0.92, 0.98, 1.0))
	m.set_instance_shader_parameter("rim_col", col)
	m.set_instance_shader_parameter("energy", 1.8)
	var tw := m.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(m, "scale", Vector3(1.0, 1.0, h), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_callback(func():
		if is_instance_valid(parent):
			CombatFX.burst(parent, "ice_shards", base + Vector3.UP * h * 0.5, Color(0.78, 0.92, 1.0), Vector3.UP, 0.6))
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.15)
	tw.tween_callback(m.queue_free)


# =====================================================================
#  Barriere, Bannkreise, Strahlen
# =====================================================================

## Schutzbarriere um den Träger (Größere Magische Schutzbarriere, Blutrausch, Dämonenschild, Eiserne Haut).
static func barrier(c: Fighter, col: Color, radius: float = 1.25) -> MeshInstance3D:
	var m := _mesh(c, _sphere(), _shield_mat(), Vector3(0, c.body_height * 0.55, 0), Vector3.ONE * radius * 2.0)
	m.set_instance_shader_parameter("tint", col)
	m.set_instance_shader_parameter("fade", 0.0)
	var tw := m.create_tween()
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 0.0, 1.0, 0.35)
	m.scale = Vector3.ONE * radius * 1.4
	m.create_tween().tween_property(m, "scale", Vector3.ONE * radius * 2.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	CombatFX.burst(c.get_parent(), "motes", c.global_position + Vector3.UP, col, Vector3.UP, 1.4)
	CombatFX.sound("shield_up", c.global_position + Vector3.UP, 0.9)
	return m


## Einschlag auf der Barriere: Welle vom Trefferpunkt aus.
static func barrier_hit(m: MeshInstance3D, from: Vector3) -> void:
	if m == null or not is_instance_valid(m):
		return
	var d := m.global_transform.affine_inverse() * from
	m.set_instance_shader_parameter("hit_dir", d.normalized() if d.length() > 0.01 else Vector3.FORWARD)
	m.create_tween().tween_method(func(v: float): m.set_instance_shader_parameter("hit_t", v), 1.0, 0.0, 0.6)


## Barriere zerspringt (oder läuft aus).
static func barrier_break(m: MeshInstance3D, shattered: bool) -> void:
	if m == null or not is_instance_valid(m):
		return
	var tw := m.create_tween()
	if shattered:
		tw.tween_method(func(v: float): m.set_instance_shader_parameter("crack", v), 0.0, 1.0, 0.25)
		if m.get_parent() and m.get_parent().get_parent():
			CombatFX.burst(m.get_parent().get_parent(), "sparks_big", m.global_position, Color(1.0, 0.85, 0.45), Vector3.UP, 0.8)
	else:
		tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5)
	tw.tween_callback(m.queue_free)


## Bannkreis um ein gelähmtes Ziel: Runenkreis am Boden und zwei schwebende, gegenläufige Ringe am Körper.
static func bind(t: Fighter, col: Color, secs: float, design: String = "b") -> void:
	if not CombatFX.enabled or t == null or not t.is_inside_tree():
		return
	var parent := t.get_parent()
	GroundMark.rune(parent, t.global_position, 1.5, col, secs, design, t, 0.8)
	for k in 2:
		var ring := GroundMark.floating(parent, t.global_position + Vector3.UP * (0.7 + k * 0.75) * t.body_height * 0.6, 0.85 - k * 0.12, col, secs, "b", t, (0.7 + k * 0.75) * t.body_height * 0.6)
		if ring:
			ring.spin_speed = 2.2 if k == 0 else -2.8
	CombatFX.burst(parent, "motes", t.global_position + Vector3.UP, col, Vector3.UP, 1.0)
	CombatFX.sound("bind", t.global_position + Vector3.UP, 0.9)


## Lichtsäule (heilige Lanze von oben, Superrang): Zylinder, der aufblitzt und verblasst.
static func pillar(parent: Node, at: Vector3, radius: float, height: float, col: Color, hold: float = 0.4, energy: float = 6.0) -> MeshInstance3D:
	var m := _mesh(parent, _cylinder(), _beam_mat(), at + Vector3.UP * height * 0.5, Vector3(radius * 0.15, height, radius * 0.15))
	m.set_instance_shader_parameter("tint", col)
	m.set_instance_shader_parameter("energy", energy)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(radius * 2.0, height, radius * 2.0), 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6)
	tw.parallel().tween_property(m, "scale", Vector3(radius * 0.4, height, radius * 0.4), 0.6)
	tw.tween_callback(m.queue_free)
	return m


## Gerader Strahl von a nach b (Ki-Stoß, Lanzenwurf).
static func beam(parent: Node, a: Vector3, b: Vector3, col: Color, width: float = 0.25, secs: float = 0.3) -> void:
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var m := _mesh(parent, _cylinder(), _beam_mat(), (a + b) * 0.5, Vector3.ONE)
	var y := (b - a).normalized()
	m.global_basis = CombatFX._basis_y(y) * Basis.from_scale(Vector3(width, len, width))
	m.set_instance_shader_parameter("tint", col)
	m.set_instance_shader_parameter("energy", 6.0)
	m.set_instance_shader_parameter("scroll", -6.0)
	var tw := m.create_tween()
	tw.tween_method(func(v: float): m.set_instance_shader_parameter("fade", v), 1.0, 0.0, secs)
	tw.tween_callback(m.queue_free)


## Läuterungslanze: eine Lanze aus Licht stürzt vom Himmel auf das Ziel.
static func sky_lance(parent: Node, at: Vector3, col: Color) -> void:
	var lance := _mesh(parent, _spike(5.0, 0.35), _orb_mat("lance"), at + Vector3.UP * 26.0, Vector3.ONE)
	lance.rotation.x = -PI * 0.5
	lance.set_instance_shader_parameter("core_col", Color(1, 1, 0.95))
	lance.set_instance_shader_parameter("rim_col", col)
	lance.set_instance_shader_parameter("energy", 6.0)
	var tw := lance.create_tween()
	tw.tween_property(lance, "global_position", at + Vector3.UP * 4.6, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(parent):
			pillar(parent, at - Vector3.UP * 0.5, 1.1, 14.0, col, 0.25, 7.0)
			explosion(parent, at, 1.6, "holy", col)
			CombatFX.burst(parent, "motes", at, col, Vector3.UP, 2.2)
			CombatFX.sound("holy_impact", at, 1.1)
			CombatFX.shake(0.35, at))
	tw.tween_method(func(v: float): lance.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.25)
	tw.tween_callback(lance.queue_free)


# =====================================================================
#  Blitz
# =====================================================================

class Bolt extends MeshInstance3D:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var life := 0.32
	var width := 0.16
	var branches := 3
	var _t := 0.0
	var _regen := 0.0
	var _im := ImmediateMesh.new()

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		mesh = _im
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		extra_cull_margin = 50.0

	func _process(delta: float) -> void:
		_t += delta
		_regen -= delta
		if _regen <= 0.0:
			_regen = 0.05
			_build()
		set_instance_shader_parameter("fade", clampf(1.0 - _t / life, 0.0, 1.0) * randf_range(0.65, 1.0))
		if _t >= life:
			queue_free()

	func _build() -> void:
		_im.clear_surfaces()
		var cam := get_viewport().get_camera_3d()
		var eye := cam.global_position if cam else a + Vector3.UP * 10.0
		var main := _jag(a, b, 5, a.distance_to(b) * 0.14)
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_ribbon(main, width, eye)
		for k in branches:
			var i := randi_range(1, main.size() - 2)
			var p := main[i]
			var d := (b - a).normalized()
			var r := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
			var e := p + (d * 0.5 + r).normalized() * a.distance_to(b) * randf_range(0.12, 0.3)
			_ribbon(_jag(p, e, 3, p.distance_to(e) * 0.25), width * 0.5, eye)
		_im.surface_end()

	func _jag(p0: Vector3, p1: Vector3, levels: int, amp: float) -> PackedVector3Array:
		var pts := PackedVector3Array([p0, p1])
		var am := amp
		for l in levels:
			var out := PackedVector3Array()
			for i in pts.size() - 1:
				var m := (pts[i] + pts[i + 1]) * 0.5
				var d := (pts[i + 1] - pts[i]).normalized()
				var r := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
				r = (r - d * r.dot(d)).normalized() * randf() * am
				out.append(pts[i])
				out.append(m + r)
			out.append(pts[pts.size() - 1])
			pts = out
			am *= 0.55
		return pts

	func _ribbon(pts: PackedVector3Array, w: float, eye: Vector3) -> void:
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var d := (p1 - p0).normalized()
			var s0 := d.cross((eye - p0).normalized()).normalized() * w * 0.5
			var s1 := s0
			var u0 := float(i) / (pts.size() - 1)
			var u1 := float(i + 1) / (pts.size() - 1)
			_im.surface_set_uv(Vector2(u0, 0.0)); _im.surface_add_vertex(p0 - s0)
			_im.surface_set_uv(Vector2(u0, 1.0)); _im.surface_add_vertex(p0 + s0)
			_im.surface_set_uv(Vector2(u1, 1.0)); _im.surface_add_vertex(p1 + s1)
			_im.surface_set_uv(Vector2(u0, 0.0)); _im.surface_add_vertex(p0 - s0)
			_im.surface_set_uv(Vector2(u1, 1.0)); _im.surface_add_vertex(p1 + s1)
			_im.surface_set_uv(Vector2(u1, 0.0)); _im.surface_add_vertex(p1 - s1)


static func bolt(parent: Node, a: Vector3, b: Vector3, col: Color, width: float = 0.16, life: float = 0.32) -> void:
	if not CombatFX.enabled or parent == null:
		return
	var bo := Bolt.new()
	bo.a = a
	bo.b = b
	bo.width = width
	bo.life = life
	bo.material_override = _bolt_mat()
	parent.add_child(bo)
	bo.set_instance_shader_parameter("tint", col)
	CombatFX.flash(parent, b, col, 5.0, 8.0, 0.25)
	CombatFX.burst(parent, "sparks", b, col, Vector3.UP, 1.2)
	CombatFX.burst(parent, "flash_soft", b, col, Vector3.UP, 0.8)


# =====================================================================
#  Sprünge und Nachbilder
# =====================================================================

## Leuchtende Momentaufnahme der Figur, die verblasst.
static func ghost(rig: CharacterRig, col: Color, life: float = 0.32) -> void:
	if rig == null or not is_instance_valid(rig) or not rig.is_inside_tree() or not Settings.particles:
		return
	var holder := rig.get_parent().get_parent() if rig.get_parent() else null
	if holder == null:
		return
	var root := Node3D.new()
	holder.add_child(root)
	var parts: Array = []
	for n in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var m: Mesh = mi.mesh
		if mi.skin != null:
			if not mi.has_method("bake_mesh_from_current_skeleton_pose"):
				continue
			m = mi.call("bake_mesh_from_current_skeleton_pose")
			if m == null:
				continue
		var g := MeshInstance3D.new()
		g.mesh = m
		g.material_override = _ghost_mat()
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		g.layers = 2
		root.add_child(g)
		g.global_transform = mi.global_transform
		g.set_instance_shader_parameter("tint", col)
		parts.append(g)
	var tw := root.create_tween()
	tw.tween_method(func(v: float):
		for g in parts:
			if is_instance_valid(g):
				g.set_instance_shader_parameter("fade", v), 0.85, 0.0, life)
	tw.tween_callback(root.queue_free)


## Landung nach einem Sprung: Krater, Staubring, Trümmer, Druckring, Erschütterung; je Element mehr.
static func leap_land(c: Fighter, sp: Dictionary) -> void:
	if not CombatFX.enabled:
		return
	var parent := c.get_parent()
	var col := Color(sp.get("color", "#ffffff"))
	var r := float(sp.get("radius", 3.0))
	var at := c.global_position
	CombatFX.burst(parent, "dust_ring", at + Vector3.UP * 0.1, Color(0.56, 0.52, 0.46), Vector3.UP, 1.4)
	CombatFX.burst(parent, "stone", at + Vector3.UP * 0.2, Color(0.5, 0.47, 0.43), Vector3.UP, 1.2)
	CombatFX.burst(parent, "dust_puff", at + Vector3.UP * 0.4, Color(0.6, 0.56, 0.5), Vector3.UP, 1.5)
	GroundMark.ring(parent, at, r * 1.15, col, 0.5)
	var g := CombatFX._ground_below(parent, at + Vector3.UP)
	if g != Vector3.INF:
		CombatFX.decal(parent, g, "crack", r * 1.5, 14.0)
	match element(sp):
		"ice":
			CombatFX.burst(parent, "ice_shards", at + Vector3.UP * 0.3, Color(0.78, 0.92, 1.0), Vector3.UP, 1.6)
			CombatFX.burst(parent, "frost_mist", at + Vector3.UP * 0.3, Color(0.85, 0.92, 1.0), Vector3.UP, 1.6)
			if g != Vector3.INF:
				CombatFX.decal(parent, g, "frost", r * 2.0, 12.0)
		"blood", "dark":
			CombatFX.burst(parent, "blood_mist", at + Vector3.UP * 0.5, col.darkened(0.3), Vector3.UP, 2.0)
			CombatFX.burst(parent, "motes", at + Vector3.UP * 0.6, col, Vector3.UP, 1.2)
		_:
			CombatFX.burst(parent, "sparks", at + Vector3.UP * 0.3, Color(1.0, 0.75, 0.4), Vector3.UP, 1.0)
	distortion(parent, at + Vector3.UP * 0.5, r * 1.4, 0.04, 0.4)
	CombatFX.sound("leap_land", at + Vector3.UP * 0.5, 1.0)
	CombatFX.shake(0.4, at)
	if c.is_player:
		CombatFX.fov_kick(3.5)


# =====================================================================
#  Herzgriff
# =====================================================================

## Herzgriff, Phase 1: ein geisterhaftes Herz erscheint vor der Hand und schlägt immer schneller; das Ziel glüht rot.
static func heart_begin(c: Fighter, t: Fighter, sp: Dictionary) -> Dictionary:
	var h := {}
	if not CombatFX.enabled or c == null or t == null:
		return h
	var parent := c.get_parent()
	var col := Color(sp.get("color", "#ff2a4f"))
	var cast := float(sp.get("cast", 1.1))
	# vor der ausgestreckten Hand in Brusthöhe, leicht zur Seite der Zauberhand
	var right := c.facing.cross(Vector3.UP).normalized()
	var at := c.global_position + Vector3.UP * 1.85 + c.facing * 0.7 + right * 0.6
	var heart := _mesh(parent, _heart_mesh(), _orb_mat("heart"), at, Vector3.ONE * 0.01)
	heart.set_instance_shader_parameter("core_col", Color(0.85, 0.06, 0.12))
	heart.set_instance_shader_parameter("rim_col", Color(0.4, 0.0, 0.05))
	heart.set_instance_shader_parameter("energy", 2.3)
	heart.rotation.y = atan2(c.facing.x, c.facing.z)
	h.heart = heart
	var tw := heart.create_tween()
	tw.tween_property(heart, "scale", Vector3.ONE * 0.24, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	h.light = _light(heart, Vector3.ZERO, col, 2.5, 4.0)
	# Herzschläge: immer schneller bis zum Zugriff
	var beats := [0.18, 0.5, 0.74, 0.9, 1.0]
	for b in beats:
		var beat_at := cast * float(b) - 0.06
		parent.get_tree().create_timer(maxf(0.0, beat_at), false).timeout.connect(func():
			if is_instance_valid(heart):
				var p := heart.create_tween()
				p.tween_method(func(v: float): heart.set_instance_shader_parameter("pulse", v), 1.0, 0.0, 0.22)
				p.parallel().tween_property(heart, "scale", heart.scale * 1.22, 0.06)
				p.parallel().tween_property(heart, "scale", heart.scale, 0.16).set_delay(0.06)
				CombatFX.sound("heart_beat", heart.global_position, 0.75 + float(b) * 0.4, 0.0))
	if is_instance_valid(t):
		var aura := CombatFX.emitter(t, "aura", col)
		if aura:
			aura.position = Vector3.UP * 0.1
			h.aura = aura
		if t.rig:
			t.rig.glow(Color(1.0, 0.1, 0.15), 0.35)
	h.target = t
	return h


## Herzgriff, Phase 2: die Hand schließt sich – das Herz zerplatzt, das Ziel bricht zusammen.
static func heart_release(h: Dictionary, c: Fighter, killed: bool) -> void:
	if h.is_empty():
		return
	var heart: MeshInstance3D = h.get("heart")
	var t: Fighter = h.get("target")
	if heart and is_instance_valid(heart):
		var parent := heart.get_parent()
		var at := heart.global_position
		var tw := heart.create_tween()
		tw.tween_property(heart, "scale", Vector3(0.36, 0.06, 0.36), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(parent):
				CombatFX.burst(parent, "blood", at, Color(0.45, 0.01, 0.03), Vector3.UP, 2.0)
				CombatFX.burst(parent, "blood_mist", at, Color(0.55, 0.02, 0.05), Vector3.UP, 2.0)
				CombatFX.burst(parent, "motes", at, Color(1.0, 0.15, 0.25), Vector3.UP, 1.5)
				CombatFX.burst(parent, "flash", at, Color(1.0, 0.2, 0.3))
			heart.queue_free())
	if t and is_instance_valid(t) and t.is_inside_tree():
		var p := t.get_parent()
		var chest := t.global_position + Vector3.UP * t.body_height * 0.62
		CombatFX.burst(p, "blood", chest, Color(0.4, 0.01, 0.02), Vector3.UP, 1.6)
		CombatFX.burst(p, "flash_soft", chest, Color(1.0, 0.15, 0.25), Vector3.UP, 1.4)
		CombatFX.flash(p, chest, Color(1.0, 0.1, 0.2), 6.0, 7.0, 0.5)
		distortion(p, chest, 2.5, 0.05, 0.35)
		if t.rig:
			t.rig.glow(Color.WHITE, 0.0)
		if killed:
			CombatFX.float_text(p, t.global_position + Vector3.UP * (t.body_height + 1.9), "Herz zerquetscht", Color(1.0, 0.25, 0.32), 44)
	if h.has("aura") and is_instance_valid(h.aura):
		CombatFX.stop(h.aura)
	CombatFX.sound("heart_crush", c.global_position + Vector3.UP * 1.3 if c else Vector3.ZERO, 1.0, 0.03)
	CombatFX.shake(0.38)
	CombatFX.fov_kick(4.0)
	CombatFX.slowmo(0.3, 0.38)
	screen_flash(Color(0.7, 0.0, 0.05, 0.35), 0.45)


static func _heart_mesh() -> ArrayMesh:
	if _meshes.has("heart"):
		return _meshes.heart
	var rings := 22
	var segs := 30
	var pts := []
	for i in rings + 1:
		var th := PI * i / rings
		var row := []
		for j in segs + 1:
			var ph := TAU * j / segs
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var lo := 0.0
			var hi := 1.7
			for k in 24:
				var m := (lo + hi) * 0.5
				var x := d.x * m
				var y := d.z * m
				var z := d.y * m
				var a := x * x + 2.25 * y * y + z * z - 1.0
				var f := a * a * a - x * x * z * z * z - 0.1125 * y * y * z * z * z
				if f < 0.0:
					lo = m
				else:
					hi = m
			row.append(d * lo)
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings:
		for j in segs:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i + 1][j]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			for v in [a, c, b, a, d, c]:
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	_meshes.heart = mesh
	return mesh


# =====================================================================
#  Superrang-Magie: Fallen Down
# =====================================================================

## Aufbau: riesiger Runenkreis am Boden, ein Kranz senkrechter Magiekreise um Ainz, ein Kreis hoch über ihm,
## aufsteigendes Licht und eine Warnung am Zielort, die sich bis zur Auslösung füllt.
static func super_begin(c: Fighter, center: Vector3, sp: Dictionary) -> Dictionary:
	var h := {"nodes": []}
	if not CombatFX.enabled:
		return h
	var parent := c.get_parent()
	var col := Color(sp.get("color", "#fff2b0"))
	var cast := float(sp.get("cast", 4.0))
	h.nodes.append(GroundMark.rune(parent, c.global_position, 7.0, col, cast + 0.8, "c", c, 0.25))
	h.nodes.append(GroundMark.rune(parent, c.global_position, 3.4, Color(1.0, 0.95, 0.8), cast + 0.8, "a", c, -0.5))
	var n := 7
	var base_a := atan2(c.facing.z, c.facing.x)
	for i in n:
		var a := base_a + deg_to_rad(lerpf(-115.0, 115.0, float(i) / (n - 1)))
		var pos := c.global_position + Vector3(cos(a) * 5.0, 2.4 + sin(float(i) * 1.7) * 0.4, sin(a) * 5.0)
		var f := GroundMark.floating(parent, pos, 1.15, col, cast + 0.8, "c", null, 0.0)
		if f:
			# senkrecht, zur Mitte gedreht
			f.global_basis = Basis.looking_at((c.global_position + Vector3.UP * 2.6 - pos).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			f.spin_speed = 0.6 if i % 2 == 0 else -0.6
			f.max_fade = 0.0
			var tw := f.create_tween()
			tw.tween_interval(cast * 0.45 * i / n)
			tw.tween_property(f, "max_fade", 1.0, 0.4)
			h.nodes.append(f)
	var top := GroundMark.floating(parent, c.global_position + Vector3.UP * 9.0, 4.0, col, cast + 0.8, "a", null, 0.0)
	if top:
		top.spin_speed = 0.35
		h.nodes.append(top)
	var aura := CombatFX.emitter(c, "aura", col)
	if aura:
		aura.amount = 80
		h.aura = aura
	h.light = _light(c, Vector3.UP * 3.0, col, 0.0, 18.0)
	(h.light as OmniLight3D).create_tween().tween_property(h.light, "light_energy", 6.0, cast)
	h.warn = GroundMark.telegraph(parent, center, 8.0, 360.0, 0.0, Color(1.0, 0.82, 0.35), cast)
	CombatFX.sound("super_charge", c.global_position + Vector3.UP * 2.0, 1.0, 0.0)
	return h


## Auslösung: eine gewaltige Lichtsäule fällt auf den Zielort – Blendung, Druckwelle, verbrannte Erde.
static func super_release(h: Dictionary, c: Fighter, center: Vector3, sp: Dictionary) -> void:
	var parent := c.get_parent()
	var col := Color(sp.get("color", "#fff2b0"))
	for nd in h.get("nodes", []):
		if is_instance_valid(nd):
			(nd as GroundMark).release()
	if h.has("aura") and is_instance_valid(h.aura):
		CombatFX.stop(h.aura)
	if h.has("light") and is_instance_valid(h.light):
		var l: OmniLight3D = h.light
		l.create_tween().tween_property(l, "light_energy", 0.0, 0.6)
		l.get_tree().create_timer(0.7, false).timeout.connect(l.queue_free)
	pillar(parent, center - Vector3.UP * 2.0, 6.5, 90.0, col, 1.1, 5.0)
	pillar(parent, center - Vector3.UP * 2.0, 2.4, 90.0, Color(1, 1, 0.95), 1.3, 7.0)
	explosion(parent, center + Vector3.UP * 0.5, 7.5, "holy", col)
	for i in 3:
		GroundMark.ring(parent, center, 10.0 + i * 5.0, col, 0.8 + i * 0.25, 0.08)
	CombatFX.burst(parent, "dust_ring", center + Vector3.UP * 0.2, Color(0.6, 0.55, 0.48), Vector3.UP, 3.0)
	CombatFX.burst(parent, "motes", center + Vector3.UP * 2.0, col, Vector3.UP, 4.0)
	CombatFX.burst(parent, "embers", center + Vector3.UP * 0.5, Color(1.0, 0.7, 0.3), Vector3.UP, 3.0)
	CombatFX.burst(parent, "sparks_big", center + Vector3.UP * 1.0, col, Vector3.UP, 2.0)
	var big := CombatFX.flash(parent, center + Vector3.UP * 6.0, col, 26.0, 60.0, 1.8)
	if big:
		big.shadow_enabled = true
	var g := CombatFX._ground_below(parent, center + Vector3.UP * 2.0)
	if g != Vector3.INF:
		CombatFX.decal(parent, g, "scorch", 16.0, 30.0, Color(1, 1, 1), 6.0)
		CombatFX.decal(parent, g, "crack", 12.0, 30.0)
	distortion(parent, center + Vector3.UP * 2.0, 16.0, 0.07, 0.8)
	screen_flash(Color(1.0, 0.97, 0.85, 0.85), 0.9)
	CombatFX.sound("super_blast", center + Vector3.UP * 2.0, 1.2, 0.0)
	CombatFX.shake(0.95)
	CombatFX.fov_kick(7.0)
	CombatFX.slowmo(0.25, 0.65)


# =====================================================================
#  Bildschirmblitz
# =====================================================================

static func screen_flash(col: Color, secs: float) -> void:
	if not CombatFX.enabled:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _flash_layer == null or not is_instance_valid(_flash_layer):
		_flash_layer = CanvasLayer.new()
		_flash_layer.layer = 50
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.color = Color(1, 1, 1, 0)
		_flash_layer.add_child(_flash_rect)
		tree.root.add_child(_flash_layer)
	_flash_rect.color = col
	var tw := _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# =====================================================================
#  Bausteine
# =====================================================================

static func _mesh(parent: Node, mesh: Mesh, mat: Material, at: Vector3, scl: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(m)
	if parent is Node3D and (parent as Node3D).is_inside_tree() and not (parent is Projectile or parent is Fighter):
		m.global_position = at
	else:
		m.position = at
	m.scale = scl
	return m


static func _light(parent: Node, at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.light_bake_mode = Light3D.BAKE_DISABLED
	l.position = at
	parent.add_child(l)
	return l


static func _sphere() -> SphereMesh:
	if not _meshes.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 40
		s.rings = 20
		_meshes.sphere = s
	return _meshes.sphere


static func _cylinder() -> CylinderMesh:
	if not _meshes.has("cyl"):
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 40
		c.rings = 6
		c.cap_top = false
		c.cap_bottom = false
		_meshes.cyl = c
	return _meshes.cyl


## Spitzer Körper entlang −Z (Lanze, Speer, Eisdorn): Länge len, Radius r.
static func _spike(len: float, r: float) -> Mesh:
	var key := "spike|%.2f|%.2f" % [len, r]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = r
		c.height = len
		c.radial_segments = 6
		c.rings = 3
		# Spitze nach −Z (Flugrichtung), Fuß im Ursprung: Zylinder um X kippen und verschieben
		var st := SurfaceTool.new()
		st.create_from(c, 0)
		var arr := st.commit_to_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var rot := Basis(Vector3.RIGHT, -PI * 0.5)
		for i in verts.size():
			verts[i] = rot * verts[i] - Vector3(0, 0, len * 0.5)
			norms[i] = rot * norms[i]
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_meshes[key] = m
	return _meshes[key]


static func _arrow(p: Node3D) -> void:
	var wood := B3.mat(Color(0.42, 0.3, 0.18), 0.8)
	var steel := B3.mat(Color(0.6, 0.6, 0.64), 0.3, 0.9)
	var feather := B3.mat(Color(0.85, 0.82, 0.75), 0.9)
	var shaft := B3.cyl(p, 0.012, 0.012, 0.85, Vector3(0, 0, 0.1), wood, false, 6)
	shaft.rotation.x = PI * 0.5
	var head := B3.cone(p, 0.03, 0.12, Vector3(0, 0, -0.38), steel)
	head.rotation.x = -PI * 0.5
	for k in 3:
		var f := B3.box(p, Vector3(0.003, 0.05, 0.14), Vector3(0, 0, 0.45), feather, false)
		f.rotation.z = TAU * k / 3.0


static func _sword(p: Node3D) -> Node3D:
	var s := Node3D.new()
	p.add_child(s)
	var steel := B3.mat(Color(0.2, 0.2, 0.24), 0.25, 0.9)
	var gold := B3.mat(Color(0.75, 0.6, 0.25), 0.3, 0.9)
	B3.box(s, Vector3(0.12, 1.5, 0.03), Vector3(0, 0.55, 0), steel, false)
	B3.box(s, Vector3(0.4, 0.06, 0.08), Vector3(0, -0.22, 0), gold, false)
	B3.cyl(s, 0.035, 0.035, 0.3, Vector3(0, -0.4, 0), B3.mat(Color(0.15, 0.08, 0.05)), false, 6)
	s.rotation.x = PI * 0.5
	return s


static func _orb_mat(kind: String) -> ShaderMaterial:
	var key := "orb_" + kind
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(CombatFX.SH + "fx_orb.gdshader")
		m.set_shader_parameter("noise_tex", CombatFX._texture("fx_noise"))
		match kind:
			"fire":
				m.set_shader_parameter("wobble", 0.14)
				m.set_shader_parameter("noise_speed", 0.9)
			"lance":
				m.set_shader_parameter("wobble", 0.0)
				m.set_shader_parameter("rim_power", 1.4)
				m.set_shader_parameter("noise_speed", 0.4)
			"heart":
				m.set_shader_parameter("wobble", 0.03)
				m.set_shader_parameter("veins", 1.0)
				m.set_shader_parameter("noise_speed", 0.25)
			_:
				m.set_shader_parameter("wobble", 0.05)
		_mats[key] = m
	return _mats[key]


static func _simple(key: String, shader: String, noise: bool = true) -> ShaderMaterial:
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(CombatFX.SH + shader)
		if noise:
			m.set_shader_parameter("noise_tex", CombatFX._texture("fx_noise"))
		_mats[key] = m
	return _mats[key]


static func _dark_mat() -> ShaderMaterial:
	return _simple("dark", "fx_orb_dark.gdshader")


static func _explosion_mat() -> ShaderMaterial:
	return _simple("explosion", "fx_explosion.gdshader")


static func _shield_mat() -> ShaderMaterial:
	return _simple("shield", "fx_shield.gdshader")


static func _distort_mat() -> ShaderMaterial:
	return _simple("distort", "fx_distort.gdshader", false)


static func _beam_mat() -> ShaderMaterial:
	return _simple("beam", "fx_beam.gdshader")


static func _bolt_mat() -> ShaderMaterial:
	return _simple("bolt", "fx_bolt.gdshader", false)


static func _ghost_mat() -> ShaderMaterial:
	return _simple("ghost", "fx_ghost.gdshader", false)


static func _scorch(parent: Node, at: Vector3, size: float) -> void:
	var g := CombatFX._ground_below(parent, at + Vector3.UP * 0.3)
	if g != Vector3.INF and at.y - g.y < 2.5:
		CombatFX.decal(parent, g, "scorch", size, 16.0, Color(1, 1, 1), 3.0)


static func prewarm(parent: Node, at: Vector3) -> void:
	for k in ["fire", "lance", "heart", "soft"]:
		var m := _mesh(parent, _sphere(), _orb_mat(k), at, Vector3.ONE * 0.1)
		parent.get_tree().create_timer(0.3, false).timeout.connect(m.queue_free)
	for mat in [_dark_mat(), _explosion_mat(), _shield_mat(), _distort_mat(), _ghost_mat()]:
		var m := _mesh(parent, _sphere(), mat, at, Vector3.ONE * 0.1)
		parent.get_tree().create_timer(0.3, false).timeout.connect(m.queue_free)
	for mat in [_beam_mat()]:
		var m := _mesh(parent, _cylinder(), mat, at, Vector3.ONE * 0.1)
		parent.get_tree().create_timer(0.3, false).timeout.connect(m.queue_free)
	bolt(parent, at, at + Vector3.UP * 0.2, Color(0.6, 0.8, 1.0), 0.05, 0.2)
	_heart_mesh()

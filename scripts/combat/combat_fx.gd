class_name CombatFX
## Kampf- und Zaubereffekte. Alle Vorlagen (Partikel-Prozesse, Materialien, Meshes) entstehen einmal und werden
## geteilt; Farben kommen je Effekt als Instanz-Parameter – so wird mitten im Kampf nichts neu kompiliert.
##
##   on_struck()  wird von Fighter.take_hit für jedes Ergebnis aufgerufen und setzt den Treffer zusammen:
##                Splitter/Funken/Blut je Stoff, Geräusch, Schadenszahl, Trefferstopp, Zurückzucken,
##                Kamera-Erschütterung, bei Paraden und großen Siegen kurze Zeitlupe
##   burst()      Partikelstoß aus einer Vorlage (siehe _preset) in beliebiger Tönung
##   flash()      Lichtblitz · decal() Bodenmarke (Brand, Blut, Frost, Riss) · number() Schadenszahl
##   shake()      Kamera-Erschütterung · hitstop() Trefferstopp · slowmo() Zeitlupe · sound() Raumklang
##   prewarm()    zeigt jede Vorlage einmal (hinter dem Ladeschleier), damit der erste Treffer nicht ruckelt

const TEX := "res://assets/textures/fx/"
const SH := "res://assets/shaders/fx/"

## Stoff eines Kämpfers → Treffereffekt: [Partikelvorlagen], Geräusch, Tönung, Bodenmarke
const MATERIALS := {
	"flesh": {"fx": [["blood", 1.0], ["blood_spray", 1.0], ["blood_mist", 1.0]], "sound": "hit_flesh", "tint": Color(0.36, 0.015, 0.01), "decal": "blood", "flash": Color(1.0, 0.45, 0.35)},
	"beast": {"fx": [["blood", 0.8], ["blood_spray", 0.8], ["blood_mist", 0.7], ["dust_puff", 0.4]], "sound": "hit_flesh", "tint": Color(0.36, 0.015, 0.01), "decal": "blood", "flash": Color(1.0, 0.5, 0.35)},
	"bone": {"fx": [["bone", 1.0], ["dust_puff", 0.8]], "sound": "hit_bone", "tint": Color(0.86, 0.82, 0.7), "flash": Color(1.0, 0.95, 0.82)},
	"armor": {"fx": [["sparks", 1.0], ["blood", 0.35]], "sound": "hit_armor", "tint": Color(1.0, 0.62, 0.28), "decal": "blood", "flash": Color(1.0, 0.75, 0.4)},
	"dark_armor": {"fx": [["sparks", 0.9], ["wisps", 0.6]], "sound": "hit_armor", "tint": Color(0.75, 0.45, 1.0), "flash": Color(0.8, 0.55, 1.0)},
	"stone": {"fx": [["stone", 1.0], ["dust_puff", 1.2]], "sound": "hit_stone", "tint": Color(0.55, 0.52, 0.48), "flash": Color(1.0, 0.95, 0.85)},
	"holy": {"fx": [["motes", 1.0], ["sparks", 0.5]], "sound": "hit_holy", "tint": Color(1.0, 0.88, 0.5), "flash": Color(1.0, 0.9, 0.55)},
	"ice": {"fx": [["ice_shards", 0.8], ["frost_mist", 0.7], ["sparks", 0.3]], "sound": "hit_ice", "tint": Color(0.7, 0.9, 1.0), "flash": Color(0.7, 0.9, 1.0)},
	"fire": {"fx": [["embers", 1.3], ["flame_puff", 1.0], ["sparks", 0.5]], "sound": "hit_stone", "tint": Color(1.0, 0.5, 0.15), "flash": Color(1.0, 0.65, 0.3)},
	"plate": {"fx": [["sparks", 1.2], ["sparks_big", 0.35]], "sound": "hit_armor", "tint": Color(0.85, 0.9, 1.0), "flash": Color(0.9, 0.95, 1.0)},
	"undead_lord": {"fx": [["bone", 0.6], ["motes", 0.7]], "sound": "hit_bone", "tint": Color(0.7, 0.45, 1.0), "flash": Color(0.85, 0.6, 1.0)},
}
## Schadensart → Zusatzeffekt und Farbe der Zahl
const TYPE_FX := {
	"fire": [["embers", 1.0], ["flame_puff", 0.6]], "ice": [["ice_shards", 0.6], ["frost_mist", 0.6]],
	"negative": [["wisps", 1.0], ["motes", 0.5]], "holy": [["motes", 1.0], ["flash_soft", 0.6]], "lightning": [["sparks", 1.0], ["flash_soft", 0.5]],
}
const TYPE_TINT := {
	"fire": Color(1.0, 0.5, 0.12), "ice": Color(0.55, 0.85, 1.0), "negative": Color(0.6, 0.25, 1.0),
	"holy": Color(1.0, 0.85, 0.45), "lightning": Color(0.55, 0.75, 1.0), "physical": Color(1, 1, 1),
}
const NUMBER_COL := {
	"fire": Color(1.0, 0.62, 0.25), "negative": Color(0.78, 0.48, 1.0), "holy": Color(1.0, 0.95, 0.62),
	"ice": Color(0.62, 0.88, 1.0), "lightning": Color(0.7, 0.85, 1.0),
}
const MAX_DECALS := 28

static var player: Node3D              ## Player3D – für Erschütterung, Blickwinkel-Zoom und Lautstärke
static var enabled := true             ## Tests können Effekte abschalten
static var _procs := {}
static var _draws := {}
static var _decals: Array = []
static var _tex := {}
static var _clock: Clock
static var _ground: GPUParticlesCollisionHeightField3D


# =====================================================================
#  Uhr für Zeitlupe (läuft in Echtzeit, auch wenn Engine.time_scale klein ist)
# =====================================================================

class Clock extends Node:
	var slow_scale := 1.0
	var slow_until := 0.0
	var ease_out := 0.18

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		if slow_scale >= 1.0:
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now < slow_until:
			Engine.time_scale = slow_scale
		else:
			var k := clampf((now - slow_until) / ease_out, 0.0, 1.0)
			Engine.time_scale = lerpf(slow_scale, 1.0, k * k * (3.0 - 2.0 * k))
			if k >= 1.0:
				slow_scale = 1.0
				Engine.time_scale = 1.0

	func _exit_tree() -> void:
		Engine.time_scale = 1.0


static func _get_clock() -> Clock:
	if _clock == null or not is_instance_valid(_clock):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		_clock = Clock.new()
		_clock.name = "CombatFXClock"
		tree.root.add_child.call_deferred(_clock)
	return _clock


## Zeitlupe für `real_secs` Sekunden Echtzeit (danach sanft zurück). Stärkere Zeitlupe gewinnt.
static func slowmo(scale: float, real_secs: float) -> void:
	if not enabled or not Settings.hitstop:
		return
	var c := _get_clock()
	if c == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if c.slow_scale < 1.0 and scale > c.slow_scale and now < c.slow_until:
		c.slow_until = maxf(c.slow_until, now + real_secs * 0.5)
		return
	c.slow_scale = scale
	c.slow_until = now + real_secs
	Engine.time_scale = scale


## Alle geteilten Vorlagen freigeben (Testende).
static func clear_caches() -> void:
	_procs.clear()
	_draws.clear()
	_tex.clear()
	_decals.clear()
	SlashFX._meshes.clear()
	SlashFX._mat = null
	SpellFX._mats.clear()
	SpellFX._meshes.clear()
	GroundMark._mats.clear()
	if _ground and is_instance_valid(_ground):
		_ground.queue_free()
	_ground = null


static func reset_time() -> void:
	if _clock and is_instance_valid(_clock):
		_clock.slow_scale = 1.0
	Engine.time_scale = 1.0


# =====================================================================
#  Treffer zusammensetzen
# =====================================================================

## Wer steckt hinter einem Treffer? Kämpfer direkt, bei Geschossen deren Schütze.
static func attacker_of(from: Node) -> Fighter:
	if from == null or not is_instance_valid(from):
		return null
	if from is Fighter:
		return from
	var s: Variant = from.get("source")
	return s if s is Fighter and is_instance_valid(s) else null


static func on_struck(v: Fighter, from: Node3D, info: Dictionary, result: String, dealt: float) -> void:
	if not enabled or not is_instance_valid(v) or not v.is_inside_tree() or result == "none":
		return
	var parent := v.get_parent()
	var atk := attacker_of(from)
	var src: Vector3 = from.global_position if from and is_instance_valid(from) else v.global_position + v.facing
	var at := v.hit_point(src)
	var dir := at - src
	dir.y *= 0.25
	dir = dir.normalized() if dir.length() > 0.01 else -v.facing
	var pl := v.is_player or (atk != null and atk.is_player)
	var amount := float(info.get("amount", 0.0))
	var heavy := amount >= 30.0 or String(info.get("kind", "")) == "heavy"
	var flags: Array = info.get("flags", [])
	var crit := "crit" in flags
	var ranged := bool(info.get("ranged", false))
	match result:
		"dodge":
			sound("dodge", v.global_position + Vector3.UP, 0.45)
		"parry":
			burst(parent, "sparks_big", at, Color(1.0, 0.78, 0.32), -dir)
			burst(parent, "flash", at, Color(1.0, 0.86, 0.5))
			burst(parent, "motes", at, Color(1.0, 0.8, 0.4), -dir, 0.6)
			flash(parent, at, Color(1.0, 0.78, 0.4), 7.0, 8.0, 0.3)
			GroundMark.ring(parent, v.global_position, 2.6, Color(1.0, 0.8, 0.4), 0.45)
			sound("parry", at, 1.0, 0.04)
			hitstop(v, atk, 0.12)
			if pl:
				shake(0.32)
				fov_kick(4.0)
				slowmo(0.3, 0.3)
		"block":
			burst(parent, "sparks", at, Color(1.0, 0.7, 0.35), -dir, 0.8)
			burst(parent, "flash_soft", at, Color(1.0, 0.75, 0.45), Vector3.UP, 0.6)
			sound("block", at, 0.95)
			hitstop(v, atk, 0.04)
			if pl:
				shake(0.13 + amount / 400.0)
		"guardbreak":
			burst(parent, "sparks_big", at, Color(0.65, 0.82, 1.0), -dir)
			burst(parent, "flash", at, Color(0.7, 0.85, 1.0))
			sound("guardbreak", at, 1.0)
			hitstop(v, atk, 0.1)
			if pl:
				shake(0.42)
				fov_kick(3.0)
		"shield":
			burst(parent, "motes", at, Color(1.0, 0.85, 0.45), -dir, 1.2)
			burst(parent, "flash_soft", at, Color(1.0, 0.85, 0.45))
			sound("shield_break", at, 0.9)
			hitstop(v, atk, 0.05)
			if pl:
				shake(0.2)
		"hit", "kill":
			impact(parent, at, dir, v.fx_material, heavy or crit, String(info.get("type", "physical")), amount)
			if crit:
				burst(parent, "flash", at, Color(1.0, 0.9, 0.62), Vector3.UP, 0.8)
				sound("crit", at, 0.75, 0.03)
			if dealt > 0.0:
				number(v, dealt, info, flags)
			var hs := 0.045 + (0.035 if heavy else 0.0) + (0.025 if crit else 0.0) + (0.035 if result == "kill" else 0.0)
			hitstop(v, null if ranged else atk, hs)
			v.react(dir, clampf(0.35 + amount / 60.0, 0.3, 1.6) * (1.4 if crit else 1.0))
			if pl:
				if v.is_player:
					shake(0.24 + clampf(dealt / 90.0, 0.0, 0.45))
				else:
					shake((0.1 if not heavy else 0.2) + (0.08 if crit else 0.0) + (0.1 if result == "kill" else 0.0))
				if heavy or crit:
					fov_kick(2.0)


## Treffer am Körper: Effekte je Stoff, dazu je Schadensart (Glut, Frost, Schatten, Licht).
static func impact(parent: Node, at: Vector3, dir: Vector3, mat: String, big: bool, type: String = "physical", amount: float = 20.0) -> void:
	var m: Dictionary = MATERIALS.get(mat, MATERIALS.flesh)
	var mult := (1.4 if big else 1.0) * clampf(0.7 + amount / 40.0, 0.7, 1.8)
	# Splitter, Funken und Blut spritzen aus der Wunde zurück zur Seite des Angreifers und nach oben
	var side := dir.cross(Vector3.UP).normalized() * randf_range(-0.6, 0.6)
	var spray := (-dir * 0.7 + Vector3.UP * 0.55 + side).normalized()
	burst(parent, "hit_flash", at, m.get("flash", Color(1, 0.9, 0.8)), Vector3.UP, 1.0)
	for e in m.fx:
		burst(parent, e[0], at, m.tint, spray, float(e[1]) * mult)
	for e in TYPE_FX.get(type, []):
		burst(parent, e[0], at, TYPE_TINT.get(type, Color.WHITE), spray, float(e[1]) * mult)
	sound(m.sound, at, 0.8 + (0.3 if big else 0.0), 0.08)
	if m.has("decal") and (big or randf() < 0.45):
		var ground := _ground_below(parent, at + dir * randf_range(0.4, 1.4))
		if ground != Vector3.INF:
			decal(parent, ground, m.decal, randf_range(0.7, 1.3) * (1.3 if big else 1.0), 14.0)


# =====================================================================
#  Rückmeldung: Kamera, Trefferstopp, Zahlen, Klang, Licht
# =====================================================================

static func shake(amount: float, at: Vector3 = Vector3.INF) -> void:
	if not enabled or player == null or not is_instance_valid(player):
		return
	var a := amount
	if at != Vector3.INF:
		a *= clampf(1.0 - player.global_position.distance_to(at) / 30.0, 0.0, 1.0)
	if a > 0.005 and player.has_method("add_trauma"):
		player.add_trauma(a * Settings.screen_shake)


static func fov_kick(deg: float) -> void:
	if enabled and player and is_instance_valid(player) and player.has_method("fov_kick"):
		player.fov_kick(deg)


## Trefferstopp: Opfer und Angreifer frieren kurz ein – der Schlag „sitzt“.
static func hitstop(victim: Fighter, attacker: Fighter, secs: float) -> void:
	if not enabled or not Settings.hitstop:
		return
	if victim and is_instance_valid(victim):
		victim.freeze(secs + 0.015, true)
	if attacker and is_instance_valid(attacker) and attacker != victim:
		attacker.freeze(secs, false)


static func sound(name: String, at: Vector3, volume: float = 1.0, pitch_var: float = 0.07) -> void:
	if enabled:
		Audio.sfx3d(name, at, volume, pitch_var)


## Punktlicht, das in `secs` erlischt.
static func flash(parent: Node, at: Vector3, col: Color, energy: float = 4.0, rng: float = 6.0, secs: float = 0.3) -> OmniLight3D:
	if not enabled or parent == null:
		return null
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.light_bake_mode = Light3D.BAKE_DISABLED
	parent.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)
	return l


## Schadenszahl über dem Getroffenen: springt auf, steigt im Bogen davon; Krit/Konter/Rücken als Zusatzzeile.
static func number(v: Fighter, amount: float, info: Dictionary, flags: Array = []) -> void:
	var type := String(info.get("type", "physical"))
	var col: Color = NUMBER_COL.get(type, Color(1, 1, 1))
	var size := 44
	var sub := ""
	if "crit" in flags:
		col = col.lerp(Palette.GOLD_BRIGHT, 0.55)
		size = 66
		sub = "KRITISCH"
	elif "back" in flags:
		size = 54
		sub = "RÜCKENTREFFER"
	elif "punish" in flags:
		size = 52
		sub = "KONTER"
	elif "helpless" in flags:
		size = 52
		sub = "WEHRLOS"
	if amount >= 100.0:
		size += 10
	var text := str(roundi(amount))
	if v.is_player:
		col = Color(1.0, 0.32, 0.3)
		text = "−" + text
		size = 40
		sub = ""
	float_text(v.get_parent(), v.global_position + Vector3(randf_range(-0.35, 0.35), v.body_height + 0.5, randf_range(-0.2, 0.2)), text, col, size, sub)


## Schwebender Text (Zahlen, „+12 Gold“, „Herz zerquetscht“ …).
static func float_text(parent: Node, at: Vector3, text: String, col: Color, size: int = 44, sub: String = "") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = NazarickTheme.display_font(800)
	l.font_size = size
	l.outline_size = 12
	l.modulate = col
	l.outline_modulate = Color(col.darkened(0.88), 0.92)
	l.pixel_size = 0.006
	l.no_depth_test = true
	l.render_priority = 10
	l.fixed_size = false
	parent.add_child(l)
	l.global_position = at
	if sub != "":
		var s := Label3D.new()
		s.text = sub
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.font = NazarickTheme.display_font(700)
		s.font_size = 22
		s.outline_size = 8
		s.modulate = col.lightened(0.2)
		s.outline_modulate = Color(0, 0, 0, 0.9)
		s.pixel_size = 0.006
		s.no_depth_test = true
		s.render_priority = 10
		s.position = Vector3(0, -0.32, 0)
		l.add_child(s)
	var big := size >= 56
	l.scale = Vector3.ONE * (2.1 if big else 1.45)
	var side := Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", at + Vector3(0, 1.3 if not big else 1.6, 0) + side, 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6 if not big else 0.85)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.6 if not big else 0.85)
	tw.chain().tween_callback(l.queue_free)


# =====================================================================
#  Bodenmarken (Decals: Brand, Blut, Frost, Riss)
# =====================================================================

static func decal(parent: Node, at: Vector3, kind: String, size: float = 2.0, life: float = 12.0, col: Color = Color.WHITE, emit: float = 0.0) -> Decal:
	if not enabled or parent == null:
		return null
	var d := Decal.new()
	d.size = Vector3(size, 1.6, size)
	var base := kind
	if kind == "blood":
		base = "blood_%d" % (randi() % 4)
		d.texture_orm = _texture("decal_blood_orm")
	d.texture_albedo = _texture("decal_" + base)
	if kind == "crack":
		d.texture_normal = _texture("decal_crack_n")
	if kind == "scorch":
		d.texture_emission = _texture("decal_scorch_emit")
		d.emission_energy = emit if emit > 0.0 else 3.0
	d.modulate = col
	d.albedo_mix = 1.0
	d.upper_fade = 0.25
	d.lower_fade = 0.35
	d.normal_fade = 0.45
	d.cull_mask = 1                    # nur Welt – nie auf Figuren
	d.distance_fade_enabled = true
	d.distance_fade_begin = 45.0
	d.distance_fade_length = 10.0
	parent.add_child(d)
	d.global_position = at + Vector3(0, 0.25, 0)
	d.rotation.y = randf() * TAU
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := d.create_tween()
	if kind == "scorch":
		tw.tween_property(d, "emission_energy", 0.0, minf(life * 0.4, 5.0))
		tw.tween_interval(maxf(0.0, life * 0.6))
	else:
		tw.tween_interval(life)
	tw.tween_property(d, "modulate:a", 0.0, 1.8)
	tw.tween_callback(func():
		_decals.erase(d)
		d.queue_free())
	return d


static func _ground_below(parent: Node, at: Vector3) -> Vector3:
	var n := parent as Node3D
	if n == null or not n.is_inside_tree():
		return Vector3.INF
	var space := n.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.5, 0), at - Vector3(0, 4.0, 0), 1)
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3.INF


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(TEX + name + ".png")
	return _tex[name]


# =====================================================================
#  Partikel
# =====================================================================

## Partikelstoß aus einer Vorlage. dir = Hauptrichtung (Vorlage sprüht entlang +Y), amount_mult skaliert die Anzahl.
static func burst(parent: Node, kind: String, at: Vector3, col: Color, dir: Vector3 = Vector3.UP, amount_mult: float = 1.0, glow: Color = Color(0, 0, 0, 0)) -> GPUParticles3D:
	if not enabled or parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var pr := _preset(kind)
	if pr.is_empty():
		return null
	var p := GPUParticles3D.new()
	p.process_material = _proc(kind)
	var dw: Array = _draw(String(pr.draw))
	p.draw_pass_1 = dw[0]
	p.material_override = dw[1]
	p.transform_align = pr.get("align", GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD)
	p.amount = maxi(1, int(round(float(pr.amount) * amount_mult * (1.0 if Settings.particles else 0.55))))
	p.lifetime = float(pr.life)
	p.one_shot = not pr.get("loop", false)
	p.explosiveness = float(pr.get("explode", 1.0))
	p.randomness = 0.2
	p.local_coords = false
	p.fixed_fps = 0
	p.interpolate = false
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.set_instance_shader_parameter("tint", col)
	if glow.a > 0.0:
		p.set_instance_shader_parameter("glow", glow)
	parent.add_child(p)
	p.global_position = at
	if dir.length() > 0.01:
		p.global_basis = _basis_y(dir)
	if pr.get("collide", false):
		_ensure_ground(parent, at)
	p.emitting = true
	if p.one_shot:
		p.get_tree().create_timer(float(pr.life) * 1.3 + 0.4, false).timeout.connect(p.queue_free)
	return p


## Dauerhafter Emitter (Schweif eines Geschosses, Aura, brennendes Ziel) – Aufrufer gibt ihn frei.
static func emitter(parent: Node, kind: String, col: Color, glow: Color = Color(0, 0, 0, 0)) -> GPUParticles3D:
	if parent == null:
		return null
	var pr := _preset(kind)
	if pr.is_empty():
		return null
	var p := GPUParticles3D.new()
	p.process_material = _proc(kind)
	var dw: Array = _draw(String(pr.draw))
	p.draw_pass_1 = dw[0]
	p.material_override = dw[1]
	p.transform_align = pr.get("align", GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD)
	p.amount = maxi(1, int(round(float(pr.amount) * (1.0 if Settings.particles else 0.55))))
	p.lifetime = float(pr.life)
	p.explosiveness = 0.0
	p.local_coords = false
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.set_instance_shader_parameter("tint", col)
	if glow.a > 0.0:
		p.set_instance_shader_parameter("glow", glow)
	parent.add_child(p)
	p.emitting = true
	return p


## Emitter auslaufen lassen (keine neuen Partikel, nach Lebenszeit frei).
static func stop(p: GPUParticles3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	var tree := p.get_tree()
	if tree:
		var keep := p.global_transform
		if p.get_parent() and p.get_parent().get_parent():
			# vom Träger lösen, damit der Schweif nicht mit dem Geschoss verschwindet
			var lvl := p.get_parent().get_parent()
			p.get_parent().remove_child(p)
			lvl.add_child(p)
			p.global_transform = keep
		tree.create_timer(p.lifetime + 0.3, false).timeout.connect(p.queue_free)


static func _basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Bodenkollision für Funken, Splitter und Blutstropfen: ein Höhenfeld um den Kampfort, das bei Bedarf nachrückt.
static func _ensure_ground(parent: Node, at: Vector3) -> void:
	if OS.get_environment("NO_FXGROUND") != "":
		return
	if _ground == null or not is_instance_valid(_ground) or not _ground.is_inside_tree() or _ground.get_parent() != parent:
		if _ground and is_instance_valid(_ground):
			_ground.queue_free()
		_ground = GPUParticlesCollisionHeightField3D.new()
		_ground.size = Vector3(44, 24, 44)
		_ground.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
		_ground.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
		_ground.cull_mask = 1
		parent.add_child(_ground)
		_ground.global_position = at.snapped(Vector3(2, 2, 2))
		return
	var d := _ground.global_position - at
	if Vector2(d.x, d.z).length() > 12.0 or absf(d.y) > 7.0:
		_ground.global_position = at.snapped(Vector3(2, 2, 2))


# --- Vorlagen ---------------------------------------------------------------------------------------------------

## Partikelvorlage: amount, life, draw (Darstellung) und Prozess-Werte.
static func _preset(kind: String) -> Dictionary:
	match kind:
		"sparks":
			return {"amount": 30, "life": 0.5, "draw": "streak", "align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY,
				"spread": 55.0, "vel": [5.0, 13.0], "grav": Vector3(0, -11, 0), "damp": [1.5, 3.5], "scale": [0.8, 1.6],
				"scale_curve": [[0.0, 1.0], [1.0, 0.25]], "ramp": [[0.0, Color(2.6, 0.9, 0, 1)], [0.35, Color(1.8, 0.25, 0, 1)], [1.0, Color(0.5, 0, 0, 0)]],
				"collide": true, "bounce": 0.35, "friction": 0.35}
		"sparks_big":
			return {"amount": 70, "life": 0.85, "draw": "streak", "align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY,
				"spread": 75.0, "vel": [6.0, 16.0], "grav": Vector3(0, -10, 0), "damp": [1.0, 3.0], "scale": [1.0, 2.2],
				"scale_curve": [[0.0, 1.0], [1.0, 0.2]], "ramp": [[0.0, Color(3.0, 1.0, 0, 1)], [0.3, Color(2.0, 0.35, 0, 1)], [1.0, Color(0.6, 0, 0, 0)]],
				"collide": true, "bounce": 0.4, "friction": 0.3}
		"embers":
			return {"amount": 30, "life": 1.5, "draw": "glow", "spread": 80.0, "vel": [1.0, 4.5], "grav": Vector3(0, 1.4, 0),
				"damp": [0.6, 1.4], "scale": [0.05, 0.12], "turb": [1.2, 0.6],
				"ramp": [[0.0, Color(3.0, 0.8, 0, 1)], [0.4, Color(2.0, 0.15, 0, 0.9)], [1.0, Color(0.6, 0, 0, 0)]]}
		"motes":
			return {"amount": 34, "life": 1.1, "draw": "glow", "spread": 180.0, "vel": [1.4, 5.0], "grav": Vector3(0, 0.6, 0),
				"damp": [2.5, 4.0], "scale": [0.07, 0.18], "turb": [0.8, 0.8],
				"ramp": [[0.0, Color(2.6, 0.8, 0, 1)], [0.5, Color(1.8, 0.2, 0, 0.85)], [1.0, Color(0.5, 0, 0, 0)]]}
		"flash":
			return {"amount": 1, "life": 0.24, "draw": "flare", "spread": 0.0, "vel": [0.0, 0.0], "grav": Vector3.ZERO,
				"damp": [0.0, 0.0], "scale": [2.4, 2.8], "scale_curve": [[0.0, 0.5], [0.15, 1.0], [1.0, 0.7]], "spin": true,
				"ramp": [[0.0, Color(3.0, 0.9, 0, 1)], [1.0, Color(1.0, 0.2, 0, 0)]]}
		"hit_flash":
			return {"amount": 1, "life": 0.14, "draw": "flare", "spread": 0.0, "vel": [0.0, 0.0], "grav": Vector3.ZERO,
				"damp": [0.0, 0.0], "scale": [1.0, 1.35], "scale_curve": [[0.0, 0.35], [0.25, 1.0], [1.0, 0.75]], "spin": true,
				"ramp": [[0.0, Color(3.0, 0.85, 0, 1)], [1.0, Color(1.0, 0.2, 0, 0)]]}
		"flash_soft":
			return {"amount": 1, "life": 0.32, "draw": "glow", "spread": 0.0, "vel": [0.0, 0.0], "grav": Vector3.ZERO,
				"damp": [0.0, 0.0], "scale": [2.2, 2.6], "scale_curve": [[0.0, 0.6], [1.0, 1.2]],
				"ramp": [[0.0, Color(1.6, 0.5, 0, 0.9)], [1.0, Color(0.5, 0, 0, 0)]]}
		"blood":
			return {"amount": 30, "life": 1.0, "draw": "drop", "spread": 42.0, "vel": [2.5, 7.5], "grav": Vector3(0, -15, 0),
				"damp": [0.3, 1.0], "scale": [0.045, 0.1], "ramp": [[0.0, Color(1, 0, 0, 1)], [0.8, Color(0.9, 0, 0, 1)], [1.0, Color(0.8, 0, 0, 0)]],
				"collide": true, "bounce": 0.0, "friction": 1.0}
		"blood_mist":
			return {"amount": 6, "life": 0.6, "draw": "smoke", "spread": 35.0, "vel": [0.6, 2.2], "grav": Vector3(0, -0.4, 0),
				"damp": [2.0, 3.0], "scale": [0.4, 0.8], "scale_curve": [[0.0, 0.5], [1.0, 1.4]], "spin": true,
				"ramp": [[0.0, Color(1, 0, 0, 0.0)], [0.12, Color(1, 0, 0, 0.62)], [1.0, Color(0.8, 0, 0, 0)]]}
		"blood_spray":
			return {"amount": 14, "life": 0.4, "draw": "streak_dark", "align": GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY,
				"spread": 30.0, "vel": [4.0, 9.0], "grav": Vector3(0, -12, 0), "damp": [1.0, 2.0], "scale": [0.6, 1.2],
				"scale_curve": [[0.0, 1.0], [1.0, 0.4]], "ramp": [[0.0, Color(1, 0, 0, 1)], [0.7, Color(0.9, 0, 0, 0.9)], [1.0, Color(0.8, 0, 0, 0)]]}
		"bone":
			return {"amount": 22, "life": 1.2, "draw": "chip_bone", "align": GPUParticles3D.TRANSFORM_ALIGN_DISABLED, "spread": 60.0,
				"vel": [3.0, 7.0], "grav": Vector3(0, -14, 0), "damp": [0.2, 0.8], "scale": [0.06, 0.15], "spin": true, "spin_vel": [-720.0, 720.0],
				"scale_curve": [[0.0, 1.0], [0.75, 1.0], [1.0, 0.0]], "ramp": [[0.0, Color(1, 0, 0, 1)], [1.0, Color(1, 0, 0, 1)]],
				"collide": true, "bounce": 0.3, "friction": 0.5}
		"stone":
			return {"amount": 22, "life": 1.3, "draw": "chip_stone", "align": GPUParticles3D.TRANSFORM_ALIGN_DISABLED, "spread": 65.0,
				"vel": [3.0, 7.5], "grav": Vector3(0, -15, 0), "damp": [0.2, 0.7], "scale": [0.07, 0.17], "spin": true, "spin_vel": [-500.0, 500.0],
				"scale_curve": [[0.0, 1.0], [0.75, 1.0], [1.0, 0.0]], "ramp": [[0.0, Color(1, 0, 0, 1)], [1.0, Color(1, 0, 0, 1)]],
				"collide": true, "bounce": 0.25, "friction": 0.6}
		"ice_shards":
			return {"amount": 28, "life": 1.1, "draw": "chip_ice", "align": GPUParticles3D.TRANSFORM_ALIGN_DISABLED, "spread": 75.0,
				"vel": [3.0, 9.0], "grav": Vector3(0, -13, 0), "damp": [0.2, 0.6], "scale": [0.06, 0.16], "spin": true, "spin_vel": [-600.0, 600.0],
				"scale_curve": [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]], "ramp": [[0.0, Color(1, 0, 0, 1)], [1.0, Color(1, 0, 0, 1)]],
				"collide": true, "bounce": 0.35, "friction": 0.3}
		"dust_puff":
			return {"amount": 10, "life": 1.2, "draw": "smoke", "spread": 70.0, "vel": [0.9, 2.8], "grav": Vector3(0, 0.25, 0),
				"damp": [2.0, 3.5], "scale": [0.55, 1.1], "scale_curve": [[0.0, 0.45], [1.0, 1.5]], "spin": true,
				"ramp": [[0.0, Color(1, 0, 0, 0.0)], [0.1, Color(1, 0, 0, 0.62)], [1.0, Color(1, 0, 0, 0)]]}
		"dust_ring":
			return {"amount": 26, "life": 1.5, "draw": "smoke", "spread": 6.0, "vel": [0.2, 0.6], "grav": Vector3(0, 0.15, 0),
				"damp": [1.5, 2.5], "scale": [0.6, 1.2], "scale_curve": [[0.0, 0.5], [1.0, 1.7]], "spin": true,
				"shape": "ring", "ring": [0.6, 0.2], "radial": [5.0, 9.0],
				"ramp": [[0.0, Color(1, 0, 0, 0.0)], [0.08, Color(1, 0, 0, 0.6)], [1.0, Color(1, 0, 0, 0)]]}
		"smoke":
			return {"amount": 12, "life": 2.2, "draw": "smoke", "spread": 60.0, "vel": [0.5, 2.0], "grav": Vector3(0, 0.6, 0),
				"damp": [1.2, 2.0], "scale": [0.8, 1.5], "scale_curve": [[0.0, 0.4], [1.0, 1.8]], "spin": true, "shape": "sphere", "radius": 0.4,
				"ramp": [[0.0, Color(1, 0, 0, 0.0)], [0.1, Color(1, 0.2, 0, 0.6)], [1.0, Color(0.8, 1, 0, 0)]]}
		"flame_puff":
			return {"amount": 8, "life": 0.6, "draw": "flame", "spread": 50.0, "vel": [0.6, 2.2], "grav": Vector3(0, 2.5, 0),
				"damp": [1.5, 2.5], "scale": [0.3, 0.6], "scale_curve": [[0.0, 0.6], [1.0, 0.1]], "spin": true,
				"ramp": [[0.0, Color(2.2, 0.7, 0, 1)], [0.4, Color(1.6, 0.1, 0, 0.8)], [1.0, Color(0.5, 0, 0, 0)]]}
		"wisps":
			return {"amount": 10, "life": 1.2, "draw": "smoke", "spread": 90.0, "vel": [0.8, 2.6], "grav": Vector3(0, 0.9, 0),
				"damp": [1.5, 2.5], "scale": [0.25, 0.55], "scale_curve": [[0.0, 0.4], [1.0, 1.3]], "spin": true, "turb": [1.0, 0.6],
				"ramp": [[0.0, Color(0.25, 0, 0, 0.0)], [0.15, Color(0.25, 0, 0, 0.75)], [1.0, Color(0.2, 1, 0, 0)]]}
		"frost_mist":
			return {"amount": 8, "life": 1.3, "draw": "smoke", "spread": 80.0, "vel": [0.5, 2.0], "grav": Vector3(0, -0.3, 0),
				"damp": [1.5, 2.5], "scale": [0.35, 0.8], "scale_curve": [[0.0, 0.5], [1.0, 1.6]], "spin": true,
				"ramp": [[0.0, Color(1.3, 0, 0, 0.0)], [0.12, Color(1.3, 0, 0, 0.55)], [1.0, Color(1.2, 0, 0, 0)]]}
		"implode":
			return {"amount": 40, "life": 0.7, "draw": "glow", "spread": 180.0, "vel": [0.0, 0.0], "grav": Vector3.ZERO,
				"damp": [0.0, 0.0], "scale": [0.05, 0.12], "shape": "sphere", "radius": 1.6, "radial": [-3.5, -2.0],
				"ramp": [[0.0, Color(0.5, 0, 0, 0)], [0.3, Color(2.0, 0.3, 0, 1)], [1.0, Color(2.5, 0.9, 0, 0)]]}
		# --- Dauerschweife (emitter) --------------------------------------------------------------------------
		"trail_fire":
			return {"amount": 90, "life": 0.5, "draw": "flame", "loop": true, "spread": 180.0, "vel": [0.2, 0.9], "grav": Vector3(0, 1.8, 0),
				"damp": [0.5, 1.0], "scale": [0.35, 0.7], "scale_curve": [[0.0, 1.0], [1.0, 0.1]], "spin": true, "shape": "sphere", "radius": 0.15,
				"ramp": [[0.0, Color(2.6, 0.85, 0, 1)], [0.3, Color(1.8, 0.15, 0, 0.9)], [0.7, Color(0.7, 0, 0, 0.5)], [1.0, Color(0.3, 0, 0, 0)]]}
		"trail_smoke":
			return {"amount": 24, "life": 1.2, "draw": "smoke", "loop": true, "spread": 180.0, "vel": [0.1, 0.5], "grav": Vector3(0, 0.8, 0),
				"damp": [1.0, 2.0], "scale": [0.3, 0.6], "scale_curve": [[0.0, 0.5], [1.0, 1.6]], "spin": true, "shape": "sphere", "radius": 0.12,
				"ramp": [[0.0, Color(0.5, 0, 0, 0.0)], [0.2, Color(0.5, 0, 0, 0.45)], [1.0, Color(0.4, 0, 0, 0)]]}
		"trail_motes":
			return {"amount": 40, "life": 0.7, "draw": "glow", "loop": true, "spread": 180.0, "vel": [0.3, 1.2], "grav": Vector3.ZERO,
				"damp": [1.0, 2.0], "scale": [0.04, 0.1], "shape": "sphere", "radius": 0.18,
				"ramp": [[0.0, Color(2.6, 0.8, 0, 1)], [0.5, Color(1.8, 0.2, 0, 0.8)], [1.0, Color(0.5, 0, 0, 0)]]}
		"trail_wisps":
			return {"amount": 30, "life": 0.9, "draw": "smoke", "loop": true, "spread": 180.0, "vel": [0.2, 0.7], "grav": Vector3(0, 0.4, 0),
				"damp": [1.0, 2.0], "scale": [0.22, 0.45], "scale_curve": [[0.0, 0.6], [1.0, 1.3]], "spin": true, "shape": "sphere", "radius": 0.15,
				"ramp": [[0.0, Color(0.2, 0, 0, 0.0)], [0.2, Color(0.2, 0, 0, 0.7)], [1.0, Color(0.15, 1, 0, 0)]]}
		"aura":
			return {"amount": 36, "life": 1.4, "draw": "glow", "loop": true, "spread": 20.0, "vel": [0.4, 1.2], "grav": Vector3(0, 0.6, 0),
				"damp": [0.5, 1.0], "scale": [0.04, 0.1], "shape": "ring", "ring": [0.55, 0.35],
				"ramp": [[0.0, Color(0.5, 0, 0, 0)], [0.2, Color(2.2, 0.4, 0, 1)], [1.0, Color(0.8, 0, 0, 0)]]}
		"blaze":
			return {"amount": 64, "life": 1.15, "draw": "flame", "loop": true, "spread": 18.0, "vel": [1.0, 2.6], "grav": Vector3(0, 2.4, 0),
				"damp": [0.4, 0.9], "scale": [0.7, 1.5], "scale_curve": [[0.0, 0.7], [0.3, 1.0], [1.0, 0.15]], "spin": true, "shape": "box", "box": Vector3(1.4, 0.5, 1.4),
				"ramp": [[0.0, Color(2.6, 0.85, 0, 1)], [0.3, Color(1.9, 0.2, 0, 0.9)], [1.0, Color(0.4, 0, 0, 0)]]}
		"smoke_column":
			return {"amount": 34, "life": 7.0, "draw": "smoke", "loop": true, "spread": 10.0, "vel": [1.8, 3.0], "grav": Vector3(0.35, 0.2, 0.12),
				"damp": [0.05, 0.12], "scale": [1.4, 2.4], "scale_curve": [[0.0, 0.45], [1.0, 3.4]], "spin": true, "spin_vel": [-15.0, 15.0], "shape": "sphere", "radius": 1.0,
				"ramp": [[0.0, Color(1, 0, 0, 0.0)], [0.07, Color(1, 0.1, 0, 0.7)], [0.5, Color(0.9, 0.7, 0, 0.5)], [1.0, Color(0.8, 1, 0, 0)]]}
		"ash":
			return {"amount": 26, "life": 3.2, "draw": "glow", "loop": true, "spread": 35.0, "vel": [1.2, 3.4], "grav": Vector3(0.2, 0.7, 0),
				"damp": [0.2, 0.6], "scale": [0.04, 0.09], "turb": [1.6, 1.0], "shape": "box", "box": Vector3(1.4, 0.4, 1.4),
				"ramp": [[0.0, Color(3.0, 0.7, 0, 1)], [0.5, Color(1.8, 0.15, 0, 0.8)], [1.0, Color(0.5, 0, 0, 0)]]}
		"elemental_fire":
			return {"amount": 80, "life": 0.85, "draw": "flame", "loop": true, "spread": 25.0, "vel": [0.8, 2.0], "grav": Vector3(0, 2.8, 0),
				"damp": [0.4, 0.9], "scale": [0.5, 1.15], "scale_curve": [[0.0, 0.8], [0.3, 1.0], [1.0, 0.1]], "spin": true, "shape": "box", "box": Vector3(0.85, 0.75, 0.55),
				"ramp": [[0.0, Color(2.8, 0.9, 0, 1)], [0.3, Color(1.9, 0.2, 0, 0.9)], [1.0, Color(0.4, 0, 0, 0)]]}
		"body_fire":
			return {"amount": 48, "life": 0.75, "draw": "flame", "loop": true, "spread": 25.0, "vel": [0.6, 1.7], "grav": Vector3(0, 2.6, 0),
				"damp": [0.5, 1.0], "scale": [0.32, 0.7], "scale_curve": [[0.0, 0.9], [1.0, 0.1]], "spin": true, "shape": "box", "box": Vector3(0.45, 0.85, 0.45),
				"ramp": [[0.0, Color(2.6, 0.85, 0, 1)], [0.35, Color(1.7, 0.15, 0, 0.85)], [1.0, Color(0.4, 0, 0, 0)]]}
		"burning":
			return {"amount": 30, "life": 0.6, "draw": "flame", "loop": true, "spread": 25.0, "vel": [0.5, 1.4], "grav": Vector3(0, 2.0, 0),
				"damp": [0.5, 1.0], "scale": [0.18, 0.4], "scale_curve": [[0.0, 0.9], [1.0, 0.1]], "spin": true, "shape": "box", "box": Vector3(0.3, 0.6, 0.3),
				"ramp": [[0.0, Color(2.4, 0.8, 0, 1)], [0.35, Color(1.6, 0.12, 0, 0.85)], [1.0, Color(0.4, 0, 0, 0)]]}
	return {}


static func _proc(kind: String) -> ParticleProcessMaterial:
	if _procs.has(kind):
		return _procs[kind]
	var o := _preset(kind)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = float(o.get("spread", 45.0))
	var vel: Array = o.get("vel", [1.0, 2.0])
	m.initial_velocity_min = float(vel[0])
	m.initial_velocity_max = float(vel[1])
	m.gravity = o.get("grav", Vector3(0, -9.8, 0))
	var damp: Array = o.get("damp", [0.0, 0.0])
	m.damping_min = float(damp[0])
	m.damping_max = float(damp[1])
	var sc: Array = o.get("scale", [1.0, 1.0])
	m.scale_min = float(sc[0])
	m.scale_max = float(sc[1])
	m.lifetime_randomness = 0.3
	if o.has("scale_curve"):
		m.scale_curve = _curve(o.scale_curve)
	m.color_ramp = _ramp(o.ramp)
	if o.get("spin", false):
		m.angle_min = -180.0
		m.angle_max = 180.0
		var sv: Array = o.get("spin_vel", [-60.0, 60.0])
		m.angular_velocity_min = float(sv[0])
		m.angular_velocity_max = float(sv[1])
	match String(o.get("shape", "point")):
		"sphere":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = float(o.get("radius", 0.3))
		"ring":
			var r: Array = o.ring
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3.UP
			m.emission_ring_radius = float(r[0])
			m.emission_ring_inner_radius = float(r[0]) * float(r[1])
			m.emission_ring_height = 0.05
		"box":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = o.box
	if o.has("radial"):
		var rv: Array = o.radial
		m.radial_accel_min = float(rv[0])
		m.radial_accel_max = float(rv[1])
	if o.has("turb"):
		var t: Array = o.turb
		m.turbulence_enabled = true
		m.turbulence_noise_strength = float(t[0])
		m.turbulence_noise_scale = 3.0
		m.turbulence_influence_min = float(t[1]) * 0.05
		m.turbulence_influence_max = float(t[1]) * 0.12
	if o.get("collide", false):
		m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		m.collision_bounce = float(o.get("bounce", 0.3))
		m.collision_friction = float(o.get("friction", 0.5))
		m.collision_use_scale = true
	if String(o.get("draw", "")) in ["smoke", "flame"]:
		m.anim_offset_min = 0.0
		m.anim_offset_max = 1.0
	_procs[kind] = m
	return m


## Darstellung: [Mesh, Material]
static func _draw(kind: String) -> Array:
	if _draws.has(kind):
		return _draws[kind]
	var mesh: Mesh
	var mat: ShaderMaterial = ShaderMaterial.new()
	match kind:
		"streak":
			var q := QuadMesh.new()
			q.size = Vector2(0.06, 0.55)
			mesh = q
			mat.shader = load(SH + "fx_sprite.gdshader")
			mat.set_shader_parameter("tex", _texture("fx_streak"))
			mat.set_shader_parameter("energy", 4.2)
			mat.set_shader_parameter("soft_dist", 0.0)
		"glow", "flare":
			var q := QuadMesh.new()
			mesh = q
			mat.shader = load(SH + "fx_sprite.gdshader")
			mat.set_shader_parameter("tex", _texture("fx_dot" if kind == "glow" else "fx_flare"))
			mat.set_shader_parameter("energy", 2.6 if kind == "glow" else 3.4)
			mat.set_shader_parameter("soft_dist", 0.15 if kind == "glow" else 0.0)
		"flame":
			var q := QuadMesh.new()
			mesh = q
			mat.shader = load(SH + "fx_sprite.gdshader")
			mat.set_shader_parameter("tex", _texture("fx_smoke"))
			mat.set_shader_parameter("atlas", true)
			mat.set_shader_parameter("energy", 3.0)
			mat.set_shader_parameter("soft_dist", 0.3)
		"smoke":
			var q := QuadMesh.new()
			mesh = q
			mat.shader = load(SH + "fx_smoke.gdshader")
			mat.set_shader_parameter("tex", _texture("fx_smoke"))
			mat.set_shader_parameter("atlas", true)
		"streak_dark":
			var q := QuadMesh.new()
			q.size = Vector2(0.05, 0.5)
			mesh = q
			mat.shader = load(SH + "fx_smoke.gdshader")
			mat.set_shader_parameter("tex", _texture("fx_streak"))
			mat.set_shader_parameter("atlas", false)
			mat.set_shader_parameter("soft_dist", 0.02)
		"drop":
			var q := QuadMesh.new()
			mesh = q
			mat.shader = load(SH + "fx_smoke.gdshader")
			mat.set_shader_parameter("tex", _texture("fx_dot"))
			mat.set_shader_parameter("atlas", false)
			mat.set_shader_parameter("soft_dist", 0.05)
		"chip_bone", "chip_stone", "chip_ice":
			if kind == "chip_bone":
				var b := BoxMesh.new()
				b.size = Vector3(0.35, 1.0, 0.3)
				mesh = b
			elif kind == "chip_stone":
				var b := BoxMesh.new()
				b.size = Vector3(1.0, 0.75, 0.85)
				mesh = b
			else:
				var pm := PrismMesh.new()
				pm.size = Vector3(0.55, 1.3, 0.35)
				mesh = pm
			mat.shader = load(SH + "fx_debris.gdshader")
			mat.set_shader_parameter("roughness", 0.12 if kind == "chip_ice" else 0.85)
			mat.set_shader_parameter("emission", 0.12 if kind == "chip_ice" else 0.0)
	_draws[kind] = [mesh, mat]
	return _draws[kind]


static func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	t.width = 128
	return t


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 3.0
	for p in points:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	var t := CurveTexture.new()
	t.curve = c
	t.width = 64
	return t


# =====================================================================
#  Vorwärmen
# =====================================================================

const PREWARM := ["sparks", "sparks_big", "embers", "motes", "flash", "hit_flash", "flash_soft", "blood", "blood_mist", "blood_spray", "bone", "stone",
	"ice_shards", "dust_puff", "dust_ring", "smoke", "flame_puff", "wisps", "frost_mist", "implode"]

## Zeigt jede Vorlage einmal kurz vor der Kamera (während der Ladeschleier deckt), damit Shader und Pipelines
## bereitstehen, bevor der erste Treffer fällt.
static func prewarm(parent: Node3D, cam: Camera3D) -> void:
	if parent == null or cam == null or not parent.is_inside_tree() or OS.get_environment("NO_PREWARM") != "":
		return
	var at := cam.global_position - cam.global_basis.z * 3.0
	# durchsichtig getönt und nach wenigen Bildern wieder weg: vorher flogen nach jeder Ankunft weiße Funken (bis 16 m/s)
	# noch zwei Sekunden lang durchs Bild, während der Ladeschleier schon aufging
	for k in PREWARM:
		var b := burst(parent, k, at, Color(0, 0, 0, 0), Vector3.UP, 0.2)
		if b:
			b.get_tree().create_timer(0.12, false).timeout.connect(b.queue_free)
	for k in ["trail_fire", "trail_smoke", "trail_motes", "trail_wisps", "aura", "burning"]:
		var e := emitter(parent, k, Color(0, 0, 0, 0))
		if e:
			e.global_position = at
			e.get_tree().create_timer(0.12, false).timeout.connect(e.queue_free)
	GroundMark.prewarm(parent, at)
	SlashFX.prewarm(parent, at)
	SpellFX.prewarm(parent, at)
	for k in ["scorch", "blood", "frost", "crack"]:
		var d := decal(parent, at, k, 0.5, 0.2)
		if d:
			d.modulate.a = 0.01

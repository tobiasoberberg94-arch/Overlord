class_name GroundMark
extends MeshInstance3D
## Über den Boden gelegte Marke: ein Raster, dessen Punkte per Strahl auf den Untergrund gesetzt werden – sie folgt
## Hängen, Stufen und Treppen. Aussehen per Shader (assets/shaders/fx/fx_ground_*):
##   Kreis-/Kegel-/Rechteck-Warnung (füllt sich während des Ausholens), Druckring, Magiekreis, Glutkreis.
## Ablauf: einblenden → halten bzw. füllen → ausblenden → frei. follow = mitwandernder Träger (z. B. Zaubernder).

enum Mode { CIRCLE, CONE, RING, RUNE, RECT, EMBER, CONEWAVE }

const LIFT := 0.05

static var _mats := {}

var duration := 1.0
var fade_in := 0.12
var fade_out := 0.25
var fill_time := 0.0          ## Warnung: progress läuft in fill_time von 0 auf 1
var grow := Vector2(-1, -1)   ## Druckring: progress von grow.x nach grow.y
var spin_speed := 0.0
var follow: Node3D
var float_height := -1.0      ## ≥ 0: in fester Höhe über dem Träger schweben
var max_fade := 1.0
var _t := 0.0
var _released := false


## Marke anlegen. half = halbe Ausdehnung (x seitlich, y = Länge nach vorn), yaw = Blickrichtung (vorn = −Z).
static func spawn(parent: Node, center: Vector3, half: Vector2, mode: int, col: Color, life: float, yaw: float = 0.0, additive: bool = false, rune: String = "") -> GroundMark:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree() or not CombatFX.enabled:
		return null
	var g := GroundMark.new()
	g.duration = life
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	g.material_override = _material(mode, additive, rune)
	g.mesh = _draped(parent as Node3D, center, half, yaw)
	parent.add_child(g)
	g.global_position = center
	g.rotation.y = yaw
	g.set_instance_shader_parameter("tint", col)
	g.set_instance_shader_parameter("fade", 0.0)
	g.set_instance_shader_parameter("progress", 0.0)
	return g


## Angriffswarnung als Kreis (360°) oder Kegel um bzw. vor dem Angreifer; füllt sich in `windup` Sekunden.
static func telegraph(parent: Node, center: Vector3, radius: float, arc: float, yaw: float, col: Color, windup: float) -> GroundMark:
	var cone := arc < 359.0
	var g := spawn(parent, center, Vector2(radius, radius), Mode.CONE if cone else Mode.CIRCLE, col, windup + 0.18, yaw)
	if g:
		g.fill_time = windup
		g.fade_in = minf(0.15, windup * 0.3)
		g.fade_out = 0.18
		g.set_instance_shader_parameter("arc", arc)
		g.set_instance_shader_parameter("energy", 1.6)
	return g


## Rechteckige Warnung (Sturmangriff, Linienzauber) von `from` aus `length` Meter nach vorn.
static func telegraph_line(parent: Node, from: Vector3, yaw: float, length: float, half_width: float, col: Color, windup: float) -> GroundMark:
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var g := spawn(parent, from + fwd * length * 0.5, Vector2(half_width, length * 0.5), Mode.RECT, col, windup + 0.18, yaw)
	if g:
		g.fill_time = windup
		g.fade_out = 0.18
		g.set_instance_shader_parameter("energy", 1.6)
	return g


## Druckring, der sich von der Mitte bis `radius` ausbreitet.
static func ring(parent: Node, center: Vector3, radius: float, col: Color, life: float = 0.6, ring_w: float = 0.12) -> GroundMark:
	var g := spawn(parent, center, Vector2(radius, radius), Mode.RING, col, life, 0.0, true)
	if g:
		g.grow = Vector2(0.05, 0.98)
		g.fade_in = 0.02
		g.fade_out = life * 0.6
		g.set_instance_shader_parameter("width", ring_w)
		g.set_instance_shader_parameter("energy", 2.2)
	return g


## Magiekreis (Runen) unter einem Zaubernden; dreht sich, folgt optional dem Träger.
static func rune(parent: Node, center: Vector3, radius: float, col: Color, life: float, design: String = "a", carrier: Node3D = null, spin: float = 0.6) -> GroundMark:
	var g := spawn(parent, center, Vector2(radius, radius), Mode.RUNE, col, life, randf() * TAU, true, design)
	if g:
		g.spin_speed = spin
		g.follow = carrier
		g.fade_in = 0.25
		g.fade_out = 0.45
		g.set_instance_shader_parameter("energy", 2.4)
	return g


## Schwebender Magiekreis (flache Scheibe, nicht über den Boden gelegt): Bannringe am Körper, Kreise des Superrangs.
## carrier + height: folgt dem Träger in fester Höhe darüber.
static func floating(parent: Node, center: Vector3, radius: float, col: Color, life: float, design: String = "a", carrier: Node3D = null, height: float = 0.0) -> GroundMark:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree() or not CombatFX.enabled:
		return null
	var g := GroundMark.new()
	g.duration = life
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	g.material_override = _material(Mode.RUNE, true, design)
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	g.mesh = pm
	g.follow = carrier
	g.float_height = height if carrier else -1.0
	g.fade_in = 0.25
	g.fade_out = 0.4
	parent.add_child(g)
	g.global_position = center
	g.set_instance_shader_parameter("tint", col)
	g.set_instance_shader_parameter("fade", 0.0)
	g.set_instance_shader_parameter("energy", 2.6)
	return g


## Glutkreis (brennender Boden, Höllenfeuer).
static func ember(parent: Node, center: Vector3, radius: float, col: Color, life: float) -> GroundMark:
	var g := spawn(parent, center, Vector2(radius, radius), Mode.EMBER, col, life, randf() * TAU, true)
	if g:
		g.fade_in = 0.2
		g.fade_out = minf(1.5, life * 0.4)
		g.set_instance_shader_parameter("energy", 2.0)
	return g


## Vorzeitig ausblenden (z. B. Angriff abgebrochen).
func release() -> void:
	if _released:
		return
	_released = true
	duration = minf(duration, _t + fade_out)


func _process(delta: float) -> void:
	_t += delta
	if follow and is_instance_valid(follow):
		if float_height >= 0.0:
			global_position = follow.global_position + Vector3.UP * float_height
		else:
			global_position = Vector3(follow.global_position.x, global_position.y, follow.global_position.z)
	var f := minf(1.0, _t / maxf(fade_in, 0.001))
	if _t > duration - fade_out:
		f = minf(f, maxf(0.0, (duration - _t) / maxf(fade_out, 0.001)))
	set_instance_shader_parameter("fade", f * max_fade)
	if fill_time > 0.0:
		set_instance_shader_parameter("progress", clampf(_t / fill_time, 0.0, 1.0))
	elif grow.x >= 0.0:
		var k := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
		set_instance_shader_parameter("progress", lerpf(grow.x, grow.y, 1.0 - pow(1.0 - k, 2.2)))
	if spin_speed != 0.0:
		set_instance_shader_parameter("spin", _t * spin_speed)
	if _t >= duration:
		queue_free()


static func _material(mode: int, additive: bool, design: String) -> ShaderMaterial:
	var key := "%d|%s|%s" % [mode, additive, design]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(CombatFX.SH + ("fx_ground_add.gdshader" if additive else "fx_ground_mix.gdshader"))
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("noise_tex", CombatFX._texture("fx_noise"))
	if mode == Mode.RUNE:
		m.set_shader_parameter("rune_tex", CombatFX._texture("fx_rune_" + (design if design != "" else "a")))
	m.render_priority = 2
	_mats[key] = m
	return m


## Raster über den Boden legen: je Punkt ein Strahl von oben auf die Welt-Kollision (Ebene 1).
static func _draped(parent: Node3D, center: Vector3, half: Vector2, yaw: float) -> ArrayMesh:
	var cells := clampi(int(ceil(maxf(half.x, half.y) * 1.5)), 6, 20)
	var cx := cells if half.x >= half.y * 0.5 else maxi(3, int(cells * half.x / half.y))
	var cz := cells if half.y >= half.x * 0.5 else maxi(3, int(cells * half.y / half.x))
	var space := parent.get_world_3d().direct_space_state if parent else null
	var b := Basis(Vector3.UP, yaw)
	var hs := PackedFloat32Array()
	hs.resize((cx + 1) * (cz + 1))
	for j in cz + 1:
		for i in cx + 1:
			var lx := (float(i) / cx * 2.0 - 1.0) * half.x
			var lz := (float(j) / cz * 2.0 - 1.0) * half.y
			var w := center + b * Vector3(lx, 0, lz)
			var y := 0.0
			if space:
				var q := PhysicsRayQueryParameters3D.create(w + Vector3(0, 2.2, 0), w - Vector3(0, 3.5, 0), 1)
				var hit := space.intersect_ray(q)
				if hit:
					y = float(hit.position.y) - center.y
			hs[j * (cx + 1) + i] = y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in cz + 1:
		for i in cx + 1:
			st.set_uv(Vector2(float(i) / cx, float(j) / cz))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3((float(i) / cx * 2.0 - 1.0) * half.x, hs[j * (cx + 1) + i] + LIFT, (float(j) / cz * 2.0 - 1.0) * half.y))
	for j in cz:
		for i in cx:
			var a := j * (cx + 1) + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + cx + 2)
			st.add_index(a)
			st.add_index(a + cx + 2)
			st.add_index(a + cx + 1)
	return st.commit()


static func prewarm(parent: Node, at: Vector3) -> void:
	for mode in [Mode.CIRCLE, Mode.CONE, Mode.RECT]:
		spawn(parent, at, Vector2(0.5, 0.5), mode, Color(1, 0.4, 0.1), 0.25)
	for d in ["a", "b", "c"]:
		spawn(parent, at, Vector2(0.5, 0.5), Mode.RUNE, Color(0.6, 0.8, 1.0), 0.25, 0.0, true, d)
	spawn(parent, at, Vector2(0.5, 0.5), Mode.RING, Color(1, 1, 1), 0.25, 0.0, true)
	spawn(parent, at, Vector2(0.5, 0.5), Mode.EMBER, Color(1, 0.4, 0.1), 0.25, 0.0, true)

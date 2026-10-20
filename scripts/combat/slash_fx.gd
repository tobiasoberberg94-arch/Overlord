class_name SlashFX
extends MeshInstance3D
## Hiebspur eines Nahkampfangriffs: ein Bogen genau dort, wo die Trefferzone liegt (Reichweite, Winkel), der in der
## aktiven Phase von einer Seite zur anderen gezogen wird und dann verblasst.
## Arten: h (waagerecht), d1/d2 (schräg), v (von oben), ring (360°), thrust (Stoß), claw (drei Krallenspuren), none.
## Gewählt aus attack.fx.slash bzw. aus Name/Werten des Angriffs; Kombos wechseln die Schwungrichtung.

static var _meshes := {}
static var _mat: ShaderMaterial

var owner_fighter: Fighter
var sweep := 0.16
var life := 0.42
var tail := 0.6
var height := 1.1
var _t := 0.0


static func spawn(f: Fighter, a: Dictionary, col: Color, energy: float = 3.0, combo_index: int = 0) -> SlashFX:
	if f == null or not is_instance_valid(f) or not f.is_inside_tree() or not CombatFX.enabled:
		return null
	var kind := _kind_for(a, combo_index)
	if kind == "none":
		return null
	var reach := float(a.get("range", 2.0))
	var arc := float(a.get("arc", 120.0))
	var s := SlashFX.new()
	s.owner_fighter = f
	s.sweep = clampf(float(a.get("active", 0.15)) * 1.1, 0.08, 0.35)
	s.life = s.sweep + 0.28
	s.height = f.body_height * 0.58
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	s.material_override = _material()
	var tilt := 0.0
	var mirror := combo_index % 2 == 1
	match kind:
		"h":
			s.mesh = _arc(clampf(arc, 70.0, 220.0), reach * 0.3, reach * 1.02)
			tilt = deg_to_rad(randf_range(-6.0, 6.0))
		"d1", "d2":
			s.mesh = _arc(clampf(arc, 70.0, 200.0), reach * 0.3, reach * 1.02)
			tilt = deg_to_rad(32.0 if kind == "d1" else -32.0)
		"v":
			s.mesh = _arc(150.0, reach * 0.25, reach * 1.0)
			tilt = deg_to_rad(90.0 + randf_range(-8.0, 8.0))
			s.height = f.body_height * 0.45
		"ring":
			s.mesh = _arc(360.0, reach * 0.35, reach * 1.0)
			s.sweep = maxf(s.sweep, 0.22)
			s.tail = 0.9
			s.life = s.sweep + 0.3
			s.height = f.body_height * 0.42
		"thrust":
			s.mesh = _thrust(reach * 1.05)
			s.tail = 0.8
		"claw":
			s.mesh = _claw(reach)
			tilt = deg_to_rad(25.0)
	f.get_parent().add_child(s)
	var fwd := f.facing
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var b := Basis.looking_at(fwd, Vector3.UP)
	b = b * Basis(Vector3(0, 0, 1), tilt)
	if mirror:
		b = b * Basis.from_scale(Vector3(-1, 1, 1))
	s.global_transform = Transform3D(b, f.global_position + Vector3.UP * s.height)
	s.set_instance_shader_parameter("tint", col)
	s.set_instance_shader_parameter("energy", energy)
	s.set_instance_shader_parameter("tail", s.tail)
	s.set_instance_shader_parameter("head", 0.0)
	return s


## Art des Schwungs aus den Angriffsdaten.
static func _kind_for(a: Dictionary, combo_index: int) -> String:
	var fx: Variant = a.get("fx", {})
	if fx is Dictionary and fx.has("slash"):
		return String(fx.slash)
	var id := (String(a.get("id", "")) + " " + String(a.get("name", ""))).to_lower()
	var arc := float(a.get("arc", 120.0))
	if arc >= 359.0:
		return "ring"
	for w in ["bite", "biss", "claw", "kralle", "pounce", "sprung"]:
		if id.contains(w):
			return "claw"
	for w in ["thrust", "stich", "stoß", "lunge", "spear", "lance", "dash", "spuit"]:
		if id.contains(w):
			return "thrust"
	for w in ["overhead", "slam", "smash", "schmett", "urteil", "spalt", "cleave", "stomp", "stampf"]:
		if id.contains(w):
			return "v"
	if arc < 70.0:
		return "thrust"
	return ["d1", "h", "d2"][combo_index % 3]


func _process(delta: float) -> void:
	_t += delta
	# während des Schwungs dem Angreifer folgen (Ausfallschritt), danach stehen bleiben
	if _t <= sweep and owner_fighter and is_instance_valid(owner_fighter):
		global_position = owner_fighter.global_position + Vector3.UP * height
	var head := clampf(_t / sweep, 0.0, 1.0) * (1.0 + tail * 0.35) + maxf(0.0, _t - sweep) / maxf(life - sweep, 0.01) * tail
	set_instance_shader_parameter("head", head)
	set_instance_shader_parameter("fade", clampf((life - _t) / 0.12, 0.0, 1.0))
	if _t >= life:
		queue_free()


static func _material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load(CombatFX.SH + "fx_slash.gdshader")
		_mat.set_shader_parameter("noise_tex", CombatFX._texture("fx_noise"))
	return _mat


## Bogenband in der XZ-Ebene um −Z (vorn): UV.x = Verlauf, UV.y = innen (0) … Klingenspitze (1).
static func _arc(arc_deg: float, r_in: float, r_out: float) -> ArrayMesh:
	var key := "a|%d|%.2f|%.2f" % [int(arc_deg), r_in, r_out]
	if _meshes.has(key):
		return _meshes[key]
	var seg := clampi(int(arc_deg / 5.0), 10, 72)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in seg + 1:
		var t := float(i) / seg
		var a := deg_to_rad(-arc_deg * 0.5 + arc_deg * t)
		var d := Vector3(sin(a), 0.0, -cos(a))
		# leichte Wölbung: Klingenspitze etwas tiefer als die Innenkante (wirkt wie ein Schwung, nicht wie eine Scheibe)
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(d * r_in + Vector3(0, 0.06, 0))
		st.set_uv(Vector2(t, 1.0))
		st.add_vertex(d * r_out - Vector3(0, 0.04, 0))
	var m := st.commit()
	_meshes[key] = m
	return m


## Stoß: gerades Band nach vorn mit heller Mittellinie (UV.y 0 → 1 → 0 quer).
static func _thrust(length: float) -> ArrayMesh:
	var key := "t|%.2f" % length
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.22
	var seg := 12
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var z0 := -lerpf(0.35, length, t0)
		var z1 := -lerpf(0.35, length, t1)
		var w0 := w * (1.0 - t0 * 0.7)
		var w1 := w * (1.0 - t1 * 0.7)
		for side in [-1.0, 1.0]:
			var e0 := Vector3(side * w0, 0, z0)
			var e1 := Vector3(side * w1, 0, z1)
			var c0 := Vector3(0, 0, z0)
			var c1 := Vector3(0, 0, z1)
			st.set_uv(Vector2(t0, 0.0)); st.add_vertex(e0)
			st.set_uv(Vector2(t0, 1.0)); st.add_vertex(c0)
			st.set_uv(Vector2(t1, 1.0)); st.add_vertex(c1)
			st.set_uv(Vector2(t0, 0.0)); st.add_vertex(e0)
			st.set_uv(Vector2(t1, 1.0)); st.add_vertex(c1)
			st.set_uv(Vector2(t1, 0.0)); st.add_vertex(e1)
	var m := st.commit()
	_meshes[key] = m
	return m


## Drei kurze, parallele Krallenbögen.
static func _claw(reach: float) -> ArrayMesh:
	var key := "c|%.2f" % reach
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var off := (k - 1) * 0.16
		var seg := 14
		for i in seg:
			var t0 := float(i) / seg
			var t1 := float(i + 1) / seg
			var a0 := deg_to_rad(-40.0 + 80.0 * t0)
			var a1 := deg_to_rad(-40.0 + 80.0 * t1)
			var r := reach * 0.9
			var p0 := Vector3(sin(a0) * r, off, -cos(a0) * r)
			var p1 := Vector3(sin(a1) * r, off, -cos(a1) * r)
			var q0 := p0 * 0.82 + Vector3(0, off * 0.18, 0)
			var q1 := p1 * 0.82 + Vector3(0, off * 0.18, 0)
			st.set_uv(Vector2(t0, 0.3)); st.add_vertex(q0)
			st.set_uv(Vector2(t0, 1.0)); st.add_vertex(p0)
			st.set_uv(Vector2(t1, 1.0)); st.add_vertex(p1)
			st.set_uv(Vector2(t0, 0.3)); st.add_vertex(q0)
			st.set_uv(Vector2(t1, 1.0)); st.add_vertex(p1)
			st.set_uv(Vector2(t1, 0.3)); st.add_vertex(q1)
	var m := st.commit()
	_meshes[key] = m
	return m


static func prewarm(parent: Node, at: Vector3) -> void:
	var s := SlashFX.new()
	s.mesh = _arc(120.0, 0.5, 2.0)
	s.material_override = _material()
	s.life = 0.25
	s.sweep = 0.1
	parent.add_child(s)
	s.global_position = at

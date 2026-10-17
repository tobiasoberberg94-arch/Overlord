class_name LocationBuilder
## Erzeugt die begehbaren Orte aus data/locations.json. Jede „kind“ hat ein eigenes
## Rezept (Thronsaal, Gletscher, Dorf, Stadt, Wald …). Rückgabe: Ankerpunkte für
## Spieler, Wächter, NPCs und Interaktionsobjekte.
##
## Rückgabe-Dictionary:
##   spawn: Vector3, yaw: float, gate: Vector3, board: Vector3 (optional),
##   slots: Array[Vector3] (Plätze für Figuren), keeper: Vector3,
##   throne/table/desk: Vector3 (nur Thronsaal)

const GOLD := Color(0.85, 0.66, 0.22)
const VIOLET := Color(0.55, 0.2, 0.95)

static var _rng := RandomNumberGenerator.new()


static func build(loc: Dictionary, root: Node3D) -> Dictionary:
	_rng.seed = hash(loc.id)
	# Ein komplettes Ortsmodell (assets/models/locations/<id>.glb) ersetzt das Rezept
	var scene := ModelLib.instance("locations", loc.id)
	var a: Dictionary
	if scene:
		a = _from_model(loc, root, scene)
		_gate(root, a.gate)
		return a
	match loc.kind:
		"throne": a = _throne(root)
		"tombs": a = _tombs(root)
		"glacier": a = _glacier(root)
		"jungle": a = _jungle(root)
		"lava": a = _lava(root)
		"royal": a = _royal(root)
		"library": a = _library(root)
		"treasury": a = _treasury(root)
		"village": a = _village(root)
		"city": a = _city(root, loc.get("style", "human"))
		"palace": a = _palace(root)
		"wall": a = _wall(root)
		"cathedral": a = _cathedral(root)
		"forest": a = _forest(root, loc.get("style", ""))
		"swamp": a = _swamp(root)
		"battlefield": a = _battlefield(root)
		"mountain": a = _mountain(root)
		"peaks": a = _peaks(root)
		_: a = _village(root)
	_gate(root, a.gate)
	return a


## Ortsmodell einsetzen. Ankerpunkte über benannte Knoten (Marker3D/Node3D):
##   Spawn, Gate, Throne, Table, Desk, Board, Keeper, Slot1…SlotN
## Fehlende Anker bekommen sinnvolle Standardwerte.
static func _from_model(loc: Dictionary, root: Node3D, scene: Node3D) -> Dictionary:
	root.add_child(scene)
	ModelLib.add_collision(scene)
	# Lichter aus dem Modell (z. B. Lampen eines Unreal-Exports) haben fremde Einheiten:
	# auf spieltaugliche Werte bringen, Schatten nur bei hoher Grafikstufe.
	for l in scene.find_children("*", "OmniLight3D", true, false):
		var omni := l as OmniLight3D
		omni.light_energy = 0.05 if is_forward_plus() else 0.45   # Forward+: SDFGI verteilt das Licht zusätzlich
		omni.omni_range = clampf(omni.omni_range, 3.0, 6.0)
		omni.omni_attenuation = 1.5
		omni.shadow_enabled = false
	for l in scene.find_children("*", "SpotLight3D", true, false):
		(l as SpotLight3D).light_energy = 1.5
		(l as SpotLight3D).shadow_enabled = false
	var named := {}
	for n in scene.find_children("*", "Node3D", true, false):
		named[String(n.name).to_lower()] = n
	var at := func(key: String, fallback: Vector3) -> Vector3:
		return (named[key] as Node3D).global_position if named.has(key) else fallback
	var a := {"spawn": at.call("spawn", Vector3(0, 0.2, 10)), "yaw": 0.0, "gate": at.call("gate", Vector3(0, 0, 14))}
	for k in ["throne", "table", "desk", "board", "keeper"]:
		if named.has(k):
			a[k] = (named[k] as Node3D).global_position
	if loc.group == "world" and not a.has("board"):
		a["board"] = a.spawn + Vector3(3, 0, -4)
	var slots: Array = []
	for i in range(1, 20):
		if named.has("slot%d" % i):
			slots.append((named["slot%d" % i] as Node3D).global_position)
	a["slots"] = slots if not slots.is_empty() else _arc(a.spawn + Vector3(0, 0, -8), 5, 6, 60, 300)
	if named.has("spawn"):
		a["yaw"] = (named["spawn"] as Node3D).global_rotation.y
	if loc.group == "nazarick" and not a.has("keeper"):
		a["keeper"] = a.spawn + Vector3(0, 0, -10)
	_model_dressing(loc, root, named, a)
	B3.bounds(root, 120)
	return a


# =====================================================================
#  Umgebung (Himmel, Nebel, Licht)
# =====================================================================

static func environment(root: Node3D, _loc: Dictionary, preset: Dictionary) -> void:
	var env := Environment.new()
	if preset.get("sky", true):
		# Prozeduraler Himmel (keine gemalten Bilder): Farben je Ort
		var sky := Sky.new()
		var pm := ProceduralSkyMaterial.new()
		var top: Color = preset.get("sky_top", Color(0.18, 0.2, 0.35))
		var hor: Color = preset.get("fog", Color(0.4, 0.4, 0.5)).lerp(Color(0.6, 0.6, 0.65), 0.3)
		pm.sky_top_color = top
		pm.sky_horizon_color = hor
		pm.ground_horizon_color = hor.darkened(0.3)
		pm.ground_bottom_color = hor.darkened(0.7)
		pm.sun_angle_max = 25.0
		pm.energy_multiplier = float(preset.get("sky_energy", 0.8))
		sky.sky_material = pm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = preset.get("bg", Color(0.02, 0.0, 0.04))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.get("ambient", Color(0.35, 0.3, 0.45))
	env.ambient_light_energy = float(preset.get("ambient_energy", 0.6))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(preset.get("exposure", 1.0))
	env.fog_enabled = true
	env.fog_light_color = preset.get("fog", Color(0.08, 0.04, 0.12))
	env.fog_density = float(preset.get("fog_density", 0.02))
	env.fog_sky_affect = float(preset.get("fog_sky", 0.3))
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	if is_forward_plus():
		_forward_plus_env(env, preset)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = preset.get("sun", Color(0.75, 0.7, 0.9))
	sun.light_energy = float(preset.get("sun_energy", 0.6))
	sun.rotation_degrees = preset.get("sun_rot", Vector3(-50, 35, 0))
	sun.shadow_enabled = Settings.particles
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)


static func is_forward_plus() -> bool:
	# Godot 4.3 kennt get_current_rendering_method() noch nicht: Einstellung prüfen und ob
	# wirklich ein RenderingDevice läuft (nicht bei Compatibility-Fallback/headless).
	return ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus" \
		and RenderingServer.get_rendering_device() != null


## Effekte, die nur der Forward+-Renderer kann: globale Beleuchtung (SDFGI),
## Umgebungsverdeckung (SSAO/SSIL), Bildschirmreflexionen und Volumennebel.
## Der Volumennebel übernimmt die Stimmung, der einfache Tiefennebel wird schwächer.
static func _forward_plus_env(env: Environment, preset: Dictionary) -> void:
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = float(preset.get("gi", 0.9))
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(preset.get("fog_density", 0.02)) * float(preset.get("vol_fog", 0.9))
	env.volumetric_fog_albedo = preset.get("fog", Color(0.08, 0.04, 0.12)).lightened(0.4)
	env.volumetric_fog_emission = preset.get("fog", Color(0.08, 0.04, 0.12)) * 0.15
	env.volumetric_fog_gi_inject = 0.8
	env.volumetric_fog_length = 48.0
	env.fog_density *= 0.35
	# Umgebungslicht kommt jetzt teils aus SDFGI – Grundhelligkeit etwas zurücknehmen
	env.ambient_light_energy *= 0.7


## Licht-/Nebelvorgaben je Ortstyp.
static func preset(kind: String) -> Dictionary:
	match kind:
		"throne": return {"sky": false, "bg": Color(0.015, 0.0, 0.03), "ambient": Color(0.5, 0.4, 0.65), "ambient_energy": 0.9, "fog": Color(0.1, 0.03, 0.16), "fog_density": 0.012, "sun_energy": 0.25}
		"tombs": return {"sky": false, "gi": 0.3, "vol_fog": 0.25, "bg": Color(0.01, 0.02, 0.02), "ambient": Color(0.25, 0.35, 0.3), "ambient_energy": 0.45, "fog": Color(0.03, 0.06, 0.05), "fog_density": 0.035, "sun_energy": 0.1}
		"glacier": return {"sky_top": Color(0.05, 0.12, 0.3), "sky_energy": 0.7, "ambient": Color(0.4, 0.5, 0.75), "ambient_energy": 0.45, "exposure": 0.8, "fog": Color(0.35, 0.5, 0.75), "fog_density": 0.02, "sun": Color(0.7, 0.85, 1.0), "sun_energy": 0.8}
		"jungle": return {"sky_top": Color(0.15, 0.35, 0.6), "sky_energy": 0.7, "ambient": Color(0.35, 0.5, 0.35), "ambient_energy": 0.7, "fog": Color(0.08, 0.14, 0.08), "fog_density": 0.022, "sun": Color(0.8, 0.9, 0.7), "sun_energy": 0.9}
		"lava": return {"sky_top": Color(0.15, 0.02, 0.0), "sky_energy": 0.8, "ambient": Color(0.6, 0.25, 0.15), "ambient_energy": 0.7, "fog": Color(0.25, 0.06, 0.02), "fog_density": 0.02, "sun": Color(1.0, 0.5, 0.3), "sun_energy": 0.6}
		"royal": return {"sky": false, "bg": Color(0.03, 0.02, 0.03), "ambient": Color(0.6, 0.5, 0.45), "ambient_energy": 0.7, "fog": Color(0.08, 0.05, 0.06), "fog_density": 0.01, "sun_energy": 0.2}
		"library": return {"sky": false, "bg": Color(0.02, 0.015, 0.01), "ambient": Color(0.55, 0.45, 0.35), "ambient_energy": 0.6, "fog": Color(0.07, 0.05, 0.03), "fog_density": 0.018, "sun_energy": 0.15}
		"treasury": return {"sky": false, "bg": Color(0.03, 0.02, 0.0), "ambient": Color(0.7, 0.55, 0.3), "ambient_energy": 0.7, "fog": Color(0.12, 0.08, 0.02), "fog_density": 0.012, "sun_energy": 0.3}
		"village": return {"sky_top": Color(0.2, 0.42, 0.75), "sky_energy": 1.0, "ambient": Color(0.6, 0.6, 0.55), "ambient_energy": 0.8, "fog": Color(0.55, 0.6, 0.65), "fog_density": 0.008, "sun": Color(1.0, 0.92, 0.8), "sun_energy": 1.2, "sun_rot": Vector3(-40, 50, 0)}
		"city", "palace", "cathedral": return {"sky_top": Color(0.22, 0.4, 0.7), "sky_energy": 1.0, "ambient": Color(0.6, 0.6, 0.65), "ambient_energy": 0.75, "fog": Color(0.5, 0.55, 0.6), "fog_density": 0.007, "sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.1, "sun_rot": Vector3(-45, 30, 0)}
		"wall": return {"sky_top": Color(0.25, 0.35, 0.55), "sky_energy": 0.9, "ambient": Color(0.55, 0.55, 0.6), "ambient_energy": 0.7, "fog": Color(0.45, 0.45, 0.5), "fog_density": 0.01, "sun_energy": 0.9}
		"forest": return {"sky_top": Color(0.08, 0.15, 0.2), "sky_energy": 0.6, "ambient": Color(0.35, 0.4, 0.35), "ambient_energy": 0.6, "fog": Color(0.1, 0.12, 0.1), "fog_density": 0.03, "sun": Color(0.8, 0.85, 0.7), "sun_energy": 0.7}
		"swamp": return {"sky_top": Color(0.12, 0.16, 0.16), "sky_energy": 0.6, "ambient": Color(0.35, 0.4, 0.38), "ambient_energy": 0.6, "fog": Color(0.3, 0.35, 0.33), "fog_density": 0.045, "sun_energy": 0.5}
		"battlefield": return {"sky_top": Color(0.08, 0.04, 0.14), "sky_energy": 0.6, "ambient": Color(0.35, 0.3, 0.4), "ambient_energy": 0.55, "fog": Color(0.25, 0.22, 0.3), "fog_density": 0.04, "sun": Color(0.7, 0.6, 0.8), "sun_energy": 0.5}
		"mountain", "peaks": return {"sky_top": Color(0.15, 0.3, 0.6), "sky_energy": 0.8, "ambient": Color(0.5, 0.55, 0.65), "ambient_energy": 0.5, "exposure": 0.85, "fog": Color(0.6, 0.65, 0.75), "fog_density": 0.012, "sun": Color(0.9, 0.95, 1.0), "sun_energy": 1.0}
	return {}


# =====================================================================
#  Gemeinsame Elemente
# =====================================================================

## Gate-Licht: unter Forward+ verteilt SDFGI es im ganzen Raum – deutlich schwächer.
static func _gate_energy() -> float:
	return 0.6 if is_forward_plus() else 2.0


## Gate: magisches Portal (Teleport zwischen den Orten).
static func _gate(root: Node3D, pos: Vector3) -> void:
	if ModelLib.place_prop(root, "gate_portal", pos):
		B3.light(root, pos + Vector3(0, 2, 1), VIOLET, _gate_energy(), 7.0)
		return
	var g := Node3D.new()
	g.name = "GatePortal"
	g.position = pos
	root.add_child(g)
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.75
	tm.rings = 32
	var ring := B3.mesh(g, tm, Vector3(0, 2.0, 0), B3.mat(Color(0.2, 0.05, 0.3), 0.3, 0.6, VIOLET, 2.5), Vector3(90, 0, 0))
	ring.set_meta("spin", 0.4)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.02
	B3.mesh(g, disc, Vector3(0, 2.0, 0), B3.mat(Color(0.05, 0.0, 0.1, 0.85), 0.0, 0.0, Color(0.25, 0.05, 0.45), 1.5), Vector3(90, 0, 0))
	B3.cyl(g, 1.6, 1.8, 0.2, Vector3(0, 0.1, 0), B3.mat(Color(0.08, 0.06, 0.1), 0.6, 0.3), true, 20)
	B3.light(g, Vector3(0, 2, 1), VIOLET, _gate_energy(), 5.0 if is_forward_plus() else 7.0)
	B3.motes(g, Vector3(0, 2, 0), Vector3(1.2, 1.2, 0.2), Color(0.7, 0.4, 1.0), 30)
	# Leuchtender Ring/Scheibe nicht in die globale Beleuchtung (SDFGI) einspeisen,
	# sonst färbt das Portal ganze Räume violett.
	for mi in g.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED


## Verteilt n Plätze im Halbkreis (für Figuren).
static func _arc(center: Vector3, r: float, n: int, from_deg: float, to_deg: float) -> Array:
	var out: Array = []
	for i in n:
		var t := 0.5 if n == 1 else float(i) / (n - 1)
		var a := deg_to_rad(lerpf(from_deg, to_deg, t))
		out.append(center + Vector3(sin(a) * r, 0, cos(a) * r))
	return out


static func _scatter(n: int, half: float, keep_clear: Array, clear_r: float) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < n * 20:
		tries += 1
		var p := Vector3(_rng.randf_range(-half, half), 0, _rng.randf_range(-half, half))
		var ok := true
		for c in keep_clear:
			if Vector2(p.x - c.x, p.z - c.z).length() < clear_r:
				ok = false
				break
		if ok:
			out.append(p)
	return out


# =====================================================================
#  Nazarick
# =====================================================================

static func _throne(root: Node3D) -> Dictionary:
	var marble := B3.noise_mat(Color(0.05, 0.03, 0.08), Color(0.16, 0.1, 0.22), 0.05, 0.25)
	var stone := B3.noise_mat(Color(0.08, 0.06, 0.1), Color(0.2, 0.16, 0.24), 0.07, 0.6)
	var gold := B3.mat(GOLD, 0.3, 0.9)
	var w := 13.0
	var l := 30.0
	B3.ground(root, 40, marble)
	# Wände, Decke
	B3.box(root, Vector3(1, 16, l * 2), Vector3(-w, 8, 0), stone)
	B3.box(root, Vector3(1, 16, l * 2), Vector3(w, 8, 0), stone)
	B3.box(root, Vector3(w * 2, 16, 1), Vector3(0, 8, -l), stone)
	B3.box(root, Vector3(w * 2, 16, 1), Vector3(0, 8, l), stone)
	B3.box(root, Vector3(w * 2, 1, l * 2), Vector3(0, 16.5, 0), stone, false)
	# Roter Teppich und Säulenreihen mit den 41 Gildenbannern
	B3.box(root, Vector3(4, 0.04, l * 2 - 8), Vector3(0, 0.02, 2), B3.mat(Color(0.45, 0.02, 0.06), 0.9), false)
	B3.box(root, Vector3(4.4, 0.03, l * 2 - 8), Vector3(0, 0.015, 2), gold, false)
	var crest: Texture2D = Palette.icon("faction_nazarick")
	for i in 6:
		var z := -18.0 + i * 8.0
		for s in [-1.0, 1.0]:
			B3.pillar(root, Vector3(7.5 * s, 0, z), 15.5, 0.7, stone, gold)
			B3.banner(root, Vector3((w - 0.6) * s, 14, z + 4), Color(0.2, 0.04, 0.3), crest, 6.0, 90.0 * s)
			B3.crystal(root, Vector3((w - 1.5) * s, 0, z), VIOLET, 2.2)
	# Thronpodest mit Stufen
	var dais_z := -24.0
	B3.box(root, Vector3(12, 1.2, 8), Vector3(0, 0.6, dais_z - 1), marble)
	B3.stairs(root, Vector3(0, 0, dais_z + 4.5), 8, 3, 0.4, 0.6, marble)
	B3.box(root, Vector3(3.2, 1.0, 2.2), Vector3(0, 1.7, dais_z - 1.5), gold)
	B3.box(root, Vector3(3.4, 6.5, 0.6), Vector3(0, 4.4, dais_z - 2.6), gold)
	B3.box(root, Vector3(2.4, 5.5, 0.4), Vector3(0, 4.4, dais_z - 2.2), B3.mat(Color(0.1, 0.02, 0.15), 0.4))
	B3.crystal(root, Vector3(0, 7.6, dais_z - 2.6), Color(0.9, 0.1, 0.25), 1.6)
	for s in [-1.0, 1.0]:
		B3.box(root, Vector3(0.6, 1.8, 2.2), Vector3(1.6 * s, 2.3, dais_z - 1.5), gold)
		B3.brazier(root, Vector3(4.5 * s, 1.2, dais_z + 1))
	B3.light(root, Vector3(0, 9, dais_z), Color(0.8, 0.5, 1.0), 2.5, 16)
	# Riesiges Fenster aus Licht hinter dem Thron
	B3.box(root, Vector3(8, 10, 0.2), Vector3(0, 9, -l + 0.6), B3.mat(Color(0.3, 0.1, 0.5), 0.2, 0.0, Color(0.45, 0.15, 0.8), 1.6), false)
	# Kriegstisch mit der Weltkarte, Albedos Pult (Verwaltung & Wochenziele)
	var table := Vector3(-8.0, 0, 6.0)
	var desk := Vector3(8.0, 0, 6.0)
	_war_table(root, table)
	_desk(root, desk)
	B3.motes(root, Vector3(0, 6, 0), Vector3(10, 5, 25), Color(0.7, 0.5, 1.0), 80)
	B3.bounds(root, 40)
	var slots: Array = []
	for i in 5:
		slots.append(Vector3(-3.5, 0, -16.0 + i * 3.2))
		slots.append(Vector3(3.5, 0, -16.0 + i * 3.2))
	return {"spawn": Vector3(0, 0.2, 14), "yaw": 0.0, "gate": Vector3(0, 0, 25), "slots": slots,
		"throne": Vector3(0, 1.2, dais_z + 1.5), "table": table, "desk": desk, "keeper": Vector3(-2.5, 1.2, dais_z + 0.5)}


## Kriegstisch mit Reliefkarte und Spielfiguren.
static func _war_table(root: Node3D, table: Vector3) -> void:
	B3.box(root, Vector3(3.6, 1.0, 2.4), table + Vector3(0, 0.5, 0), B3.mat(Color(0.12, 0.07, 0.05), 0.6))
	B3.box(root, Vector3(3.3, 0.04, 2.1), table + Vector3(0, 1.02, 0), B3.noise_mat(Color(0.25, 0.32, 0.18), Color(0.45, 0.42, 0.3), 0.5), false)
	for i in 6:
		var p := table + Vector3(_rng.randf_range(-1.4, 1.4), 1.05, _rng.randf_range(-0.85, 0.85))
		B3.cone(root, 0.18, _rng.randf_range(0.15, 0.35), p, B3.mat(Color(0.5, 0.48, 0.45), 0.8))
	for i in 4:
		var p := table + Vector3(_rng.randf_range(-1.3, 1.3), 1.04, _rng.randf_range(-0.8, 0.8))
		B3.cyl(root, 0.05, 0.06, 0.18, p + Vector3(0, 0.09, 0), B3.mat([Color(0.55, 0.25, 0.95), Color(0.85, 0.1, 0.15)][i % 2], 0.4, 0.5), false, 8)
	B3.light(root, table + Vector3(0, 3, 0), Color(1, 0.85, 0.6), 1.5, 6)


## Albedos Pult.
static func _desk(root: Node3D, desk: Vector3) -> void:
	B3.box(root, Vector3(2.4, 1.1, 1.2), desk + Vector3(0, 0.55, 0), B3.mat(Color(0.08, 0.04, 0.1), 0.5))
	B3.box(root, Vector3(2.5, 0.06, 1.3), desk + Vector3(0, 1.12, 0), B3.mat(GOLD, 0.3, 0.9), false)
	B3.sphere(root, 0.18, desk + Vector3(0.7, 1.3, 0), B3.mat(VIOLET, 0.1, 0.0, VIOLET, 3.0))
	B3.light(root, desk + Vector3(0, 2.5, 0), Color(0.9, 0.7, 1.0), 1.2, 5)


## Ausstattung eines Ortsmodells über benannte Anker:
##   Banner_n (Gildenbanner), Fire_n (Feuer), Lamp_n (warmes Licht), Violet_n (violettes Licht)
## Im Thronsaal zusätzlich roter Teppich zum Thron, Kriegstisch (Table) und Pult (Desk).
static func _model_dressing(loc: Dictionary, root: Node3D, named: Dictionary, a: Dictionary) -> void:
	var crest: Texture2D = Palette.icon("faction_nazarick")
	for key in named:
		var n := named[key] as Node3D
		if n is Light3D or n is MeshInstance3D:
			continue   # nur leere Ankerpunkte, keine Lampen/Meshes aus dem Modell (z. B. Lamp_n der Grabkammern)
		var p := n.global_position
		if key.begins_with("banner_"):
			B3.banner(root, p, Color(0.2, 0.04, 0.3), crest, 5.5, -90.0 * signf(p.x))
		elif key.begins_with("fire_"):
			B3.light(root, p + Vector3(0, 0.4, 0), Color(1.0, 0.55, 0.22), 2.2, 9.0).set_meta("flicker", true)
			B3.motes(root, p + Vector3(0, 0.8, 0), Vector3(0.4, 0.6, 0.4), Color(1.0, 0.6, 0.2), 16)
		elif key.begins_with("lamp_"):
			B3.light(root, p, Color(1.0, 0.78, 0.5), 2.6, 14.0)
		elif key.begins_with("violet_"):
			B3.light(root, p, VIOLET, 3.0, 14.0)
	if loc.kind == "throne":
		if a.has("throne"):
			var start: Vector3 = a.gate
			var end: Vector3 = a.throne
			var mid := (start + end) / 2.0
			var length := end.distance_to(start) + 2.0
			var carpet := B3.box(root, Vector3(3.6, 0.04, length), Vector3(mid.x, 0.03, mid.z), B3.mat(Color(0.45, 0.02, 0.06), 0.9), false)
			carpet.rotation.y = atan2(end.x - start.x, end.z - start.z)
			var trim := B3.box(root, Vector3(4.0, 0.03, length), Vector3(mid.x, 0.02, mid.z), B3.mat(GOLD, 0.3, 0.9), false)
			trim.rotation.y = carpet.rotation.y
		if a.has("table"):
			_war_table(root, a.table)
		if a.has("desk"):
			_desk(root, a.desk)
		B3.motes(root, a.spawn + Vector3(0, 5, -20), Vector3(8, 4, 22), Color(0.7, 0.5, 1.0), 70)


## Gemeinsames Gerüst für die Ebenen: Boden, Begrenzung, Wächter-Platz.
static func _floor_base(root: Node3D, ground_mat: Material, half: float = 32.0) -> void:
	B3.ground(root, half, ground_mat)
	B3.bounds(root, half)


static func _tombs(root: Node3D) -> Dictionary:
	var stone := B3.noise_mat(Color(0.07, 0.08, 0.07), Color(0.2, 0.22, 0.2), 0.08, 0.8)
	_floor_base(root, stone)
	var coffin := B3.mat(Color(0.12, 0.08, 0.06), 0.7)
	var wall := B3.noise_mat(Color(0.06, 0.06, 0.06), Color(0.18, 0.18, 0.17), 0.12, 0.9)
	# Labyrinth aus Gruftwänden
	for i in 7:
		var x := -24.0 + i * 8.0
		B3.box(root, Vector3(1.2, 6, 20), Vector3(x, 3, -12 if i % 2 == 0 else 8), wall)
		for j in 3:
			B3.box(root, Vector3(1.0, 0.7, 2.4), Vector3(x + 2.5, 0.35, -16 + j * 10), coffin)
			B3.box(root, Vector3(1.1, 0.12, 2.5), Vector3(x + 2.5, 0.76, -16 + j * 10), B3.mat(Color(0.3, 0.25, 0.2), 0.6), false)
	for p in [Vector3(-20, 0, 0), Vector3(-4, 0, 14), Vector3(12, 0, -4), Vector3(22, 0, 10), Vector3(4, 0, -20)]:
		B3.brazier(root, p, Color(0.3, 1.0, 0.5))
	B3.box(root, Vector3(64, 1, 64), Vector3(0, 9, 0), wall, false)
	B3.motes(root, Vector3(0, 2, 0), Vector3(28, 2, 28), Color(0.4, 1.0, 0.6), 60)
	return {"spawn": Vector3(0, 0.2, 24), "yaw": 0.0, "gate": Vector3(0, 0, 28), "keeper": Vector3(0, 0, 4), "slots": _arc(Vector3(0, 0, 4), 4, 4, 120, 240)}


static func _glacier(root: Node3D) -> Dictionary:
	var ice := B3.noise_mat(Color(0.35, 0.5, 0.7), Color(0.65, 0.78, 0.92), 0.04, 0.15)
	_floor_base(root, ice, 40)
	var spike := B3.mat(Color(0.6, 0.85, 1.0, 0.9), 0.05, 0.1, Color(0.25, 0.5, 0.9), 1.2)
	for p in _scatter(40, 36, [Vector3.ZERO, Vector3(0, 0, 30)], 9.0):
		B3.cone(root, _rng.randf_range(0.6, 1.6), _rng.randf_range(2.5, 9.0), p, spike, true)
	# Cocytus' Eispalast
	B3.box(root, Vector3(14, 10, 8), Vector3(0, 5, -26), B3.mat(Color(0.7, 0.85, 1.0, 0.95), 0.05, 0.1, Color(0.2, 0.45, 0.8), 0.8))
	for s in [-1.0, 1.0]:
		B3.cone(root, 2.0, 16, Vector3(7 * s, 0, -26), spike, true)
	B3.light(root, Vector3(0, 6, -18), Color(0.5, 0.75, 1.0), 3.0, 18)
	B3.motes(root, Vector3(0, 8, 0), Vector3(36, 6, 36), Color(0.9, 0.95, 1.0), 160, 0.6)
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 32), "keeper": Vector3(0, 0, -14), "slots": _arc(Vector3(0, 0, -14), 5, 4, 140, 220)}


static func _jungle(root: Node3D) -> Dictionary:
	var grass := B3.noise_mat(Color(0.08, 0.16, 0.06), Color(0.2, 0.32, 0.12), 0.06, 0.95)
	_floor_base(root, grass, 45)
	var trunk := B3.mat(Color(0.18, 0.12, 0.08))
	var leaves := B3.noise_mat(Color(0.05, 0.2, 0.06), Color(0.15, 0.38, 0.12), 0.2, 0.9)
	# Amphitheater: Ringe aus Stufen
	var stone := B3.noise_mat(Color(0.35, 0.32, 0.28), Color(0.55, 0.5, 0.44), 0.1, 0.8)
	for i in 4:
		var r := 14.0 + i * 1.6
		var tm := TorusMesh.new()
		tm.inner_radius = r
		tm.outer_radius = r + 1.6
		tm.rings = 48
		B3.mesh(root, tm, Vector3(0, 0.4 + i * 0.8, -6), stone, Vector3.ZERO, Vector3(1, 1.0 + i * 0.6, 1))
	B3.ground(root, 12, B3.noise_mat(Color(0.45, 0.38, 0.25), Color(0.6, 0.52, 0.36), 0.15, 0.95), 0.02)
	for p in _scatter(70, 42, [Vector3(0, 0, -6), Vector3(0, 0, 34)], 21.0):
		B3.tree(root, p, _rng.randf_range(7, 14), trunk, leaves)
	B3.motes(root, Vector3(0, 3, 0), Vector3(40, 3, 40), Color(0.8, 1.0, 0.4), 120)
	return {"spawn": Vector3(0, 0.2, 30), "yaw": 0.0, "gate": Vector3(0, 0, 36), "keeper": Vector3(-2, 0, -4), "slots": _arc(Vector3(0, 0, -6), 6, 6, 120, 240)}


static func _lava(root: Node3D) -> Dictionary:
	var rockm := B3.noise_mat(Color(0.06, 0.03, 0.02), Color(0.22, 0.1, 0.06), 0.09, 0.8)
	_floor_base(root, rockm, 40)
	var lava := B3.noise_mat(Color(1.0, 0.3, 0.02), Color(1.0, 0.75, 0.2), 0.08, 1.0, Color(1.0, 0.4, 0.05))
	# Lavaflüsse (leicht abgesenkt, nicht begehbar)
	for z in [-16.0, 6.0]:
		B3.box(root, Vector3(80, 0.1, 5), Vector3(0, 0.03, z), lava, false)
		for s in [-1.0, 1.0]:
			B3.wall_invisible(root, Vector3(38, 4, 5), Vector3(21.2 * s, 2, z))
		B3.light(root, Vector3(-15, 1.5, z), Color(1, 0.4, 0.1), 3.0, 14)
		B3.light(root, Vector3(15, 1.5, z), Color(1, 0.4, 0.1), 3.0, 14)
		# Brücke
		B3.box(root, Vector3(4, 0.4, 7), Vector3(0, 0.2, z), B3.mat(Color(0.15, 0.08, 0.05), 0.7))
		for s in [-1.0, 1.0]:
			B3.box(root, Vector3(0.3, 1.0, 7), Vector3(2 * s, 0.7, z), B3.mat(Color(0.15, 0.08, 0.05), 0.7))
	# Teufelspalast
	var dark := B3.mat(Color(0.12, 0.04, 0.04), 0.6, 0.2)
	B3.box(root, Vector3(16, 9, 8), Vector3(0, 4.5, -28), dark)
	for s in [-1.0, 0.0, 1.0]:
		B3.cone(root, 1.6, 14 if s == 0.0 else 10, Vector3(6 * s, 9, -28), dark)
	for p in _scatter(18, 36, [Vector3(0, 0, -16), Vector3(0, 0, 6), Vector3(0, 0, 30), Vector3(0, 0, -28)], 7.0):
		B3.cone(root, _rng.randf_range(1, 2.5), _rng.randf_range(3, 8), p, rockm, true)
	B3.motes(root, Vector3(0, 4, 0), Vector3(36, 4, 36), Color(1.0, 0.45, 0.1), 140)
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 32), "keeper": Vector3(0, 0, -20), "slots": _arc(Vector3(0, 0, -20), 5, 4, 130, 230)}


static func _royal(root: Node3D) -> Dictionary:
	var marble := B3.noise_mat(Color(0.75, 0.7, 0.62), Color(0.95, 0.92, 0.85), 0.05, 0.2)
	var wall := B3.noise_mat(Color(0.18, 0.08, 0.1), Color(0.3, 0.14, 0.16), 0.1, 0.6)
	var gold := B3.mat(GOLD, 0.3, 0.9)
	_floor_base(root, marble, 22)
	for s in [-1.0, 1.0]:
		B3.box(root, Vector3(1, 10, 44), Vector3(21 * s, 5, 0), wall)
		B3.box(root, Vector3(44, 10, 1), Vector3(0, 5, 21 * s), wall)
	B3.box(root, Vector3(44, 1, 44), Vector3(0, 10.5, 0), wall, false)
	B3.box(root, Vector3(10, 0.03, 30), Vector3(0, 0.02, 0), B3.mat(Color(0.35, 0.05, 0.12), 0.95), false)
	# Kronleuchter
	for z in [-10.0, 0.0, 10.0]:
		B3.cyl(root, 1.2, 0.5, 0.6, Vector3(0, 8.5, z), gold, false)
		B3.light(root, Vector3(0, 7.8, z), Color(1, 0.85, 0.6), 2.5, 14)
		B3.sphere(root, 0.25, Vector3(0, 8.0, z), B3.mat(Color(1, 0.9, 0.7), 1, 0, Color(1, 0.85, 0.5), 4))
	# Sitzgruppen, Bar, Bad
	for p in [Vector3(-12, 0, -10), Vector3(12, 0, -10), Vector3(-12, 0, 8)]:
		B3.box(root, Vector3(3, 0.6, 1.2), p + Vector3(0, 0.3, 0), B3.mat(Color(0.35, 0.08, 0.15), 0.9))
		B3.box(root, Vector3(1.6, 0.8, 1.6), p + Vector3(0, 0.4, 2.2), gold)
	B3.box(root, Vector3(8, 1.2, 1.2), Vector3(12, 0.6, 10), B3.mat(Color(0.2, 0.1, 0.06), 0.4))
	B3.box(root, Vector3(6, 0.2, 6), Vector3(-12, 0.05, -2), B3.mat(Color(0.3, 0.6, 0.9, 0.8), 0.05, 0.0, Color(0.1, 0.3, 0.5), 0.6), false)
	return {"spawn": Vector3(0, 0.2, 14), "yaw": 0.0, "gate": Vector3(0, 0, 18), "keeper": Vector3(0, 0, -12), "slots": _arc(Vector3(0, 0, -6), 6, 4, 130, 230)}


static func _library(root: Node3D) -> Dictionary:
	var wood := B3.noise_mat(Color(0.16, 0.09, 0.05), Color(0.3, 0.18, 0.09), 0.2, 0.7)
	var floor_m := B3.noise_mat(Color(0.1, 0.07, 0.05), Color(0.2, 0.14, 0.09), 0.08, 0.5)
	_floor_base(root, floor_m, 26)
	var books := [Color(0.5, 0.1, 0.1), Color(0.1, 0.2, 0.45), Color(0.15, 0.35, 0.15), Color(0.45, 0.35, 0.1), Color(0.3, 0.1, 0.35)]
	for row in 6:
		for s in [-1.0, 1.0]:
			var x: float = s * (5.0 + row * 3.4)
			B3.box(root, Vector3(1.0, 7, 30), Vector3(x, 3.5, -2), wood)
			for k in 5:
				B3.box(root, Vector3(1.05, 0.9, 28), Vector3(x, 0.8 + k * 1.3, -2), B3.mat(books[(row + k) % books.size()], 0.8), false)
	for z in [-12.0, 0.0, 12.0]:
		B3.sphere(root, 0.3, Vector3(0, 4, z), B3.mat(Color(1, 0.9, 0.6), 1, 0, Color(1, 0.8, 0.4), 4))
		B3.light(root, Vector3(0, 4, z), Color(1, 0.8, 0.5), 2.0, 12)
	B3.motes(root, Vector3(0, 3, 0), Vector3(20, 3, 20), Color(1.0, 0.85, 0.5), 80)
	return {"spawn": Vector3(0, 0.2, 18), "yaw": 0.0, "gate": Vector3(0, 0, 22), "keeper": Vector3(0, 0, -14), "slots": _arc(Vector3(0, 0, -10), 3, 3, 150, 210)}


static func _treasury(root: Node3D) -> Dictionary:
	var floor_m := B3.noise_mat(Color(0.2, 0.15, 0.05), Color(0.45, 0.35, 0.1), 0.08, 0.4)
	_floor_base(root, floor_m, 26)
	var gold := B3.mat(GOLD, 0.25, 1.0)
	for p in _scatter(26, 22, [Vector3.ZERO, Vector3(0, 0, 20)], 7.0):
		var s := _rng.randf_range(1.5, 4.0)
		B3.sphere(root, s, p, gold, Vector3(1.4, 0.45, 1.2), true)
	for p in _scatter(12, 18, [Vector3.ZERO, Vector3(0, 0, 20)], 6.0):
		B3.box(root, Vector3(1.4, 0.9, 0.9), p + Vector3(0, 0.45, 0), B3.mat(Color(0.25, 0.12, 0.05), 0.6))
		B3.crystal(root, p + Vector3(0, 0.9, 0), [VIOLET, Color(1, 0.2, 0.3), Color(0.2, 0.6, 1)][_rng.randi() % 3], 0.8)
	B3.light(root, Vector3(0, 8, 0), Color(1, 0.85, 0.5), 3.0, 30)
	B3.motes(root, Vector3(0, 3, 0), Vector3(20, 3, 20), Color(1.0, 0.85, 0.3), 120)
	return {"spawn": Vector3(0, 0.2, 16), "yaw": 0.0, "gate": Vector3(0, 0, 21), "keeper": Vector3(0, 0, -3), "slots": _arc(Vector3(0, 0, -3), 3, 3, 150, 210)}


# =====================================================================
#  Die Neue Welt
# =====================================================================

static func _village(root: Node3D) -> Dictionary:
	var grass := B3.noise_mat(Color(0.2, 0.3, 0.1), Color(0.35, 0.45, 0.18), 0.05, 0.95)
	B3.ground(root, 50, grass)
	B3.bounds(root, 48)
	B3.box(root, Vector3(4, 0.04, 90), Vector3(0, 0.02, 0), B3.noise_mat(Color(0.35, 0.27, 0.16), Color(0.5, 0.4, 0.25), 0.2, 1.0), false)
	var wall := B3.noise_mat(Color(0.55, 0.45, 0.32), Color(0.7, 0.6, 0.45), 0.2, 0.9)
	var roof := B3.noise_mat(Color(0.45, 0.35, 0.15), Color(0.6, 0.5, 0.25), 0.3, 1.0)
	var spots := [Vector3(-8, 0, -6), Vector3(8, 0, -10), Vector3(-9, 0, 8), Vector3(9, 0, 6), Vector3(-16, 0, -16), Vector3(16, 0, -2), Vector3(-7, 0, -22), Vector3(10, 0, -24)]
	for p in spots:
		B3.house(root, p, Vector3(5, 3, 4), wall, roof, 90.0 if p.x < 0 else -90.0)
	var trunk := B3.mat(Color(0.25, 0.17, 0.1))
	var leaves := B3.noise_mat(Color(0.12, 0.3, 0.1), Color(0.25, 0.45, 0.15), 0.2)
	for p in _scatter(40, 46, [Vector3.ZERO, Vector3(0, 0, 30)], 26.0):
		B3.tree(root, p, _rng.randf_range(6, 11), trunk, leaves)
	# Palisade und Wachturm
	for i in 24:
		B3.cyl(root, 0.18, 0.2, 2.6, Vector3(-24 + i * 2.0, 1.3, -30), trunk, true, 6)
	B3.box(root, Vector3(2.4, 6, 2.4), Vector3(18, 3, -28), B3.mat(Color(0.3, 0.2, 0.12)))
	# Brunnen (Dorfplatz)
	B3.cyl(root, 1.2, 1.3, 0.9, Vector3(0, 0.45, -2), B3.noise_mat(Color(0.4, 0.4, 0.4), Color(0.6, 0.6, 0.6), 0.3), true)
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 33), "board": Vector3(3.5, 0, 2), "slots": _arc(Vector3(0, 0, -2), 5, 6, 60, 300)}


static func _city(root: Node3D, _style: String) -> Dictionary:
	var paving := B3.noise_mat(Color(0.32, 0.3, 0.28), Color(0.5, 0.48, 0.45), 0.25, 0.9)
	B3.ground(root, 60, B3.noise_mat(Color(0.22, 0.3, 0.14), Color(0.32, 0.4, 0.2), 0.05))
	B3.ground(root, 30, paving, 0.01)
	B3.bounds(root, 58)
	var stone := B3.noise_mat(Color(0.45, 0.43, 0.4), Color(0.62, 0.6, 0.56), 0.1, 0.9)
	var roof := B3.noise_mat(Color(0.25, 0.1, 0.08), Color(0.4, 0.18, 0.12), 0.3)
	B3.city_wall(root, 30, 9, stone, B3.mat(Color(0.2, 0.22, 0.35), 0.7))
	var wall_m := B3.noise_mat(Color(0.6, 0.55, 0.45), Color(0.78, 0.72, 0.6), 0.2)
	var crest: Texture2D = Palette.icon("faction_kingdom")
	for gx in range(-3, 4):
		for gz in range(-3, 3):
			if absi(gx) <= 1 and gz >= -1:
				continue  # Marktplatz und Hauptstraße frei
			var p := Vector3(gx * 7.5, 0, gz * 7.5 - 4)
			B3.house(root, p, Vector3(5, _rng.randf_range(4, 8), 5), wall_m, roof, [0.0, 90.0, 180.0][_rng.randi() % 3])
	# Rathaus/Gilde am Platz
	B3.box(root, Vector3(10, 9, 6), Vector3(0, 4.5, -18), stone)
	B3.prism(root, Vector3(11, 4, 7), Vector3(0, 11, -18), roof)
	B3.tower(root, Vector3(0, 0, -22), 2.0, 16, stone, roof)
	for s in [-1.0, 1.0]:
		B3.banner(root, Vector3(3.5 * s, 8, -14.9), Color(0.15, 0.2, 0.45), crest, 4.0)
	B3.cyl(root, 2.0, 2.2, 1.0, Vector3(0, 0.5, -3), stone, true)
	B3.sphere(root, 0.6, Vector3(0, 2.0, -3), B3.mat(Color(0.5, 0.7, 1.0), 0.1, 0.0, Color(0.3, 0.5, 0.9), 1.5))
	B3.brazier(root, Vector3(-5, 0, 6))
	B3.brazier(root, Vector3(5, 0, 6))
	return {"spawn": Vector3(0, 0.2, 40), "yaw": 0.0, "gate": Vector3(0, 0, 46), "board": Vector3(4, 0, -9), "slots": _arc(Vector3(0, 0, -3), 6, 6, 60, 300)}


static func _palace(root: Node3D) -> Dictionary:
	var a := _city(root, "empire")
	var marble := B3.noise_mat(Color(0.75, 0.72, 0.68), Color(0.92, 0.9, 0.86), 0.08, 0.4)
	var roof := B3.mat(Color(0.7, 0.25, 0.1), 0.6)
	B3.box(root, Vector3(22, 12, 8), Vector3(0, 6, -26), marble)
	B3.cyl(root, 4, 4, 6, Vector3(0, 15, -26), marble, false, 20)
	B3.sphere(root, 4.2, Vector3(0, 18, -26), B3.mat(GOLD, 0.3, 0.9), Vector3(1, 0.7, 1))
	for s in [-1.0, 1.0]:
		B3.tower(root, Vector3(11 * s, 0, -26), 2.2, 18, marble, roof)
		B3.banner(root, Vector3(5 * s, 11, -21.9), Color(0.55, 0.08, 0.06), null, 6.0)
	return a


static func _wall(root: Node3D) -> Dictionary:
	var grass := B3.noise_mat(Color(0.35, 0.33, 0.2), Color(0.5, 0.46, 0.3), 0.05)
	B3.ground(root, 55, grass)
	B3.bounds(root, 53)
	var stone := B3.noise_mat(Color(0.65, 0.63, 0.58), Color(0.82, 0.8, 0.75), 0.1, 0.9)
	B3.box(root, Vector3(110, 18, 5), Vector3(0, 9, -30), stone)
	for x in range(-50, 51, 12):
		B3.tower(root, Vector3(x, 0, -30), 3, 23, stone, B3.mat(Color(0.25, 0.3, 0.55), 0.7))
	# Feldlager mit Zelten
	var cloth := B3.mat(Color(0.85, 0.82, 0.75), 0.95)
	for p in _scatter(14, 30, [Vector3.ZERO, Vector3(0, 0, 30)], 9.0):
		if p.z < -24:
			continue
		B3.prism(root, Vector3(4, 2.6, 4), p + Vector3(0, 1.3, 0), cloth, Vector3(0, _rng.randf_range(0, 90), 0))
	for p in [Vector3(-6, 0, 0), Vector3(6, 0, 4), Vector3(0, 0, -10)]:
		B3.brazier(root, p)
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 35), "board": Vector3(4, 0, -4), "slots": _arc(Vector3(0, 0, -4), 6, 5, 70, 290)}


static func _cathedral(root: Node3D) -> Dictionary:
	var a := _city(root, "holy")
	var white := B3.noise_mat(Color(0.88, 0.88, 0.85), Color(1, 1, 0.97), 0.1, 0.5)
	B3.box(root, Vector3(14, 16, 12), Vector3(0, 8, -24), white)
	B3.prism(root, Vector3(15, 7, 13), Vector3(0, 19.5, -24), B3.mat(Color(0.8, 0.7, 0.4), 0.4, 0.6))
	for s in [-1.0, 1.0]:
		B3.tower(root, Vector3(8 * s, 0, -19), 2.5, 26, white, B3.mat(GOLD, 0.3, 0.9))
	B3.box(root, Vector3(4, 6, 0.2), Vector3(0, 9, -17.9), B3.mat(Color(1, 0.95, 0.7), 1, 0, Color(1, 0.9, 0.5), 2.0), false)
	return a


static func _forest(root: Node3D, style: String) -> Dictionary:
	var elf := style == "elf"
	var moss := B3.noise_mat(Color(0.06, 0.12, 0.05), Color(0.16, 0.24, 0.1), 0.07)
	B3.ground(root, 50, moss)
	B3.bounds(root, 48)
	var trunk := B3.noise_mat(Color(0.12, 0.08, 0.06), Color(0.24, 0.17, 0.12), 0.3)
	var leaves := B3.noise_mat(Color(0.04, 0.14, 0.05), Color(0.1, 0.28, 0.1), 0.25)
	if elf:
		leaves = B3.noise_mat(Color(0.05, 0.2, 0.12), Color(0.2, 0.45, 0.3), 0.25, 0.9, Color(0.05, 0.2, 0.1))
	for p in _scatter(90 if not elf else 50, 46, [Vector3.ZERO, Vector3(0, 0, 30), Vector3(0, 0, 15)], 7.0):
		B3.tree(root, p, _rng.randf_range(9, 16) * (1.8 if elf else 1.0), trunk, leaves, not elf and _rng.randf() < 0.4)
	if elf:
		# Baumpalast: riesiger Stamm mit leuchtenden Plattformen
		B3.cyl(root, 3, 4, 40, Vector3(0, 20, -24), trunk, true, 16)
		for i in 3:
			B3.cyl(root, 7 - i, 7 - i, 0.4, Vector3(0, 8 + i * 9, -24), B3.mat(Color(0.3, 0.22, 0.12)), false, 20)
			B3.light(root, Vector3(0, 9 + i * 9, -20), Color(0.5, 1.0, 0.6), 2.0, 12)
		B3.motes(root, Vector3(0, 4, 0), Vector3(40, 4, 40), Color(0.6, 1.0, 0.7), 140)
	else:
		B3.motes(root, Vector3(0, 2, 0), Vector3(40, 2, 40), Color(0.9, 1.0, 0.5), 60)
	for p in _scatter(16, 40, [Vector3.ZERO, Vector3(0, 0, 30)], 8.0):
		B3.rock(root, p, _rng.randf_range(0.6, 1.5), B3.noise_mat(Color(0.25, 0.27, 0.25), Color(0.4, 0.42, 0.38), 0.3))
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 34), "board": Vector3(4, 0, 2), "slots": _arc(Vector3.ZERO, 5, 5, 60, 300)}


static func _swamp(root: Node3D) -> Dictionary:
	var mud := B3.noise_mat(Color(0.12, 0.13, 0.08), Color(0.25, 0.26, 0.15), 0.08)
	B3.ground(root, 48, mud)
	B3.bounds(root, 46)
	var water := B3.mat(Color(0.12, 0.2, 0.18, 0.8), 0.05, 0.1)
	for p in _scatter(10, 38, [Vector3.ZERO, Vector3(0, 0, 30)], 12.0):
		B3.cyl(root, _rng.randf_range(4, 9), _rng.randf_range(4, 9), 0.05, p + Vector3(0, 0.04, 0), water, false, 20)
	var reed := B3.mat(Color(0.35, 0.4, 0.2))
	for p in _scatter(80, 44, [Vector3.ZERO], 5.0):
		B3.cyl(root, 0.02, 0.05, _rng.randf_range(1.2, 2.4), p + Vector3(0, 0.9, 0), reed, false, 4)
	# Pfahlhütten der Echsenmenschen
	var wood := B3.mat(Color(0.3, 0.22, 0.12))
	for p in [Vector3(-10, 0, -8), Vector3(10, 0, -12), Vector3(-4, 0, -20), Vector3(14, 0, 4)]:
		for c in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			B3.cyl(root, 0.15, 0.15, 2, p + c + Vector3(0, 1, 0), wood, true, 6)
		B3.box(root, Vector3(4, 0.3, 4), p + Vector3(0, 2.1, 0), wood, false)
		B3.cone(root, 3, 2.5, p + Vector3(0, 2.2, 0), B3.mat(Color(0.5, 0.45, 0.25)))
	var trunk := B3.mat(Color(0.15, 0.12, 0.08))
	for p in _scatter(20, 44, [Vector3.ZERO, Vector3(0, 0, 30)], 10.0):
		B3.tree(root, p, _rng.randf_range(6, 10), trunk, B3.noise_mat(Color(0.15, 0.2, 0.1), Color(0.25, 0.3, 0.15), 0.2))
	return {"spawn": Vector3(0, 0.2, 26), "yaw": 0.0, "gate": Vector3(0, 0, 32), "board": Vector3(3, 0, 0), "slots": _arc(Vector3.ZERO, 5, 5, 60, 300)}


static func _battlefield(root: Node3D) -> Dictionary:
	var dirt := B3.noise_mat(Color(0.12, 0.1, 0.1), Color(0.26, 0.22, 0.2), 0.06)
	B3.ground(root, 55, dirt)
	B3.bounds(root, 53)
	var stone := B3.noise_mat(Color(0.2, 0.18, 0.2), Color(0.35, 0.32, 0.34), 0.15)
	# Ruinen
	for p in _scatter(14, 45, [Vector3.ZERO, Vector3(0, 0, 32)], 10.0):
		var h := _rng.randf_range(2, 8)
		B3.box(root, Vector3(_rng.randf_range(2, 6), h, 1.2), p + Vector3(0, h / 2.0, 0), stone, true, Vector3(0, _rng.randf_range(0, 180), 0))
	# Gräber, Knochen, zerbrochene Waffen
	var bone := B3.mat(Color(0.8, 0.78, 0.7))
	for p in _scatter(40, 45, [Vector3(0, 0, 32)], 4.0):
		B3.box(root, Vector3(0.12, 1.4, 0.12), p + Vector3(0, 0.7, 0), B3.mat(Color(0.35, 0.33, 0.33), 0.4, 0.8), false, Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20)))
		B3.sphere(root, 0.18, p + Vector3(0.5, 0.15, 0.3), bone)
	B3.motes(root, Vector3(0, 1.5, 0), Vector3(50, 1.5, 50), Color(0.6, 0.5, 0.8), 120)
	for p in [Vector3(-12, 0, -8), Vector3(10, 0, -16), Vector3(16, 0, 10)]:
		B3.brazier(root, p, Color(0.6, 0.3, 1.0))
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 34), "board": Vector3(4, 0, 0), "slots": _arc(Vector3(0, 0, -2), 6, 6, 60, 300)}


static func _mountain(root: Node3D) -> Dictionary:
	var snow := B3.noise_mat(Color(0.55, 0.58, 0.64), Color(0.82, 0.85, 0.9), 0.05, 0.6)
	B3.ground(root, 55, snow)
	B3.bounds(root, 50)
	var rockm := B3.noise_mat(Color(0.3, 0.3, 0.33), Color(0.5, 0.5, 0.52), 0.12)
	for p in _scatter(16, 52, [Vector3.ZERO, Vector3(0, 0, 30), Vector3(0, 0, -26)], 18.0):
		B3.cone(root, _rng.randf_range(8, 16), _rng.randf_range(18, 35), p, rockm, true)
	# Zwergentor im Fels mit glühenden Runen
	B3.box(root, Vector3(30, 22, 10), Vector3(0, 11, -32), rockm)
	B3.box(root, Vector3(8, 10, 1), Vector3(0, 5, -26.6), B3.mat(Color(0.2, 0.2, 0.22), 0.4, 0.8))
	for i in 5:
		B3.box(root, Vector3(0.6, 0.9, 0.1), Vector3(-3 + i * 1.5, 8, -26.0), B3.mat(Color(0.3, 0.8, 1.0), 1, 0, Color(0.3, 0.8, 1.0), 4), false)
	for s in [-1.0, 1.0]:
		B3.brazier(root, Vector3(6 * s, 0, -24), Color(1.0, 0.6, 0.2))
	B3.motes(root, Vector3(0, 8, 0), Vector3(45, 6, 45), Color(1, 1, 1), 180, 0.8)
	return {"spawn": Vector3(0, 0.2, 28), "yaw": 0.0, "gate": Vector3(0, 0, 34), "board": Vector3(4, 0, -16), "slots": _arc(Vector3(0, 0, -16), 6, 5, 70, 290)}


static func _peaks(root: Node3D) -> Dictionary:
	var a := _mountain(root)
	# Drachenhort: gewaltige Klauenfelsen und ein Ring aus Platin
	var plat := B3.mat(Color(0.85, 0.9, 0.95), 0.2, 1.0)
	for i in 8:
		var ang := TAU * i / 8.0
		B3.cone(root, 1.2, 9, Vector3(cos(ang) * 11, 0, sin(ang) * 11 - 6), plat, true)
	B3.light(root, Vector3(0, 6, -6), Color(0.7, 0.85, 1.0), 3.0, 20)
	return a

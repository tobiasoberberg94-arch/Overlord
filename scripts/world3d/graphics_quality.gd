class_name GraphicsQuality
## Grafikstufen (Einstellungen → Grafik), gemessen mit `LOC=bench` (tools/world3d_test.gd; RTX 3060 Ti, 3440×1440, FSR 2):
## „Hoch“ (Standard): weiche PCSS-Schatten mit halb so vielen Abtastungen, globale Beleuchtung in halber Auflösung,
## SDFGI mit 8 Strahlen, Spiegelungen mit 32 Schritten, SSIL und Volumennebel etwas gröber, in Wäldern SDFGI mit
## 3 Kaskaden – im Bild wie Ultra, 3–4 ms schneller. „Ultra“: alles in voller Qualität (das Bild bis Version 2.3).
## „Ausgewogen“ (60 FPS auch in Wäldern): gefilterte PCF-Schatten, keine Spiegelungen in der Natur, Schattenkarte 2048
## und kürzere Schatten, Gras und Bäume wechseln etwas früher in ihre fernen Detailstufen.
## Keine Stufe reduziert die Dreiecke der Modelle – nur die Entfernungen der vorhandenen Detailstufen.

const NAMES := ["Ausgewogen", "Hoch (empfohlen)", "Ultra"]
const NATURE := ["forest", "jungle", "grassland", "battlefield", "mountain", "peaks", "swamp"]
const WOODS := ["forest", "jungle", "swamp"]   ## dichtes Laub: GI mit 3 Kaskaden (gemessen −0,5 ms im Wald von Tob)

static var _applied := -1


static func level() -> int:
	return clampi(int(Settings.graphics), 0, NAMES.size() - 1)


## Renderer-weite Einstellungen – beim Start und bei jeder Änderung der Einstellungen.
static func apply_global() -> void:
	var l := level()
	if l == _applied or RenderingServer.get_rendering_device() == null:
		return
	_applied = l
	RenderingServer.gi_set_use_half_resolution(l < 2)
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_16 if l == 2 else RenderingServer.ENV_SDFGI_RAY_COUNT_8)
	RenderingServer.environment_set_sdfgi_frames_to_update_light(RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES if l == 2 else RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM if l == 2 else RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4 if l == 2 else 2, 50.0, 300.0)
	var fog := 64 if l == 2 else 48
	RenderingServer.environment_set_volumetric_fog_volume_size(fog, fog)
	# Weiche Schatten (PCSS, Penumbra wächst mit dem Abstand zum Schattenwerfer): Ultra mit 8+8 Abtastungen, Hoch mit
	# 4+4 (zeitlich geglättet, im Bild gleich; −2 ms gegenüber Ultra). Ausgewogen filtert per PCF (gleichmäßig weich).
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW if l == 1 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	# Ausgewogen: Schattenkarte 2048 (−1,1 ms im Wald), Gras und Bäume dünnen etwas früher aus
	RenderingServer.directional_shadow_atlas_set_size(2048 if l == 0 else 4096, true)
	GrassField.range_scale = 0.8 if l == 0 else 1.0
	FoliageLod.range_scale = 0.8 if l == 0 else 1.0
	retune_all()


## Je Ort: Sonne und Umgebung nach Stufe abstimmen – nach dem Aufbau und nach jedem neuen Himmel (HdriSky.apply
## setzt den Sonnenwinkel neu; `fresh` merkt ihn sich als PCSS-Vorgabe für „Ultra“).
static func tune(env: Environment, sun: DirectionalLight3D, kind: String = "", fresh: bool = true) -> void:
	if env == null or sun == null:
		return
	if fresh or not sun.has_meta("pcss"):
		sun.set_meta("pcss", sun.light_angular_distance)
	if not sun.has_meta("gq_env"):
		sun.set_meta("gq_env", env)
		sun.set_meta("shadow_dist", sun.directional_shadow_max_distance)
		sun.add_to_group(&"gq_sun")
		env.set_meta("ssr", env.ssr_enabled)
		env.set_meta("kind", kind)
		env.set_meta("sdfgi", [env.sdfgi_cascades, env.sdfgi_min_cell_size])
	kind = String(env.get_meta("kind", kind))
	var l := level()
	var ad: float = sun.get_meta("pcss")
	# Weiche Schatten: Ultra und Hoch mit PCSS (Kontakthärtung), Ausgewogen mit gefiltertem PCF ähnlicher Weichheit
	if l >= 1:
		sun.light_angular_distance = ad
		sun.shadow_blur = 1.5
	else:
		sun.light_angular_distance = 0.0
		sun.shadow_blur = clampf(1.3 + ad * 0.8, 1.6, 3.6)
	env.ssr_max_steps = 48 if l == 2 else 32
	env.ssr_enabled = bool(env.get_meta("ssr")) and not (l == 0 and kind in NATURE)
	sun.directional_shadow_max_distance = float(sun.get_meta("shadow_dist")) * (0.75 if l == 0 else 1.0)
	var sd: Array = env.get_meta("sdfgi")
	var woods := l < 2 and kind in WOODS
	var cascades := 3 if woods else int(sd[0])
	var cell := maxf(float(sd[1]), 0.2) if woods else float(sd[1])
	if env.sdfgi_cascades != cascades or not is_equal_approx(env.sdfgi_min_cell_size, cell):
		env.sdfgi_cascades = cascades
		env.sdfgi_min_cell_size = cell


## Nach einer Änderung in den Einstellungen: alle geladenen Orte (Sonnen) neu abstimmen.
static func retune_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"gq_sun"):
		var sun := n as DirectionalLight3D
		if sun and sun.has_meta("gq_env") and sun.get_meta("gq_env") is Environment:
			tune(sun.get_meta("gq_env"), sun, "", false)

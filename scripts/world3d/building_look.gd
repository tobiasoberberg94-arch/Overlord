class_name BuildingLook
## Bauwerke realistisch (assets/shaders/building.gdshader): die Standardmaterialien der Ortsmodelle bekommen
## Fotostruktur (Poly Haven, CC0), Märchendächer werden zu Schiefer/Ziegel, Platzhalterflächen aus dem Export
## (ohne Textur) zu Fotomauerwerk, dazu Verwitterung je Ortsart: Sockelschmutz (Geländehöhe als globale Karte),
## Regenspuren, Moos, Flechten, Staub.

const SHADER := preload("res://assets/shaders/building.gdshader")

## Fotostrukturen: [Ordner, Name, Meter je Wiederholung]
const PHOTOS := {
	"grain": ["terrain", "rock_face", 1.9],          # Steinkörnung ohne Fugen (Detail auf Originalstein)
	"plaster": ["build", "worn_plaster_wall", 2.8],
	"wood": ["build", "rough_wood", 1.5],
	"metal": ["build", "rusty_metal_02", 1.3],
	"slates": ["build", "castle_wall_slates", 2.6],
	"ashlar": ["build", "rustic_stone_wall", 3.0],
	"rubble": ["build", "stone_wall", 2.8],
	"limestone": ["build", "marble_01", 3.2],
	"sandstone": ["build", "sandstone_blocks_04", 3.2],
	"brick": ["build", "castle_brick_07", 2.4],
	"flagstone": ["build", "monastery_stone_floor", 3.4],
	"roof_slate": ["build", "roof_slates_02", 2.4],
	"roof_clay": ["build", "clay_roof_tiles_02", 2.4],
	"planks": ["build", "old_planks_02", 2.4],
	"stucco": ["build", "plastered_wall_02", 3.2],
	"sand": ["build", "park_sand", 3.0],
	"thatch": ["build", "thatch_roof_angled", 2.2],
	"blocks": ["build", "medieval_blocks_02", 3.0],
	"bark": ["build", "jolcham_oak_bark_01", 2.4],
	"basalt": ["terrain", "dark_rock_02", 3.4],
	"cliff": ["terrain", "rock_face_03", 3.0],
	"logs": ["build", "medieval_wood", 1.8],
	"mossrock": ["terrain", "mossy_rock", 2.6],
	"snow": ["terrain", "snow_02", 3.0],
	"hay": ["terrain", "withered_grass", 1.4],
}

## Je Ortsart: Verwitterung w = [Moos, Staub, Regenspuren, Sockelschmutz], Dachfarben roofs = [dunkler Schiefer,
## grauer Schiefer, roter Ziegel, brauner Ziegel], Naturton des Steins (tone, tone_amount), Mauerwerk für Flächen
## ohne Textur (wall).
const LOOK := {
	"grassland": {"w": [0.5, 0.05, 0.55, 0.8], "roofs": [0.45, 0.35, 0.1, 0.1], "tone": Color(0.6, 0.59, 0.55), "tone_amount": 0.3, "wall": "slates"},
	"village": {"w": [0.55, 0.05, 0.5, 0.9], "roofs": [0.2, 0.2, 0.35, 0.25], "tone": Color(0.64, 0.6, 0.53), "tone_amount": 0.0, "wall": "rubble"},
	"city": {"w": [0.35, 0.05, 0.6, 0.85], "roofs": [0.3, 0.25, 0.28, 0.17], "tone": Color(0.66, 0.62, 0.55), "tone_amount": 0.35, "wall": "ashlar"},
	"palace": {"w": [0.22, 0.08, 0.45, 0.6], "roofs": [0.5, 0.3, 0.12, 0.08], "tone": Color(0.76, 0.69, 0.58), "tone_amount": 0.4, "wall": "sandstone"},
	"cathedral": {"w": [0.18, 0.05, 0.4, 0.5], "roofs": [0.25, 0.55, 0.12, 0.08], "tone": Color(0.82, 0.78, 0.7), "tone_amount": 0.45, "wall": "limestone"},
	"wall": {"w": [0.35, 0.05, 0.65, 0.8], "roofs": [0.5, 0.35, 0.1, 0.05], "tone": Color(0.6, 0.6, 0.58), "tone_amount": 0.3, "wall": "slates"},
	"forest": {"w": [0.9, 0.0, 0.5, 0.9], "roofs": [0.3, 0.3, 0.2, 0.2], "tone": Color(0.55, 0.55, 0.5), "tone_amount": 0.0, "wall": "rubble"},
	"jungle": {"w": [1.0, 0.0, 0.5, 0.85], "roofs": [0.3, 0.3, 0.2, 0.2], "tone": Color(0.62, 0.58, 0.5), "tone_amount": 0.0, "wall": "sandstone"},
	"swamp": {"w": [1.0, 0.0, 0.6, 1.0], "roofs": [0.2, 0.3, 0.2, 0.3], "tone": Color(0.5, 0.5, 0.46), "tone_amount": 0.0, "wall": "rubble"},
	"cemetery": {"w": [0.75, 0.0, 0.7, 0.9], "roofs": [0.6, 0.3, 0.05, 0.05], "tone": Color(0.56, 0.56, 0.54), "tone_amount": 0.35, "wall": "slates"},
	"battlefield": {"w": [0.3, 0.15, 0.6, 1.0], "roofs": [0.5, 0.3, 0.1, 0.1], "tone": Color(0.52, 0.5, 0.47), "tone_amount": 0.35, "wall": "rubble"},
	"mountain": {"w": [0.25, 0.35, 0.45, 0.6], "roofs": [0.55, 0.35, 0.05, 0.05], "tone": Color(0.56, 0.53, 0.5), "tone_amount": 0.4, "wall": "slates"},
	"peaks": {"w": [0.15, 0.3, 0.45, 0.6], "roofs": [0.6, 0.3, 0.05, 0.05], "tone": Color(0.52, 0.5, 0.48), "tone_amount": 0.4, "wall": "slates"},
	"tombs": {"w": [0.22, 0.3, 0.25, 0.5], "roofs": [0.6, 0.4, 0.0, 0.0], "tone": Color(0.55, 0.53, 0.5), "tone_amount": 0.0, "wall": "slates"},
	"lava": {"w": [0.0, 0.45, 0.2, 0.7], "roofs": [0.7, 0.3, 0.0, 0.0], "tone": Color(0.4, 0.37, 0.35), "tone_amount": 0.0, "wall": "slates", "volcanic": true},
	"glacier": {"w": [0.0, 0.1, 0.2, 0.3], "roofs": [0.6, 0.4, 0.0, 0.0], "tone": Color(0.6, 0.62, 0.65), "tone_amount": 0.0, "wall": "slates"},
	"throne": {"w": [0.0, 0.04, 0.0, 0.1], "roofs": [0.6, 0.4, 0.0, 0.0], "tone": Color(0.6, 0.6, 0.6), "tone_amount": 0.0, "wall": "limestone"},
	"royal": {"w": [0.0, 0.04, 0.0, 0.1], "roofs": [0.6, 0.4, 0.0, 0.0], "tone": Color(0.6, 0.6, 0.6), "tone_amount": 0.0, "wall": "limestone"},
	"library": {"w": [0.0, 0.08, 0.0, 0.15], "roofs": [0.6, 0.4, 0.0, 0.0], "tone": Color(0.6, 0.6, 0.6), "tone_amount": 0.0, "wall": "limestone"},
	"treasury": {"w": [0.0, 0.04, 0.0, 0.1], "roofs": [0.6, 0.4, 0.0, 0.0], "tone": Color(0.6, 0.6, 0.6), "tone_amount": 0.0, "wall": "sandstone"},
}

## Materialklassen: [Fotodetail, Detail-Stärke, Relief-Stärke, Rauheit, Specular, Verwitterung]
const CLASSES := {
	"stone": ["grain", 0.32, 0.55, 0.88, 0.35, 1.0],
	"floor": ["grain", 0.22, 0.4, 0.82, 0.38, 1.0],
	"plaster": ["plaster", 0.3, 0.4, 0.92, 0.3, 1.0],
	"wood": ["wood", 0.3, 0.45, 0.8, 0.33, 0.9],
	"roof": ["grain", 0.22, 0.35, 0.74, 0.42, 1.0],
	"metal": ["metal", 0.18, 0.25, 0.5, 0.5, 0.4],
	"fabric": ["", 0.0, 0.0, 0.95, 0.25, 0.7],
}

## Prozedural gebaute Bauwerke (tools/pipeline/town_kit.py): Material → [Klasse, Fotomaterial]. Sie bekommen das
## Foto ganz (dreiseitig in Weltkoordinaten), ihre UVs sind nur Notbehelf.
const PROC_MATS := {
	"mi_greatwall": ["stone", "slates"],
	"mi_arenawall": ["stone", "limestone", Color(1, 1, 1), 0.6],
	"mi_arenafloor": ["floor", "flagstone", Color(1, 1, 1), 0.35],
	"mi_arenasand": ["floor", "sand", Color(1, 1, 1), 0.08],
	"mi_bastion": ["stone", "slates"],
	"mi_mausoleum": ["stone", "limestone"],
	"mi_mausoleumdark": ["stone", "slates"],
	"mi_mausoleumroof": ["roof", "roof_slate"],
	"mi_cryptstone": ["stone", "rubble"],
	"mi_cemeterywall": ["stone", "rubble"],
	"mi_gravestone": ["stone", "slates", Color(0.8, 0.8, 0.82)],
	"mi_marblewhite": ["stone", "limestone", Color(1.12, 1.1, 1.06)],
	"mi_blackstone": ["stone", "slates", Color(0.42, 0.4, 0.44)],
	"mi_ironfence": ["metal", "metal", Color(0.16, 0.15, 0.15)],
	"mi_thatch": ["roof", "thatch", Color(1.05, 1.0, 0.9), 0.7],
	"mi_planks": ["wood", "planks", Color(0.9, 0.85, 0.8), 0.8],
	"mi_logwood": ["wood", "logs", Color(0.85, 0.8, 0.75), 0.9],
	"mi_palisadelog": ["wood", "logs", Color(0.8, 0.74, 0.68), 0.9],
	"mi_bone": ["stone", "limestone", Color(0.42, 0.42, 0.5), 0.35],
	"mi_dwarfstone": ["stone", "slates", Color(0.86, 0.9, 1.0), 0.6],
	"mi_dwarfgold": ["metal", "metal", Color(1.6, 1.15, 0.45), 0.1],
	"mi_bark": ["wood", "bark", Color(0.95, 0.92, 0.88), 1.0],
	"mi_elfstone": ["stone", "limestone", Color(0.92, 0.94, 0.9), 0.7],
	"mi_caverock": ["stone", "cliff", Color(0.72, 0.74, 0.72), 1.0],
	"mi_cryptdoor": ["wood", "planks", Color(0.5, 0.42, 0.36)],
}

## Ersatz für Flächen ohne Textur je Klasse („wall“ = Mauerwerk der Ortsart)
const REPLACE := {"stone": "wall", "floor": "flagstone", "plaster": "stucco", "wood": "planks", "roof": "roof_slate", "metal": "metal", "fabric": "stucco"}

const SKIP := ["leaf", "leav", "foliage", "grass", "flower", "bush", "tree", "trunk", "bark", "branch", "spruce", "pine",
	"palm", "fern", "ivy", "vine", "moss", "glass", "water", "ice", "snow", "frost", "lava", "fire", "flame", "candle",
	"crystal", "gem", "jewel", "gold", "coin", "treasure", "sky", "cloud", "hair", "skin", "eye", "book", "paper",
	"bone", "skull", "spine", "skeleton", "horn", "blood", "decal", "particle", "landscape", "terrain", "ground_rock",
	"lantern_glow", "emissive", "hay", "thatch", "straw"]
const SKIP_NODES := ["tree", "spruce", "pine", "bush", "foliage", "palm", "fern", "grass", "flower", "lava", "goldpile", "ice",
	"snowground", "icelake", "ivy", "plant", "hay", "rock"]
const BUILDING_NODES := ["house", "build", "church", "castle", "tower", "wall", "mill", "set", "accoms", "bridge", "temple",
	"pyramid", "mayan", "ruin", "fort", "gate", "chapel", "tomb", "crypt"]

static var _photo_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _ground_tex: ImageTexture


static func apply(scene: Node3D, loc: Dictionary) -> void:
	_mat_cache.clear()
	var kind: String = loc.get("kind", "")
	var look: Dictionary = LOOK.get(kind, LOOK["city"])
	var w: Array = look.w
	RenderingServer.global_shader_parameter_set("overlord_weather", Vector4(w[0], w[1], w[2], w[3]))
	var r: Array = look.roofs
	RenderingServer.global_shader_parameter_set("overlord_roofs", Vector4(r[0], r[1], r[2], r[3]))
	if not _ground_map(scene):
		RenderingServer.global_shader_parameter_set("overlord_ground_rect", Vector4.ZERO)
		var sp := scene.find_child("Spawn", true, false) as Node3D
		RenderingServer.global_shader_parameter_set("overlord_floor_y", sp.global_position.y if sp else 0.0)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	# texturierte Materialien nach Namen: Exportvarianten ohne Textur („MI_CastleWall3_9“) erben davon
	var by_name := {}
	for n in meshes:
		var mesh := (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as StandardMaterial3D
			if m and m.albedo_texture:
				by_name[String(m.resource_name)] = m
	var count := 0
	var interior: bool = loc.get("group", "") == "nazarick" and not kind in ["jungle", "glacier", "lava"]
	var volcanic: bool = look.get("volcanic", false)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.material_override != null:
			continue
		if _skip_node(String(mi.name)) and not (volcanic and _is_rocky(String(mi.name))):
			continue
		for s in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(s) != null:
				continue
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			var sm := _convert(m, String(mi.name), look, by_name, interior)
			if sm:
				mi.set_surface_override_material(s, sm)
				count += 1
	print("Bauwerke: %d Flächen, %d Materialien" % [count, _mat_cache.size()])


static func _is_rocky(nm: String) -> bool:
	var l := nm.to_lower()
	return (l.contains("rock") or l.contains("cliff") or l.contains("stone")) and not l.contains("lava")


## Lavahölle: Fels wird zu dunklem Basalt (Fotoscan) mit glühenden Adern.
static func _volcanic(m: StandardMaterial3D, look: Dictionary) -> ShaderMaterial:
	var key := "vulkan|" + str(m.get_instance_id())
	if _mat_cache.has(key):
		return _mat_cache[key]
	var sm := _make(m, "stone", true, look, false, "basalt")
	sm.set_shader_parameter("photo_tint", Color(0.8, 0.72, 0.68))
	sm.set_shader_parameter("lava_glow", 1.0)
	sm.set_shader_parameter("weather", 0.35)
	_mat_cache[key] = sm
	return sm


static func _skip_node(nm: String) -> bool:
	var l := nm.to_lower()
	if l.begins_with("nocol_") or l.begins_with("ground") or l.begins_with("water") or l.begins_with("foto"):
		return true
	if _is_building(l):              # Gebäude nie über Teilwörter („ice“ in „Office“) ausschließen
		return false
	var core := l.trim_prefix("sm_").trim_prefix("fv_").trim_prefix("mw_")
	for k in SKIP_NODES:
		if core.begins_with(k) or (k.length() >= 4 and l.contains(k)):
			return true
	return false


static func _is_building(l: String) -> bool:
	for k in BUILDING_NODES:
		if l.contains(k):
			return true
	return false


static func _resolve(nm: String, by_name: Dictionary) -> StandardMaterial3D:
	var re := RegEx.create_from_string("_\\d+$")
	var cur := nm
	for i in 3:
		var stripped := re.sub(cur, "")
		if stripped == cur:
			break
		cur = stripped
		if by_name.has(cur):
			return by_name[cur]
	return null


static func _convert(m: StandardMaterial3D, mesh_name: String, look: Dictionary, by_name: Dictionary, interior: bool) -> Material:
	if look.get("volcanic", false):
		var vn := String(m.resource_name).to_lower()
		if (vn.contains("rock") or vn.contains("cliff") or vn.contains("stone") or vn.contains("ground") or _is_rocky(mesh_name)) 				and not vn.contains("lava") and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			return _volcanic(m, look)
	var proc_key := String(m.resource_name).to_lower().get_slice(".", 0)
	proc_key = RegEx.create_from_string("_\\d+$").sub(proc_key, "")
	if PROC_MATS.has(proc_key):
		var pk := "proc|" + str(m.get_instance_id())
		if not _mat_cache.has(pk):
			var e: Array = PROC_MATS[proc_key]
			var pm := _make(m, e[0], true, look, interior, e[1])
			if e.size() > 2:
				pm.set_shader_parameter("photo_tint", e[2])
			if e.size() > 3:
				pm.set_shader_parameter("weather", float(e[3]))      # gepflegte Flächen: kaum Moos/Schmutz
			if e[0] == "metal":
				pm.set_shader_parameter("metallic", 0.55)
				pm.set_shader_parameter("roughness", 0.55)
			if proc_key == "mi_dwarfgold":                  # poliertes Gold statt Rost
				pm.set_shader_parameter("photo_mix", 0.0)
				pm.set_shader_parameter("albedo_col", Color(0.93, 0.7, 0.3))
				pm.set_shader_parameter("metallic", 1.0)
				pm.set_shader_parameter("roughness", 0.3)
				pm.set_shader_parameter("detail", 0.12)
			_mat_cache[pk] = pm
		return _mat_cache[pk]
	var src := m
	var untextured := m.albedo_texture == null
	if untextured:
		var base := _resolve(String(m.resource_name), by_name)
		if base:
			src = base
			untextured = false
	var key: String = str(m.get_instance_id()) + ("|" + _mesh_class(mesh_name) if untextured else "")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var cls := _classify(src, mesh_name, untextured)
	var out: Material = null
	if cls != "" and not (interior and cls in ["fabric", "metal"]):
		out = _make(src, cls, untextured, look, interior)
	_mat_cache[key] = out
	return out


## Grobe Bauteilart aus dem Meshnamen (für Platzhaltermaterialien, die viele Bauteile teilen)
static func _mesh_class(mesh_name: String) -> String:
	var l := mesh_name.to_lower()
	if l.contains("roof"):
		return "roof"
	if l.contains("floor") or l.contains("stair") or l.contains("step") or l.contains("platform") or l.contains("terrace") or l.contains("terraxe"):
		return "floor"
	if l.contains("wood") or l.contains("plank") or l.contains("fence") or l.contains("barrel") or l.contains("crate") or l.contains("box") or l.contains("wagon") or l.contains("cart"):
		return "wood"
	return "stone"


static func _classify(m: StandardMaterial3D, mesh_name: String, untextured: bool) -> String:
	var n := String(m.resource_name).to_lower()
	var mn := mesh_name.to_lower()
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.emission_enabled:
		return ""
	for k in SKIP:
		if n.contains(k):
			return ""
	if n.contains("rock") and not _is_building(mn):
		return ""                                   # Felsen: Fotoscans (PhProps.swap_rocks)
	if untextured and (n.begins_with("worldgrid") or n.begins_with("fbx default") or n == ""):
		return _mesh_class(mesh_name)
	if n.contains("roof") or n.contains("shingle"):
		return "roof"
	if n.contains("plaster") or n.contains("stucco"):
		return "plaster"
	if n.contains("floor") or n.contains("floo") or n.contains("cobble") or n.contains("paving") or n.contains("slatefloor"):
		return "floor"
	for k in ["wood", "plank", "door", "beam", "timber", "barrel", "crate", "cart", "wagon", "bench", "table", "chair",
			"fence", "log", "bucket", "shelf", "stall", "desk", "porch", "cabinet", "windmill", "boat", "box"]:
		if n.contains(k):
			return "wood"
	for k in ["metal", "iron", "steel", "standlight", "lamp", "light", "spear", "sword", "armor", "chain", "bell", "knight", "weapon"]:
		if n.contains(k):
			return "metal" if not mn.contains("statue") else "stone"
	for k in ["cloth", "banner", "tent", "flag", "carpet", "curtain", "rug", "fabric", "bag", "sack", "linen"]:
		if n.contains(k):
			return "fabric"
	if m.metallic > 0.4:
		return "metal"
	if untextured:
		return _mesh_class(mesh_name)
	# nach Farbe: kräftig bunt (Gold, Farbe, Stoff) bleibt, Braun = Holz, sonst Stein
	var c := TexStats.color(m.albedo_texture) * m.albedo_color
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mnc := minf(c.r, minf(c.g, c.b))
	var sat := (mx - mnc) / maxf(mx, 0.01)
	var named_stone := false
	for k in ["wall", "stone", "brick", "castle", "modular", "trim", "pillar", "colum", "collum", "arch", "edge", "stair", "tower",
			"bridge", "build", "accoms", "platform", "statue", "orn", "seal", "ceiling", "module", "pyrmid", "mayan", "jap", "back"]:
		if n.contains(k):
			named_stone = true
			break
	if not named_stone:
		if sat > 0.5:
			return ""
		if c.h > 0.04 and c.h < 0.14 and sat > 0.3 and mx < 0.55:
			return "wood"
	return "stone"


static func _photo(key: String) -> Dictionary:
	if _photo_cache.has(key):
		return _photo_cache[key]
	var p: Array = PHOTOS[key]
	var d := "res://assets/textures/%s/%s/%s_" % [p[0], p[1], p[1]]
	var diff: Texture2D = load(d + "diff.jpg")
	var e := {"diff": diff, "nor": load(d + "nor.jpg"), "rough": load(d + "rough.jpg"), "size": float(p[2]), "lum": float(TexStats.of(diff)[3])}
	_photo_cache[key] = e
	return e


## Fotomaterial für nachträglich gebaute Ausstattung (Möbel, Tische …): photo = Schlüssel in PHOTOS.
static func photo_material(photo: String, cls := "wood", tint := Color(1, 1, 1), weather := 0.15) -> ShaderMaterial:
	var key := "pm|%s|%s|%s|%f" % [photo, cls, tint.to_html(), weather]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var src := StandardMaterial3D.new()
	src.resource_name = "ausstattung_" + photo
	var sm := _make(src, cls, true, LOOK["throne"], true, photo)
	sm.set_shader_parameter("photo_tint", tint)
	sm.set_shader_parameter("weather", weather)
	_mat_cache[key] = sm
	return sm


static func _make(src: StandardMaterial3D, cls: String, untextured: bool, look: Dictionary, interior: bool, photo_override := "") -> ShaderMaterial:
	var c: Array = CLASSES[cls]
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	sm.resource_name = "bau_" + String(src.resource_name)
	var stats: Array = TexStats.of(src.albedo_texture) if not untextured else [0.5, 0.5, 0.5, 0.214, 1.0]
	var base_lum: float = maxf(float(stats[3]), 0.01)
	if not untextured:
		sm.set_shader_parameter("albedo_tex", src.albedo_texture)
		sm.set_shader_parameter("has_albedo", true)
		var col := src.albedo_color
		# grelle, fast weiße Steine (Märchenlook) auf Naturhelligkeit
		if cls in ["stone", "plaster", "floor"] and base_lum > 0.42:
			var k := pow(0.42 / base_lum, 1.0 / 2.2)          # sRGB-Faktor für lineare Helligkeit 0.42
			col = Color(col.r * k, col.g * k, col.b * k, col.a)
		sm.set_shader_parameter("albedo_col", col)
		sm.set_shader_parameter("base_lum", base_lum * col.srgb_to_linear().get_luminance())
	if src.normal_enabled and src.normal_texture and not untextured:
		sm.set_shader_parameter("normal_tex", src.normal_texture)
		sm.set_shader_parameter("has_normal", true)
		sm.set_shader_parameter("normal_depth", clampf(src.normal_scale, 0.2, 2.0))
	sm.set_shader_parameter("uv_scale", Vector2(src.uv1_scale.x, src.uv1_scale.y))
	sm.set_shader_parameter("uv_offset", Vector2(src.uv1_offset.x, src.uv1_offset.y))
	var metal := src.metallic if cls == "metal" else 0.0
	sm.set_shader_parameter("metallic", metal)
	sm.set_shader_parameter("roughness", float(c[3]) if cls != "metal" else clampf(src.roughness, 0.35, 0.7))
	sm.set_shader_parameter("specular", float(c[4]))
	# Fotostruktur: Detail auf dem Original oder Ersatz
	var pkey: String = c[0]
	if untextured:
		pkey = REPLACE[cls] if photo_override == "" else photo_override
		if pkey == "wall":
			pkey = look.get("wall", "ashlar")
	if pkey != "":
		var ph := _photo(pkey)
		sm.set_shader_parameter("photo_diff", ph.diff)
		sm.set_shader_parameter("photo_nor", ph.nor)
		sm.set_shader_parameter("photo_rough", ph.rough)
		sm.set_shader_parameter("photo_size", ph.size)
		sm.set_shader_parameter("photo_lum", ph.lum)
		sm.set_shader_parameter("photo_mix", 1.0 if untextured else 0.0)
		sm.set_shader_parameter("detail", float(c[1]) * (0.6 if interior else 1.0))
		sm.set_shader_parameter("detail_normal", float(c[2]) * (0.6 if interior else 1.0))
		if untextured and float(look.get("tone_amount", 0.0)) > 0.0 and cls in ["stone", "floor", "plaster"]:
			var t: Color = look.tone
			var tl := maxf(t.get_luminance(), 0.01)
			var tint := Color(t.r / tl, t.g / tl, t.b / tl).lerp(Color.WHITE, 1.0 - float(look.tone_amount))
			sm.set_shader_parameter("photo_tint", tint)
	else:
		sm.set_shader_parameter("detail", 0.0)
		sm.set_shader_parameter("detail_normal", 0.0)
	# Farbe
	if cls == "roof" and not untextured and _fairy(stats):
		sm.set_shader_parameter("recolor", 1)
		sm.set_shader_parameter("moss_bias", 0.06)
	elif cls in ["stone", "plaster", "floor"] and float(look.get("tone_amount", 0.0)) > 0.0 and not untextured:
		sm.set_shader_parameter("recolor", 2)
		sm.set_shader_parameter("tone", look.tone)
		sm.set_shader_parameter("tone_amount", look.tone_amount)
		# helle, glatte Wandflächen der Stadthäuser (Stuck/Putz) bekommen je Haus eigene Kalkfarben
		var n := String(src.resource_name).to_lower()
		if cls != "floor" and base_lum > 0.22 and (n.contains("modular") or n.contains("plaster") or n.contains("accoms")) and not n.contains("modular4"):
			sm.set_shader_parameter("facade", 1.0)
	if cls == "roof":
		sm.set_shader_parameter("moss_bias", 0.06)
	elif cls == "fabric":
		sm.set_shader_parameter("moss_bias", -1.0)            # Stoff vermoost nicht
	sm.set_shader_parameter("variation", 0.03 if interior else 0.07)
	sm.set_shader_parameter("weather", float(c[5]))
	return sm


## Märchenfarbe (Türkis, Blau, Violett, kräftiges Grün) statt Naturton?
static func _fairy(stats: Array) -> bool:
	var c := Color(stats[0], stats[1], stats[2])
	var mx := maxf(c.r, maxf(c.g, c.b))
	var sat := (mx - minf(c.r, minf(c.g, c.b))) / maxf(mx, 0.01)
	return sat > 0.25 and c.h > 0.38 and c.h < 0.8


## Geländehöhe als Textur (für den Sockelschmutz im Shader): Punkte der Ground-Meshes auf ein Raster.
static func _ground_map(scene: Node3D) -> bool:
	var pts := PackedVector3Array()
	for n in scene.find_children("Ground*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var vs: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			pts.append_array(mi.global_transform * vs)
	if pts.size() < 64:
		return false
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.z)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.z)
	var w := maxf(mx.x - mn.x, 1.0)
	var d := maxf(mx.y - mn.y, 1.0)
	const N := 256
	var hs := PackedFloat32Array()
	hs.resize(N * N)
	hs.fill(-1.0e9)
	var sx := (N - 1) / w
	var sz := (N - 1) / d
	for p in pts:
		var k := clampi(int((p.z - mn.y) * sz + 0.5), 0, N - 1) * N + clampi(int((p.x - mn.x) * sx + 0.5), 0, N - 1)
		if p.y > hs[k]:
			hs[k] = p.y
	# Lücken (gröberes Gelände, Löcher) aus den Nachbarn füllen
	var holes := PackedInt32Array()
	for k in N * N:
		if hs[k] < -1.0e8:
			holes.append(k)
	var lo := INF
	for k in N * N:
		if hs[k] > -1.0e8:
			lo = minf(lo, hs[k])
	for it in 24:
		if holes.is_empty():
			break
		var rest := PackedInt32Array()
		var fill := {}
		for k in holes:
			var x := k % N
			var z := k / N
			var s := 0.0
			var c := 0
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + o.x
				var zz: int = z + o.y
				if xx >= 0 and xx < N and zz >= 0 and zz < N and hs[zz * N + xx] > -1.0e8:
					s += hs[zz * N + xx]
					c += 1
			if c > 0:
				fill[k] = s / c
			else:
				rest.append(k)
		for k in fill:
			hs[k] = fill[k]
		holes = rest
	for k in holes:
		hs[k] = lo
	var img := Image.create_from_data(N, N, false, Image.FORMAT_RF, hs.to_byte_array())
	img.convert(Image.FORMAT_RH)
	_ground_tex = ImageTexture.create_from_image(img)
	RenderingServer.global_shader_parameter_set("overlord_ground_h", _ground_tex)
	var ox := mn.x - 0.5 * w / (N - 1)
	var oz := mn.y - 0.5 * d / (N - 1)
	RenderingServer.global_shader_parameter_set("overlord_ground_rect", Vector4(ox, oz, (N - 1) / (w * N), (N - 1) / (d * N)))
	RenderingServer.global_shader_parameter_set("overlord_floor_y", lo)
	return true

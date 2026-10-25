extends RefCounted
## (per preload als VLook eingebunden – kein class_name, damit der Klassencache nicht stolpert)
## Bestückt und färbt die Dorfbewohner-Modelle (assets/models/characters/villager_m.glb und villager_f.glb aus
## tools/pipeline/build_villager.py) nach einer Figurenbeschreibung, wie sie Townsfolk und data/figures.json liefern:
##   skin, hair [farbe, stil], top, bottom [pants|dress|gown|robe, farbe], trim, eyes, scale, armor, apron, cape, tabard,
##   helmet, plume, beard, glasses, crown, cap, straw, ears, female, weapon [art, farbe]
## Das Modell trägt alle Frisuren, Hüte und Kleidungsstücke als eigene Knoten (zunächst alle sichtbar); hier werden
## die passenden eingeblendet und die Materialien (nach Namen: Skin, Hair, Top, Bottom, Trim, Pupil, Cape, …) je Figur
## als Kopien eingefärbt. Figuren mit Flügeln, Schwanz, Hörnern oder Schnauze bleiben prozedural.

const OPTIONAL := ["Ears_elf", "Hair_short", "Hair_slick", "Hair_long", "Hair_bob", "Hair_bun", "Hair_ponytail", "Hair_twin",
	"Beard", "Hat_cap", "Hat_straw", "Helmet", "Crown", "Glasses", "Armor_chest", "Pauldrons", "Apron", "Tabard", "Cape", "Skirt"]
const HAIR_NODES := {"short": "Hair_short", "slick": "Hair_slick", "long": "Hair_long", "bob": "Hair_bob", "bun": "Hair_bun",
	"ponytail": "Hair_ponytail", "twin": "Hair_twin"}
const DONOR_HEIGHT := 1.84      ## Höhe des Rigs (Demiurge); Bewohner mit scale 1 werden 1,72 m
const TARGET_HEIGHT := 1.72
const ARMOR_COLOR := Color(0.6, 0.6, 0.65)
const STRAW := Color(0.76, 0.64, 0.36)


## Modell für eine Figurenbeschreibung: "villager_f" / "villager_m" oder "" (prozedural bleiben).
static func model_for(f: Dictionary) -> String:
	for k in ["wings", "tail", "horns", "snout", "spikes", "big_arm", "claws", "round_ears", "belly", "crest"]:
		if f.has(k):
			return ""
	var bottom: Array = f.get("bottom", [])
	var kind := String(bottom[0]) if bottom.size() > 0 else "pants"
	var female: bool = f.get("female", kind == "dress" or kind == "gown")
	return "villager_f" if female else "villager_m"


## Wendet die Beschreibung auf ein erzeugtes Rig mit Dorfbewohner-Modell an.
static func apply(r: CharacterRig, f: Dictionary) -> void:
	if not r.has_model or r._model == null:
		return
	var root: Node3D = r._model
	root.scale = Vector3.ONE * float(f.get("scale", 1.0)) * (TARGET_HEIGHT / DONOR_HEIGHT)
	var bottom: Array = f.get("bottom", ["pants", "#2a2a2a"])
	var kind := String(bottom[0]) if bottom.size() > 0 else "pants"
	var bottom_col := _c(bottom[1] if bottom.size() > 1 else null, "#2a2a2a")
	var hair_spec: Array = f.get("hair", ["#2a2a2a", "short"])
	var hair_col := _c(hair_spec[0] if hair_spec.size() > 0 else null, "#2a2a2a")
	var style := String(hair_spec[1]) if hair_spec.size() > 1 else "short"
	var armored: bool = f.get("armor", false)
	var top_col := ARMOR_COLOR if armored else _c(f.get("top"))
	# Sichtbare Teile
	var show: Dictionary = {}
	if f.has("helmet"):
		show["Helmet"] = true
	elif style != "bald" and not f.has("hood"):
		show[HAIR_NODES.get(style, "Hair_short")] = true
	for key in ["beard", "glasses", "crown", "apron", "cape", "tabard"]:
		if f.has(key) and f[key]:
			show[key.capitalize()] = true
	if f.has("cap"):
		show["Hat_cap"] = true
	if f.get("straw", false):
		show["Hat_straw"] = true
	if f.get("ears", false):
		show["Ears_elf"] = true
	if armored:
		show["Armor_chest"] = true
		show["Pauldrons"] = true
	if kind == "dress" or kind == "gown" or kind == "robe":
		show["Skirt"] = true
	# Farben je Materialname
	var colors: Dictionary = {
		"Skin": _c(f.get("skin"), "#e8d0c0"),
		"Hair": hair_col,
		"Top": top_col,
		"Bottom": bottom_col,
		"Skirt": bottom_col,
		"Trim": _c(f.get("trim"), "#8a6a3a"),
		"Pupil": _c(f.get("eyes"), "#3a2a2a"),
		"Cape": _c(f.get("cape"), "#5a1414"),
		"Tabard": _c(f.get("tabard"), "#1d2f6b"),
		"Hat": _c(f.get("cap"), "#5a4a3a") if f.has("cap") else STRAW,
	}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var n := String(m.name)
		if n in OPTIONAL:
			m.visible = show.has(n)
			if not m.visible:
				continue
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var base := m.mesh.surface_get_material(s) as StandardMaterial3D
			if base == null:
				continue
			var mname := String(base.resource_name)
			var col: Variant = colors.get(mname)
			# Sonderfälle je Knoten: Bart in Bartfarbe, Helm in Helmfarbe, Brille in Brillenfarbe
			if n == "Beard" and f.has("beard"):
				col = _c(f.beard)
			elif n == "Helmet" and mname == "Metal" and f.has("helmet"):
				col = _c(f.helmet)
			elif n == "Helmet" and mname == "Cape":
				col = _c(f.get("plume", f.get("helmet")), "#8a2020")
			elif n == "Glasses" and f.has("glasses"):
				col = _c(f.glasses)
			if col == null and not (armored and mname == "Top"):
				continue
			var dup := base.duplicate() as StandardMaterial3D
			if col != null:
				dup.albedo_color = col
			if armored and mname == "Top":
				dup.metallic = 0.8
				dup.roughness = 0.35
			m.set_surface_override_material(s, dup)
	# Waffe in der rechten Hand (wie bei den Ersatzfiguren gebaut, am Handknochen befestigt)
	var weapon: Array = f.get("weapon", [])
	if not weapon.is_empty():
		var holder := Node3D.new()
		holder.name = "WeaponHolder"
		if r.attach_to_bone("mixamorig_RightHand", holder):
			ProcModel._hand_weapon(r, holder, weapon, 1.0)
			for c in holder.get_children():
				(c as Node3D).position = Vector3(0, 0.0, 0.03)
			holder.rotation_degrees = Vector3(90, 0, 0)
			holder.position = Vector3(0, 0.05, 0)


static func _c(v: Variant, fallback: String = "#888888") -> Color:
	return Color(str(v)) if v != null and str(v) != "" else Color(fallback)

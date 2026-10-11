extends Node
## Content – lädt alle statischen Spielinhalte aus res://data/*.json.
##
## Neue Missionen, Ereignisse, Kapitel oder Charaktere werden ausschließlich in
## den JSON-Dateien ergänzt. Der Code muss dafür nicht angepasst werden.

const DATA_DIR := "res://data/"

var lord: Dictionary = {}                 ## Daten zum Overlord (Startressourcen, innerer Monolog)
var characters: Dictionary = {}           ## id -> Charakterprofil
var character_order: Array[String] = []   ## Reihenfolge wie in der JSON-Datei
var missions: Dictionary = {}             ## id -> Missionsvorlage
var events: Dictionary = {}               ## id -> Ereignis (Story, Zufall, Rivalität, Kette)
var initiatives: Dictionary = {}          ## id -> Eigeninitiative eines Untertanen
var chapters: Array = []                  ## Kapitel in Reihenfolge
var directives: Dictionary = {}           ## Befehlsarten (Freie Hand, Diskret, …)
var regions: Array = []                   ## Regionen der Weltkarte
var region_by_id: Dictionary = {}
var region_links: Array = []              ## Wegenetz [a, b, Tage]
var systems: Dictionary = {}              ## Wirtschaft, Bedrohungen, Komplikationen, Synergien, Erlasse
var locations: Array = []                 ## begehbare 3D-Orte (data/locations.json)
var location_by_id: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	var chars: Dictionary = _load_json("characters.json")
	lord = chars.get("_lord", {})
	chars.erase("_lord")
	characters = chars
	character_order.clear()
	for cid in chars.keys():
		# NPCs (Pleiaden, Victim …) sind nur Sprecher in Ereignissen, keine spielbaren Untertanen
		if not chars[cid].get("npc", false):
			character_order.append(cid)

	missions.clear()
	for m in _load_json("missions.json").get("missions", []):
		missions[m["id"]] = m

	var ev: Dictionary = _load_json("events.json")
	events.clear()
	for e in ev.get("events", []):
		events[e["id"]] = e
	initiatives.clear()
	for i in ev.get("initiatives", []):
		initiatives[i["id"]] = i

	var story: Dictionary = _load_json("story.json")
	chapters = story.get("chapters", [])
	directives = story.get("directives", {})

	systems = _load_json("systems.json")
	locations = _load_json("locations.json").get("locations", [])
	for l in locations:
		location_by_id[l.id] = l
	var reg: Dictionary = _load_json("regions.json")
	regions = reg.get("regions", [])
	region_links = reg.get("links", [])
	region_by_id.clear()
	for r in regions:
		region_by_id[r.id] = r
	# Aufträge ihren Regionen zuordnen; Aufträge außerhalb Nazaricks setzen eine entdeckte Region voraus
	var mreg: Dictionary = reg.get("mission_regions", {})
	for mid in mreg:
		if missions.has(mid):
			var m: Dictionary = missions[mid]
			m["region"] = mreg[mid]
			if not region_by_id.get(mreg[mid], {}).get("home", false):
				var req: Dictionary = m.get("requires", {})
				var disc: Array = req.get("region_discovered", [])
				if not mreg[mid] in disc:
					disc.append(mreg[mid])
				req["region_discovered"] = disc
				m["requires"] = req
	_generate_region_missions()


## Erzeugt je Region: Erkundung, Einfluss ausbauen, Unruhen befrieden.
func _generate_region_missions() -> void:
	for r in regions:
		if r.get("home", false):
			continue
		var id: String = r.id
		var diff := int(r.get("difficulty", 50))
		var hostile: bool = r.get("hostile", false)
		var explore_req: Dictionary = r.get("explore_requires", {}).duplicate()
		explore_req["region_undiscovered"] = id
		missions["x_" + id] = {
			"id": "x_" + id, "title": "Erkundung: " + r.short, "category": "Erkundung", "location": r.name,
			"region": id, "generated": true,
			"description": "Sendet einen Kundschafter nach %s. %s Erst eine erkundete Region kann beeinflusst werden." % [r.name, r.desc],
			"days": 4, "difficulty": diff - 12, "weights": {"intellekt": 1, "diskretion": 2, "kampf": 1},
			"recommended": ["aura", "sebas"], "rewards": {"info": 5}, "influence": 5, "requires": explore_req,
			"outcomes": {
				"triumph": "%s ist vollständig kartiert: Machtverhältnisse, Handelswege, Schwachstellen." % r.name,
				"success": "%s ist erkundet. Erste Kontakte sind geknüpft." % r.name,
				"partial": "Ein grober Überblick über %s – mehr nicht." % r.name,
				"failure": "Die Kundschafter kehrten aus %s ohne verwertbare Erkenntnisse zurück." % r.name,
			},
		}
		missions["i_" + id] = {
			"id": "i_" + id, "title": "Einfluss ausbauen: " + r.short, "category": "Diplomatie" if not hostile else "Geheimoperation",
			"location": r.name, "region": id, "generated": true, "repeatable": true, "repeat_cooldown": 5,
			"description": "Bestechung, Schutzversprechen, Informanten, Furcht – baut Nazaricks Einfluss in %s aus. Mehr Einfluss bringt höhere Einkünfte, zieht aber Aufmerksamkeit auf sich." % r.name,
			"days": 5, "difficulty": diff + (10 if hostile else 0), "weights": {"diplomatie": 2, "diskretion": 1, "intellekt": 1},
			"recommended": ["albedo", "demiurge"], "rewards": {"gold": 15, "attention": 2}, "influence": 14,
			"requires": {"region_discovered": [id], "region_influence_below": {id: 100}},
			"outcomes": {
				"triumph": "In %s sprechen nun Händler, Priester und Hauptleute in Nazaricks Sinne – ohne es zu ahnen." % r.name,
				"success": "Nazaricks Netz in %s ist dichter geworden." % r.name,
				"partial": "Einige Kontakte in %s sind gewonnen, andere misstrauisch." % r.name,
				"failure": "Die Bemühungen in %s sind gescheitert. Man beginnt, Fragen zu stellen." % r.name,
			},
		}
		missions["u_" + id] = {
			"id": "u_" + id, "title": "Unruhen befrieden: " + r.short, "category": "Verwaltung", "location": r.name,
			"region": id, "generated": true, "repeatable": true, "repeat_cooldown": 3,
			"description": "Die Bevölkerung von %s wird unruhig. Mit Güte, Brot oder blanker Furcht lässt sich die Lage beruhigen – Gnadenlosigkeit wirkt schnell, aber hinterlässt Narben." % r.name,
			"days": 3, "difficulty": diff - 5, "weights": {"diplomatie": 2, "kampf": 1},
			"recommended": ["sebas", "cocytus"], "rewards": {"reputation": 2}, "influence": 4,
			"requires": {"region_discovered": [id], "region_unrest_min": {id: 35}},
			"on_success": {"regions": {id: {"unrest": -35}}},
			"outcomes": {
				"triumph": "In %s herrscht wieder Ruhe – und Dankbarkeit." % r.name,
				"success": "Die Unruhe in %s ist abgeklungen." % r.name,
				"partial": "Die Lage in %s bleibt angespannt." % r.name,
				"failure": "Die Unruhe in %s ist eskaliert." % r.name,
			},
		}


func difficulty(id: String) -> Dictionary:
	for d in systems.get("difficulties", []):
		if d.id == id:
			return d
	return {}


func chapter(number: int) -> Dictionary:
	var idx := clampi(number, 1, chapters.size()) - 1
	return chapters[idx]


## Sucht ein Bild unter res://assets/<dir>/<name>.(webp|png|jpg|jpeg).
func find_image(dir: String, name: String) -> Texture2D:
	for ext in ["webp", "png", "jpg", "jpeg"]:
		var p := "res://assets/%s/%s.%s" % [dir, name, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


## Ordnet einem Ortsnamen ein passendes Hintergrundbild zu (Stichwortsuche).
const LOCATION_IMAGES := [
	["Thronsaal", "throne_room"], ["E-Rantel", "e_rantel"], ["Schatzkammer", "treasury"], ["Carne", "carne_village"], ["Arwintar", "baharuth"], ["Kaiser", "baharuth"],
	["E-Rantel", "re_estize"], ["Hauptstadt", "re_estize"], ["Re-Estize", "re_estize"], ["Adelsh", "re_estize"],
	["Theokratie", "holy_kingdom"], ["Wald", "forest"], ["Tob", "forest"], ["Waldrand", "forest"],
	["Katze", "battlefield"], ["Sumpf", "battlefield"], ["Echsen", "battlefield"], ["Amphitheater", "battlefield"],
	["Arena", "battlefield"], ["Nazarick", "nazarick_exterior"], ["Ebene", "nazarick_exterior"],
	["Gebirge", "world_map"], ["Argland", "world_map"], ["Abelion", "world_map"], ["Grasland", "nazarick_exterior"],
]


func location_image(location: String) -> Texture2D:
	for pair in LOCATION_IMAGES:
		if location.findn(pair[0]) >= 0:
			return find_image("backgrounds", pair[1])
	return find_image("backgrounds", "world_map") if location != "" else null


func char_data(cid: String) -> Dictionary:
	return characters.get(cid, {})


func char_color(cid: String) -> Color:
	return Color(char_data(cid).get("color", "#d4af37"))


func char_accent(cid: String) -> Color:
	return Color(char_data(cid).get("accent", "#5b2a8c"))


func _load_json(file: String) -> Dictionary:
	var path := DATA_DIR + file
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Content: Kann %s nicht öffnen" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Content: %s ist kein gültiges JSON-Objekt" % path)
		return {}
	return parsed

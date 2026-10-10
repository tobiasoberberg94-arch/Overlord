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
	["Thronsaal", "throne_room"], ["Carne", "carne_village"], ["Arwintar", "baharuth"], ["Kaiser", "baharuth"],
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

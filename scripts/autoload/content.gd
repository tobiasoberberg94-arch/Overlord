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

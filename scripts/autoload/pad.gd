extends Node
## Controller-Unterstützung: merkt sich, ob zuletzt Gamepad oder Maus/Tastatur benutzt wurde (`active`), liefert
## Tastensymbole je Aktion (`glyph`) und Vibration (`rumble`). Die Belegung selbst steht in Player3D._ensure_actions:
##   Linker Stick gehen · L3 rennen · Rechter Stick Kamera · R3 Ziel fixieren
##   A benutzen/bestätigen · B Rolle/zurück · X leichter Angriff · Y schwerer Angriff
##   LT Block/Parade · LB Superrang-Zauber · RB Zauber 5 · RT Zauber 6 · Steuerkreuz Zauber 1–4
##   Start Menü (dort „Bücher, Karten & Berichte“) · Back Weltkarte
## PlayStation-Controller zeigen ✕ ○ □ △ und L1/R1/L2/R2.

signal changed(active: bool)

var active := false
var sony := false

const GLYPH := {
	"interact": "A", "ui_accept": "A", "dodge": "B", "ui_cancel": "B", "attack_light": "X", "attack_heavy": "Y",
	"block": "LT", "spell_super": "LB", "spell_5": "RB", "spell_6": "RT",
	"spell_1": "▲", "spell_2": "▶", "spell_3": "▼", "spell_4": "◀",
	"lock_on": "R3", "sprint": "L3", "menu": "Start", "map": "Back",
}
const SONY := {"A": "✕", "B": "○", "X": "□", "Y": "△", "LT": "L2", "RT": "R2", "LB": "L1", "RB": "R1", "Back": "Share"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Player3D._ensure_actions()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool): _detect())
	_detect()


func _detect() -> void:
	sony = false
	for d in Input.get_connected_joypads():
		var n := Input.get_joy_name(d).to_lower()
		if "ps4" in n or "ps5" in n or "dualshock" in n or "dualsense" in n or "sony" in n or "wireless controller" in n:
			sony = true


## Gamepad-Eingabe schaltet auf Controller-Darstellung um, Maus/Tastatur zurück; der Mauszeiger folgt.
func _input(event: InputEvent) -> void:
	var is_pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3)
	var is_kbm := event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0)
	if is_pad and not active:
		active = true
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		changed.emit(true)
	elif is_kbm and active:
		active = false
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		changed.emit(false)


## Symbol der Controller-Taste einer Aktion ("A", "LT", "▲" …), PlayStation-Namen falls so ein Gerät angeschlossen ist.
func glyph(action: String) -> String:
	var g: String = GLYPH.get(action, "?")
	if sony and SONY.has(g):
		return SONY[g]
	return g


## Kurze Vibration (Treffer, Parade); strength 0–1.
func rumble(strength: float = 0.5, secs: float = 0.2) -> void:
	if not Settings.pad_rumble:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(strength * 0.6, 0.0, 1.0), clampf(strength, 0.0, 1.0), secs)


## Ist ein Controller angeschlossen?
func connected() -> bool:
	return not Input.get_connected_joypads().is_empty()

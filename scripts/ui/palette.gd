class_name Palette
## Zentrale Farbpalette des Nazarick-Designs. Alle UI-Skripte beziehen ihre
## Farben von hier – ein neuer Look erfordert nur Änderungen in dieser Datei.

const VOID := Color("07040b")          ## tiefstes Schwarz
const ABYSS := Color("0d0816")         ## Panel-Hintergrund
const NIGHT := Color("160c24")         ## erhöhte Flächen
const VIOLET_DEEP := Color("2a1342")
const VIOLET := Color("5b2a8c")
const VIOLET_GLOW := Color("9b5cff")
const GOLD := Color("d4af37")
const GOLD_BRIGHT := Color("f5d77a")
const GOLD_DARK := Color("7a5f1e")
const BLOOD := Color("8b0016")
const CRIMSON := Color("d11a3a")
const PARCHMENT := Color("ebe2cc")     ## Fließtext
const MUTED := Color("8f86a3")         ## Nebentext
const SUCCESS := Color("6fdc8c")
const WARNING := Color("f2b43c")
const DANGER := Color("ff4a5a")

const RESOURCE_COLORS := {
	"power": Color("d11a3a"),
	"info": Color("6fb3ff"),
	"reputation": Color("d4af37"),
	"morale": Color("9b5cff"),
	"gold": Color("f5d77a"),
	"attention": Color("ff8c1a"),
}

const RESOURCE_ICONS := {
	"power": "⚔", "info": "✦", "reputation": "♛",
	"morale": "♥", "gold": "◈", "attention": "◉",
}

const LOG_COLORS := {
	"info": "#b7aecb", "mission": "#d4af37", "story": "#c79bff",
	"emotion": "#ff7aa8", "warning": "#ff4a5a", "initiative": "#7fd8ff",
}


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)

class_name TradeDialog
extends Overlay
## Handel mit einer Figur (data/trade.json): links das Angebot – Dienste (Heiltrank, Nachtlager, Segen, Gerücht)
## und Ausrüstung zum Kauf –, rechts der Verkauf: Materialien aus dem Beutel zu den Preisen dieses Händlers
## (Mengen für laufende Aufträge bleiben zurück) und abgelegte Ausrüstung zum Schmelzwert.

static var _data: Dictionary = {}

var cid: String
var cfg: Dictionary
var player: Node
var _gold := Label.new()
var _offer_box := VBoxContainer.new()
var _sell_box := VBoxContainer.new()
var _msg := Label.new()
var _rng := RandomNumberGenerator.new()


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/trade.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


## Treibt diese Figur Handel?
static func has(id: String) -> bool:
	return data().has(id)


static func gold() -> int:
	return int(Game.state.get("resources", {}).get("gold", 0))


func _init(id: String, p: Node = null) -> void:
	super._init(Vector2(1060, 660))
	cid = id
	cfg = data().get(id, {})
	player = p
	_rng.randomize()
	content.add_child(make_header(String(cfg.get("title", Content.char_data(id).get("name", id))), String(cfg.get("greeting", ""))))
	_gold.theme_type_variation = "SubHeaderLabel"
	_gold.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	content.add_child(_gold)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	for pair in [["Angebot", _offer_box], ["Verkaufen", _sell_box]]:
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := Label.new()
		h.text = pair[0]
		h.theme_type_variation = "HeaderLabel"
		h.add_theme_font_size_override("font_size", 20)
		vb.add_child(h)
		var sc := ScrollContainer.new()
		sc.custom_minimum_size.y = 380
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		var box := pair[1] as VBoxContainer
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 6)
		sc.add_child(box)
		vb.add_child(sc)
		cols.add_child(vb)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size.y = 48
	_msg.add_theme_color_override("font_color", Palette.PARCHMENT)
	content.add_child(_msg)
	_refresh()


func _row(text: String, sub: String, button: String, enabled: bool, action: Callable) -> void:
	var b := Button.new()
	b.text = text + ("\n" + sub if sub != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 52
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not enabled
	b.tooltip_text = button
	b.pressed.connect(action)
	return_box_for(b)


var _target_box: VBoxContainer


func return_box_for(b: Button) -> void:
	_target_box.add_child(b)


func _refresh() -> void:
	for box in [_offer_box, _sell_box]:
		for c in box.get_children():
			c.queue_free()
	_gold.text = "Euer Gold: %d" % gold()
	# --- Angebot ------------------------------------------------------------------------------------
	_target_box = _offer_box
	var any_offer := false
	for o in cfg.get("offers", []):
		if o.has("requires") and not Game.check(o.requires):
			continue
		any_offer = true
		var price := int(o.get("price", 0))
		var can := gold() >= price
		if String(o.kind) == "item":
			var it := Progress.item_def(String(o.id))
			var rar := Progress.rarity(String(it.get("rarity", "common")))
			_row("%s  ·  %d Gold" % [it.get("name", o.id), price], "%s · %s" % [String(rar.get("name", "")), _slot_name(String(it.get("slot", "")))],
				"Kaufen", can, func(): _buy(o))
		else:
			var usable := _service_usable(String(o.id))
			_row("%s  ·  %d Gold" % [o.get("name", o.id), price], String(o.get("desc", "")), "Kaufen", can and usable, func(): _buy(o))
	if not any_offer:
		var l := Label.new()
		l.text = "Nichts im Angebot."
		l.add_theme_color_override("font_color", Color(0.6, 0.58, 0.68))
		_offer_box.add_child(l)
	# --- Verkauf: Materialien ------------------------------------------------------------------------
	_target_box = _sell_box
	var any_sell := false
	var buys: Dictionary = cfg.get("buys", {})
	var all: bool = cfg.get("buys_all", false)
	var factor := float(cfg.get("factor", 1.0))
	for m in Quests.bag().keys():
		var d := Quests.material(m)
		if d.get("unique", false):
			continue
		if not all and not buys.has(m):
			continue
		var price := int(buys.get(m, roundi(float(d.get("value", 1)) * factor)))
		var free := Quests.count(m) - _reserved(m)
		if free <= 0:
			continue
		any_sell = true
		_row("%s %s ×%d  ·  je %d Gold" % [String(d.get("icon", "•")), String(d.get("name", m)), free, price], String(d.get("desc", "")),
			"Alle verkaufen", true, func(): _sell_material(m, free, price))
	# --- Verkauf: abgelegte Ausrüstung -----------------------------------------------------------------
	for e in Progress.inventory():
		var uid := String(e.get("uid", ""))
		if uid == "" or Progress.owner_of(uid) != "":
			continue
		var it := Progress.item_def(String(e.get("item", e.get("id", ""))))
		if it.is_empty():
			continue
		var rar := Progress.rarity(String(it.get("rarity", "common")))
		var price := int(rar.get("sell", 40))
		any_sell = true
		_row("%s  ·  %d Gold" % [it.get("name", "?"), price], "%s · %s" % [String(rar.get("name", "")), _slot_name(String(it.get("slot", "")))],
			"Verkaufen", true, func(): _sell_item(uid, String(it.get("name", "?")), price))
	if not any_sell:
		var l := Label.new()
		l.text = "Nichts, was dieser Händler kaufen würde." if not all else "Euer Beutel ist leer."
		l.add_theme_color_override("font_color", Color(0.6, 0.58, 0.68))
		_sell_box.add_child(l)
	call_deferred("_focus_first")


func _slot_name(slot: String) -> String:
	return {"waffe": "Waffe", "ruestung": "Rüstung", "schmuck": "Schmuck"}.get(slot, slot)


## Für laufende Aufträge benötigte Mengen bleiben im Beutel.
func _reserved(m: String) -> int:
	var needed := 0
	for q in Quests.active():
		var s := Quests.step(q)
		if String(s.get("item", "")) == m:
			needed = maxi(needed, int(s.get("count", 0)))
	return needed


func _service_usable(id: String) -> bool:
	if player == null:
		return id == "rumor"
	match id:
		"heal": return player.hp < player.max_hp - 0.5
		"mana": return player.mana < player.max_mana - 0.5
		"meal": return player.hp < player.max_hp - 0.5 or player.stamina < player.max_stamina - 0.5
		"rest", "heal_full", "bless": return player.hp < player.max_hp - 0.5 or player.mana < player.max_mana - 0.5 or player.stamina < player.max_stamina - 0.5
	return true


func _buy(o: Dictionary) -> void:
	var price := int(o.get("price", 0))
	if gold() < price:
		_say("Dafür reicht Euer Gold nicht.")
		return
	Game.apply_effects({"res": {"gold": -price}})
	if String(o.kind) == "item":
		Progress.grant_item(String(o.id), "Gekauft: " + String(cfg.get("title", cid)))
		_say("%s gehört jetzt Euch – im Zauberbuch (Ringe) oder bei den Wächtern anlegen." % Progress.item_def(String(o.id)).get("name", o.id))
		Audio.sfx("loot", 0.7)
	else:
		match String(o.id):
			"heal":
				player.heal(1.0, 0.0, 0.3)
				_say("Der Trank brennt – und das Leben kehrt zurück.")
			"mana":
				player.heal(0.0, 1.0, 0.0)
				_say("Kalt wie Quellwasser. Das Mana ist wieder da.")
			"meal":
				player.heal(0.5, 0.0, 0.5)
				_say("Der Eintopf ist heiß, das Bier dünn. Es hilft trotzdem.")
			"rest":
				player.heal(1.0, 1.0, 1.0)
				_say("Ihr schlaft, bis es hell wird. Alles ist erholt.")
			"bless":
				player.heal(0.5, 0.5, 0.0)
				_say("Ein kurzes Gebet, ein Tropfen Weihwasser – die Götter nehmen die Spende an.")
			"heal_full":
				player.heal(1.0, 1.0, 0.5)
				_say("Das große Gebet. Die Priester sehen Euch dabei nicht an.")
			"rumor":
				var rumors: Array = cfg.get("rumors", [])
				_say(String(rumors[_rng.randi() % rumors.size()]) if not rumors.is_empty() else "Nichts Neues.")
		Audio.sfx("page", 0.6)
	_refresh()


func _sell_material(m: String, n: int, price: int) -> void:
	if not Quests.take_item(m, n):
		return
	Game.apply_effects({"res": {"gold": price * n}})
	Audio.sfx("loot", 0.6)
	_say("Verkauft: %d × %s für %d Gold." % [n, String(Quests.material(m).get("name", m)), price * n])
	_refresh()


func _sell_item(uid: String, item_name: String, price: int) -> void:
	var g := Progress.sell(uid)
	Audio.sfx("loot", 0.6)
	_say("%s verkauft: +%d Gold." % [item_name, g if g > 0 else price])
	_refresh()


func _say(t: String) -> void:
	_msg.text = t

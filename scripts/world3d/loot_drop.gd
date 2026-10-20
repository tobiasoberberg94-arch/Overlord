class_name LootDrop
extends Node3D
## Beute zum Aufheben (Elite-Gegner, Bosse): ein schwebender Fund – Ring oder Artefakt – mit Lichtsäule in der Farbe
## seiner Seltenheit, Funkeln und Licht, sichtbar über das Schlachtfeld. Ainz hebt ihn im Vorbeigehen auf.

const PICKUP := 1.9

var kind := "item"             ## item (Artefakt für die Wächter) · ring (Ring für Ainz)
var item_id := ""
var rarity := "common"
var source := ""
var _t := 0.0
var _taken := false
var _gem: Node3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _aura: GPUParticles3D
var _col := Color.WHITE


static func drop(parent: Node, at: Vector3, k: String, id: String, rar: String, src: String) -> LootDrop:
	if parent == null or not is_instance_valid(parent) or id == "":
		return null
	var d := LootDrop.new()
	d.kind = k
	d.item_id = id
	d.rarity = rar
	d.source = src
	d.name = "LootDrop"
	d.add_to_group("loot_drops")
	parent.add_child(d)
	var g := CombatFX._ground_below(parent, at + Vector3.UP * 2.0)
	d.global_position = g if g != Vector3.INF else at
	d._build()
	return d


func _build() -> void:
	_col = Progress.rarity_color(rarity)
	var big := rarity in ["epic", "legendary", "world"]
	_gem = Node3D.new()
	_gem.position = Vector3.UP * 2.4
	add_child(_gem)
	if kind == "ring":
		var tor := TorusMesh.new()
		tor.inner_radius = 0.17
		tor.outer_radius = 0.23
		tor.rings = 24
		tor.ring_segments = 10
		var band := MeshInstance3D.new()
		band.mesh = tor
		band.material_override = B3.mat(Color(0.95, 0.78, 0.36), 0.25, 1.0, _col, 0.8)
		band.rotation_degrees.x = 90.0
		_gem.add_child(band)
		var stone := SpellFX._mesh(_gem, SpellFX._sphere(), SpellFX._orb_mat("soft"), Vector3.ZERO, Vector3.ONE * 0.12)
		stone.position = Vector3(0, 0.23, 0)
		stone.set_instance_shader_parameter("core_col", _col.lightened(0.4))
		stone.set_instance_shader_parameter("rim_col", _col)
		stone.set_instance_shader_parameter("energy", 3.0)
	else:
		# geschliffener Edelstein (wenige Facetten), darin ein Lichtkern
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.5
		sm.radial_segments = 6
		sm.rings = 2
		var gem := MeshInstance3D.new()
		gem.mesh = sm
		gem.material_override = B3.mat(_col.darkened(0.2), 0.12, 0.3, _col, 1.6)
		_gem.add_child(gem)
		var core := SpellFX._mesh(_gem, SpellFX._sphere(), SpellFX._orb_mat("soft"), Vector3.ZERO, Vector3.ONE * 0.18)
		core.position = Vector3.ZERO
		core.set_instance_shader_parameter("core_col", Color(1, 1, 1))
		core.set_instance_shader_parameter("rim_col", _col)
		core.set_instance_shader_parameter("energy", 2.5)
	# Lichtsäule: von weitem sichtbar, seltene Funde höher und heller
	var h := 11.0 if big else 7.0
	var wd := 0.7 if big else 0.45
	_beam = SpellFX._mesh(self, SpellFX._cylinder(), SpellFX._beam_mat(), Vector3.ZERO, Vector3(wd, h, wd))
	_beam.position = Vector3.UP * h * 0.5
	_beam.set_instance_shader_parameter("tint", _col)
	_beam.set_instance_shader_parameter("energy", 3.2 if big else 2.2)
	_beam.set_instance_shader_parameter("scroll", 0.5)
	_light = OmniLight3D.new()
	_light.light_color = _col
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 0.8
	add_child(_light)
	_aura = CombatFX.emitter(self, "aura", _col)
	GroundMark.rune(get_parent(), global_position, 0.9, _col, 600.0, "a", null, 0.6)
	# Fall mit Aufprall
	var tw := create_tween()
	tw.tween_property(_gem, "position:y", 0.75, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "light_energy", 1.8 if big else 1.2, 0.5)
	CombatFX.sound("loot_drop", global_position + Vector3.UP, 0.75, 0.04)
	CombatFX.burst(get_parent(), "sparks", global_position + Vector3.UP * 0.4, _col, Vector3.UP, 0.8)


func _process(delta: float) -> void:
	_t += delta
	if _taken or _gem == null:
		return
	_gem.rotate_y(delta * 1.6)
	if _t > 0.6:
		_gem.position.y = 0.75 + sin(_t * 2.2) * 0.08
	var p: Node3D = CombatFX.player
	if p and is_instance_valid(p) and _t > 0.6:
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < PICKUP and absf(p.global_position.y - global_position.y) < 2.5:
			collect()


## Aufheben: der Fund fliegt zu Ainz, die Säule erlischt, die Beute landet im Zauberbuch bzw. in der Schatzkammer.
func collect() -> void:
	if _taken:
		return
	_taken = true
	remove_from_group("loot_drops")
	if kind == "ring":
		Progress.grant_ring(item_id, source)
	else:
		Progress.grant_item(item_id, source)
	CombatFX.sound("loot_pickup", global_position + Vector3.UP, 0.8, 0.03)
	CombatFX.burst(get_parent(), "motes", global_position + Vector3.UP * 0.8, _col, Vector3.UP, 1.4)
	CombatFX.burst(get_parent(), "flash", global_position + Vector3.UP * 0.8, _col)
	if _aura and is_instance_valid(_aura):
		CombatFX.stop(_aura)
	var tw := create_tween().set_parallel(true)
	var p: Node3D = CombatFX.player
	if p and is_instance_valid(p):
		tw.tween_property(_gem, "global_position", p.global_position + Vector3.UP * 1.3, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_gem, "scale", Vector3.ONE * 0.1, 0.35)
	tw.tween_property(_light, "light_energy", 0.0, 0.4)
	tw.tween_method(func(v: float): _beam.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5)
	tw.chain().tween_callback(queue_free)

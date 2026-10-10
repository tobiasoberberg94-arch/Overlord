class_name UIFx
## Kleine, wiederverwendbare UI-Animationen (Tweens).

## Blendet ein CanvasItem weich ein.
static func fade_in(node: CanvasItem, duration: float = 0.35, delay: float = 0.0) -> Tween:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration).set_delay(delay).set_trans(Tween.TRANS_SINE)
	return tw


## Ein- „Aufploppen“: Skalierung 0.92 → 1 plus Einblenden (wie bei Mobile-Games).
static func pop_in(node: Control, duration: float = 0.32, delay: float = 0.0) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.92, 0.92)
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, duration).set_delay(delay)
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hover-Effekt: sanftes Vergrößern beim Überfahren mit der Maus.
static func add_hover_scale(c: Control, factor: float = 1.04) -> void:
	c.mouse_entered.connect(func(): _scale_to(c, factor))
	c.mouse_exited.connect(func(): _scale_to(c, 1.0))


static func _scale_to(c: Control, factor: float) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2.0
	c.z_index = 1 if factor > 1.0 else 0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(factor, factor), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Endloses Pulsieren (z. B. für Benachrichtigungs-Badges).
static func pulse(node: CanvasItem, low: float = 0.55, period: float = 1.2) -> Tween:
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", low, period / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.0, period / 2.0).set_trans(Tween.TRANS_SINE)
	return tw


## Kurzes Aufblitzen in einer Farbe (Feedback bei Änderungen).
static func flash(node: CanvasItem, color: Color = Color(1.4, 1.25, 0.8)) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", color, 0.08)
	tw.tween_property(node, "modulate", Color.WHITE, 0.35)


## Schreibmaschinen-Effekt für RichTextLabels.
static func typewriter(label: RichTextLabel, chars_per_sec: float = 140.0) -> Tween:
	var factor := Settings.text_speed_factor()
	if factor <= 0.0:
		label.visible_ratio = 1.0
		return label.create_tween()
	chars_per_sec *= factor
	label.visible_ratio = 0.0
	var length := maxi(1, label.get_total_character_count())
	var tw := label.create_tween()
	tw.tween_property(label, "visible_ratio", 1.0, clampf(length / chars_per_sec, 0.25, 4.0))
	return tw

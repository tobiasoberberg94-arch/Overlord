extends Node
## Fotomodus (F9, Pausenmenü, Controller: Start → Fotomodus): freie Kamera bei angehaltener Welt, HUD aus.
##   WASD / linker Stick bewegen · Maus / rechter Stick schauen · Q/E bzw. LT/RT auf und ab · Shift / L3 schnell
##   Mausrad Brennweite · 1–4 Filter (Natur, Sepia, Noir, Kräftig) · Leertaste / A Foto speichern · Esc / B / F9 zurück
## Fotos landen in user://screenshots/ (im Spiel: Dokumente → Overlord).

var active := false
var _world: Node
var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _filter := 0
var _env: Environment
var _base := {}
var _hint: Label


func toggle() -> void:
	if active:
		_exit()
	else:
		_enter()


func _enter() -> void:
	_world = get_parent()
	if _world == null or not is_instance_valid(_world.player) or _world.cinematic:
		return
	active = true
	_world.cinematic = true
	_cam = Camera3D.new()
	_cam.far = _world.player.camera.far
	_cam.fov = 55.0
	add_child(_cam)
	_cam.global_transform = _world.player.camera.global_transform
	var e := -_cam.global_transform.basis.z
	_yaw = atan2(-e.x, -e.z)
	_pitch = asin(clampf(e.y, -1.0, 1.0))
	_cam.current = true
	_env = null
	for c in _world.level.find_children("*", "WorldEnvironment", true, false):
		_env = (c as WorldEnvironment).environment
	if _env:
		_base = {"sat": _env.adjustment_saturation, "con": _env.adjustment_contrast, "bri": _env.adjustment_brightness, "on": _env.adjustment_enabled}
	_filter = 0
	_world.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hint = Label.new()
	_hint.text = "FOTOMODUS   WASD/Stick bewegen · Maus/Stick schauen · Q/E auf/ab · Rad Brennweite · 1–4 Filter · Leertaste/A Foto · Esc/B zurück"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 0.85))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -40
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_world.ui_root.add_child(_hint)
	_world.toast("Fotomodus – die Welt hält den Atem an.", Color(0.9, 0.85, 0.7))


func _exit() -> void:
	active = false
	if _env and not _base.is_empty():
		_env.adjustment_saturation = float(_base.sat)
		_env.adjustment_contrast = float(_base.con)
		_env.adjustment_brightness = float(_base.bri)
		_env.adjustment_enabled = bool(_base.on)
	if _hint and is_instance_valid(_hint):
		_hint.queue_free()
	if is_instance_valid(_world) and is_instance_valid(_world.player):
		_world.player.camera.current = true
		_world.cinematic = false
		_world.hud.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not Pad.active else Input.MOUSE_MODE_HIDDEN
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= (event as InputEventMouseMotion).relative.x * 0.0035
		_pitch = clampf(_pitch - (event as InputEventMouseMotion).relative.y * 0.003, -1.45, 1.45)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov - 3.0, 15.0, 90.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov + 3.0, 15.0, 90.0)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE, KEY_F9:
				_exit()
			KEY_SPACE:
				snapshot()
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_filter(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	var jb := event as InputEventJoypadButton
	if jb and jb.pressed:
		match jb.button_index:
			JOY_BUTTON_B, JOY_BUTTON_START:
				_exit()
			JOY_BUTTON_A:
				snapshot()
			JOY_BUTTON_DPAD_LEFT:
				set_filter((_filter + 3) % 4)
			JOY_BUTTON_DPAD_RIGHT:
				set_filter((_filter + 1) % 4)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active or _cam == null:
		return
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down", 0.18)
	_yaw -= look.x * 2.4 * delta
	_pitch = clampf(_pitch - look.y * 1.8 * delta, -1.45, 1.45)
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.2)
	var up := (1.0 if Input.is_key_pressed(KEY_E) else 0.0) - (1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	up += Input.get_action_strength("spell_6") - Input.get_action_strength("block")
	var speed := 6.0 * (3.0 if Input.is_action_pressed("sprint") else 1.0)
	var dir := _cam.global_transform.basis * Vector3(mv.x, 0.0, mv.y)
	_cam.global_position += (dir + Vector3(0, up, 0)) * speed * delta


## Filter: 0 Natur, 1 Sepia (warm, blass), 2 Noir (schwarzweiß, hart), 3 Kräftig.
func set_filter(i: int) -> void:
	_filter = i
	if _env == null:
		return
	_env.adjustment_enabled = true
	match i:
		0:
			_env.adjustment_saturation = float(_base.sat)
			_env.adjustment_contrast = float(_base.con)
			_env.adjustment_brightness = float(_base.bri)
		1:
			_env.adjustment_saturation = 0.35
			_env.adjustment_contrast = 1.05
			_env.adjustment_brightness = 1.08
		2:
			_env.adjustment_saturation = 0.0
			_env.adjustment_contrast = 1.35
			_env.adjustment_brightness = 0.95
		3:
			_env.adjustment_saturation = 1.45
			_env.adjustment_contrast = 1.15
			_env.adjustment_brightness = 1.0
	_world.toast(["Filter: Natur", "Filter: Sepia", "Filter: Noir", "Filter: Kräftig"][i], Color(0.9, 0.85, 0.7))


## Foto speichern (ohne Hinweiszeile).
func snapshot() -> void:
	if _hint:
		_hint.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var name := "user://screenshots/foto_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(name)
	if _hint:
		_hint.visible = true
	_world.toast("Foto gespeichert: %s" % ProjectSettings.globalize_path(name), Palette.GOLD_BRIGHT)
	Audio.sfx("click", 0.8)

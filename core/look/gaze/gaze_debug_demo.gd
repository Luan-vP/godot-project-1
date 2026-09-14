extends Control
## Manual proof of eye tracking: is the tracker alive, do the numbers move the
## right way, and does the mapping feel like looking?
##
## Shows the raw reading, where the mapping thinks the player is looking, the
## dead zone and full-deflection ellipses that decide the turn, and a heading
## the turn accumulates into — everything a person holding the phone needs to
## judge it, without a panorama level in the way.
##
## On a build with the gaze plugin this reads the device. Anywhere else it
## falls back to the pointer standing in for eyes, so the mapping can still be
## felt: Space holds a blink, F hides the face.
##
## Calibrate (button, C, or double tap): look at the cross in the middle for
## about half a second. With the pointer, press C rather than clicking the
## button, or the pointer is on the button while it calibrates.

const BACKGROUND := Color(0.07, 0.075, 0.09)
const TEXT := Color(0.86, 0.87, 0.9)
const MUTED := Color(0.5, 0.52, 0.57)
const ZONE := Color(0.35, 0.4, 0.5, 0.5)
const EDGE := Color(0.35, 0.4, 0.5, 0.25)
const RAW := Color(0.6, 0.62, 0.68, 0.8)
const TRACKING := Color(0.45, 0.85, 0.6)
const HELD := Color(0.95, 0.75, 0.35)
const LOST := Color(0.9, 0.4, 0.4)

var _device := NativeEyeGazeBackend.new()
var _pointer: PointerEyeGazeBackend
var _source: EyeGazeLookSource
var _heading: Vector2 = Vector2.ZERO
var _readout: Label
var _backend_button: Button
var _camera_button: Button
var _running: bool = false
var _frame_times: Array[float] = []
var _last_timestamp: float = NAN
var _logged_state: int = -1
var _logged_at: float = -INF


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pointer = PointerEyeGazeBackend.new(get_viewport())
	_build_ui()
	_use_backend(_device if NativeEyeGazeBackend.is_present() else _pointer)


func _exit_tree() -> void:
	if _source != null:
		_source.stop()


func _process(delta: float) -> void:
	if _source == null:
		return
	var turn := _source.poll(delta)
	# Same signs as PanoramaLookCamera: positive x turns right, so yaw falls.
	_heading.x = wrapf(_heading.x - turn.x, -PI, PI)
	_heading.y = clampf(_heading.y - turn.y, -deg_to_rad(85.0), deg_to_rad(85.0))
	_count_frame(_source.last_sample.timestamp)
	_log_reading(_source.last_sample)
	_readout.text = _describe()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed and touch.double_tap:
		_calibrate()
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_pointer.blinking = key.pressed
		KEY_F:
			if key.pressed:
				_pointer.face_hidden = not _pointer.face_hidden
		KEY_C:
			if key.pressed:
				_calibrate()
		KEY_M:
			if key.pressed:
				_toggle_backend()
		KEY_R:
			if key.pressed:
				_heading = Vector2.ZERO


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var centre := size * 0.5
	var half := size * 0.5
	var filter := _source.filter if _source != null else EyeGazeFilter.new()

	# Full deflection is the span, which the defaults put at the screen edges.
	_draw_ellipse(centre, half, EDGE)
	_draw_ellipse(centre, half * filter.deadzone, ZONE)
	draw_line(centre - Vector2(14, 0), centre + Vector2(14, 0), TEXT, 2.0)
	draw_line(centre - Vector2(0, 14), centre + Vector2(0, 14), TEXT, 2.0)

	if _source == null:
		return
	var sample := _source.last_sample
	if sample.is_tracking():
		# Raw: this reading against the calibrated neutral, unsmoothed, so
		# jitter is visible next to what the mapping actually steers with.
		var raw := EyeGazeMapping.deflection(sample.gaze, filter.neutral, filter.span)
		draw_arc(_to_screen(raw, centre, half), 10.0, 0.0, TAU, 24, RAW, 2.0)
	if filter.has_gaze():
		var colour := TRACKING if sample.is_tracking() and sample.blink < filter.max_blink else HELD
		draw_circle(_to_screen(filter.deflection, centre, half), 16.0, colour)
	elif sample.state != EyeGazeSample.State.TRACKING:
		draw_circle(centre, 6.0, LOST)

	_draw_heading(Rect2(Vector2(24, size.y - 250), Vector2(size.x - 48, 50)))


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	# Clear of the Dynamic Island and home indicator on a phone.
	SafeArea.fit_control(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_label("Eye gaze", 28, TEXT))
	_readout = _label("", 15, TEXT)
	column.add_child(_readout)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var hint := _label(
		(
			"Look at the cross, then Calibrate. Hold a look off-centre to turn.\n"
			+ "Keys: C calibrate, M device/pointer, R reset heading, Space blink, F hide face"
		),
		13,
		MUTED
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	buttons.add_child(_button("Calibrate", _calibrate))
	_camera_button = _button("Stop", _toggle_running)
	buttons.add_child(_camera_button)
	_backend_button = _button("Pointer", _toggle_backend)
	buttons.add_child(_backend_button)


func _use_backend(backend: EyeGazeBackend) -> void:
	if _source != null:
		_source.stop()
	_source = EyeGazeLookSource.new(backend)
	_source.start()
	_running = true
	_heading = Vector2.ZERO
	_last_timestamp = NAN
	_frame_times.clear()
	_backend_button.text = "Use device" if backend == _pointer else "Use pointer"
	_camera_button.text = "Stop"


func _toggle_backend() -> void:
	_use_backend(_pointer if _source.backend == _device else _device)


func _toggle_running() -> void:
	_running = not _running
	if _running:
		_source.start()
	else:
		_source.stop()
	_camera_button.text = "Stop" if _running else "Start"


func _calibrate() -> void:
	if _source != null:
		_source.calibrate()


func _count_frame(timestamp: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if timestamp != _last_timestamp:
		_last_timestamp = timestamp
		_frame_times.append(now)
	while not _frame_times.is_empty() and now - _frame_times[0] > 1.0:
		_frame_times.pop_front()


## A line per tracking state change, and one a second while tracking, so a
## device log shows the tracker coming alive, finding a face, the gaze moving
## and the turn it makes, without anyone reading the screen.
func _log_reading(sample: EyeGazeSample) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var periodic := sample.is_tracking() and now - _logged_at >= 1.0
	if sample.state == _logged_state and not periodic:
		return
	_logged_state = sample.state
	_logged_at = now
	print(
		(
			"[eye gaze] %s via %s, gaze %s, head %s, confidence %.2f, blink %.2f, turn %s/s %s"
			% [
				EyeGazeSample.state_name(sample.state),
				_source.describe(),
				_degrees(sample.gaze),
				_degrees(sample.head),
				sample.confidence,
				sample.blink,
				_degrees(_source.filter.rate),
				sample.message,
			]
		)
	)


func _describe() -> String:
	var sample := _source.last_sample
	var filter := _source.filter
	var calibration := (
		"listening..."
		if filter.is_calibrating()
		else ("%s" % _degrees(filter.neutral) if filter.is_calibrated() else "not yet")
	)
	var lines: PackedStringArray = [
		"backend      %s" % _source.describe(),
		"state        %s" % EyeGazeSample.state_name(sample.state),
		"gaze         %s" % _degrees(sample.gaze),
		"head         %s" % _degrees(sample.head),
		"confidence   %.2f   blink %.2f" % [sample.confidence, sample.blink],
		"frames       %d/s   t=%.3f" % [_frame_times.size(), sample.timestamp],
		"neutral      %s" % calibration,
		"deflection   (%+.2f, %+.2f)" % [filter.deflection.x, filter.deflection.y],
		"turn         %s/s" % _degrees(filter.rate),
		"heading      %s" % _degrees(_heading),
	]
	if sample.message != "":
		lines.append("message      %s" % sample.message)
	return "\n".join(lines)


func _draw_heading(rect: Rect2) -> void:
	draw_rect(rect, EDGE, false, 1.0)
	var x := rect.position.x + rect.size.x * (0.5 - _heading.x / TAU)
	var y := rect.position.y + rect.size.y * (0.5 - _heading.y / PI)
	draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), TRACKING, 2.0)
	draw_circle(Vector2(x, y), 5.0, TRACKING)


func _draw_ellipse(centre: Vector2, radii: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU * i / 64.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, colour, 2.0)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


static func _to_screen(deflection: Vector2, centre: Vector2, half: Vector2) -> Vector2:
	# Deflection is up-positive; screen y grows downwards.
	return centre + Vector2(deflection.x, -deflection.y) * half


static func _degrees(radians: Vector2) -> String:
	return "(%+6.1f°, %+6.1f°)" % [rad_to_deg(radians.x), rad_to_deg(radians.y)]


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

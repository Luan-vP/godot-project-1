extends Node2D
## The eye band: a tank full of floaty eyes, each playing one part of the
## host's band while it floats clear of the walls. Tilt (WASD) or stir to push
## eyes against a wall and strip the arrangement back; let them drift free to
## fill it out. L1/R1 (or Q/E) move the key down/up a fourth, L2/R2 (or Z/X) a
## fifth — see [KeyShiftInput].
##
## A foreground over the host's tank ([SharedLayers]): the eyes float in its
## fluid and stir it, and their wants decide which of the band's parts play.
## See [EyeBand] for how eyes become parts.
##
## Drag to stir and paint. Arrows tilt, space jogs, C recalibrates, R empties
## the tank, B makes everyone blink. On a phone WASD and space are replaced by
## the real accelerometer, with no change here — [MotionInput] picks the
## source.

const EYE_COUNT := 7
const FLOATER_COUNT := 70

## Mouse motion is a speed; the tank wants an acceleration. This bridges them.
const STIR_GAIN := 9.0

const STIR_RADIUS := 110.0
const PAINT_RATE := 3.2

## Left alone, the eyes in this tank random-walk into the walls within ten
## seconds and stay there, which would leave the band silent almost at once.
## A soft spring towards the middle, in 1/second^2, keeps them afloat by
## default, weak enough that holding a tilt still pins them to a wall. At 0.8
## even a full tilt pinned nothing; at 0.4 a free tank played nearly the whole
## arrangement. 0.1, chosen by ear, leaves the eyes looser: more drifting onto
## walls on their own, and more work to keep the band playing.
const CENTRE_PULL := 0.1

const RING_GAP := 7.0
const PLAYING_COLOR := UiTokens.HUD_TEXT
const SILENT_COLOR := Color(UiTokens.SIGIL, 0.22)
const TOUCHING_COLOR := UiTokens.ALERT

## Read straight from [Input], not [KeyShiftInput], so the debug line shows
## whether the hardware event reaches Godot at all — independent of any bug
## or remap in the key-shift path it would otherwise be used to diagnose.
const DEBUG_BUTTONS := {
	"L1": JOY_BUTTON_LEFT_SHOULDER,
	"R1": JOY_BUTTON_RIGHT_SHOULDER,
}
const DEBUG_AXES := {
	"L2": JOY_AXIS_TRIGGER_LEFT,
	"R2": JOY_AXIS_TRIGGER_RIGHT,
}

## Countdown ring while a part is about to start (rune) or stop (alert) — see
## [enum EyeBand.Pending].
const PENDING_START_COLOR := UiTokens.RUNE
const PENDING_STOP_COLOR := UiTokens.ALERT
const PENDING_RING_WIDTH := 3.0

## Which eyes are clear of the walls, and so which parts are wanted. Always this
## scene's own; it only sounds when standalone.
var _simulation: FluidSimulation
## The level's host: the tank to float in and the band to play.
var _shared: SharedLayers
var _motion: MotionInput
var _readout: Label
var _last_mouse: Vector2 = Vector2.ZERO

var _contacts: EyeBand
## The band that sounds: [member _contacts] standalone, the carousel's shared
## band when hosted (see [SharedLayers]), which then gets its parts mirrored
## from the contacts every frame.
var _band: Band
var _overlay: Node2D
var _parts_label: Label
var _debug_label: Label
var _key_shift := KeyShiftInput.new()


func _ready() -> void:
	_shared = SharedLayers.host_of(self)
	if _shared == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	_build_tank_level()
	_contacts = EyeBand.new()
	_contacts.name = "EyeBand"
	add_child(_contacts)
	_band = _shared.band

	_overlay = Node2D.new()
	_overlay.name = "PartRings"
	_overlay.z_index = 50
	_overlay.draw.connect(_draw_rings)
	add_child(_overlay)

	var layer := CanvasLayer.new()
	_parts_label = UiTheme.label("", UiTheme.HUD)
	_parts_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_parts_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_parts_label.offset_left = 16.0
	_parts_label.offset_bottom = -12.0
	layer.add_child(_parts_label)

	_debug_label = UiTheme.label("", UiTheme.HUD_FAINT)
	_debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_label.offset_left = 16.0
	_debug_label.offset_top = 12.0
	layer.add_child(_debug_label)
	add_child(layer)
	_update_label()


## The eyes, the tilt and jog that move the tank, the floaters, and the
## motion readout.
func _build_tank_level() -> void:
	var extent := get_viewport_rect().size

	_simulation = _shared.fluid

	_motion = MotionInput.new()
	_motion.name = "MotionInput"
	add_child(_motion)

	# Live tilt values on the device itself, where there is no console: F3, or
	# the gamepad's Y button, hides them.
	var motion_debug := MotionDebugOverlay.new()
	motion_debug.name = "MotionDebugOverlay"
	add_child(motion_debug)

	var driver := FluidMotionDriver.new()
	driver.name = "FluidMotionDriver"
	add_child(driver)

	_build_readout()

	for i in EYE_COUNT:
		add_child(_make_eye(i, extent))

	var floaters := FloaterField.new()
	floaters.name = "Floaters"
	floaters.count = FLOATER_COUNT
	add_child(floaters)

	_last_mouse = get_global_mouse_position()


## Drag to stir and paint.
func _stir(delta: float) -> void:
	var mouse := get_global_mouse_position()
	var motion := mouse - _last_mouse
	_last_mouse = mouse
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if delta <= 0.0 or motion.length() < 0.5:
		return
	var color := ArtPalette.dye(int(Time.get_ticks_msec() / 900))
	_simulation.add_velocity_impulse(mouse, motion / delta * STIR_GAIN, STIR_RADIUS, delta)
	_simulation.add_paint(mouse, color, PAINT_RATE, STIR_RADIUS * 0.6, delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null:
		return
	if key.keycode == KEY_R:
		_simulation.reset()
	elif key.keycode == KEY_C:
		_motion.calibrate()
	elif key.keycode == KEY_B:
		for eye in get_children():
			if eye is FloatyEye:
				(eye as FloatyEye).blink()


func _physics_process(delta: float) -> void:
	var centre := _simulation.get_world_rect().get_center()
	for child in get_children():
		var eye := child as FloatyEye
		if eye != null:
			eye.velocity += (centre - eye.global_position) * CENTRE_PULL * delta


func _unhandled_input(event: InputEvent) -> void:
	var step := _key_shift.step_for(event)
	if step != 0:
		_band.set_key_offset(_band.get_key_offset() + step)
		get_viewport().set_input_as_handled()
		# The readout shows the key we just set, not the one still sounding:
		# chords, bass, arp and melody only catch up from the next step (see
		# [method EyeBand.set_key_offset]), but the press itself is instant.
		_update_label()


func _process(delta: float) -> void:
	_stir(delta)
	for part in Band.PARTS:
		_band.set_part_wanted(part, _contacts.wants_part(part))
	_overlay.queue_redraw()
	_update_label()
	_update_debug_label()


func _update_label() -> void:
	var parts: PackedStringArray = []
	for part in Band.PARTS:
		var mark := "●" if _band.is_playing(part) else "○"
		if _band.is_playing(part) != _band.wants_part(part):
			mark = "◐"
		parts.append("%s %s" % [mark, part])
	_parts_label.text = (
		(
			"♪ %s · %s · key %+d\n"
			% [
				_band.song_title(),
				_band.current_section(),
				KeyShiftInput.display_offset(_band.get_key_offset()),
			]
		)
		+ "   ".join(parts)
		+ "      keep eyes off the walls to hear them"
	)


## Raw pad state for L1/R1/L2/R2, to tell a controller that is not sending
## these events at all apart from one whose events just aren't reaching
## [method _unhandled_input].
func _update_debug_label() -> void:
	var pads := Input.get_connected_joypads()
	var device := pads[0] if not pads.is_empty() else 0
	var line: PackedStringArray = []
	for label in DEBUG_BUTTONS:
		var pressed := Input.is_joy_button_pressed(device, DEBUG_BUTTONS[label])
		line.append("%s %s" % [label, "●" if pressed else "○"])
	for label in DEBUG_AXES:
		line.append("%s %.2f" % [label, Input.get_joy_axis(device, DEBUG_AXES[label])])
	_debug_label.text = "   ".join(line)


## A ring round each eye: bright while its part plays, red while it is pressed
## against a wall, faint while it waits silent. Its part is written beneath.
## While a part is due to start or stop at the next bar, the ring becomes a
## countdown instead — white or red, its arc shrinking to nothing as the bar
## line arrives (see [method EyeBand.pending]).
func _draw_rings() -> void:
	var font := UiTheme.hud_font()
	var countdown := EyeBand.countdown_fraction(
		AudioManager.get_seconds_until_next_bar(), AudioManager.get_music_clock().seconds_per_bar()
	)
	for child in get_children():
		var eye := child as FloatyEye
		if eye == null:
			continue
		var part := _contacts.part_for(eye)
		if part.is_empty():
			continue
		var color := PLAYING_COLOR if _band.is_playing(part) else SILENT_COLOR
		if _contacts.is_touching(eye):
			color = TOUCHING_COLOR
		var ring_radius := eye.radius + RING_GAP
		var pending := _band.pending(part)
		if pending != EyeBand.Pending.NONE:
			if pending == EyeBand.Pending.STARTING:
				color = PENDING_START_COLOR
			else:
				color = PENDING_STOP_COLOR
			var sweep := TAU * countdown
			_overlay.draw_arc(
				eye.global_position,
				ring_radius,
				-PI / 2.0,
				-PI / 2.0 + sweep,
				48,
				color,
				PENDING_RING_WIDTH,
				true
			)
		else:
			_overlay.draw_arc(eye.global_position, ring_radius, 0.0, TAU, 48, color, 2.0, true)
		var text_at := eye.global_position + Vector2(-ring_radius, ring_radius + 16.0)
		_overlay.draw_string(
			font, text_at, part, HORIZONTAL_ALIGNMENT_CENTER, ring_radius * 2.0, 13, color
		)


## Which source won, and what the tilt is doing. Worth showing: the whole point
## of the port is that this line changes on a phone and nothing else does.
func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	_readout = UiTheme.label("", UiTheme.HUD_FAINT)
	_readout.position = Vector2(16.0, 12.0)
	layer.add_child(_readout)
	SafeArea.offset_layer(layer, get_viewport())
	add_child(layer)
	_motion.source_changed.connect(_on_source_changed)
	_on_source_changed(_motion.get_source_description())


func _on_source_changed(description: String) -> void:
	if _readout != null:
		_readout.text = "motion: %s" % description


func _make_eye(index: int, extent: Vector2) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.name = "Eye%d" % index
	eye.position = Vector2(randf_range(0.15, 0.85), randf_range(0.15, 0.85)) * extent
	eye.radius = randf_range(26.0, 62.0)
	eye.iris_color = ArtPalette.dye(index)
	# Bigger eyes shove more water and are harder for it to shove back.
	eye.wake_radius = eye.radius * 2.2
	eye.wake_strength = 5.0 + eye.radius * 0.07
	eye.drag = 4.4 - eye.radius * 0.03
	eye.paint_amount = 0.55
	eye.paint_color = eye.iris_color.lerp(ArtPalette.WASH, 0.35)
	eye.paint_radius = eye.radius * 1.4
	return eye

extends Control
## Tilt readout: which source is live, what it reports, and the scene leaning
## the way a level's would.
##
## The bring-up tool for a new device. Nothing in [code]core/motion[/code] can
## say what a device's axes mean — the pipeline is orientation-agnostic by
## construction precisely so that it need not — but "tilt right, the horizon
## rolls left" is a claim about real hardware, and this is where it is checked
## in the ten seconds it deserves rather than by reading a driver.
##
## C, or the recentre button, takes the pose being held as level.

## Radius of the tilt dial, in pixels.
const DIAL_RADIUS := 90.0

## Length of the drawn horizon, in pixels.
const HORIZON_HALF_WIDTH := 220.0

const INK := Color(0.20, 0.22, 0.26, 0.85)
const FAINT := Color(0.20, 0.22, 0.26, 0.30)
const LIVE := Color(0.35, 0.55, 0.85, 0.95)

var _motion: MotionInput
var _readout: Label
var _jogs: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_motion = MotionInput.new()
	_motion.name = "MotionInput"
	add_child(_motion)
	_motion.jogged.connect(func(_direction: Vector2) -> void: _jogs += 1)

	_readout = Label.new()
	_readout.name = "Readout"
	_readout.position = Vector2(16.0, 12.0)
	_readout.add_theme_color_override("font_color", INK)
	add_child(_readout)

	var hint := Label.new()
	hint.name = "Hint"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 16.0
	hint.offset_top = -34.0
	hint.add_theme_color_override("font_color", FAINT)
	hint.text = "tilt the device · arrows tilt on a desktop · space jogs · C recentres"
	add_child(hint)


func _process(_delta: float) -> void:
	var offset := _scene_offset()
	var gravity := _motion.gravity
	var lines := PackedStringArray()
	lines.append("source: %s" % _motion.get_source_description())
	lines.append("calibrated: %s" % ("yes" if _motion.is_calibrated() else "no"))
	lines.append("gravity: %+6.2f %+6.2f %+6.2f m/s^2" % [gravity.x, gravity.y, gravity.z])
	lines.append("tilt: %+.2f %+.2f" % [_motion.tilt.x, _motion.tilt.y])
	lines.append("scene: roll %+.1f°  pitch %+.1f°" % [rad_to_deg(offset.x), rad_to_deg(offset.y)])
	lines.append("jogs: %d" % _jogs)
	_readout.text = "\n".join(lines)
	queue_redraw()


## What a panorama level would be doing with this tilt, borrowed from the
## driver that does it rather than copied: the demo is only worth anything if
## it shows the mapping levels actually use.
func _scene_offset() -> Vector2:
	return MotionTiltDriver.offset_for_spans(
		_motion.tilt, MotionTiltDriver.DEFAULT_ROLL_DEGREES, MotionTiltDriver.DEFAULT_PITCH_DEGREES
	)


func _draw() -> void:
	var offset := _scene_offset()
	var centre := size * 0.5

	# The horizon, leaning as a level's would. Pitch moves it up the view the
	# same way the camera's would, at a pixels-per-radian guess that only has
	# to make the movement visible.
	draw_set_transform(centre + Vector2(0.0, offset.y * DIAL_RADIUS * 4.0), offset.x, Vector2.ONE)
	draw_line(Vector2(-HORIZON_HALF_WIDTH, 0.0), Vector2(HORIZON_HALF_WIDTH, 0.0), LIVE, 3.0)
	for x in [-1.0, -0.5, 0.5, 1.0]:
		var foot := Vector2(x * HORIZON_HALF_WIDTH, 0.0)
		draw_line(foot, foot + Vector2(0.0, 26.0), FAINT, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The tilt itself, before any of that mapping: full deflection is the rim.
	var dial := Vector2(size.x - DIAL_RADIUS - 40.0, DIAL_RADIUS + 40.0)
	draw_arc(dial, DIAL_RADIUS, 0.0, TAU, 64, FAINT, 2.0)
	draw_arc(dial, DIAL_RADIUS * _motion.tilt_deadzone, 0.0, TAU, 32, FAINT, 1.0)
	draw_circle(dial + _motion.tilt * DIAL_RADIUS, 7.0, LIVE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(MotionInput.RECENTRE_ACTION):
		_motion.calibrate()

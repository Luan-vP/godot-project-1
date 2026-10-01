extends GutTest
## Covers [MotionTiltDriver]: the mapping from device tilt to the angle the
## scene sits at, and that a tilt actually reaches a camera.
##
## Driven through a [ScriptedMotionSource], the same way [MotionInput]'s own
## tests are, because no real device reports in CI.

const STEP := 1.0 / 60.0
const G := 9.80665
const UPRIGHT := Vector3(0.0, -G, 0.0)

var _camera: PanoramaLookCamera
var _motion: MotionInput
var _source: ScriptedMotionSource
var _driver: MotionTiltDriver


func before_each() -> void:
	_camera = PanoramaLookCamera.new()
	_camera.name = "PanoramaLookCamera"
	_camera.capture_mouse = false
	add_child_autofree(_camera)
	_camera.set_process(false)
	_camera.get_look_input().clear_sources()

	_motion = MotionInput.new()
	_motion.name = "MotionInput"
	add_child_autofree(_motion)
	_motion.set_process(false)
	_motion.tilt_smoothing = 0.0
	_motion.tilt_deadzone = 0.0
	_motion.tilt_span_degrees = 30.0
	_source = ScriptedMotionSource.new()
	_motion.set_source(_source)

	# Added last and left unwired: finding the camera and the input for itself
	# is how a level uses it, so that is what is worth exercising.
	_driver = MotionTiltDriver.new()
	add_child_autofree(_driver)


func after_each() -> void:
	ComfortSettings.look_sensitivity_multiplier = 1.0


## Gravity for a device rotated [param degrees] about the screen's horizontal
## axis, from upright — its right-hand edge dipping.
func _tilted(degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(sin(angle), -cos(angle), 0.0) * G


func _step(gravity: Vector3, frames := 1) -> void:
	for _i in frames:
		_source.push(gravity)
		_motion._process(STEP)


func test_level_leaves_the_scene_alone() -> void:
	_step(UPRIGHT)
	assert_eq(_driver.offset_for(Vector2.ZERO), Vector2.ZERO, "No tilt, no lean")
	assert_eq(_camera.tilt_offset, Vector2.ZERO, "And the camera stays put")


func test_tilting_right_rolls_the_horizon_left() -> void:
	# The scene stays where it was in the world, the way the view through a
	# window does, rather than following the screen round.
	_step(UPRIGHT)
	_step(_tilted(30.0))
	assert_lt(_camera.tilt_offset.x, 0.0, "A right-hand lean should roll the horizon left")
	assert_almost_eq(
		rad_to_deg(_camera.tilt_offset.x), -_driver.roll_degrees, 0.01, "Full tilt, full roll"
	)


func test_the_lean_comes_back_when_the_device_does() -> void:
	# The whole reason tilt is an offset rather than a turn: it recentres.
	_step(UPRIGHT)
	_step(_tilted(30.0))
	assert_lt(_camera.tilt_offset.x, 0.0, "Leaning")
	_step(UPRIGHT)
	assert_almost_eq(_camera.tilt_offset.x, 0.0, 0.0001, "And back to level")


func test_a_negative_span_flips_the_direction() -> void:
	_driver.roll_degrees = -_driver.roll_degrees
	assert_gt(_driver.offset_for(Vector2(1.0, 0.0)).x, 0.0, "Negative spans reverse the lean")


func test_a_zero_span_uses_only_the_other_axis() -> void:
	_driver.roll_degrees = 0.0
	var offset := _driver.offset_for(Vector2(1.0, 1.0))
	assert_almost_eq(offset.x, 0.0, 0.0001, "No roll")
	assert_lt(offset.y, 0.0, "Pitch still moves")


func test_comfort_settings_scale_the_lean() -> void:
	# A tilting horizon is exactly what a player pulling back from motion is
	# pulling back from, so the same setting that calms looking around has to
	# reach this too.
	var full := _driver.offset_for(Vector2(1.0, 0.0))
	ComfortSettings.look_sensitivity_multiplier = 0.5
	var halved := _driver.offset_for(Vector2(1.0, 0.0))
	assert_almost_eq(halved.x, full.x * 0.5, 0.0001, "Half as sensitive, half the lean")


func test_comfort_settings_can_be_turned_off_for_a_driver() -> void:
	_driver.apply_comfort_settings = false
	ComfortSettings.look_sensitivity_multiplier = 0.5
	assert_almost_eq(
		rad_to_deg(_driver.offset_for(Vector2(1.0, 0.0)).x),
		-_driver.roll_degrees,
		0.01,
		"An opted-out driver keeps its own spans"
	)

extends GutTest
## Drives the whole motion pipeline headlessly through a scripted source.
##
## This is what the port is for. None of the code under test here can be
## reached from CI or from a development desktop by any other route: real
## sensors report nothing on either.

const STEP := 1.0 / 60.0
const G := 9.80665
const UPRIGHT := Vector3(0.0, -G, 0.0)

var _motion: MotionInput
var _source: ScriptedMotionSource


func before_each() -> void:
	_motion = MotionInput.new()
	add_child_autofree(_motion)
	# Drive _process by hand so the pipeline advances in known steps.
	_motion.set_process(false)
	_motion.tilt_smoothing = 0.0
	_motion.tilt_deadzone = 0.0
	_motion.tilt_span_degrees = 30.0
	_source = ScriptedMotionSource.new()
	_motion.set_source(_source)


## Gravity for a device rotated [param degrees] about the screen's horizontal
## axis, from upright.
func _tilted(degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(sin(angle), -cos(angle), 0.0) * G


func _step(gravity: Vector3, acceleration := Vector3.ZERO, frames := 1) -> void:
	for _i in frames:
		_source.push(gravity, acceleration)
		_motion._process(STEP)


func test_the_source_can_be_swapped() -> void:
	assert_eq(_motion.get_source(), _source, "Scripted source should be installed")
	assert_eq(_motion.get_source_description(), "scripted", "Description should follow")


func test_the_first_reading_becomes_level() -> void:
	_step(UPRIGHT)
	assert_true(_motion.is_calibrated(), "Auto-calibration should have run")
	assert_almost_eq(_motion.tilt.length(), 0.0, 0.001, "Reference pose is level")


func test_tilting_the_device_produces_tilt() -> void:
	_step(UPRIGHT)
	_step(_tilted(30.0))
	assert_almost_eq(_motion.tilt.x, 1.0, 0.001, "Full tilt")
	assert_almost_eq(_motion.tilt.y, 0.0, 0.001, "No tilt on the other axis")


func test_tilt_changes_are_announced() -> void:
	_step(UPRIGHT)
	watch_signals(_motion)
	_step(_tilted(20.0))
	assert_signal_emitted(_motion, "tilt_changed", "Should announce the change")


func test_a_shake_emits_one_jog() -> void:
	_step(UPRIGHT)
	watch_signals(_motion)
	# One physical shake spans many frames; it must still be one jog.
	_step(UPRIGHT, Vector3(16.0, 0.0, 0.0), 20)
	assert_signal_emit_count(_motion, "jogged", 1, "One shake, one jog")


func test_a_still_device_never_jogs() -> void:
	_step(UPRIGHT)
	watch_signals(_motion)
	_step(UPRIGHT, Vector3(1.5, 0.0, 0.0), 60)
	assert_signal_not_emitted(_motion, "jogged", "Holding still is not a shake")


func test_a_sensorless_platform_produces_nothing() -> void:
	_source.set_available(false)
	watch_signals(_motion)
	_step(_tilted(30.0), Vector3(30.0, 0.0, 0.0), 30)
	assert_signal_not_emitted(_motion, "tilt_changed", "No readings, no tilt")
	assert_signal_not_emitted(_motion, "jogged", "No readings, no jog")
	assert_almost_eq(_motion.tilt.length(), 0.0, 0.001, "Tilt should stay at rest")


func test_recalibrating_makes_the_held_pose_level() -> void:
	_step(UPRIGHT)
	var held := _tilted(25.0)
	_step(held)
	assert_gt(_motion.tilt.length(), 0.5, "Tilted before recalibrating")

	_source.push(held)
	_motion.calibrate()
	_step(held)
	assert_almost_eq(_motion.tilt.length(), 0.0, 0.001, "Held pose is now level")


func test_smoothing_delays_the_response() -> void:
	_motion.tilt_smoothing = 0.2
	_step(UPRIGHT)
	_step(_tilted(30.0))
	assert_gt(_motion.tilt.x, 0.0, "Should start moving")
	assert_lt(_motion.tilt.x, 1.0, "Should not arrive in one frame")
	_step(_tilted(30.0), Vector3.ZERO, 120)
	assert_almost_eq(_motion.tilt.x, 1.0, 0.001, "Should arrive given time")


func test_tilt_converges_fully_and_returns_to_rest() -> void:
	# Smoothing takes ever-smaller steps as it converges. Gating the state
	# update on the signal epsilon — rather than the emit alone — freezes the
	# tilt just short of its target, and on the way back leaves the current
	# permanently leaning with no way to clear it but a recalibrate.
	_motion.tilt_smoothing = 0.2
	_step(UPRIGHT)
	_step(_tilted(30.0), Vector3.ZERO, 120)
	assert_almost_eq(_motion.tilt.x, 1.0, 0.001, "Should reach full tilt, not stall near it")
	_step(UPRIGHT, Vector3.ZERO, 120)
	assert_almost_eq(_motion.tilt.length(), 0.0, 0.001, "Should settle all the way back to rest")

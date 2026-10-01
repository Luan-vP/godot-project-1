extends GutTest
## Covers the stateful gaze pipeline through a scripted backend: calibration,
## the held-look rate, and what blinks, lost faces and stalled frames do to it.

const STEP := 1.0 / 60.0
const NEUTRAL := Vector2(0.0, -0.2)

var _backend: ScriptedEyeGazeBackend
var _filter: EyeGazeFilter


func before_each() -> void:
	_backend = ScriptedEyeGazeBackend.new()
	_filter = EyeGazeFilter.new()


## Look at [param gaze] for [param seconds], a camera frame per game frame.
func _look(gaze: Vector2, seconds: float, dt: float = STEP, blink: float = 0.0) -> Vector2:
	var rate := Vector2.ZERO
	for _i in roundi(seconds / dt):
		_backend.look(gaze, 1.0, blink)
		rate = _filter.feed(_backend.poll(), dt)
	return rate


func _lose_face(seconds: float) -> Vector2:
	var rate := Vector2.ZERO
	for _i in roundi(seconds / STEP):
		_backend.lose_face()
		rate = _filter.feed(_backend.poll(), STEP)
	return rate


## Calibrate on [constant NEUTRAL], then let the gaze filter settle there.
func _calibrated() -> void:
	_look(NEUTRAL, _filter.calibration_seconds + 0.5)


## Neutral plus [param fraction] of the span to the right.
func _right(fraction: float) -> Vector2:
	return NEUTRAL + Vector2(_filter.span.x * fraction, 0.0)


func test_nothing_turns_before_calibration_has_finished() -> void:
	var rate := _look(_right(1.0), _filter.calibration_seconds * 0.5)
	assert_eq(rate, Vector2.ZERO, "No neutral yet, so no turn")


func test_the_first_usable_gaze_calibrates_itself() -> void:
	# The front camera sits above the screen, so a look at the middle reads
	# as looking down. That has to become neutral, not a downward turn.
	_calibrated()
	assert_true(_filter.is_calibrated(), "Should have calibrated without being asked")
	assert_almost_eq(_filter.neutral.y, NEUTRAL.y, 0.001, "Neutral pitch")
	assert_almost_eq(_filter.rate.length(), 0.0, 0.0001, "Looking at neutral turns nothing")


func test_a_look_held_at_the_edge_turns_at_full_rate() -> void:
	_calibrated()
	var rate := _look(_right(1.0), 3.0)
	assert_almost_eq(rate.x, _filter.max_rate.x, 0.01, "Full yaw rate, turning right")
	assert_almost_eq(rate.y, 0.0, 0.001, "No pitch")


func test_looking_up_pitches_up() -> void:
	_calibrated()
	var rate := _look(NEUTRAL + Vector2(0.0, _filter.span.y), 3.0)
	assert_almost_eq(rate.y, -_filter.max_rate.y, 0.01, "Negative y pitches the camera up")


func test_a_look_inside_the_dead_zone_turns_nothing() -> void:
	_calibrated()
	var rate := _look(_right(_filter.deadzone * 0.9), 3.0)
	assert_almost_eq(rate.x, 0.0, 0.0001, "Inside the zone")


func test_a_quick_glance_barely_starts_a_turn() -> void:
	_calibrated()
	var rate := _look(_right(1.0), 0.1)
	assert_gt(rate.x, 0.0, "It should have started")
	assert_lt(rate.x, _filter.max_rate.x * 0.4, "But a glance should not reach full rate")


func test_a_blink_within_the_grace_does_not_interrupt_a_turn() -> void:
	_calibrated()
	_look(_right(1.0), 3.0)
	var during := _look(_right(1.0), 0.15, STEP, 1.0)
	assert_almost_eq(during.x, _filter.max_rate.x, 0.01, "Turn carries on through a blink")


func test_the_blink_itself_does_not_steer() -> void:
	_calibrated()
	# A closing eye's gaze swings; those readings must be ignored.
	var rate := _look(_right(1.0), 0.2, STEP, 1.0)
	assert_almost_eq(rate.x, 0.0, 0.0001, "Blinking readings are not a look")


func test_a_lost_face_eases_the_turn_out_rather_than_stopping_dead() -> void:
	_calibrated()
	_look(_right(1.0), 3.0)
	var just_after := _lose_face(_filter.dropout_grace + STEP * 2.0)
	assert_gt(just_after.x, _filter.max_rate.x * 0.5, "Still easing out just after the grace")
	var later := _lose_face(2.0)
	assert_almost_eq(later.x, 0.0, 0.001, "Stopped once the face has been gone a while")
	assert_false(_filter.has_gaze(), "No gaze")


func test_a_stalled_backend_stops_steering() -> void:
	_calibrated()
	_look(_right(1.0), 3.0)
	# Still claiming TRACKING, but no new frames.
	var rate := Vector2.ZERO
	for _i in roundi(3.0 / STEP):
		_backend.hold()
		rate = _filter.feed(_backend.poll(), STEP)
	assert_almost_eq(rate.x, 0.0, 0.001, "Repeated frames past stale_after are not a look")


func test_polling_faster_than_the_camera_still_turns() -> void:
	_calibrated()
	var rate := Vector2.ZERO
	# A 120 Hz display over a 60 Hz camera: every other poll repeats a frame.
	for i in roundi(3.0 / (STEP * 0.5)):
		if i % 2 == 0:
			_backend.look(_right(1.0))
		rate = _filter.feed(_backend.poll(), STEP * 0.5)
	assert_almost_eq(rate.x, _filter.max_rate.x, 0.01, "Repeats within stale_after are fine")


func test_the_turn_does_not_depend_on_the_frame_rate() -> void:
	_filter.auto_calibrate = false
	_filter.calibrate()
	_look(NEUTRAL, 1.0, 1.0 / 30.0)
	var slow := _look(_right(1.0), 0.5, 1.0 / 30.0).x

	before_each()
	_filter.auto_calibrate = false
	_filter.calibrate()
	_look(NEUTRAL, 1.0, 1.0 / 150.0)
	var fast := _look(_right(1.0), 0.5, 1.0 / 150.0).x
	assert_almost_eq(slow, fast, 0.03, "Half a second of a held look at 30 and 150 fps")


func test_reacquiring_a_face_snaps_to_the_new_gaze() -> void:
	_calibrated()
	_look(_right(1.0), 1.0)
	_lose_face(1.0)
	var left := NEUTRAL - Vector2(_filter.span.x, 0.0)
	_look(left, STEP)
	assert_eq(_filter.smoothed_gaze, left, "No sweep across from the stale gaze")


func test_recalibrating_stops_the_turn_and_takes_the_new_neutral() -> void:
	_calibrated()
	_look(_right(1.0), 3.0)
	_filter.calibrate()
	var listening := _look(_right(1.0), _filter.calibration_seconds * 0.5)
	assert_lt(listening.x, _filter.max_rate.x * 0.5, "Easing out while listening")
	var after := _look(_right(1.0), 3.0)
	assert_almost_eq(_filter.neutral.x, _right(1.0).x, 0.001, "The held look is neutral now")
	assert_almost_eq(after.x, 0.0, 0.001, "And turns nothing")


func test_unconfident_readings_are_ignored() -> void:
	_calibrated()
	var rate := Vector2.ZERO
	for _i in roundi(0.2 / STEP):
		_backend.look(_right(1.0), 0.1)
		rate = _filter.feed(_backend.poll(), STEP)
	assert_almost_eq(rate.x, 0.0, 0.0001, "Low confidence is not a look")

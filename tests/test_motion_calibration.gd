extends GutTest
## Covers turning raw device gravity into screen-space tilt.

const EPSILON := 0.0005
const G := 9.80665

## Gravity for a device held upright and level.
const UPRIGHT := Vector3(0.0, -G, 0.0)

var _calibration: MotionCalibration


func before_each() -> void:
	_calibration = MotionCalibration.new()


func _assert_vector(got: Vector2, expected: Vector2, context: String) -> void:
	assert_almost_eq(got.x, expected.x, EPSILON, "%s (x)" % context)
	assert_almost_eq(got.y, expected.y, EPSILON, "%s (y)" % context)


## Gravity for a device rotated [param degrees] about the screen's horizontal
## axis, from the upright reference.
func _tilted_sideways(degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(sin(angle), -cos(angle), 0.0) * G


func test_an_uncalibrated_reading_produces_no_tilt() -> void:
	assert_false(_calibration.is_calibrated(), "Should start uncalibrated")
	_assert_vector(_calibration.tilt_from(UPRIGHT, 30.0), Vector2.ZERO, "Uncalibrated")
	_assert_vector(_calibration.project(Vector3(1.0, 2.0, 3.0)), Vector2.ZERO, "Projection")


func test_calibration_rejects_a_reading_with_no_direction() -> void:
	assert_false(_calibration.calibrate(Vector3.ZERO), "A zero vector is not a direction")
	assert_false(_calibration.is_calibrated(), "Should stay uncalibrated")


func test_holding_the_reference_pose_reads_as_level() -> void:
	assert_true(_calibration.calibrate(UPRIGHT), "Calibration should succeed")
	_assert_vector(_calibration.tilt_from(UPRIGHT, 30.0), Vector2.ZERO, "Level")


func test_a_full_span_tilt_reads_as_one() -> void:
	_calibration.calibrate(UPRIGHT)
	var tilt := _calibration.tilt_from(_tilted_sideways(30.0), 30.0)
	assert_almost_eq(tilt.length(), 1.0, EPSILON, "Tilted the full span")
	assert_gt(tilt.x, 0.0, "Tilting towards +X should read positive")


func test_tilt_scales_with_the_angle() -> void:
	_calibration.calibrate(UPRIGHT)
	# Reported tilt is the sine of the angle over the sine of the span.
	var half := _calibration.tilt_from(_tilted_sideways(15.0), 30.0)
	assert_almost_eq(half.x, sin(deg_to_rad(15.0)) / sin(deg_to_rad(30.0)), EPSILON, "Half")


func test_tilt_is_clamped_past_the_span() -> void:
	_calibration.calibrate(UPRIGHT)
	var tilt := _calibration.tilt_from(_tilted_sideways(75.0), 30.0)
	assert_almost_eq(tilt.length(), 1.0, EPSILON, "Well past the span")


func test_tilting_the_other_way_reverses_the_sign() -> void:
	_calibration.calibrate(UPRIGHT)
	var positive := _calibration.tilt_from(_tilted_sideways(20.0), 30.0)
	var negative := _calibration.tilt_from(_tilted_sideways(-20.0), 30.0)
	_assert_vector(negative, -positive, "Mirrored tilt")


func test_calibration_works_from_a_device_lying_flat() -> void:
	# The case a hard-coded "down is -Y" assumption gets wrong: someone playing
	# with the device flat on a table.
	var flat := Vector3(0.0, 0.0, -G)
	assert_true(_calibration.calibrate(flat), "Flat should calibrate")
	_assert_vector(_calibration.tilt_from(flat, 30.0), Vector2.ZERO, "Flat is level")

	var angle := deg_to_rad(30.0)
	var lifted := Vector3(sin(angle), 0.0, -cos(angle)) * G
	var tilt := _calibration.tilt_from(lifted, 30.0)
	assert_almost_eq(tilt.length(), 1.0, EPSILON, "Full tilt from a flat reference")


func test_recalibrating_makes_the_current_pose_level() -> void:
	_calibration.calibrate(UPRIGHT)
	var held := _tilted_sideways(20.0)
	assert_gt(_calibration.tilt_from(held, 30.0).length(), 0.5, "Tilted before recalibrating")

	_calibration.calibrate(held)
	_assert_vector(_calibration.tilt_from(held, 30.0), Vector2.ZERO, "Now level")


func test_reset_forgets_the_reference() -> void:
	_calibration.calibrate(UPRIGHT)
	_calibration.reset()
	assert_false(_calibration.is_calibrated(), "Should be uncalibrated again")

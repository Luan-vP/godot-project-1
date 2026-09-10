extends GutTest
## Covers the smoothing and dead-zone helpers.

const EPSILON := 0.0005


func _assert_vector(got: Vector2, expected: Vector2, context: String) -> void:
	assert_almost_eq(got.x, expected.x, EPSILON, "%s (x)" % context)
	assert_almost_eq(got.y, expected.y, EPSILON, "%s (y)" % context)


func _smooth_for_one_second(steps: int, time_constant: float) -> Vector2:
	var value := Vector2.ZERO
	var target := Vector2(1.0, 0.0)
	for _i in steps:
		value = MotionFilter.smooth(value, target, time_constant, 1.0 / float(steps))
	return value


func test_smoothing_moves_towards_the_target() -> void:
	var once := MotionFilter.smooth(Vector2.ZERO, Vector2(1.0, 0.0), 0.25, 1.0 / 60.0)
	assert_gt(once.x, 0.0, "Should move towards the target")
	assert_lt(once.x, 1.0, "Should not arrive in one step")


func test_smoothing_does_not_depend_on_the_frame_rate() -> void:
	# The property that matters: a second of smoothing lands in the same place
	# whether that second was 30 frames or 144. A per-frame factor would not.
	var slow := _smooth_for_one_second(30, 0.25)
	var fast := _smooth_for_one_second(144, 0.25)
	_assert_vector(slow, fast, "One second at two frame rates")
	# Analytically, the remaining gap after time t is exp(-t / time_constant).
	assert_almost_eq(slow.x, 1.0 - exp(-1.0 / 0.25), EPSILON, "Closed gap")


func test_a_zero_time_constant_snaps() -> void:
	var target := Vector2(0.3, -0.7)
	_assert_vector(MotionFilter.smooth(Vector2.ZERO, target, 0.0, 0.016), target, "No smoothing")


func test_a_zero_delta_snaps_rather_than_dividing_by_zero() -> void:
	var target := Vector2(0.3, -0.7)
	_assert_vector(MotionFilter.smooth(Vector2.ZERO, target, 0.25, 0.0), target, "Zero delta")


func test_the_deadzone_suppresses_small_readings() -> void:
	_assert_vector(MotionFilter.apply_deadzone(Vector2(0.05, 0.0), 0.1), Vector2.ZERO, "Inside")
	_assert_vector(MotionFilter.apply_deadzone(Vector2.ZERO, 0.1), Vector2.ZERO, "Exactly zero")


func test_the_deadzone_ramps_from_zero_rather_than_jumping() -> void:
	# A bare threshold would output 0.2 the instant it engaged, which reads as
	# a broken sensor. Just outside the zone the output should be near zero.
	var just_outside := MotionFilter.apply_deadzone(Vector2(0.2001, 0.0), 0.2)
	assert_almost_eq(just_outside.x, 0.0, 0.001, "Just outside the zone")


func test_the_deadzone_preserves_full_deflection() -> void:
	var full := MotionFilter.apply_deadzone(Vector2(1.0, 0.0), 0.2)
	assert_almost_eq(full.x, 1.0, EPSILON, "Full tilt should still be full")


func test_the_deadzone_preserves_direction() -> void:
	var value := Vector2(0.6, -0.8)
	var result := MotionFilter.apply_deadzone(value, 0.2)
	assert_almost_eq(
		result.normalized().dot(value.normalized()), 1.0, EPSILON, "Direction unchanged"
	)

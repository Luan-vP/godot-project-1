extends GutTest
## Covers the drift law that carries a body along the current.

const EPSILON := 0.0001


func _assert_vector(got: Vector2, expected: Vector2, context: String) -> void:
	assert_almost_eq(got.x, expected.x, EPSILON, "%s (x)" % context)
	assert_almost_eq(got.y, expected.y, EPSILON, "%s (y)" % context)


func test_without_drag_the_body_ignores_the_current() -> void:
	var result := FluidBody.drift(Vector2(10.0, 0.0), Vector2(0.0, 90.0), 0.0, 0.0, 1000.0, 0.1)
	_assert_vector(result, Vector2(10.0, 0.0), "Zero drag")


func test_drag_pulls_the_body_towards_the_current() -> void:
	var result := FluidBody.drift(Vector2(10.0, 0.0), Vector2(0.0, 0.0), 5.0, 0.0, 1000.0, 0.1)
	_assert_vector(result, Vector2(5.0, 0.0), "Half of the difference in one step")


func test_a_body_already_moving_with_the_current_is_left_alone() -> void:
	var flow := Vector2(30.0, -12.0)
	var result := FluidBody.drift(flow, flow, 8.0, 0.0, 1000.0, 0.2)
	_assert_vector(result, flow, "Matched to the flow")


func test_a_long_step_snaps_to_the_current_instead_of_overshooting() -> void:
	# drag_rate * delta well past 1 would invert the pull if it were not
	# clamped, and the body would oscillate harder every frame.
	var result := FluidBody.drift(Vector2(100.0, 0.0), Vector2(0.0, 0.0), 40.0, 0.0, 1000.0, 0.5)
	_assert_vector(result, Vector2.ZERO, "Clamped pull")


func test_buoyancy_only_affects_the_vertical() -> void:
	var result := FluidBody.drift(Vector2(4.0, 0.0), Vector2(4.0, 0.0), 1.0, -20.0, 1000.0, 0.5)
	_assert_vector(result, Vector2(4.0, -10.0), "Rising body")


func test_speed_is_capped() -> void:
	var result := FluidBody.drift(Vector2(300.0, 400.0), Vector2.ZERO, 0.0, 0.0, 50.0, 0.1)
	assert_almost_eq(result.length(), 50.0, EPSILON, "Speed limit")
	_assert_vector(result, Vector2(30.0, 40.0), "Direction preserved")

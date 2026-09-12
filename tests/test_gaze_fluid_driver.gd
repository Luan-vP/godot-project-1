extends GutTest
## Covers the pure mapping from angular velocity to the tank's two forcing
## channels — the part of [GazeFluidDriver] that can be checked without a
## camera, a tank, or a GPU. The wiring around it (finding the camera and the
## tank, calling them once a frame) is exercised the same way
## [code]FluidMotionDriver[/code]'s is: not at all, since none of it is more
## than a resolve-and-forward.

const EPSILON := 0.0001


func _assert_vector(got: Vector2, expected: Vector2, context: String) -> void:
	assert_almost_eq(got.x, expected.x, EPSILON, "%s (x)" % context)
	assert_almost_eq(got.y, expected.y, EPSILON, "%s (y)" % context)


func test_looking_slower_than_the_deadzone_produces_no_bias() -> void:
	var bias := GazeFluidDriver.hold_bias(Vector2(0.02, -0.01), 0.05, 300.0)
	_assert_vector(bias, Vector2.ZERO, "Below the deadzone")


func test_a_held_turn_produces_a_proportional_bias() -> void:
	# Zero deadzone isolates the scaling from the dead-zone rescale, which
	# test_motion_filter.gd already covers on its own.
	var bias := GazeFluidDriver.hold_bias(Vector2(2.0, -1.0), 0.0, 300.0)
	_assert_vector(bias, Vector2(600.0, -300.0), "Bias should scale with sensitivity")


func test_the_bias_is_not_flipped_relative_to_the_raw_angular_velocity() -> void:
	# The whole mapping hinges on using angular_velocity unflipped — see the
	# class doc for why that already points the way floaters should sweep.
	# Flipping a sign here would silently invert every direction in the game.
	var bias := GazeFluidDriver.hold_bias(Vector2(1.0, 0.0), 0.0, 100.0)
	assert_gt(bias.x, 0.0, "A positive angular velocity should not flip sign")


func test_a_steady_hold_produces_no_repeated_nudge() -> void:
	var held := Vector2(2.5, -0.5)
	var nudge := GazeFluidDriver.flick_nudge(held, held, 0.0, 400.0)
	_assert_vector(nudge, Vector2.ZERO, "Nothing changed, nothing to nudge")


func test_a_flick_from_rest_produces_a_proportional_nudge() -> void:
	var nudge := GazeFluidDriver.flick_nudge(Vector2(4.0, 0.0), Vector2.ZERO, 0.0, 50.0)
	_assert_vector(nudge, Vector2(200.0, 0.0), "Onset of a turn should nudge")


func test_a_turn_settling_back_to_rest_nudges_the_other_way() -> void:
	var start := GazeFluidDriver.flick_nudge(Vector2(4.0, 0.0), Vector2.ZERO, 0.0, 50.0)
	var stop := GazeFluidDriver.flick_nudge(Vector2.ZERO, Vector2(4.0, 0.0), 0.0, 50.0)
	assert_gt(start.x, 0.0, "Turning should nudge one way")
	assert_lt(stop.x, 0.0, "Stopping should nudge the other way")


func test_jitter_below_the_deadzone_never_nudges() -> void:
	# Two different readings, both inside the zone, would difference to a
	# nonzero raw change — the dead-zoning has to happen before the
	# subtraction, not after, or a resting hand would keep faintly nudging.
	var nudge := GazeFluidDriver.flick_nudge(Vector2(0.01, 0.0), Vector2(-0.02, 0.0), 0.05, 400.0)
	_assert_vector(nudge, Vector2.ZERO, "Both readings are inside the deadzone")


func test_a_flick_that_starts_outside_the_deadzone_still_nudges() -> void:
	var nudge := GazeFluidDriver.flick_nudge(Vector2(3.0, 0.0), Vector2.ZERO, 0.05, 50.0)
	assert_gt(nudge.x, 0.0, "A real flick should clear the deadzone and still nudge")

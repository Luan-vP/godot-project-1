extends GutTest
## Covers the wrap that recycles a floater at the tank edge, and the
## non-neutral, non-stirring defaults a floater starts with.

const EPSILON := 0.0001


func test_a_position_inside_the_rect_is_left_alone() -> void:
	var rect := Rect2(Vector2(0.0, 0.0), Vector2(200.0, 100.0))
	var result := Floater.recycled_position(Vector2(50.0, 40.0), rect)
	assert_eq(result, Vector2(50.0, 40.0), "Untouched inside the tank")


func test_drifting_past_the_right_edge_wraps_to_the_left() -> void:
	var rect := Rect2(Vector2(0.0, 0.0), Vector2(200.0, 100.0))
	var result := Floater.recycled_position(Vector2(210.0, 40.0), rect)
	assert_almost_eq(result.x, 0.0, EPSILON, "Wrapped x")
	assert_almost_eq(result.y, 40.0, EPSILON, "y untouched")


func test_drifting_past_the_left_edge_wraps_to_the_right() -> void:
	var rect := Rect2(Vector2(0.0, 0.0), Vector2(200.0, 100.0))
	var result := Floater.recycled_position(Vector2(-10.0, 40.0), rect)
	assert_almost_eq(result.x, 200.0, EPSILON, "Wrapped x")


func test_sinking_out_the_bottom_wraps_to_the_top() -> void:
	# The whole point of a floater is a downward bias, so this is the direction
	# that actually gets exercised in play.
	var rect := Rect2(Vector2(0.0, 0.0), Vector2(200.0, 100.0))
	var result := Floater.recycled_position(Vector2(80.0, 130.0), rect)
	assert_almost_eq(result.y, 0.0, EPSILON, "Wrapped y")
	assert_almost_eq(result.x, 80.0, EPSILON, "x untouched")


func test_a_rect_with_a_non_zero_origin_wraps_relative_to_it() -> void:
	var rect := Rect2(Vector2(500.0, 500.0), Vector2(200.0, 100.0))
	var result := Floater.recycled_position(Vector2(495.0, 550.0), rect)
	assert_almost_eq(result.x, 700.0, EPSILON, "Wrapped relative to origin")


func test_a_floater_starts_non_neutrally_buoyant() -> void:
	var floater := Floater.new()
	autofree(floater)
	assert_gt(floater.buoyancy, 0.0, "Sinks by default")


func test_a_floater_does_not_stir_or_stain_by_default() -> void:
	var floater := Floater.new()
	autofree(floater)
	assert_eq(floater.wake_strength, 0.0, "No wake")
	assert_eq(floater.paint_amount, 0.0, "No paint")


func test_a_floater_is_looser_than_the_default_drag() -> void:
	# Enough inertia to overshoot when the medium swishes, per the issue.
	var floater := Floater.new()
	autofree(floater)
	var baseline := FluidBody.new()
	autofree(baseline)
	assert_lt(floater.drag, baseline.drag, "Looser coupling than a plain FluidBody")


func test_a_floater_is_not_contained_it_wraps_instead() -> void:
	var floater := Floater.new()
	autofree(floater)
	assert_false(floater.contained, "Wrapping replaces the bounce")

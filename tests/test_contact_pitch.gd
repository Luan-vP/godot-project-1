extends GutTest
## Covers [ContactPitch]'s pure position-to-hertz mapping: the endpoints, the
## logarithmic shape, and clamping out-of-range input.

const EPSILON := 0.001


func test_position_zero_is_the_root() -> void:
	assert_almost_eq(ContactPitch.hz_for_position(0.0, 220.0, 12.0), 220.0, EPSILON)


func test_position_one_is_the_span_above_the_root() -> void:
	assert_almost_eq(ContactPitch.hz_for_position(1.0, 220.0, 12.0), 440.0, EPSILON)


func test_position_is_linear_in_semitones_not_hertz() -> void:
	# Halfway along a one-octave span is the geometric mean of the endpoints
	# (a tritone up), not the arithmetic mean — pitch is heard logarithmically.
	var middle := ContactPitch.hz_for_position(0.5, 220.0, 12.0)
	assert_almost_eq(middle, 220.0 * sqrt(2.0), 0.01, "Tritone above the root")


func test_position_is_monotonic() -> void:
	var previous := ContactPitch.hz_for_position(0.0, 220.0, 12.0)
	for i in range(1, 11):
		var current := ContactPitch.hz_for_position(i / 10.0, 220.0, 12.0)
		assert_gt(current, previous, "Higher position is always a higher pitch")
		previous = current


func test_position_below_zero_clamps_to_the_root() -> void:
	assert_almost_eq(ContactPitch.hz_for_position(-0.5, 220.0, 12.0), 220.0, EPSILON)


func test_position_above_one_clamps_to_the_span() -> void:
	assert_almost_eq(ContactPitch.hz_for_position(1.5, 220.0, 12.0), 440.0, EPSILON)

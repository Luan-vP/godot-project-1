extends GutTest
## Covers the pure gaze-to-look maths: normalising, dead zone and curve, the
## sign convention, and which readings count as usable.

const EPSILON := 0.0005
const SPAN := Vector2(0.1, 0.2)


func _sample(state: EyeGazeSample.State, confidence: float, blink: float) -> EyeGazeSample:
	var sample := EyeGazeSample.new()
	sample.state = state
	sample.confidence = confidence
	sample.blink = blink
	return sample


func test_deflection_is_measured_from_neutral_per_axis() -> void:
	var got := EyeGazeMapping.deflection(Vector2(0.15, 0.1), Vector2(0.1, -0.1), SPAN)
	assert_almost_eq(got.x, 0.5, EPSILON, "0.05 of a 0.1 span")
	assert_almost_eq(got.y, 1.0, EPSILON, "0.2 of a 0.2 span")


func test_a_zero_span_produces_nothing_rather_than_infinity() -> void:
	var got := EyeGazeMapping.deflection(Vector2(0.3, 0.3), Vector2.ZERO, Vector2.ZERO)
	assert_eq(got, Vector2.ZERO, "No span, no deflection")


func test_the_dead_zone_is_an_ellipse_in_angle() -> void:
	# The same 0.06 rad off neutral is outside the zone across the narrow
	# axis and inside it along the tall one.
	var across := EyeGazeMapping.deflection(Vector2(0.06, 0.0), Vector2.ZERO, SPAN)
	var along := EyeGazeMapping.deflection(Vector2(0.0, 0.06), Vector2.ZERO, SPAN)
	assert_gt(EyeGazeMapping.shape(across, 0.4, 1.0).length(), 0.0, "Across: outside the zone")
	assert_eq(EyeGazeMapping.shape(along, 0.4, 1.0), Vector2.ZERO, "Along: inside the zone")


func test_shape_ramps_from_zero_at_the_edge_of_the_zone() -> void:
	var just_outside := EyeGazeMapping.shape(Vector2(0.401, 0.0), 0.4, 1.6)
	assert_almost_eq(just_outside.x, 0.0, 0.001, "No lurch as the turn engages")


func test_shape_reaches_full_at_the_span_and_no_further() -> void:
	assert_almost_eq(EyeGazeMapping.shape(Vector2(1.0, 0.0), 0.4, 1.6).x, 1.0, EPSILON, "Edge")
	var beyond := EyeGazeMapping.shape(Vector2(3.0, 0.0), 0.4, 1.6)
	assert_almost_eq(beyond.length(), 1.0, EPSILON, "Off-screen gaze turns no faster")


func test_the_curve_is_gentler_than_linear_in_the_middle() -> void:
	var linear := EyeGazeMapping.shape(Vector2(0.7, 0.0), 0.4, 1.0).x
	var curved := EyeGazeMapping.shape(Vector2(0.7, 0.0), 0.4, 1.6).x
	assert_almost_eq(linear, 0.5, EPSILON, "Halfway between zone and edge")
	assert_almost_eq(curved, pow(0.5, 1.6), EPSILON, "Curved")
	assert_lt(curved, linear, "Curve should soften the middle")


func test_shape_preserves_direction() -> void:
	var value := Vector2(0.6, -0.5)
	var got := EyeGazeMapping.shape(value, 0.3, 2.0)
	assert_almost_eq(got.normalized().dot(value.normalized()), 1.0, EPSILON, "Same direction")


func test_looking_right_turns_right_and_looking_up_pitches_up() -> void:
	# LookSource convention: +x turns right, +y pitches down.
	var rate := EyeGazeMapping.look_rate(Vector2(1.0, 1.0), Vector2(2.0, 1.0))
	assert_almost_eq(rate.x, 2.0, EPSILON, "Gaze right should turn right at the yaw rate")
	assert_almost_eq(rate.y, -1.0, EPSILON, "Gaze up should pitch up at the pitch rate")


func test_only_confident_open_eyed_tracking_is_usable() -> void:
	var tracking := EyeGazeSample.State.TRACKING
	assert_true(EyeGazeMapping.is_usable(_sample(tracking, 0.9, 0.1), 0.5, 0.5), "Good reading")
	assert_false(EyeGazeMapping.is_usable(_sample(tracking, 0.3, 0.1), 0.5, 0.5), "Unconfident")
	assert_false(EyeGazeMapping.is_usable(_sample(tracking, 0.9, 0.8), 0.5, 0.5), "Blinking")
	var no_face := EyeGazeSample.State.NO_FACE
	assert_false(EyeGazeMapping.is_usable(_sample(no_face, 0.9, 0.0), 0.5, 0.5), "No face")

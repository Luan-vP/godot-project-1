extends GutTest
## Covers the shape families as data: each factory should produce the right
## kind and amount of geometry, deterministically for a seeded RNG.

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 1


func test_a_dot_is_a_single_circle_with_no_strands() -> void:
	var shape := FloaterShape.make_dot()
	assert_eq(shape.dots.size(), 1, "One dot")
	assert_eq(shape.strands.size(), 0, "No strands")


func test_a_strand_is_a_single_polyline_with_no_dots() -> void:
	var shape := FloaterShape.make_strand(_rng, 6)
	assert_eq(shape.dots.size(), 0, "No dots")
	assert_eq(shape.strands.size(), 1, "One strand")
	assert_eq(shape.strands[0].size(), 7, "segments + 1 points")


func test_a_cobweb_has_one_hub_and_one_strand_per_arm() -> void:
	var shape := FloaterShape.make_cobweb(_rng, 5)
	assert_eq(shape.dots.size(), 1, "One hub")
	assert_eq(shape.strands.size(), 5, "One strand per arm")
	for strand in shape.strands:
		assert_eq(strand.size(), 3, "Root, elbow, tip")


func test_a_strand_stays_within_its_local_unit_square() -> void:
	var shape := FloaterShape.make_strand(_rng, 8, 0.3)
	for point in shape.strands[0]:
		assert_between(point.x, -1.0, 1.0, "x within unit range")


func test_a_strand_tapers_to_nothing_at_both_tips() -> void:
	var points := FloaterShape.make_strand(RandomNumberGenerator.new(), 6, 0.3).strands[0]
	var widths := FloaterShape.strand_widths(points, 0.2)
	assert_eq(widths[0], 0.0, "First tip")
	assert_eq(widths[widths.size() - 1], 0.0, "Last tip")
	for i in range(1, widths.size() - 1):
		assert_gt(widths[i], 0.0, "Point %d should have some width" % i)


func test_a_tapered_strand_keeps_its_average_width() -> void:
	# A straight, evenly spaced strand, sampled finely so the average is the
	# taper's own rather than an artefact of six points.
	var points := PackedVector2Array()
	for i in 201:
		points.append(Vector2(-1.0 + 2.0 * i / 200.0, 0.0))
	var widths := FloaterShape.strand_widths(points, 0.2)
	var total := 0.0
	for width in widths:
		total += width
	assert_almost_eq(total / widths.size(), 0.2, 0.03, "Average width")


func test_strand_thickness_wanders_along_its_length() -> void:
	var points := PackedVector2Array()
	for i in 201:
		points.append(Vector2(-1.0 + 2.0 * i / 200.0, 0.0))
	var widths := FloaterShape.strand_widths(points, 0.2)
	# A pure sin taper is symmetric about the middle; wander breaks that.
	var asymmetry := 0.0
	for i in 100:
		asymmetry = maxf(asymmetry, absf(widths[i] - widths[200 - i]))
	assert_gt(asymmetry, 0.02, "The two halves should differ")


func test_strand_widths_are_stable_for_the_same_points() -> void:
	var points := FloaterShape.make_strand(RandomNumberGenerator.new(), 6, 0.3).strands[0]
	assert_eq(FloaterShape.strand_widths(points, 0.2), FloaterShape.strand_widths(points, 0.2))

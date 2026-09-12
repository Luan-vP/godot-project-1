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

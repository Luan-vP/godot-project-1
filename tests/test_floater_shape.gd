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


func test_a_dot_is_fully_opaque_at_its_own_centre() -> void:
	var shape := FloaterShape.make_dot()
	assert_almost_eq(shape.alpha_at(Vector2.ZERO), 1.0, 0.001, "Solid at the core")


func test_a_dot_is_fully_transparent_well_outside_its_radius() -> void:
	var shape := FloaterShape.make_dot()
	assert_eq(shape.alpha_at(Vector2(5.0, 5.0)), 0.0, "Nothing far away")


func test_a_dot_has_no_hard_outline() -> void:
	# At exactly its own radius, a hard-edged dot would already be either 1 or
	# 0; a soft one is caught partway through the fade.
	var shape := FloaterShape.make_dot()
	var edge_alpha: float = shape.alpha_at(Vector2(shape.dots[0].z, 0.0))
	assert_between(edge_alpha, 0.05, 0.95, "Softly faded, not a hard cutoff")


func test_alpha_falls_off_monotonically_moving_away_from_a_dot() -> void:
	var shape := FloaterShape.make_dot()
	var previous := 1.0
	for step in range(1, 10):
		var alpha: float = shape.alpha_at(Vector2(float(step) * 0.2, 0.0))
		assert_lte(alpha, previous, "Never brighter further out")
		previous = alpha


func test_a_strand_fades_out_towards_its_own_tips() -> void:
	var shape := FloaterShape.make_strand(_rng, 6, 0.0)
	var middle: float = shape.alpha_at(Vector2.ZERO)
	var tip: float = shape.alpha_at(shape.strands[0][shape.strands[0].size() - 1])
	assert_gt(middle, tip, "Middle reads more solid than the very tip")


func test_rasterize_produces_a_square_image_sized_to_the_radius() -> void:
	var shape := FloaterShape.make_dot()
	var image := shape.rasterize(8.0)
	assert_eq(image.get_width(), image.get_height(), "Square")
	assert_gt(image.get_width(), 16, "Wide enough to cover the radius plus its soft edge")


func test_rasterize_bakes_the_soft_alpha_into_the_image() -> void:
	var shape := FloaterShape.make_dot()
	var image := shape.rasterize(8.0)
	var center := image.get_width() / 2
	var corner_alpha := image.get_pixel(0, 0).a
	var center_alpha := image.get_pixel(center, center).a
	assert_almost_eq(center_alpha, 1.0, 0.05, "Opaque at the centre pixel")
	assert_eq(corner_alpha, 0.0, "Transparent at the far corner")

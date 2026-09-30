extends GutTest
## Covers [EquirectProjection], the sphere embedding [CannyEdgeSource] relies
## on to turn panorama pixels into directions that actually agree with what
## [PanoramaSkyMaterial] renders there.

const EPSILON := 0.001


func test_top_of_the_image_is_straight_up() -> void:
	var direction := EquirectProjection.direction_for_uv(Vector2(0.5, 0.0))
	assert_almost_eq(direction.x, 0.0, EPSILON)
	assert_almost_eq(direction.y, 1.0, EPSILON)
	assert_almost_eq(direction.z, 0.0, EPSILON)


func test_bottom_of_the_image_is_straight_down() -> void:
	var direction := EquirectProjection.direction_for_uv(Vector2(0.5, 1.0))
	assert_almost_eq(direction.x, 0.0, EPSILON)
	assert_almost_eq(direction.y, -1.0, EPSILON)
	assert_almost_eq(direction.z, 0.0, EPSILON)


func test_left_edge_of_the_equator_faces_backward_on_the_z_axis() -> void:
	var direction := EquirectProjection.direction_for_uv(Vector2(0.0, 0.5))
	assert_almost_eq(direction.x, 0.0, EPSILON)
	assert_almost_eq(direction.y, 0.0, EPSILON)
	assert_almost_eq(direction.z, -1.0, EPSILON)


func test_directions_are_unit_length() -> void:
	var samples := [Vector2(0.1, 0.2), Vector2(0.4, 0.5), Vector2(0.9, 0.75)]
	for uv in samples:
		assert_almost_eq(EquirectProjection.direction_for_uv(uv).length(), 1.0, EPSILON)


func test_uv_for_direction_is_the_inverse_of_direction_for_uv() -> void:
	var samples := [
		Vector2(0.0, 0.5),
		Vector2(0.25, 0.3),
		Vector2(0.5, 0.5),
		Vector2(0.75, 0.65),
		Vector2(0.9, 0.2),
	]
	for uv in samples:
		var direction := EquirectProjection.direction_for_uv(uv)
		var round_tripped := EquirectProjection.uv_for_direction(direction)
		assert_almost_eq(round_tripped.x, uv.x, EPSILON)
		assert_almost_eq(round_tripped.y, uv.y, EPSILON)


func test_the_same_u_step_produces_a_shorter_chord_near_a_pole() -> void:
	# The whole reason CannyEdgeSource embeds pixels through this class rather
	# than treating the image as a uniform pixel grid: the same delta-u step
	# is a much smaller physical distance near a pole than at the equator.
	var equator_a := EquirectProjection.direction_for_uv(Vector2(0.45, 0.5))
	var equator_b := EquirectProjection.direction_for_uv(Vector2(0.55, 0.5))
	var equator_chord := (equator_a - equator_b).length()

	var near_pole_a := EquirectProjection.direction_for_uv(Vector2(0.45, 0.05))
	var near_pole_b := EquirectProjection.direction_for_uv(Vector2(0.55, 0.05))
	var near_pole_chord := (near_pole_a - near_pole_b).length()

	assert_lt(near_pole_chord, equator_chord, "Same u step, shorter chord near the pole")

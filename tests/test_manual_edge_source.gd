extends GutTest
## Covers [ManualEdgeSource], the trivial [EdgeSource] this issue ships, and
## with it the panorama-space geometry ([PanoramaEdge]/[PanoramaEdgePoint])
## every future [EdgeSource] implementation has to produce. No scene tree, no
## panorama texture, no [Level] — the same reason [ScoringSnapshot]'s tests
## build one by hand.

const EPSILON := 0.0001


func test_an_empty_source_has_no_edges() -> void:
	var source := ManualEdgeSource.new()
	assert_eq(source.get_edges().size(), 0)


func test_base_edge_source_also_has_no_edges() -> void:
	# The port's own default — a consumer with no EdgeSource configured
	# should see an empty level, not a crash.
	var source := EdgeSource.new()
	assert_eq(source.get_edges().size(), 0)


func test_one_polyline_produces_one_edge_with_one_point_per_vertex() -> void:
	var source := ManualEdgeSource.new()
	source.edges_degrees = [
		PackedVector2Array([Vector2(-10.0, 0.0), Vector2(0.0, 0.0), Vector2(10.0, 0.0)]),
	]
	var edges := source.get_edges()
	assert_eq(edges.size(), 1)
	assert_eq(edges[0].points.size(), 3)


func test_edge_id_is_the_polyline_index_and_stable_across_calls() -> void:
	var source := ManualEdgeSource.new()
	source.edges_degrees = [
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(10.0, 0.0)]),
		PackedVector2Array([Vector2(0.0, 20.0), Vector2(10.0, 20.0)]),
	]
	var first_call := source.get_edges()
	var second_call := source.get_edges()
	assert_eq(first_call[0].id, 0)
	assert_eq(first_call[1].id, 1)
	assert_eq(second_call[0].id, first_call[0].id, "Same source, same ids")
	assert_eq(second_call[1].id, first_call[1].id, "Same source, same ids")


func test_directions_are_unit_length() -> void:
	var source := ManualEdgeSource.new()
	source.edges_degrees = [
		PackedVector2Array([Vector2(-30.0, 45.0), Vector2(0.0, 10.0), Vector2(60.0, -20.0)]),
	]
	for point in source.get_edges()[0].points:
		assert_almost_eq(point.direction.length(), 1.0, EPSILON, "Direction must sit on the sphere")
		assert_almost_eq(point.tangent.length(), 1.0, EPSILON, "Tangent must be normalised")


func test_tangent_is_perpendicular_to_direction() -> void:
	var source := ManualEdgeSource.new()
	source.edges_degrees = [
		PackedVector2Array([Vector2(-20.0, 5.0), Vector2(0.0, 0.0), Vector2(25.0, -8.0)]),
	]
	for point in source.get_edges()[0].points:
		assert_almost_eq(
			point.direction.dot(point.tangent), 0.0, EPSILON, "Tangent must lie in the tangent plane"
		)


func test_yaw_zero_pitch_zero_faces_forward() -> void:
	# Matches PanoramaLookCamera's own yaw/pitch = 0 resting rotation.
	var source := ManualEdgeSource.new()
	source.edges_degrees = [PackedVector2Array([Vector2(0.0, 0.0)])]
	var direction: Vector3 = source.get_edges()[0].points[0].direction
	assert_almost_eq(direction.x, 0.0, EPSILON)
	assert_almost_eq(direction.y, 0.0, EPSILON)
	assert_almost_eq(direction.z, -1.0, EPSILON)


func test_a_single_point_edge_still_gets_a_usable_tangent() -> void:
	var source := ManualEdgeSource.new()
	source.edges_degrees = [PackedVector2Array([Vector2(15.0, 40.0)])]
	var point: PanoramaEdgePoint = source.get_edges()[0].points[0]
	assert_almost_eq(point.tangent.length(), 1.0, EPSILON, "Never a zero tangent")
	assert_almost_eq(point.direction.dot(point.tangent), 0.0, EPSILON)


func test_the_same_yaw_step_produces_a_shorter_chord_near_a_pole() -> void:
	# The whole point of authoring in angles rather than pixels: the same
	# ten-degree yaw step is a much smaller physical distance near a pole
	# than at the equator, and this should fall out of the sphere embedding
	# with no extra correction code.
	var source := ManualEdgeSource.new()
	source.edges_degrees = [
		PackedVector2Array([Vector2(-5.0, 0.0), Vector2(5.0, 0.0)]),
		PackedVector2Array([Vector2(-5.0, 80.0), Vector2(5.0, 80.0)]),
	]
	var edges := source.get_edges()
	var equator_chord: float = (
		edges[0].points[0].direction - edges[0].points[1].direction
	).length()
	var near_pole_chord: float = (
		edges[1].points[0].direction - edges[1].points[1].direction
	).length()
	assert_lt(near_pole_chord, equator_chord, "Same yaw step, shorter chord near the pole")

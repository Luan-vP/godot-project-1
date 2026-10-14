extends GutTest
## Covers [LineFitEdgeSource], [ContourEdgeSource] and [EdgeStats] against
## small synthetic images, like [code]test_canny_edge_source.gd[/code].

const EPSILON := 0.001


func test_simplify_collapses_a_straight_staircase() -> void:
	var path := PackedVector2Array()
	for i in 20:
		path.append(Vector2(i, 0.0 if i % 2 == 0 else 1.0))
	var simplified := LineFitEdgeSource.simplify(path, 1.5)
	assert_eq(simplified.size(), 2, "A 1px wobble is inside a 1.5px tolerance")


func test_simplify_keeps_a_corner() -> void:
	var path := PackedVector2Array()
	for i in 10:
		path.append(Vector2(i, 0))
	for i in range(1, 10):
		path.append(Vector2(9, i))
	assert_eq(LineFitEdgeSource.simplify(path, 1.0).size(), 3)


func test_fit_run_drops_a_short_run() -> void:
	var run: Array[Vector2i] = []
	for i in 5:
		run.append(Vector2i(i, 3))
	assert_true(LineFitEdgeSource.fit_run(run, 100, 50, 10.0, 1.5, 30.0).is_empty())


func test_fit_run_keeps_a_long_straight_run() -> void:
	var run: Array[Vector2i] = []
	for i in 30:
		run.append(Vector2i(i, 3))
	var fitted := LineFitEdgeSource.fit_run(run, 100, 50, 10.0, 1.5, 30.0)
	assert_eq(fitted.size(), 30)


func test_fit_run_drops_a_zigzag_as_texture() -> void:
	var run: Array[Vector2i] = []
	for i in 40:
		run.append(Vector2i(10 + i, 10 if i % 8 < 4 else 20))
	assert_true(
		LineFitEdgeSource.fit_run(run, 100, 50, 10.0, 1.0, 5.0).is_empty(),
		"Too many bends per length is texture, not an outline"
	)


func test_fit_run_survives_the_seam() -> void:
	var run: Array[Vector2i] = []
	for i in 30:
		run.append(Vector2i(posmod(85 + i, 100), 4))
	var fitted := LineFitEdgeSource.fit_run(run, 100, 50, 10.0, 1.5, 30.0)
	assert_eq(fitted.size(), 30, "A run across the wrap is one run, not a line across the image")
	for pixel in fitted:
		assert_eq(pixel.y, 4)


func test_line_fit_keeps_the_long_edge_and_drops_speckle() -> void:
	var image := Image.create(128, 64, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	image.fill_rect(Rect2i(0, 32, 128, 32), Color.WHITE)
	for x in [10, 40, 70, 100]:
		image.fill_rect(Rect2i(x, 10, 2, 2), Color.WHITE)
	var texture := ImageTexture.create_from_image(image)

	var canny := CannyEdgeSource.new()
	canny.panorama_texture = texture
	canny.blur_sigma = 0.0
	var fitted := LineFitEdgeSource.new()
	fitted.panorama_texture = texture
	fitted.blur_sigma = 0.0

	assert_gt(canny.get_edges().size(), fitted.get_edges().size(), "Speckle runs should be gone")
	assert_gt(fitted.get_edges().size(), 0, "The horizon should survive")
	for edge in fitted.get_edges():
		for point in edge.points:
			assert_almost_eq(point.direction.length(), 1.0, EPSILON)
			assert_almost_eq(point.direction.dot(point.tangent), 0.0, EPSILON)


func test_otsu_splits_two_clusters() -> void:
	var values := PackedFloat32Array()
	for i in 50:
		values.append(0.1)
		values.append(0.9)
	var threshold := ContourEdgeSource.otsu_threshold(values)
	assert_gt(threshold, 0.1)
	assert_lt(threshold, 0.9)


func test_boundary_mask_marks_only_the_region_edge() -> void:
	var region := PackedByteArray()
	region.resize(8 * 8)
	for y in range(2, 6):
		for x in range(2, 6):
			region[y * 8 + x] = 1
	var boundary := ContourEdgeSource.boundary_mask(region, 8, 8)
	assert_eq(boundary[2 * 8 + 2], 1, "A corner is on the boundary")
	assert_eq(boundary[3 * 8 + 3], 0, "The interior is not")


func test_contour_traces_a_block_outline_but_not_its_texture() -> void:
	var image := Image.create(128, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.1, 0.1, 0.1))
	image.fill_rect(Rect2i(30, 10, 60, 40), Color(0.8, 0.8, 0.8))
	# Faint texture inside the block must not produce boundaries.
	for x in range(34, 86, 6):
		image.fill_rect(Rect2i(x, 20, 2, 20), Color(0.75, 0.75, 0.75))
	var source := ContourEdgeSource.new()
	source.panorama_texture = ImageTexture.create_from_image(image)
	source.blur_sigma = 0.0
	var edges := source.get_edges()
	assert_gt(edges.size(), 0)
	assert_lt(edges.size(), 3, "One block gives one outline, not one per texture stripe")


func test_contour_without_texture_returns_no_edges() -> void:
	assert_eq(ContourEdgeSource.new().get_edges().size(), 0)


func test_edge_stats_on_no_edges_are_zero() -> void:
	var none: Array[PanoramaEdge] = []
	assert_eq(EdgeStats.run_count(none), 0)
	assert_eq(EdgeStats.length_quantile(none, 0.5), 0)
	assert_eq(EdgeStats.long_run_share(none, 10), 0.0)
	assert_eq(EdgeStats.coverage(none), 0.0)


func test_edge_stats_coverage_counts_distinct_cells() -> void:
	var points: Array[PanoramaEdgePoint] = []
	for x in [0.05, 0.3, 0.55]:
		var direction := EquirectProjection.direction_for_uv(Vector2(x, 0.5))
		points.append(PanoramaEdgePoint.new(direction, Vector3.UP))
	var edges: Array[PanoramaEdge] = [PanoramaEdge.new(0, points)]
	assert_almost_eq(EdgeStats.coverage(edges), 3.0 / 32.0, EPSILON)

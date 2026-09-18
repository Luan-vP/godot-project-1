extends GutTest
## Covers [CannyEdgeSource] against small synthetic images built by hand, the
## same reason [ManualEdgeSource]'s tests need no scene tree or real panorama
## texture — see that test file.

const EPSILON := 0.001


func test_no_texture_returns_no_edges() -> void:
	var source := CannyEdgeSource.new()
	assert_eq(source.get_edges().size(), 0)


func test_a_flat_image_has_no_edges() -> void:
	var source := CannyEdgeSource.new()
	source.panorama_texture = _solid_texture(48, 16, Color(0.5, 0.5, 0.5))
	assert_eq(source.get_edges().size(), 0)


func test_a_hard_edge_is_traced_as_a_run() -> void:
	var source := CannyEdgeSource.new()
	source.panorama_texture = _banded_texture(48, 16)
	var edges := source.get_edges()
	assert_gt(edges.size(), 0, "Two vertical bands should produce at least one traced edge")


func test_edge_points_have_unit_direction_and_perpendicular_tangent() -> void:
	var source := CannyEdgeSource.new()
	source.panorama_texture = _banded_texture(48, 16)
	var edges := source.get_edges()
	assert_gt(edges.size(), 0)
	for edge in edges:
		for point in edge.points:
			assert_almost_eq(point.direction.length(), 1.0, EPSILON)
			assert_almost_eq(point.tangent.length(), 1.0, EPSILON)
			assert_almost_eq(point.direction.dot(point.tangent), 0.0, EPSILON)


func test_get_edges_is_cached_between_calls() -> void:
	var source := CannyEdgeSource.new()
	source.panorama_texture = _banded_texture(48, 16)
	var first_call := source.get_edges()
	var second_call := source.get_edges()
	assert_same(first_call, second_call, "A second call should not re-run detection")


func test_min_run_length_can_suppress_every_edge() -> void:
	var source := CannyEdgeSource.new()
	source.panorama_texture = _banded_texture(48, 16)
	source.min_run_length = 10000
	assert_eq(source.get_edges().size(), 0, "No run in a 48x16 image reaches 10000 points")


func test_detection_still_finds_the_edge_against_a_downscaled_copy() -> void:
	var source := CannyEdgeSource.new()
	source.panorama_texture = _banded_texture(480, 160)
	source.working_width = 64
	var edges := source.get_edges()
	assert_gt(edges.size(), 0, "Downscaling should not stop the edge from being found")


static func _solid_texture(width: int, height: int, color: Color) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


## Three vertical bands, black/white/black, kept away from the horizontal
## wrap seam (column 0 and the last column are both black) so the two real
## edges are not confused with a seam artefact.
static func _banded_texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for y in height:
		for x in width:
			var band := x * 3 / width
			image.set_pixel(x, y, Color.WHITE if band == 1 else Color.BLACK)
	return ImageTexture.create_from_image(image)

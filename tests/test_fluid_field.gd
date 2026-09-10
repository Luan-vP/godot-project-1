extends GutTest
## Covers the CPU mirror of the velocity field — the seam every bit of gameplay
## reads the fluid through.

const EPSILON := 0.0001

var _field: FluidField


func before_each() -> void:
	_field = FluidField.new()
	_field.resize(2, 2)
	# The mirror happens to be one cell per simulation cell here; the test
	# below pins what happens when it is not.
	_field.configure_world(Rect2(Vector2.ZERO, Vector2(200.0, 100.0)), Vector2(100.0, 50.0))
	_field.set_cell_velocity(0, 0, Vector2(1.0, 0.0))
	_field.set_cell_velocity(1, 0, Vector2(3.0, 0.0))
	_field.set_cell_velocity(0, 1, Vector2(1.0, 4.0))
	_field.set_cell_velocity(1, 1, Vector2(3.0, 4.0))


func _assert_vector(got: Vector2, expected: Vector2, context: String) -> void:
	assert_almost_eq(got.x, expected.x, EPSILON, "%s (x)" % context)
	assert_almost_eq(got.y, expected.y, EPSILON, "%s (y)" % context)


func test_a_new_field_is_empty() -> void:
	var blank := FluidField.new()
	assert_true(blank.is_empty(), "A field with no grid should report empty")
	_assert_vector(blank.sample_uv(Vector2(0.5, 0.5)), Vector2.ZERO, "Empty field samples")


func test_resize_allocates_a_zeroed_grid() -> void:
	var field := FluidField.new()
	field.resize(4, 3)
	assert_eq(field.get_size(), Vector2i(4, 3), "Grid should match the requested size")
	assert_false(field.is_empty(), "A sized field should not report empty")
	_assert_vector(field.get_cell_velocity(2, 1), Vector2.ZERO, "Fresh cells")


func test_cell_access_clamps_out_of_range_coordinates() -> void:
	_assert_vector(_field.get_cell_velocity(-5, -5), Vector2(1.0, 0.0), "Below the grid")
	_assert_vector(_field.get_cell_velocity(99, 99), Vector2(3.0, 4.0), "Above the grid")


func test_sampling_a_cell_centre_returns_that_cell() -> void:
	_assert_vector(_field.sample_uv(Vector2(0.25, 0.25)), Vector2(1.0, 0.0), "Top left centre")
	_assert_vector(_field.sample_uv(Vector2(0.75, 0.75)), Vector2(3.0, 4.0), "Bottom right centre")


func test_sampling_between_cells_interpolates() -> void:
	_assert_vector(_field.sample_uv(Vector2(0.5, 0.25)), Vector2(2.0, 0.0), "Halfway across")
	_assert_vector(_field.sample_uv(Vector2(0.25, 0.5)), Vector2(1.0, 2.0), "Halfway down")
	_assert_vector(_field.sample_uv(Vector2(0.5, 0.5)), Vector2(2.0, 2.0), "Dead centre")


func test_sampling_outside_the_grid_clamps_to_the_edge() -> void:
	_assert_vector(_field.sample_uv(Vector2(-3.0, -3.0)), Vector2(1.0, 0.0), "Off the top left")
	_assert_vector(_field.sample_uv(Vector2(9.0, 9.0)), Vector2(3.0, 4.0), "Off the bottom right")


func test_world_and_uv_coordinates_round_trip() -> void:
	_assert_vector(_field.world_to_uv(Vector2(100.0, 50.0)), Vector2(0.5, 0.5), "Centre to UV")
	_assert_vector(_field.uv_to_world(Vector2(0.5, 0.5)), Vector2(100.0, 50.0), "UV to centre")
	_assert_vector(
		_field.uv_to_world(_field.world_to_uv(Vector2(37.0, 91.0))),
		Vector2(37.0, 91.0),
		"Round trip"
	)


func test_world_rect_offset_is_respected() -> void:
	_field.configure_world(
		Rect2(Vector2(500.0, 300.0), Vector2(200.0, 100.0)), Vector2(100.0, 50.0)
	)
	_assert_vector(_field.world_to_uv(Vector2(600.0, 350.0)), Vector2(0.5, 0.5), "Offset centre")


func test_cell_velocities_convert_to_pixels_per_second() -> void:
	# 2x2 grid over 200x100 pixels means one cell is 100x50 pixels.
	_assert_vector(
		_field.cell_to_world_velocity(Vector2(1.0, 2.0)), Vector2(100.0, 100.0), "Cells to pixels"
	)
	_assert_vector(
		_field.world_to_cell_velocity(Vector2(100.0, 100.0)), Vector2(1.0, 2.0), "Pixels to cells"
	)


func test_velocity_units_follow_the_simulation_grid_not_the_mirror() -> void:
	# The mirror is coarser than the simulation that fills it, but the values
	# in it are in the simulation's cells. Converting with the mirror's own
	# spacing (200x100 over a 2x2 grid, so 100x50) would be wrong by the ratio.
	_field.configure_world(Rect2(Vector2.ZERO, Vector2(200.0, 100.0)), Vector2(10.0, 5.0))
	_assert_vector(
		_field.cell_to_world_velocity(Vector2(3.0, 4.0)), Vector2(30.0, 20.0), "Cells to pixels"
	)
	_assert_vector(
		_field.world_to_cell_velocity(Vector2(30.0, 20.0)), Vector2(3.0, 4.0), "Pixels to cells"
	)
	_assert_vector(_field.sample_world(Vector2(100.0, 50.0)), Vector2(20.0, 10.0), "Tank centre")


func test_sample_world_combines_lookup_and_conversion() -> void:
	_assert_vector(_field.sample_world(Vector2(100.0, 50.0)), Vector2(200.0, 100.0), "Tank centre")


func test_sample_world_outside_the_tank_uses_the_nearest_edge() -> void:
	_assert_vector(
		_field.sample_world(Vector2(-900.0, -900.0)), Vector2(100.0, 0.0), "Far off the tank"
	)


func test_update_from_image_reads_red_and_green() -> void:
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBAF)
	image.set_pixel(0, 0, Color(0.5, -1.5, 9.0, 1.0))
	image.set_pixel(1, 0, Color(2.0, 0.25, 9.0, 1.0))
	image.set_pixel(0, 1, Color(-0.75, 3.0, 9.0, 1.0))
	image.set_pixel(1, 1, Color(0.0, 0.0, 9.0, 1.0))

	_field.update_from_image(image)

	_assert_vector(_field.get_cell_velocity(0, 0), Vector2(0.5, -1.5), "Top left")
	_assert_vector(_field.get_cell_velocity(1, 0), Vector2(2.0, 0.25), "Top right")
	_assert_vector(_field.get_cell_velocity(0, 1), Vector2(-0.75, 3.0), "Bottom left")
	_assert_vector(_field.get_cell_velocity(1, 1), Vector2.ZERO, "Bottom right")


func test_update_from_image_resizes_to_match() -> void:
	var image := Image.create_empty(4, 3, false, Image.FORMAT_RGBAF)
	image.fill(Color(1.0, 1.0, 0.0, 1.0))

	_field.update_from_image(image)

	assert_eq(_field.get_size(), Vector2i(4, 3), "Field should adopt the image size")
	_assert_vector(_field.get_cell_velocity(3, 2), Vector2(1.0, 1.0), "Last cell")


func test_clear_zeroes_without_resizing() -> void:
	_field.clear()
	assert_eq(_field.get_size(), Vector2i(2, 2), "Clearing should keep the grid")
	_assert_vector(_field.sample_uv(Vector2(0.5, 0.5)), Vector2.ZERO, "Cleared centre")

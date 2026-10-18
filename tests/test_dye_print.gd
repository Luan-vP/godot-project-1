extends GutTest
## Covers [DyePrint], the pictures printed into a running tank, and
## [method FluidSimulation.add_dye], which adds them over what is there.

const WORLD := Vector2(1024, 512)
const GRID := Vector2i(256, 256)


func test_a_mask_becomes_premultiplied_pigment() -> void:
	var mask := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	mask.fill(Color(1, 1, 1, 1))
	var dye := DyePrint.tinted(mask, Vector2i(4, 4), Color(0.5, 0.25, 1.0), 2.0)
	var cell := dye.get_pixel(1, 1)
	assert_almost_eq(cell.a, 2.0, 0.01, "Density where opaque")
	assert_almost_eq(cell.r, 1.0, 0.01, "Colour times density")
	mask.fill(Color(1, 1, 1, 0))
	assert_almost_eq(
		DyePrint.tinted(mask, Vector2i(4, 4), Color.WHITE, 2.0).get_pixel(1, 1).a, 0.0, 0.001
	)


func test_a_constellation_has_dots_at_its_stars_and_lines_between() -> void:
	var points: Array[Vector2] = [Vector2(100, 100), Vector2(300, 100)]
	var colors: Array[Color] = [Color.RED, Color.BLUE]
	var picture := DyePrint.constellation(points, colors, WORLD, GRID, 1.0, 8.0, 3.0)
	var dye: Image = picture["dye"]
	var origin: Vector2i = picture["cell"]
	var at := func(world: Vector2) -> Color:
		return dye.get_pixelv(DyePrint.cell_of(world, WORLD, GRID) - origin)
	var star: Color = at.call(Vector2(100, 100))
	var middle: Color = at.call(Vector2(200, 100))
	var away: Color = at.call(Vector2(200, 116))
	assert_gt(star.a, 0.5, "A dot on the star")
	assert_gt(star.r, star.b, "In its own colour")
	assert_gt(middle.a, 0.1, "A line between")
	assert_lt(middle.a, star.a, "Fainter than the stars")
	assert_almost_eq(away.a, 0.0, 0.01, "Nothing off the line")
	assert_eq(DyePrint.constellation([] as Array[Vector2], [] as Array[Color], WORLD, GRID), {})


func test_added_dye_goes_over_the_field_with_the_next_step_only() -> void:
	var tank := FluidSimulation.new()
	tank.config = FluidConfig.new()
	tank.config.simulation_resolution = 32
	add_child_autofree(tank)
	var dot := Image.create_empty(2, 2, false, Image.FORMAT_RGBAF)
	dot.fill(Color(0.5, 0.5, 0.5, 0.5))
	tank.add_dye(dot, Vector2i(31, 4))
	tank.add_dye(dot, Vector2i(31, 4))
	var frame: Dictionary = tank._frame(1.0 / 60.0)
	var bytes: PackedByteArray = frame["dye_addition"]
	assert_eq(bytes.size(), 32 * 32 * 8, "The whole field, half floats")
	var field := Image.create_from_data(32, 32, false, Image.FORMAT_RGBAH, bytes)
	assert_almost_eq(field.get_pixel(31, 4).a, 1.0, 0.01, "Two prints add up")
	assert_almost_eq(field.get_pixel(30, 4).a, 0.0, 0.001, "Only where printed")
	tank._consume_queues()
	assert_true((tank._frame(1.0 / 60.0)["dye_addition"] as PackedByteArray).is_empty(), "Spent")


func test_the_key_is_printed_by_name_in_the_middle() -> void:
	assert_eq(SpoutLevel.key_name(6, true), "F# minor")
	assert_eq(SpoutLevel.key_name(3, false), "Eb major")
	var rect := SpoutLevel.key_print_rect(Vector2(1000, 500), 0.1)
	assert_almost_eq(rect.get_center().x, 500.0, 0.01, "Centred")
	assert_almost_eq(rect.get_center().y, 250.0, 0.01)
	assert_almost_eq(rect.size.x, 1000 * SpoutLevel.KEY_PRINT_WIDTH, 0.01)
	var tall := SpoutLevel.key_print_rect(Vector2(1000, 500), 1.0)
	assert_almost_eq(tall.size.y, 500 * SpoutLevel.KEY_PRINT_MAX_HEIGHT, 0.01, "Never too tall")

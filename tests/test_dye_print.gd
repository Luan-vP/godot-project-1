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
	assert_eq(KeyPrint.key_name(6, true), "F# minor")
	assert_eq(KeyPrint.key_name(3, false), "Eb major")
	assert_eq(KeyPrint.scale_title(9, "minor pentatonic"), "A minor pentatonic")
	assert_eq(KeyPrint.scale_title(-2, "dorian"), "Bb dorian")
	var rect := KeyPrint.rect_for(Vector2(1000, 500), 0.1)
	assert_almost_eq(rect.get_center().x, 500.0, 0.01, "Centred")
	assert_almost_eq(rect.get_center().y, 250.0, 0.01)
	assert_almost_eq(rect.size.x, 1000 * KeyPrint.WIDTH, 0.01)
	var tall := KeyPrint.rect_for(Vector2(1000, 500), 1.0)
	assert_almost_eq(tall.size.y, 500 * KeyPrint.MAX_HEIGHT, 0.01, "Never too tall")


func test_every_level_shares_one_key_print_on_the_band() -> void:
	var shared := SharedLayers.new()
	add_child_autofree(shared)
	var key_print := shared.get_node("KeyPrint") as KeyPrint
	assert_not_null(key_print, "The host keeps one")
	assert_eq(key_print.band, shared.band)
	assert_true(shared.band.key_changed.is_connected(key_print._on_key_changed), "Follows the key")
	assert_true(
		shared.band.song_started.is_connected(key_print._on_song_started), "And each new song"
	)


func test_anywhere_keeps_the_name_wholly_on_the_screen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var screen := Vector2(1152, 648)
	var name_rect := Rect2(Vector2.ZERO, Vector2(400, 60))
	var lefts: Array[float] = []
	for i in 200:
		var rect := KeyPrint.anywhere(name_rect, screen, rng)
		assert_eq(rect.size, name_rect.size, "Same size")
		assert_true(Rect2(Vector2.ZERO, screen).grow(-KeyPrint.MARGIN).encloses(rect), "On screen")
		lefts.append(rect.position.x)
	assert_gt(lefts.max() - lefts.min(), 500.0, "All over, not just the middle")


func test_the_eye_tank_asks_for_the_name_anywhere_and_the_spout_does_not() -> void:
	var key_print := KeyPrint.new()
	# Out of the tree, so the levels never look for a host.
	var stage: Node = autofree(Node.new())
	key_print.stage = stage
	autofree(key_print)
	assert_false(key_print.wants_anywhere(), "No level: the middle")
	var spout: Node = SpoutLevel.new()
	stage.add_child(spout)
	assert_false(key_print.wants_anywhere(), "The spout: the middle")
	var eyes: Node = load("res://features/levels/secret_eyes/eye_band_demo.gd").new()
	stage.add_child(eyes)
	assert_true(key_print.wants_anywhere(), "The eye tank, arriving: anywhere")


func test_a_scales_name_goes_smaller_and_above_the_key() -> void:
	var screen := Vector2(1000, 500)
	# A key's name is short ("A minor"), a scale's long ("minor pentatonic").
	var key := KeyPrint.rect_for(screen, 0.2)
	var scale_rect := KeyPrint.rect_for(
		screen, 0.12, KeyPrint.SCALE_WIDTH, KeyPrint.SCALE_MAX_HEIGHT, KeyPrint.SCALE_HEIGHT
	)
	assert_almost_eq(scale_rect.get_center().x, 500.0, 0.01, "Centred across")
	assert_almost_eq(scale_rect.get_center().y, 500 * KeyPrint.SCALE_HEIGHT, 0.01)
	assert_lt(scale_rect.size.y, key.size.y, "Smaller letters")
	assert_lt(scale_rect.end.y, key.position.y, "Clear above the key")


func test_a_hovering_name_floats_until_the_next_cuts_it_short() -> void:
	var key_print := KeyPrint.new()
	add_child_autofree(key_print)
	var mask := Image.create_empty(40, 10, false, Image.FORMAT_RGBA8)
	var overlay := key_print.get_node("Hover") as CanvasLayer
	key_print._hover(mask, Color.RED, Rect2(10, 20, 200, 50), 60.0)
	assert_eq(overlay.get_child_count(), 1, "Floats over the water")
	var first := overlay.get_child(0) as TextureRect
	assert_eq(first.position, Vector2(10, 20))
	assert_eq(first.size, Vector2(200, 50))
	key_print._hover(mask, Color.BLUE, Rect2(10, 20, 200, 50), 60.0)
	await wait_seconds(KeyPrint.HOVER_FADE + 0.2)
	assert_false(is_instance_valid(first), "The newer name cut it short, and it faded")
	assert_eq(overlay.get_child_count(), 1, "The newer one still floats")

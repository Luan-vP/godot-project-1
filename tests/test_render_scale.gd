extends GutTest
## Covers the buffer arithmetic behind upscaling the heavy passes on a phone.


func test_no_upscale_on_an_unstretched_canvas_is_the_canvas() -> void:
	var size := RenderScale.buffer_size(Vector2(1152.0, 648.0), 1.0, 1)
	assert_eq(size, Vector2i(1152, 648), "One buffer pixel per unit")


func test_a_phone_draws_a_quarter_of_its_pixels_along_each_axis() -> void:
	# An iPhone 14 Pro Max: a 1398x645 canvas on a 2796x1290 screen.
	var size := RenderScale.buffer_size(Vector2(1398.0, 645.0), 2.0, 4)
	assert_eq(size, Vector2i(699, 323), "The screen's pixels over four, rounded up")


func test_a_part_pixel_rounds_up_so_the_edge_is_covered() -> void:
	var size := RenderScale.buffer_size(Vector2(10.0, 10.0), 1.0, 4)
	assert_eq(size, Vector2i(3, 3), "2.5 pixels needs 3")


func test_never_smaller_than_a_pixel() -> void:
	assert_eq(RenderScale.buffer_size(Vector2.ZERO, 2.0, 4), Vector2i.ONE, "Empty canvas")
	assert_eq(RenderScale.buffer_size(Vector2(8.0, 8.0), 1.0, 0), Vector2i(8, 8), "Zero upscale")


func test_only_a_phone_upscales() -> void:
	var expected := RenderScale.MOBILE_UPSCALE if OS.has_feature("mobile") else 1
	assert_eq(RenderScale.factor(), expected, "Mobile feature tag decides")

extends GutTest
## Covers [SafeArea]'s pixel-to-canvas arithmetic, with the numbers an iPhone 14
## Pro Max actually reports, so layout can be checked without a phone.

## 1290x2796 pixels, 59 pt island inset and 34 pt home indicator at 3x.
const PHONE_WINDOW := Vector2(1290.0, 2796.0)
const PHONE_SAFE := Rect2(0.0, 177.0, 1290.0, 2517.0)
## What a 540 wide canvas_items/expand stretch gives that screen.
const PHONE_CANVAS := Vector2(540.0, 1170.4186)


func test_a_phone_safe_area_scales_into_canvas_units() -> void:
	var safe := SafeArea.to_canvas(PHONE_SAFE, PHONE_WINDOW, PHONE_CANVAS)
	var scale := 540.0 / 1290.0
	assert_almost_eq(safe.position.y, 177.0 * scale, 0.01, "Top clears the island")
	assert_almost_eq(safe.position.x, 0.0, 0.01, "No side inset in portrait")
	assert_almost_eq(safe.end.y, (177.0 + 2517.0) * scale, 0.01, "Bottom clears the indicator")


func test_insets_measure_each_edge_in_from_the_canvas() -> void:
	var safe := Rect2(10.0, 74.0, 500.0, 1060.0)
	var edges := SafeArea.insets(safe, Vector2(540.0, 1170.0))
	assert_eq(edges, Vector4(10.0, 74.0, 30.0, 36.0))


func test_no_safe_area_means_the_whole_canvas() -> void:
	var canvas := Vector2(540.0, 960.0)
	assert_eq(
		SafeArea.to_canvas(Rect2(), PHONE_WINDOW, canvas),
		Rect2(Vector2.ZERO, canvas),
		"Nothing reported"
	)
	assert_eq(
		SafeArea.to_canvas(PHONE_SAFE, Vector2.ZERO, canvas),
		Rect2(Vector2.ZERO, canvas),
		"No window size yet"
	)


func test_a_safe_area_bigger_than_the_window_is_clipped_to_the_canvas() -> void:
	var canvas := Vector2(540.0, 960.0)
	var safe := SafeArea.to_canvas(Rect2(-50.0, -50.0, 4000.0, 4000.0), PHONE_WINDOW, canvas)
	assert_eq(safe, Rect2(Vector2.ZERO, canvas))


func test_outside_a_phone_the_safe_area_is_the_whole_canvas() -> void:
	# Desktop reports the monitor's usable area, which says nothing about the
	# window; applying it would push labels off by the menu bar.
	if OS.has_feature("mobile"):
		pass_test("Running on a phone")
		return
	var viewport := get_viewport()
	assert_eq(SafeArea.canvas_rect(viewport), viewport.get_visible_rect())

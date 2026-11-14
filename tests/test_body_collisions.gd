extends GutTest
## Covers [BodyOutline] (a painting's edge read from its transparency) and
## [BodyCollisions] (bodies pushed apart along those edges, eyes dented).

const SAND_DOLLAR := preload("res://features/levels/secret_eyes/paintings/sand_dollar.png")
const LONG_THIN := preload("res://features/levels/secret_eyes/paintings/long_thin.png")


func test_a_circle_measures_from_its_rim() -> void:
	var outline := BodyOutline.circle(10.0)
	assert_almost_eq(outline.distance(Vector2(15, 0)), 5.0, 0.001, "Outside")
	assert_almost_eq(outline.distance(Vector2(0, 4)), -6.0, 0.001, "Inside")
	assert_eq(outline.points.size(), BodyOutline.CIRCLE_POINTS)


func test_a_painting_outline_follows_the_paint_not_a_circle() -> void:
	var outline := BodyOutline.of_texture(SAND_DOLLAR)
	var size := SAND_DOLLAR.get_size()
	# The sand dollar's star is cut out: its middle is open water.
	assert_gt(outline.distance(Vector2(0.025, 0.05) * size), 0.0, "Star middle is outside")
	# The painted ring, part way out to the left, is inside.
	assert_lt(outline.distance(Vector2(-0.42, 0.0) * size), 0.0, "Painted ring is inside")
	assert_gt(outline.distance(Vector2(0.0, -0.6) * size), 0.0, "Beyond the edge is outside")
	assert_gt(outline.points.size(), 20, "Has an edge")
	assert_true(outline.points.size() <= BodyOutline.MAX_POINTS)


func test_the_long_thin_one_is_empty_inside_its_bend() -> void:
	var outline := BodyOutline.of_texture(LONG_THIN)
	# The middle of its bounding box is the open space the bar bends round.
	assert_gt(outline.distance(Vector2.ZERO), 0.0)


func test_outlines_are_built_once_per_texture() -> void:
	assert_same(BodyOutline.of_texture(LONG_THIN), BodyOutline.of_texture(LONG_THIN))


func test_overlapping_circles_are_pushed_apart_along_their_centres() -> void:
	var circle := BodyOutline.circle(10.0)
	var push := BodyCollisions.separation(
		circle, Transform2D(0.0, Vector2(0, 0)), circle, Transform2D(0.0, Vector2(15, 0))
	)
	assert_lt(push.x, 0.0, "The first is pushed away from the second")
	assert_almost_eq(push.y, 0.0, 0.01)
	assert_almost_eq(push.length(), 5.0, 1.0, "By about the overlap")


func test_apart_bodies_are_left_alone() -> void:
	var circle := BodyOutline.circle(10.0)
	var push := BodyCollisions.separation(
		circle, Transform2D(0.0, Vector2.ZERO), circle, Transform2D(0.0, Vector2(25, 0))
	)
	assert_eq(push, Vector2.ZERO)


func test_an_eye_in_the_sand_dollars_star_is_not_touching() -> void:
	var sand := BodyOutline.of_texture(SAND_DOLLAR)
	var small := BodyOutline.circle(8.0)
	var centre := Vector2(0.025, 0.05) * SAND_DOLLAR.get_size()
	var push := BodyCollisions.separation(
		small, Transform2D(0.0, centre), sand, Transform2D(0.0, Vector2.ZERO)
	)
	assert_eq(push, Vector2.ZERO, "A circle round its bounds would have hit")


func test_resolving_separates_two_paintings() -> void:
	var a := _body(LONG_THIN, Vector2(400, 300))
	var b := _body(LONG_THIN, Vector2(430, 300))
	var gap_before := a.global_position.distance_to(b.global_position)
	for i in 30:
		BodyCollisions.resolve([a, b] as Array[FloatyEye])
	assert_gt(a.global_position.distance_to(b.global_position), gap_before, "Pushed apart")
	var push := BodyCollisions.separation(
		a.outline(), a.outline_transform(), b.outline(), b.outline_transform()
	)
	assert_almost_eq(push.length(), 0.0, 2.0, "No longer overlapping")


func test_a_pressed_eye_dents_and_springs_back() -> void:
	var eye := _body(null, Vector2(300, 300))
	for i in 20:
		eye.press(Vector2.RIGHT, 10.0)
		eye._update_squish(1.0 / 60.0)
	assert_gt(eye.dent_depth(), 5.0, "Dented while pressed")
	for i in 120:
		eye._update_squish(1.0 / 60.0)
	assert_lt(eye.dent_depth(), 1.0, "Sprung back once let go")


func test_paintings_do_not_dent() -> void:
	var painted := _body(SAND_DOLLAR, Vector2(300, 300))
	painted.press(Vector2.RIGHT, 10.0)
	painted._update_squish(1.0 / 60.0)
	assert_eq(painted.dent_depth(), 0.0)


func _body(painting: Texture2D, at: Vector2) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.radius = 40.0
	eye.painting = painting
	add_child_autofree(eye)
	eye.global_position = at
	return eye

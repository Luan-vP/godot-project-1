extends GutTest
## Covers [FloatyEye]'s painted bodies: a painting replaces the procedural eye,
## is fitted to the eye's radius, and wears an eye (which still blinks) only
## when asked to.

const SAND_DOLLAR := preload("res://features/levels/secret_eyes/paintings/sand_dollar.png")
const LONG_THIN := preload("res://features/levels/secret_eyes/paintings/long_thin.png")


func test_a_plain_eye_has_no_painting() -> void:
	var eye := _eye(null, false)
	assert_true(eye.has_eye(), "The plain eye is all eye")
	assert_null(eye.get_node_or_null("Pivot/Painting"), "No painting")
	assert_not_null(eye.get_node_or_null("Pivot/Visual"), "The eye is drawn on the pivot")


func test_a_bare_painting_has_no_eye() -> void:
	var eye := _eye(SAND_DOLLAR, false)
	assert_false(eye.has_eye())
	assert_not_null(eye.get_node_or_null("Pivot/Painting"), "The painting is the body")
	assert_null(eye.find_child("Visual", true, false), "No eye drawn")


func test_a_painting_is_fitted_to_the_radius_by_its_longest_side() -> void:
	var eye := _eye(LONG_THIN, false, 50.0)
	var sprite := eye.get_node("Pivot/Painting") as Sprite2D
	var size := LONG_THIN.get_size()
	assert_almost_eq(maxf(size.x, size.y) * sprite.scale.x, 100.0, 0.01)


func test_a_painting_can_wear_an_eye_that_blinks() -> void:
	var eye := _eye(LONG_THIN, true)
	eye.eye_offset = Vector2(0.35, -0.33)
	var visual := eye.get_node_or_null("Pivot/Painting/Visual") as ColorRect
	assert_not_null(visual, "The eye rides on the painting")
	var material := visual.material as ShaderMaterial
	eye.blink()
	eye._update_blink(FloatyEye.BLINK_DURATION * 0.5)
	assert_gt(float(material.get_shader_parameter("lid")), 0.9, "Mid-blink the lids are shut")


func _eye(painting: Texture2D, painted_eye: bool, radius: float = 40.0) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.radius = radius
	eye.painting = painting
	eye.painted_eye = painted_eye
	add_child_autofree(eye)
	return eye

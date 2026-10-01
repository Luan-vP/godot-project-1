extends GutTest
## Covers the tilt wiring a panorama level is built with.
##
## No [Level] is assigned, so no medium is built and nothing here needs a GPU —
## which is the point: what is being checked is that a level owns a
## [MotionInput] and a [MotionTiltDriver] at all, and that its recentre button
## reaches the calibration.

const G := 9.80665

var _level: PanoramaLevel


func before_each() -> void:
	_level = PanoramaLevel.new()
	add_child_autofree(_level)


func test_a_level_owns_a_motion_input_and_a_tilt_driver() -> void:
	assert_not_null(_level.get_node_or_null("MotionInput"), "Tilt needs an input to come from")
	assert_not_null(_level.get_node_or_null("MotionTiltDriver"), "And a driver to reach the camera")


func test_the_tilt_driver_finds_the_level_camera() -> void:
	var motion := _level.get_node("MotionInput") as MotionInput
	var source := ScriptedMotionSource.new()
	motion.set_source(source)
	motion.tilt_smoothing = 0.0
	motion.tilt_deadzone = 0.0
	motion.tilt_span_degrees = 30.0

	source.push(Vector3(0.0, -G, 0.0))
	motion._process(1.0 / 60.0)
	source.push(Vector3(sin(deg_to_rad(30.0)), -cos(deg_to_rad(30.0)), 0.0) * G)
	motion._process(1.0 / 60.0)

	var camera := _level.get_node("PanoramaLookCamera") as PanoramaLookCamera
	assert_lt(camera.tilt_offset.x, 0.0, "A right-hand lean should have reached the camera")


func test_the_recentre_button_takes_the_held_pose_as_level() -> void:
	var motion := _level.get_node("MotionInput") as MotionInput
	var source := ScriptedMotionSource.new()
	motion.set_source(source)
	motion.tilt_smoothing = 0.0
	motion.tilt_deadzone = 0.0

	var held := Vector3(sin(deg_to_rad(25.0)), -cos(deg_to_rad(25.0)), 0.0) * G
	source.push(Vector3(0.0, -G, 0.0))
	motion._process(1.0 / 60.0)
	source.push(held)
	motion._process(1.0 / 60.0)
	assert_gt(motion.tilt.length(), 0.0, "Leaning before the recentre")

	source.push(held)
	var event := InputEventAction.new()
	event.action = MotionInput.RECENTRE_ACTION
	event.pressed = true
	_level._unhandled_input(event)
	assert_almost_eq(motion.tilt.length(), 0.0, 0.0001, "The held pose is now level")

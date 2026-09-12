extends GutTest
## Drives the camera headlessly through a scripted look source.
##
## Nothing here can be reached from real mouse or gamepad input in CI, the
## same reason MotionInput's tests drive a ScriptedMotionSource instead.

const STEP := 1.0 / 60.0

var _camera: PanoramaLookCamera
var _source: ScriptedLookSource


func before_each() -> void:
	_camera = PanoramaLookCamera.new()
	_camera.capture_mouse = false
	add_child_autofree(_camera)
	# Drive _process by hand so the pipeline advances in known steps.
	_camera.set_process(false)
	_camera.get_look_input().clear_sources()
	_source = ScriptedLookSource.new()
	_camera.get_look_input().add_source(_source)


func _step(delta: Vector2, dt: float = STEP) -> void:
	_source.push(delta)
	_camera._process(dt)


func test_starts_facing_forward() -> void:
	assert_almost_eq(_camera.yaw, 0.0, 0.0001, "Should start with no rotation")
	assert_almost_eq(_camera.pitch, 0.0, 0.0001, "Should start with no rotation")


func test_yaw_turns_right_when_the_source_reports_positive_x() -> void:
	_step(Vector2(0.2, 0.0))
	assert_almost_eq(_camera.yaw, -0.2, 0.0001, "Positive x should turn the camera right")
	assert_eq(_camera.rotation.y, _camera.yaw, "Rotation should follow yaw")


func test_pitch_moves_up_when_the_source_reports_negative_y() -> void:
	_step(Vector2(0.0, -0.2))
	assert_almost_eq(_camera.pitch, 0.2, 0.0001, "Negative y should pitch the camera up")
	assert_eq(_camera.rotation.x, _camera.pitch, "Rotation should follow pitch")


func test_pitch_is_clamped_so_the_horizon_cannot_roll_over() -> void:
	_camera.max_pitch_degrees = 85.0
	_step(Vector2(0.0, -10.0))
	assert_almost_eq(_camera.pitch, deg_to_rad(85.0), 0.0001, "Should clamp at the limit")

	_step(Vector2(0.0, 0.1))
	var expected := deg_to_rad(85.0) - 0.1
	assert_almost_eq(_camera.pitch, expected, 0.0001, "Should be free to move back off the clamp")


func test_yaw_wraps_instead_of_drifting_unbounded() -> void:
	_step(Vector2(4.0, 0.0))
	assert_between(_camera.yaw, -PI, PI, "Yaw should stay wrapped even after a big turn")


func test_angular_velocity_is_the_rotation_over_dt() -> void:
	_step(Vector2(0.3, -0.1), 0.5)
	assert_almost_eq(_camera.angular_velocity.x, -0.6, 0.0001, "Yaw rate = -delta.x / dt")
	assert_almost_eq(_camera.angular_velocity.y, 0.2, 0.0001, "Pitch rate = -delta.y / dt")


func test_angular_velocity_reflects_the_clamp_not_the_raw_input() -> void:
	_camera.max_pitch_degrees = 10.0
	_step(Vector2(0.0, -10.0), 1.0)
	# The source asked for far more than the clamp allowed; the reported rate
	# should be what actually happened, not what was asked for.
	var expected := deg_to_rad(10.0)
	assert_almost_eq(_camera.angular_velocity.y, expected, 0.0001, "Rate should reflect the clamp")


func test_zero_delta_time_is_ignored() -> void:
	_step(Vector2(0.2, 0.2), 0.0)
	assert_eq(_camera.yaw, 0.0, "Should not divide by a zero delta")
	assert_eq(_camera.angular_velocity, Vector2.ZERO, "Should leave the last velocity alone")

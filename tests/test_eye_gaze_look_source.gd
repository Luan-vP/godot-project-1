extends GutTest
## Covers the gaze look source behind the port, and how LookInput wires it in:
## observed availability, the camera lifecycle, and desktop left unchanged.

const STEP := 1.0 / 60.0

var _backend: ScriptedEyeGazeBackend
var _source: EyeGazeLookSource


func before_each() -> void:
	_backend = ScriptedEyeGazeBackend.new()
	_source = EyeGazeLookSource.new(_backend)


func test_availability_is_observed_not_assumed() -> void:
	_source.poll(STEP)
	assert_false(_source.is_available(), "A stopped tracker is not available")
	_backend.lose_face()
	_source.poll(STEP)
	assert_false(_source.is_available(), "Nor is one that has never seen a face")
	_backend.look(Vector2.ZERO)
	_source.poll(STEP)
	assert_true(_source.is_available(), "A tracked face is")


func test_poll_is_the_rate_times_delta() -> void:
	for _i in 120:
		_backend.look(Vector2.ZERO)
		_source.poll(STEP)
	for _i in 180:
		_backend.look(Vector2(_source.filter.span.x, 0.0))
		_source.poll(STEP)
	_backend.look(Vector2(_source.filter.span.x, 0.0))
	var turn := _source.poll(0.5)
	assert_almost_eq(turn.x, _source.filter.rate.x * 0.5, 0.0001, "Scaled by delta")
	assert_gt(turn.x, 0.0, "Looking right turns right")


func test_calibrate_reaches_the_filter() -> void:
	_source.calibrate()
	assert_true(_source.filter.is_calibrating(), "Should be listening for a neutral")


func test_look_input_starts_sources_in_the_tree_and_stops_them_on_the_way_out() -> void:
	var input := LookInput.new()
	add_child(input)
	input.clear_sources()
	input.add_source(_source)
	assert_true(_backend.running, "Joining a mix in the tree opens the camera")
	input.clear_sources()
	assert_false(_backend.running, "Leaving the mix closes it")

	input.add_source(_source)
	remove_child(input)
	assert_false(_backend.running, "Leaving the tree closes it")
	add_child(input)
	assert_true(_backend.running, "Coming back reopens it")
	input.queue_free()
	await wait_process_frames(1)
	assert_false(_backend.running, "Freeing closes it")


func test_look_input_calibrate_reaches_the_gaze_source() -> void:
	var input := LookInput.new()
	add_child_autofree(input)
	input.clear_sources()
	input.add_source(ScriptedLookSource.new())
	input.add_source(_source)
	input.calibrate()
	assert_true(_source.filter.is_calibrating(), "Recentre should reach eye gaze")


func test_the_desktop_mix_is_unchanged_without_a_plugin() -> void:
	if NativeEyeGazeBackend.is_present():
		pending("This build has the gaze plugin")
		return
	var input := LookInput.new()
	add_child_autofree(input)
	assert_eq(input.describe_sources(), "mouse, gamepad stick", "Mouse and stick only")


func test_the_pointer_stands_in_for_eyes() -> void:
	var pointer := PointerEyeGazeBackend.new(get_viewport())
	assert_eq(pointer.poll().state, EyeGazeSample.State.STOPPED, "Stopped until started")
	pointer.start()
	assert_eq(pointer.poll().state, EyeGazeSample.State.TRACKING, "Tracking once started")
	pointer.face_hidden = true
	assert_eq(pointer.poll().state, EyeGazeSample.State.NO_FACE, "Hidden face")

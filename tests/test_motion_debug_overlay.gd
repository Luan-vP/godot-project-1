extends GutTest
## The readout has one job the device cannot otherwise do: say which of
## "nothing is reading", "held level" and "tilting" is true.


func _overlay_with(source: MotionSource) -> MotionDebugOverlay:
	# Both under one parent, so the overlay reports on this test's input and
	# not on another scene's — the tree is shared across the whole run.
	var level := Node.new()
	add_child_autofree(level)
	var overlay := MotionDebugOverlay.new()
	level.add_child(overlay)
	if source != null:
		var motion := MotionInput.new()
		level.add_child(motion)
		# After entering the tree: MotionInput picks its own source in _ready,
		# and on a real Deck that is the Deck's sensors, not this one.
		motion.set_source(source)
		motion._process(0.016)
	overlay._process(0.016)
	return overlay


func _reading(gravity: Vector3) -> ScriptedMotionSource:
	var source := ScriptedMotionSource.new()
	source.push_repeated(gravity, Vector3.ZERO, 16)
	return source


func test_says_so_when_there_is_no_motion_input() -> void:
	var overlay := _overlay_with(null)
	assert_string_contains(overlay._label.text, "no MotionInput")


func test_reports_the_source_and_its_gravity() -> void:
	var overlay := _overlay_with(_reading(Vector3(0.0, -9.81, 0.0)))
	assert_string_contains(overlay._label.text, "source:")
	assert_string_contains(overlay._label.text, "9.81")


func test_a_silent_source_reads_as_silent_not_as_level() -> void:
	var overlay := _overlay_with(MotionSource.new())
	assert_string_contains(overlay._label.text, "silent")


func test_toggles_with_the_gamepad_button() -> void:
	var overlay := _overlay_with(null)
	assert_true(overlay.visible, "Shown to begin with")
	var press := InputEventJoypadButton.new()
	press.button_index = MotionDebugOverlay.TOGGLE_BUTTON
	press.pressed = true
	overlay._unhandled_input(press)
	assert_false(overlay.visible, "Y hides it")
	overlay._unhandled_input(press)
	assert_true(overlay.visible, "and shows it again")

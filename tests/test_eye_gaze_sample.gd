extends GutTest
## Covers the one place a backend's dictionary is interpreted.


func test_a_full_dictionary_round_trips() -> void:
	var values := {
		"state": EyeGazeSample.State.TRACKING,
		"gaze_yaw": 0.1,
		"gaze_pitch": -0.2,
		"head_yaw": 0.05,
		"head_pitch": 0.0,
		"confidence": 0.8,
		"blink": 0.1,
		"timestamp": 12.5,
		"message": "ok",
	}
	var sample := EyeGazeSample.from_dictionary(values)
	assert_true(sample.is_tracking(), "State")
	assert_almost_eq(sample.gaze.x, 0.1, 0.0001, "Gaze yaw")
	assert_almost_eq(sample.gaze.y, -0.2, 0.0001, "Gaze pitch")
	assert_almost_eq(sample.head.x, 0.05, 0.0001, "Head yaw")
	assert_almost_eq(sample.confidence, 0.8, 0.0001, "Confidence")
	assert_almost_eq(sample.timestamp, 12.5, 0.0001, "Timestamp")
	assert_eq(
		EyeGazeSample.from_dictionary(sample.to_dictionary()).to_dictionary(),
		sample.to_dictionary(),
		"Round trip"
	)


func test_an_empty_dictionary_is_unavailable_not_an_error() -> void:
	var sample := EyeGazeSample.from_dictionary({})
	assert_eq(sample.state, EyeGazeSample.State.UNAVAILABLE, "Nothing known")
	assert_eq(sample.gaze, Vector2.ZERO, "No gaze")


func test_an_unknown_state_is_never_mistaken_for_tracking() -> void:
	assert_eq(EyeGazeSample.state_from_int(99), EyeGazeSample.State.UNAVAILABLE, "Unknown")
	assert_eq(EyeGazeSample.state_from_int(-1), EyeGazeSample.State.UNAVAILABLE, "Negative")


func test_confidence_and_blink_are_clamped() -> void:
	var sample := EyeGazeSample.from_dictionary({"confidence": 3.0, "blink": -1.0})
	assert_eq(sample.confidence, 1.0, "Confidence")
	assert_eq(sample.blink, 0.0, "Blink")


func test_state_names_are_readable() -> void:
	assert_eq(EyeGazeSample.state_name(EyeGazeSample.State.NO_FACE), "NO_FACE", "Name")


func test_the_native_backend_without_a_plugin_reports_unavailable() -> void:
	# No desktop or CI build carries the plugin.
	if NativeEyeGazeBackend.is_present():
		pending("This build has the gaze plugin")
		return
	var backend := NativeEyeGazeBackend.new()
	backend.start()
	var sample := backend.poll()
	backend.stop()
	assert_eq(sample.state, EyeGazeSample.State.UNAVAILABLE, "No plugin, no tracking")

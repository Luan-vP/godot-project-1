extends GutTest
## Covers [ParameterFader]: range mapping, frame-rate-independent smoothing,
## writing to an arbitrary target property, and settling when input stops.

const EPSILON := 0.001


func _settle_for_one_second(fader: ParameterFader, steps: int, input: float) -> float:
	var value := 0.0
	for _i in steps:
		value = fader.advance(1.0 / float(steps), input)
	return value


func test_first_reading_is_not_smoothed_from_nothing() -> void:
	var fader := ParameterFader.new()
	fader.output_min = 0.0
	fader.output_max = 100.0
	fader.retention_per_second = 0.9
	assert_almost_eq(fader.advance(1.0 / 60.0, 1.0), 100.0, EPSILON, "First sample")


func test_a_step_change_settles_rather_than_jumps() -> void:
	var fader := ParameterFader.new()
	fader.output_min = 0.0
	fader.output_max = 1.0
	fader.retention_per_second = 0.5
	fader.advance(1.0 / 60.0, 0.0)
	var once := fader.advance(1.0 / 60.0, 1.0)
	assert_gt(once, 0.0, "Should move towards the new target")
	assert_lt(once, 1.0, "Should not arrive in one step")


func test_smoothing_does_not_depend_on_the_frame_rate() -> void:
	# The bug this guards against: a fixed per-frame factor closes the gap
	# roughly twice as fast at 144 fps as at 30, so the settling curve would
	# depend on the player's monitor.
	var slow := ParameterFader.new()
	slow.output_min = 0.0
	slow.output_max = 1.0
	slow.retention_per_second = 0.5
	slow.advance(0.0, 0.0)

	var fast := ParameterFader.new()
	fast.output_min = 0.0
	fast.output_max = 1.0
	fast.retention_per_second = 0.5
	fast.advance(0.0, 0.0)

	var slow_result := _settle_for_one_second(slow, 30, 1.0)
	var fast_result := _settle_for_one_second(fast, 144, 1.0)
	assert_almost_eq(slow_result, fast_result, EPSILON, "One second at 30 vs 144 fps")
	# After exactly one second, half the gap should remain.
	assert_almost_eq(slow_result, 0.5, EPSILON, "Half the gap remains after one second")


func test_zero_retention_snaps_immediately() -> void:
	var fader := ParameterFader.new()
	fader.output_min = 0.0
	fader.output_max = 1.0
	fader.retention_per_second = 0.0
	fader.advance(1.0 / 60.0, 0.0)
	assert_almost_eq(fader.advance(1.0 / 60.0, 1.0), 1.0, EPSILON, "Snaps with no retention")


func test_input_is_remapped_before_smoothing() -> void:
	var fader := ParameterFader.new()
	fader.input_min = 0.0
	fader.input_max = 10.0
	fader.output_min = 200.0
	fader.output_max = 8000.0
	fader.retention_per_second = 0.0
	assert_almost_eq(fader.advance(0.016, 0.0), 200.0, EPSILON, "Bottom of input range")
	assert_almost_eq(fader.advance(0.016, 10.0), 8000.0, EPSILON, "Top of input range")
	assert_almost_eq(fader.advance(0.016, 5.0), 4100.0, EPSILON, "Midpoint of input range")


func test_remap_is_a_pure_static_helper() -> void:
	assert_almost_eq(ParameterFader.remap(0.5, 0.0, 1.0, 0.0, 100.0), 50.0, EPSILON)
	assert_almost_eq(ParameterFader.remap(5.0, 0.0, 10.0, -1.0, 1.0), 0.0, EPSILON)


func test_drives_a_filter_cutoff() -> void:
	var filter := AudioEffectLowPassFilter.new()
	var fader := ParameterFader.new()
	fader.target = filter
	fader.property = &"cutoff_hz"
	fader.input_min = 0.0
	fader.input_max = 1.0
	fader.output_min = 200.0
	fader.output_max = 6000.0
	fader.retention_per_second = 0.0
	fader.advance(0.016, 1.0)
	assert_almost_eq(filter.cutoff_hz, 6000.0, EPSILON, "Filter cutoff written through")


func test_drives_a_wet_dry_level() -> void:
	var reverb := AudioEffectReverb.new()
	var fader := ParameterFader.new()
	fader.target = reverb
	fader.property = &"wet"
	fader.input_min = 0.0
	fader.input_max = 1.0
	fader.output_min = 0.0
	fader.output_max = 1.0
	fader.retention_per_second = 0.0
	fader.advance(0.016, 0.75)
	assert_almost_eq(reverb.wet, 0.75, EPSILON, "Wet level written through")


func test_settles_to_rest_value_once_input_stops_arriving() -> void:
	var fader := ParameterFader.new()
	fader.output_min = 0.0
	fader.output_max = 1.0
	fader.retention_per_second = 0.01
	fader.rest_value = 0.0
	fader.input_timeout = 0.2

	fader.advance(0.016, 1.0)
	# Input still arriving: within the timeout, no input should hold near the
	# last value rather than immediately sliding towards rest.
	var held := fader.advance(0.05, null)
	assert_almost_eq(held, 1.0, 0.05, "Holds steady immediately after input stops")

	# Long past the timeout, it should have eased down towards rest_value
	# rather than staying pinned at the last value forever.
	var settled := 1.0
	for _i in 300:
		settled = fader.advance(1.0 / 60.0, null)
	assert_almost_eq(settled, 0.0, EPSILON, "Settles to rest value")


func test_fresh_input_resets_the_timeout_clock() -> void:
	# Neither gap alone reaches the timeout, but their sum would if the clock
	# did not reset on the fresh reading in between.
	var fader := ParameterFader.new()
	fader.output_min = 0.0
	fader.output_max = 1.0
	fader.retention_per_second = 0.0
	fader.rest_value = 0.0
	fader.input_timeout = 0.1

	fader.advance(0.05, 1.0)
	fader.advance(0.09, null)
	fader.advance(0.05, 1.0)
	var still_at_target := fader.advance(0.09, null)
	assert_almost_eq(still_at_target, 1.0, EPSILON, "Timeout must not accumulate across fresh input")


func test_reset_forgets_state_so_the_next_reading_snaps() -> void:
	var fader := ParameterFader.new()
	fader.output_min = 0.0
	fader.output_max = 1.0
	fader.retention_per_second = 0.9
	fader.advance(1.0 / 60.0, 0.0)
	fader.reset()
	assert_almost_eq(fader.advance(1.0 / 60.0, 1.0), 1.0, EPSILON, "Snaps after reset")

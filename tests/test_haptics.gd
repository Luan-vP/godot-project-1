extends GutTest
## Covers #112: [Haptics] picking an output, rate-limiting a burst, and
## honouring the comfort setting — all against [NullHapticsOutput].

const _TEST_SETTINGS_PATH := "user://test_haptics_settings.cfg"

var _haptics: Haptics
var _output: NullHapticsOutput


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()
	ComfortSettings.set_haptics_strength(1.0)
	_output = NullHapticsOutput.new()
	_output.available = true
	_haptics = Haptics.new()
	var outputs: Array[HapticsOutput] = [_output]
	_haptics.set_outputs(outputs)
	add_child_autofree(_haptics)


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	ComfortSettings.set_haptics_strength(1.0)


func test_a_pulse_reaches_the_output() -> void:
	_haptics.pulse(0.5, 0.03)
	assert_eq(_output.pulses, [[0.5, 0.03]])


func test_an_unavailable_output_is_skipped() -> void:
	var dead := NullHapticsOutput.new()
	var outputs: Array[HapticsOutput] = [dead, _output]
	_haptics.set_outputs(outputs)
	_haptics.pulse(0.5)
	assert_eq(dead.pulses.size(), 0, "Not available, not used")
	assert_eq(_output.pulses.size(), 1, "The next one is")


func test_no_output_is_not_an_error() -> void:
	var outputs: Array[HapticsOutput] = []
	_haptics.set_outputs(outputs)
	_haptics.pulse(0.5)
	assert_eq(_haptics.describe(), "none")


func test_comfort_setting_scales_and_mutes() -> void:
	ComfortSettings.set_haptics_strength(0.5)
	_haptics.pulse(0.8)
	assert_almost_eq(float(_output.pulses[0][0]), 0.4, 0.0001, "Scaled")
	ComfortSettings.set_haptics_strength(0.0)
	_haptics.get_limiter()._last_at = -INF
	_haptics.pulse(0.8)
	assert_eq(_output.pulses.size(), 1, "Off means off")


func test_limiter_plays_spaced_requests_at_once() -> void:
	var limiter := HapticsRateLimiter.new()
	assert_eq(limiter.request(0.0, 0.5), 0.5)
	assert_eq(limiter.request(0.1, 0.6), 0.6)


func test_limiter_merges_a_burst_into_one_held_pulse_strongest_wins() -> void:
	var limiter := HapticsRateLimiter.new()
	limiter.min_interval = 0.05
	assert_eq(limiter.request(0.0, 0.3), 0.3, "First plays")
	assert_eq(limiter.request(0.01, 0.4), -1.0, "Too soon: held")
	assert_eq(limiter.request(0.02, 0.9), -1.0, "Merged")
	assert_eq(limiter.request(0.03, 0.2), -1.0, "Merged, weaker")
	assert_eq(limiter.flush(0.04), -1.0, "Not due yet")
	assert_eq(limiter.flush(0.05), 0.9, "Strongest of the burst")
	assert_false(limiter.has_held(), "Nothing left behind")


func test_a_burst_never_backs_up() -> void:
	var limiter := HapticsRateLimiter.new()
	limiter.min_interval = 0.05
	var played := 0
	var t := 0.0
	# Twenty requests a second for a second: at most one pulse per interval.
	for i in 20:
		if limiter.request(t, 1.0) >= 0.0:
			played += 1
		if limiter.flush(t) >= 0.0:
			played += 1
		t += 0.05
	assert_lte(played, 21)
	assert_false(limiter.has_held() and limiter.flush(t + 1.0) < 0.0)

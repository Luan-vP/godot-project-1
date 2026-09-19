extends GutTest
## Covers [ArrangementDirector]: the ordered layer stack and the hysteresis
## that stops a flickering intensity reading from chattering a layer in and
## out. Driven with synthetic intensity/seconds values passed straight to
## [method ArrangementDirector.update], the same way
## [LoopLayerScheduler]'s tests drive bar boundaries — a scripted sequence of
## readings, no running game, no scene tree.

const LAYERS: Array[String] = ["beat", "hats", "bass", "shimmer"]
const THRESHOLDS: Array[float] = [1.0, 3.0, 6.0, 10.0]


func _new_director(release_seconds := 2.0, min_hold_seconds := 0.0) -> ArrangementDirector:
	return ArrangementDirector.new(
		LAYERS.duplicate(), THRESHOLDS, release_seconds, min_hold_seconds
	)


func test_starts_with_no_layers_active() -> void:
	var director := _new_director()
	assert_eq(director.current_level(), 0)
	assert_eq(director.active_layers(), [])


func test_rising_intensity_adds_a_layer_immediately() -> void:
	var director := _new_director()
	var changes := director.update(1.0, 0.0)
	assert_eq(changes, {"beat": true})
	assert_eq(director.active_layers(), ["beat"])


func test_a_big_jump_adds_every_layer_it_justifies_in_one_call() -> void:
	var director := _new_director()
	var changes := director.update(10.0, 0.0)
	assert_eq(changes, {"beat": true, "hats": true, "bass": true, "shimmer": true})
	assert_eq(director.active_layers(), LAYERS)


func test_intensity_between_thresholds_holds_the_lower_layer_count() -> void:
	var director := _new_director()
	director.update(1.0, 0.0)
	var changes := director.update(2.9, 1.0)
	assert_true(changes.is_empty())
	assert_eq(director.current_level(), 1)


func test_falling_intensity_does_not_leave_before_release_seconds_elapse() -> void:
	var director := _new_director(2.0)
	director.update(3.0, 0.0)  # Two layers in.
	var changes := director.update(0.0, 1.0)  # Below both thresholds, but only 1s in.
	assert_true(changes.is_empty(), "Should still be pending, not released yet")
	assert_eq(director.current_level(), 2)


func test_falling_intensity_leaves_once_it_has_stayed_down_for_release_seconds() -> void:
	var director := _new_director(2.0)
	director.update(3.0, 0.0)  # Two layers in: beat, hats.
	director.update(0.0, 0.5)  # Starts counting down from here.
	var changes := director.update(0.0, 2.6)  # 2.1s continuously below.
	assert_eq(changes, {"hats": false}, "Only the top layer leaves, one rung at a time")
	assert_eq(director.current_level(), 1)


func test_a_brief_recovery_cancels_the_pending_release() -> void:
	var director := _new_director(2.0)
	director.update(3.0, 0.0)
	director.update(0.0, 0.5)  # Below threshold: pending release starts.
	director.update(3.0, 1.0)  # Recovers before release_seconds elapses.
	var changes := director.update(0.0, 1.6)  # Below again, but only 0.6s this time.
	assert_true(changes.is_empty(), "The earlier drop must not count towards this one")
	assert_eq(director.current_level(), 2)


func test_a_large_drop_leaves_one_layer_at_a_time_not_all_at_once() -> void:
	var director := _new_director(2.0)
	director.update(10.0, 0.0)  # Every layer in.
	director.update(0.0, 0.0)
	var first_release := director.update(0.0, 2.1)
	assert_eq(first_release, {"shimmer": false}, "Only the top rung leaves on the first release")
	assert_eq(director.current_level(), 3)

	# The next rung needs its own release_seconds, not the same countdown.
	var too_soon := director.update(0.0, 2.2)
	assert_true(too_soon.is_empty())
	var second_release := director.update(0.0, 4.2)
	assert_eq(second_release, {"bass": false})
	assert_eq(director.current_level(), 2)


func test_min_hold_seconds_keeps_a_freshly_entered_layer_even_after_release_seconds() -> void:
	var director := _new_director(1.0, 5.0)
	director.update(3.0, 0.0)  # Enters at t=0; must stay until at least t=5.
	director.update(0.0, 0.5)  # Below threshold from here on.
	var changes := director.update(0.0, 4.0)  # 3.5s below release, but only 4s of hold so far.
	assert_true(changes.is_empty(), "min_hold_seconds must still be blocking the release")
	var later := director.update(0.0, 5.5)
	assert_eq(later, {"hats": false}, "Once both conditions are satisfied, it releases")


func test_reset_forgets_the_level_and_any_pending_release() -> void:
	var director := _new_director(2.0)
	director.update(3.0, 0.0)
	director.reset()
	assert_eq(director.current_level(), 0)
	assert_eq(director.active_layers(), [])
	var changes := director.update(0.0, 100.0)
	assert_true(changes.is_empty(), "Nothing pending survives a reset")


func test_top_threshold_is_the_last_entry() -> void:
	var director := _new_director()
	assert_eq(director.top_threshold(), 10.0)


func test_top_threshold_is_zero_with_no_thresholds() -> void:
	var empty_layers: Array[String] = []
	var director := ArrangementDirector.new(empty_layers, [])
	assert_eq(director.top_threshold(), 0.0)

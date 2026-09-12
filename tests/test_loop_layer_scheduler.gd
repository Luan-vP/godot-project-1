extends GutTest
## Covers [LoopLayerScheduler]: requests queue and only release on a bar
## boundary, never before. Driven with synthetic seconds values passed
## straight to [method LoopLayerScheduler.update], so a bar boundary is
## "advanced" to on demand rather than by waiting on real playback.

const _CLOCK_TEMPO_BPM := 120.0
const _CLOCK_BEATS_PER_BAR := 4
# 120 BPM, 4 beats/bar => 2 seconds per bar.
const _BAR_SECONDS := 2.0

var _scheduler: LoopLayerScheduler


func before_each() -> void:
	_scheduler = LoopLayerScheduler.new(MusicClock.new(_CLOCK_TEMPO_BPM, _CLOCK_BEATS_PER_BAR))


func test_first_update_establishes_a_baseline_without_releasing_anything() -> void:
	_scheduler.request("bass", true)
	var changes := _scheduler.update(0.0)
	assert_true(changes.is_empty(), "First update should only set the starting bar")


func test_request_mid_bar_does_not_release_until_the_next_bar() -> void:
	_scheduler.update(0.0)  # Establish bar 0 as the baseline.
	_scheduler.request("bass", true)
	var still_mid_bar := _scheduler.update(1.9)
	assert_true(still_mid_bar.is_empty(), "Still bar 0; must not release yet")


func test_request_releases_exactly_when_the_bar_advances() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	var changes := _scheduler.update(2.1)  # Now bar 1.
	assert_eq(changes, {"bass": true})


func test_no_pending_requests_means_no_changes_even_across_a_bar_boundary() -> void:
	_scheduler.update(0.0)
	var changes := _scheduler.update(2.1)
	assert_true(changes.is_empty())


func test_a_later_request_for_the_same_layer_replaces_the_earlier_one() -> void:
	_scheduler.update(0.0)
	_scheduler.request("pad", true)
	_scheduler.request("pad", false)  # Changed its mind before the bar landed.
	var changes := _scheduler.update(2.1)
	assert_eq(changes, {"pad": false})


func test_multiple_layers_requested_in_the_same_bar_release_together() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	_scheduler.request("pad", false)
	var changes := _scheduler.update(2.1)
	assert_eq(changes, {"bass": true, "pad": false})


func test_released_changes_are_not_repeated_on_a_later_bar() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	_scheduler.update(2.1)
	var changes := _scheduler.update(4.1)  # Bar 2, nothing new pending.
	assert_true(changes.is_empty())


func test_reset_clears_pending_requests_and_the_bar_baseline() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	_scheduler.reset()
	# Baseline forgotten, so this call only re-establishes it, even at what
	# would otherwise read as a new bar.
	var changes := _scheduler.update(2.1)
	assert_true(changes.is_empty(), "Reset should have discarded the pending request")


## Regression: without rebasing, a tempo change swaps in a clock with a
## different seconds-per-bar scale but leaves _last_bar computed under the
## old one. The next update() then compares a new-clock bar against an
## old-clock bar - two different tempos rarely agree on which bar a given
## position falls in, so the mismatch reads as a crossing and releases
## anything pending immediately, mid-bar, rather than waiting for a real one.
func test_set_clock_rebases_the_baseline_without_releasing_pending() -> void:
	_scheduler.update(0.0)  # Establish bar 0 under the original 120 BPM clock.
	_scheduler.request("bass", true)

	# 240 BPM halves the bar to 1 second. At the same 1.5s playback position
	# that is mid-bar-1 under the new clock too, not a crossing.
	var faster_clock := MusicClock.new(240.0, _CLOCK_BEATS_PER_BAR)
	_scheduler.set_clock(faster_clock, 1.5)
	var immediately_after_swap := _scheduler.update(1.5)
	assert_true(
		immediately_after_swap.is_empty(),
		"Swapping clocks must not itself look like crossing a bar boundary"
	)

	var changes := _scheduler.update(2.1)  # Bar 2 under the new clock: a real crossing.
	assert_eq(changes, {"bass": true})

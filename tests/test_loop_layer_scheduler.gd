extends GutTest
## Covers [LoopLayerScheduler]: requests queue and only release on a bar
## boundary, never before. Driven with synthetic positions in beats passed
## straight to [method LoopLayerScheduler.update], so a bar boundary is
## "advanced" to on demand rather than by waiting on real playback.

const _CLOCK_TEMPO_BPM := 120.0
const _CLOCK_BEATS_PER_BAR := 4

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
	var still_mid_bar := _scheduler.update(3.9)
	assert_true(still_mid_bar.is_empty(), "Still bar 0; must not release yet")


func test_request_releases_exactly_when_the_bar_advances() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	var changes := _scheduler.update(4.1)  # Now bar 1.
	assert_eq(changes, {"bass": true})


func test_no_pending_requests_means_no_changes_even_across_a_bar_boundary() -> void:
	_scheduler.update(0.0)
	var changes := _scheduler.update(4.1)
	assert_true(changes.is_empty())


func test_a_later_request_for_the_same_layer_replaces_the_earlier_one() -> void:
	_scheduler.update(0.0)
	_scheduler.request("pad", true)
	_scheduler.request("pad", false)  # Changed its mind before the bar landed.
	var changes := _scheduler.update(4.1)
	assert_eq(changes, {"pad": false})


func test_multiple_layers_requested_in_the_same_bar_release_together() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	_scheduler.request("pad", false)
	var changes := _scheduler.update(4.1)
	assert_eq(changes, {"bass": true, "pad": false})


func test_released_changes_are_not_repeated_on_a_later_bar() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	_scheduler.update(4.1)
	var changes := _scheduler.update(8.1)  # Bar 2, nothing new pending.
	assert_true(changes.is_empty())


func test_reset_clears_pending_requests_and_the_bar_baseline() -> void:
	_scheduler.update(0.0)
	_scheduler.request("bass", true)
	_scheduler.reset()
	# Baseline forgotten, so this call only re-establishes it, even at what
	# would otherwise read as a new bar.
	var changes := _scheduler.update(4.1)
	assert_true(changes.is_empty(), "Reset should have discarded the pending request")


## A tempo change must not release a pending request early. This used to need
## rebasing: while positions were seconds, two tempos disagreed about which
## bar a position fell in, the mismatch read as a crossing, and anything
## pending released immediately, mid-bar. In beats they agree, so the swap is
## a non-event and the request still waits for a real bar line.
func test_a_tempo_change_does_not_release_a_pending_request() -> void:
	_scheduler.update(0.0)  # Establish bar 0 under the original 120 BPM clock.
	_scheduler.request("bass", true)
	_scheduler.update(3.0)  # Three beats in: mid-bar-0, whatever the tempo.

	_scheduler.set_clock(MusicClock.new(240.0, _CLOCK_BEATS_PER_BAR))
	var immediately_after_swap := _scheduler.update(3.0)
	assert_true(
		immediately_after_swap.is_empty(),
		"Swapping clocks must not itself look like crossing a bar boundary"
	)

	var changes := _scheduler.update(4.1)  # Bar 1: a real crossing.
	assert_eq(changes, {"bass": true}, "And the request is still there to release")

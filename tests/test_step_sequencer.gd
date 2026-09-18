extends GutTest
## Covers [StepSequencer] with synthetic beats: every step reported once, in
## order, early by the lookahead, and not in a burst after a hitch.
##
## [StepSequencer] speaks beats (#74), so most of these drive it directly in
## beats. Where a test wants to simulate a real frame loop accumulating wall
## time, it converts through [method MusicClock.beats_from_seconds] — the
## same conversion a real [MusicTimeSource] does internally.

const TEMPO := 70.0

var _clock := MusicClock.new(TEMPO, 4)
var _step := 60.0 / TEMPO / 4.0


func test_steps_fire_once_each_in_order_at_any_frame_rate() -> void:
	for fps in [30.0, 144.0]:
		var sequencer := StepSequencer.new(_clock)
		var fired: Array[int] = []
		var seconds := 0.0
		while seconds < _step * 32.0:
			fired.append_array(sequencer.update(_clock.beats_from_seconds(seconds)))
			seconds += 1.0 / fps
		var expected: Array[int] = []
		for i in 32:
			expected.append(i)
		assert_eq(fired, expected, "Two bars of steps at %d fps" % fps)


func test_a_step_is_not_reported_before_it_is_due() -> void:
	var sequencer := StepSequencer.new(_clock)
	assert_eq(sequencer.update(0.0), [0] as Array[int], "Step 0 at the start")
	assert_eq(
		sequencer.update(_clock.beats_from_seconds(_step * 0.99)),
		[] as Array[int],
		"Step 1 not yet"
	)
	assert_eq(
		sequencer.update(_clock.beats_from_seconds(_step * 1.0)),
		[1] as Array[int],
		"Step 1 on time"
	)


func test_lookahead_reports_a_step_early() -> void:
	var sequencer := StepSequencer.new(_clock)
	sequencer.update(0.0)
	var lookahead := _clock.beats_from_seconds(0.005)
	assert_eq(
		sequencer.update(_clock.beats_from_seconds(_step - 0.004), lookahead),
		[1] as Array[int],
		"5 ms early is allowed"
	)
	assert_eq(
		sequencer.update(_clock.beats_from_seconds(_step + 0.001), lookahead),
		[] as Array[int],
		"Not reported twice"
	)


func test_a_long_hitch_drops_old_steps_instead_of_bursting() -> void:
	var sequencer := StepSequencer.new(_clock)
	sequencer.update(0.0)
	var after_hitch := sequencer.update(_clock.beats_from_seconds(_step * 10.0))
	assert_eq(after_hitch.size(), StepSequencer.MAX_CATCH_UP, "Capped")
	assert_eq(after_hitch[-1], 10, "Ends on the step that is due now")


func test_joining_mid_step_waits_for_the_next_one() -> void:
	var sequencer := StepSequencer.new(_clock)
	assert_eq(
		sequencer.update(_clock.beats_from_seconds(_step * 5.5)),
		[] as Array[int],
		"Step 5 is already half over"
	)
	assert_eq(
		sequencer.update(_clock.beats_from_seconds(_step * 6.0)),
		[6] as Array[int],
		"Starts on step 6"
	)


func test_reset_starts_again_from_the_given_time() -> void:
	var sequencer := StepSequencer.new(_clock)
	sequencer.update(0.0)
	sequencer.update(_clock.beats_from_seconds(_step * 3.0))
	sequencer.reset()
	assert_eq(sequencer.update(0.0), [0] as Array[int], "From the top")


## A tempo change swaps in a new clock, but beats already accumulated carry
## no tempo scale (#74), so [method StepSequencer.set_clock] no longer takes
## or needs a position to rebase onto — see [method
## LoopLayerScheduler.set_clock] for the same change there.
func test_a_tempo_change_does_not_refire_steps() -> void:
	var sequencer := StepSequencer.new(_clock)
	var beats := 0.0
	while beats < 8.0 * _clock.beats_at_step(1):
		sequencer.update(beats)
		beats += 0.01
	var faster := MusicClock.new(140.0, 4)
	sequencer.set_clock(faster)
	var next := sequencer.update(beats + faster.beats_at_step(1))
	assert_eq(next.size(), 1, "One new step, not a replay")
	assert_eq(next[0], faster.step_at(beats) + 1, "The next step under the new tempo")

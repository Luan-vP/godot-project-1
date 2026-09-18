extends GutTest
## Covers [StepSequencer] with synthetic positions: every step reported once,
## in order, early by the lookahead, and not in a burst after a hitch.
##
## Positions are in beats, so at four steps to the beat a step is 0.25 and the
## tempo does not come into it — which is the point of #74.

const TEMPO := 70.0
const STEP := 0.25

var _clock := MusicClock.new(TEMPO, 4)


func test_steps_fire_once_each_in_order_at_any_frame_rate() -> void:
	for fps in [30.0, 144.0]:
		var sequencer := StepSequencer.new(_clock)
		var fired: Array[int] = []
		var beats := 0.0
		var per_frame := _clock.beats_in(1.0 / fps)
		while beats < STEP * 32.0:
			fired.append_array(sequencer.update(beats))
			beats += per_frame
		var expected: Array[int] = []
		for i in 32:
			expected.append(i)
		assert_eq(fired, expected, "Two bars of steps at %d fps" % fps)


func test_a_step_is_not_reported_before_it_is_due() -> void:
	var sequencer := StepSequencer.new(_clock)
	assert_eq(sequencer.update(0.0), [0] as Array[int], "Step 0 at the start")
	assert_eq(sequencer.update(STEP * 0.99), [] as Array[int], "Step 1 not yet")
	assert_eq(sequencer.update(STEP * 1.0), [1] as Array[int], "Step 1 on time")


func test_lookahead_reports_a_step_early() -> void:
	var sequencer := StepSequencer.new(_clock)
	sequencer.update(0.0)
	assert_eq(sequencer.update(STEP - 0.01, 0.02), [1] as Array[int], "A shade early is allowed")
	assert_eq(sequencer.update(STEP + 0.01, 0.02), [] as Array[int], "Not reported twice")


func test_a_long_hitch_drops_old_steps_instead_of_bursting() -> void:
	var sequencer := StepSequencer.new(_clock)
	sequencer.update(0.0)
	var after_hitch := sequencer.update(STEP * 10.0)
	assert_eq(after_hitch.size(), StepSequencer.MAX_CATCH_UP, "Capped")
	assert_eq(after_hitch[-1], 10, "Ends on the step that is due now")


func test_joining_mid_step_waits_for_the_next_one() -> void:
	var sequencer := StepSequencer.new(_clock)
	assert_eq(sequencer.update(STEP * 5.5), [] as Array[int], "Step 5 is already half over")
	assert_eq(sequencer.update(STEP * 6.0), [6] as Array[int], "Starts on step 6")


func test_reset_starts_again_from_the_given_position() -> void:
	var sequencer := StepSequencer.new(_clock)
	sequencer.update(0.0)
	sequencer.update(STEP * 3.0)
	sequencer.reset()
	assert_eq(sequencer.update(0.0), [0] as Array[int], "From the top")


## A tempo change must neither replay a step nor skip one. It used to take a
## rebase to manage that, because two tempos disagreed about which step a
## position in seconds fell in; in beats they agree, so the swap changes
## nothing and the run simply carries on.
func test_a_tempo_change_neither_refires_nor_skips_a_step() -> void:
	var sequencer := StepSequencer.new(_clock)
	var fired: Array[int] = []
	var beats := 0.0
	# Stop short of step 8, so the tempo changes mid-step rather than on a
	# boundary that would have fired anyway.
	while beats < STEP * 8.0 - 0.01:
		fired.append_array(sequencer.update(beats))
		beats += 0.01
	assert_eq(fired[-1], 7, "Seven steps in when the tempo changes")

	sequencer.set_clock(MusicClock.new(140.0, 4))
	assert_eq(sequencer.update(beats), [] as Array[int], "The swap alone fires nothing")
	assert_eq(sequencer.update(STEP * 8.0), [8] as Array[int], "Step 8 next, once and in order")

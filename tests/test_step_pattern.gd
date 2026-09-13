extends GutTest
## Covers [StepPattern]: text patterns, and that a rendered bar puts every hit
## at its exact sample position — the whole reason drums are rendered.

const RATE := 48000
const TEMPO := 70.0


func test_parse_reads_velocities_and_rests() -> void:
	var pattern := StepPattern.parse({"kick": "9..x.5..", "snare": "....9..."})
	assert_eq(pattern.steps, 8, "Longest line sets the step count")
	assert_almost_eq(pattern.velocity(DrumSynth.Hit.KICK, 0), 1.0, 0.001, "9 is full")
	assert_almost_eq(pattern.velocity(DrumSynth.Hit.KICK, 3), 1.0, 0.001, "x is full")
	assert_almost_eq(pattern.velocity(DrumSynth.Hit.KICK, 5), 5.0 / 9.0, 0.001, "5 of 9")
	assert_eq(pattern.velocity(DrumSynth.Hit.KICK, 1), 0.0, "Rest")
	assert_eq(pattern.velocity(DrumSynth.Hit.CLAP, 0), 0.0, "Absent track")


func test_bar_length_is_one_bar_in_whole_samples() -> void:
	assert_eq(StepPattern.bar_length(TEMPO, 4, RATE), int(round(60.0 / TEMPO * 4.0 * RATE)))
	assert_eq(StepPattern.bar_length(120.0, 4, RATE), 96000, "Exact at 120 bpm")


func test_step_offsets_do_not_accumulate_rounding() -> void:
	var bar := StepPattern.bar_length(TEMPO, 4, RATE)
	for step in 16:
		var exact := float(step) * bar / 16.0
		assert_lte(absf(StepPattern.step_offset(step, 16, bar) - exact), 0.5, "Step %d" % step)


func test_each_hit_lands_on_its_exact_sample() -> void:
	var pattern := StepPattern.parse({"snare": "....9.......9..."})
	var bar := pattern.mix(TEMPO, 4, RATE)
	var snare := DrumSynth.render(DrumSynth.Hit.SNARE, RATE)
	for step in [4, 12]:
		var offset := StepPattern.step_offset(step, 16, bar.size())
		assert_eq(bar[offset - 1], 0.0, "Silence right before step %d" % step)
		for i in 64:
			assert_almost_eq(
				bar[offset + i],
				StepPattern.soft_clip(snare[i]),
				0.0001,
				"Sample %d of step %d" % [i, step]
			)


func test_a_rendered_stream_loops_exactly_one_bar() -> void:
	var stream := StepPattern.parse({"kick": "9..............."}).render(TEMPO, 4, RATE)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Loops")
	assert_eq(stream.loop_end, StepPattern.bar_length(TEMPO, 4, RATE), "One bar")
	assert_eq(stream.data.size(), stream.loop_end * 2, "16-bit mono")


func test_a_tail_past_the_bar_wraps_to_the_start() -> void:
	var pattern := StepPattern.parse({"open_hat": "...............9"})
	var bar := pattern.mix(TEMPO, 4, RATE)
	var last := StepPattern.step_offset(15, 16, bar.size())
	var hat := DrumSynth.render(DrumSynth.Hit.OPEN_HAT, RATE)
	var into_next := bar.size() - last
	assert_gt(hat.size(), into_next, "The hat is longer than the last step")
	assert_almost_eq(
		bar[0], StepPattern.soft_clip(hat[into_next]), 0.0001, "Rings into the downbeat"
	)


func test_a_closed_hat_chokes_an_open_one() -> void:
	var pattern := StepPattern.parse({"open_hat": "9...............", "hat": "..9............."})
	var bar := pattern.mix(TEMPO, 4, RATE)
	var closed_at := StepPattern.step_offset(2, 16, bar.size())
	var closed := DrumSynth.render(DrumSynth.Hit.CLOSED_HAT, RATE)
	# Past the closed hat's own sound, nothing of the open hat should remain.
	var after := closed_at + closed.size() + 10
	assert_eq(bar[after], 0.0, "Open hat cut off at the closed hat")


func test_soft_clip_leaves_quiet_samples_alone_and_never_passes_one() -> void:
	assert_eq(StepPattern.soft_clip(0.5), 0.5)
	assert_eq(StepPattern.soft_clip(-0.8), -0.8)
	assert_lt(StepPattern.soft_clip(3.0), 1.0)
	assert_gt(StepPattern.soft_clip(-3.0), -1.0)

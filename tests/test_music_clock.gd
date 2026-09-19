extends GutTest
## Covers [MusicClock]'s bar/beat/step math directly, with synthetic beats
## values rather than real playback — the "advance it deterministically"
## acceptance criterion from #31. No drift is provable here because the
## clock never accumulates state across calls; every answer is a pure
## function of the beats it is given, however large.
##
## Bar/beat/step math never depends on tempo (#74) — a bar is a fixed number
## of beats regardless of how fast those beats are ticking by — so most tests
## below don't vary tempo at all. Only the wall-seconds conversions
## (`seconds_per_*`, `beats_from_seconds`) are tempo-dependent, and are
## covered separately.


func test_bar_zero_covers_the_first_bar() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_eq(clock.bar_at(0.0), 0)
	assert_eq(clock.bar_at(3.9), 0)
	assert_eq(clock.bar_at(4.0), 1)
	assert_eq(clock.bar_at(7.9), 1)
	assert_eq(clock.bar_at(8.0), 2)


func test_bar_math_holds_far_into_a_long_session() -> void:
	var clock := MusicClock.new(120.0, 4)
	# Ten thousand beats in, still exactly on the pure formula, no
	# accumulated drift.
	var many_beats := 10_000.0
	assert_eq(clock.bar_at(many_beats), int(many_beats / 4.0))


func test_beat_in_bar_wraps_within_the_bar() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.beat_in_bar_at(0.0), 0.0, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(1.0), 1.0, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(3.5), 3.5, 0.001)
	# Wrapped into the next bar: beat 4 is bar 1, beat 0 again.
	assert_almost_eq(clock.beat_in_bar_at(4.0), 0.0, 0.001)


func test_beats_until_next_bar_counts_down_across_the_boundary() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.beats_until_next_bar(0.0), 4.0, 0.001)
	assert_almost_eq(clock.beats_until_next_bar(3.0), 1.0, 0.001)
	assert_almost_eq(clock.beats_until_next_bar(4.0), 4.0, 0.001)


func test_bar_length_is_configurable() -> void:
	var clock := MusicClock.new(240.0, 3)
	assert_eq(clock.bar_at(2.9), 0)
	assert_eq(clock.bar_at(3.0), 1)


func test_tempo_is_configurable_for_wall_time_conversions() -> void:
	var fast_clock := MusicClock.new(240.0, 3)
	# 240 BPM => a quarter second per beat, three-quarters of a second per bar.
	assert_almost_eq(fast_clock.seconds_per_beat(), 0.25, 0.001)
	assert_almost_eq(fast_clock.seconds_per_bar(), 0.75, 0.001)


func test_beats_from_seconds_uses_the_clock_tempo() -> void:
	var clock := MusicClock.new(120.0, 4)
	# 120 BPM => 2 beats per second.
	assert_almost_eq(clock.beats_from_seconds(1.0), 2.0, 0.001)
	assert_almost_eq(clock.beats_from_seconds(0.0), 0.0, 0.001)


func test_steps_per_bar_does_not_depend_on_tempo() -> void:
	var slow := MusicClock.new(70.0, 4)
	var fast := MusicClock.new(140.0, 4)
	assert_eq(slow.steps_per_bar(), 16, "Sixteen per bar in 4/4")
	assert_eq(fast.steps_per_bar(), slow.steps_per_bar(), "Tempo does not change the grid")


func test_step_at_reads_the_same_step_from_the_same_beats_at_any_tempo() -> void:
	var slow := MusicClock.new(70.0, 4)
	var fast := MusicClock.new(140.0, 4)
	assert_eq(slow.step_at(0.0), 0, "First step")
	assert_eq(slow.step_at(0.24), 0, "Still the first step")
	assert_eq(slow.step_at(4.2525), 17, "Second bar, second step")
	assert_eq(fast.step_at(4.2525), slow.step_at(4.2525), "Tempo does not move the grid")
	assert_almost_eq(slow.beats_at_step(16), 4.0, 0.000001, "Bar 1 starts at beat 4")


func test_seconds_per_step_reflects_tempo() -> void:
	var clock := MusicClock.new(70.0, 4)
	var step := 60.0 / 70.0 / 4.0
	assert_almost_eq(clock.seconds_per_step(), step, 0.000001, "A sixteenth in wall time")


func test_steps_per_beat_is_configurable() -> void:
	var triplets := MusicClock.new(70.0, 4, 3)
	assert_eq(triplets.steps_per_bar(), 12, "Eighth-note triplets")


func test_non_positive_tempo_is_clamped_so_wall_time_never_divides_by_zero() -> void:
	# A live tempo control (#72) can be nudged all the way down to and past
	# zero; seconds_per_beat() is 60.0 / tempo_bpm underneath.
	assert_gt(MusicClock.new(0.0, 4).seconds_per_beat(), 0.0, "Zero tempo")
	assert_gt(MusicClock.new(-10.0, 4).seconds_per_beat(), 0.0, "Negative tempo")

extends GutTest
## Covers [MusicClock]: a position in beats read as bars, beats within a bar
## and grid steps, and the property the whole design rests on — that where the
## music is does not depend on the tempo.


func test_bars_advance_every_beats_per_bar() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_eq(clock.bar_at(0.0), 0)
	assert_eq(clock.bar_at(3.9), 0)
	assert_eq(clock.bar_at(4.0), 1)
	assert_eq(clock.bar_at(7.9), 1)
	assert_eq(clock.bar_at(8.0), 2)


func test_bars_keep_counting_a_long_way_in() -> void:
	var clock := MusicClock.new(120.0, 4)
	var many_beats := 40_000.0
	assert_eq(clock.bar_at(many_beats), int(many_beats / 4.0))


func test_beat_in_bar_wraps_at_the_bar_line() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.beat_in_bar_at(0.0), 0.0, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(1.0), 1.0, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(3.5), 3.5, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(4.0), 0.0, 0.001, "Wraps rather than reaching 4")


func test_beats_until_next_bar_counts_down_across_the_boundary() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.beats_until_next_bar(0.0), 4.0, 0.001)
	assert_almost_eq(clock.beats_until_next_bar(3.0), 1.0, 0.001)
	assert_almost_eq(clock.beats_until_next_bar(4.0), 4.0, 0.001, "A full bar again")


func test_bar_length_is_configurable() -> void:
	var waltz := MusicClock.new(120.0, 3)
	assert_eq(waltz.bar_at(2.9), 0)
	assert_eq(waltz.bar_at(3.0), 1, "Three beats to the bar")


func test_steps_divide_the_beat() -> void:
	var clock := MusicClock.new(70.0, 4)
	assert_eq(clock.steps_per_bar(), 16, "Sixteen per bar in 4/4")
	assert_almost_eq(clock.beats_per_step(), 0.25, 0.000001, "A sixteenth")
	assert_eq(clock.step_at(0.0), 0, "First step")
	assert_eq(clock.step_at(0.249), 0, "Still the first step")
	assert_eq(clock.step_at(4.25), 17, "Second bar, second step")
	assert_almost_eq(clock.beats_at_step(16), 4.0, 0.000001, "Bar 1 starts")


func test_step_grid_is_configurable() -> void:
	var triplets := MusicClock.new(120.0, 4, 3)
	assert_eq(triplets.steps_per_bar(), 12, "Eighth-note triplets")


## The property everything else rests on. Position is in beats, so two clocks
## that differ only in tempo agree about where the music is — which is why
## [LoopLayerScheduler] and [StepSequencer] no longer rebase when the tempo
## changes, and why a tempo control cannot make the music jump. Measured under
## the old seconds-based clock, five minutes into a 70 bpm song a nudge to
## 72 bpm moved bar 87 beat 2.0 to bar 90 beat 0.0.
func test_where_the_music_is_does_not_depend_on_the_tempo() -> void:
	var slow := MusicClock.new(70.0, 4)
	var fast := MusicClock.new(72.0, 4)
	var five_minutes_in := 350.0  # Beats, i.e. five minutes at 70 bpm.
	assert_eq(fast.bar_at(five_minutes_in), slow.bar_at(five_minutes_in), "Same bar")
	assert_almost_eq(
		fast.beat_in_bar_at(five_minutes_in),
		slow.beat_in_bar_at(five_minutes_in),
		0.000001,
		"Same beat within it"
	)
	assert_eq(fast.step_at(five_minutes_in), slow.step_at(five_minutes_in), "Same grid step")


## Tempo survives only to convert beats into wall seconds, for note lengths
## and mix lookahead.
func test_seconds_conversions_follow_the_tempo() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.seconds_per_beat(), 0.5, 0.000001)
	assert_almost_eq(clock.seconds_per_bar(), 2.0, 0.000001)
	assert_almost_eq(clock.seconds_per_step(), 0.125, 0.000001)
	assert_almost_eq(clock.beats_in(1.0), 2.0, 0.000001, "A second is two beats at 120")
	assert_almost_eq(clock.seconds_in(2.0), 1.0, 0.000001, "And back again")


## A tempo control that winds all the way down must not reach a division by
## zero in seconds_per_beat().
func test_tempo_is_clamped_above_zero() -> void:
	assert_eq(MusicClock.new(0.0, 4).tempo_bpm, MusicClock.MIN_TEMPO_BPM, "Zero")
	assert_eq(MusicClock.new(-30.0, 4).tempo_bpm, MusicClock.MIN_TEMPO_BPM, "Negative")
	assert_true(MusicClock.new(0.0, 4).seconds_per_beat() > 0.0, "Still divisible")

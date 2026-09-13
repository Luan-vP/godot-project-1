extends GutTest
## Covers [MusicClock]'s tempo/bar math directly, with synthetic seconds
## values rather than real playback — the "advance it deterministically"
## acceptance criterion from #31. No drift is provable here because the
## clock never accumulates state across calls; every answer is a pure
## function of the seconds it is given, however large.


func test_bar_zero_covers_the_first_bar() -> void:
	var clock := MusicClock.new(120.0, 4)
	# 120 BPM, 4 beats/bar => 2 seconds per bar.
	assert_eq(clock.bar_at(0.0), 0)
	assert_eq(clock.bar_at(1.9), 0)
	assert_eq(clock.bar_at(2.0), 1)
	assert_eq(clock.bar_at(3.9), 1)
	assert_eq(clock.bar_at(4.0), 2)


func test_bar_math_holds_far_into_a_long_session() -> void:
	var clock := MusicClock.new(120.0, 4)
	# Ten minutes in, still exactly on the pure formula, no accumulated drift.
	var ten_minutes := 600.0
	assert_eq(clock.bar_at(ten_minutes), int(ten_minutes / 2.0))


func test_beat_in_bar_wraps_within_the_bar() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.beat_in_bar_at(0.0), 0.0, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(0.5), 1.0, 0.001)
	assert_almost_eq(clock.beat_in_bar_at(1.75), 3.5, 0.001)
	# Wrapped into the next bar: 2.0s is bar 1, beat 0 again.
	assert_almost_eq(clock.beat_in_bar_at(2.0), 0.0, 0.001)


func test_seconds_until_next_bar_counts_down_across_the_boundary() -> void:
	var clock := MusicClock.new(120.0, 4)
	assert_almost_eq(clock.seconds_until_next_bar(0.0), 2.0, 0.001)
	assert_almost_eq(clock.seconds_until_next_bar(1.5), 0.5, 0.001)
	assert_almost_eq(clock.seconds_until_next_bar(2.0), 2.0, 0.001)


func test_tempo_and_bar_length_are_configurable() -> void:
	var fast_clock := MusicClock.new(240.0, 3)
	# 240 BPM, 3 beats/bar => 0.75 seconds per bar.
	assert_almost_eq(fast_clock.seconds_per_bar(), 0.75, 0.001)
	assert_eq(fast_clock.bar_at(0.8), 1)

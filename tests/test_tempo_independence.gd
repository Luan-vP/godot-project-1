extends GutTest
## Headless proof of #74: musical position is beats, integrated against
## whatever tempo was in force while they elapsed, rather than derived by
## dividing elapsed seconds by the *current* tempo. Drives [ScriptedMusicTime],
## [MusicClock], [StepSequencer] and [LoopLayerScheduler] directly by hand —
## no [AudioManager], no real audio — the same "advance it deterministically"
## shape [MusicClock]'s own tests use.
##
## Before #74, five minutes into a 70 bpm song, nudging the tempo to 72 bpm
## reinterpreted the whole elapsed history at the new tempo and jumped the
## position from bar 87 beat 2.0 to bar 90 beat 0.0. With position in beats,
## the beats value itself never changes when the tempo does, so bar and
## beat-in-bar read identically under any clock that looks at it.

var _scripted: ScriptedMusicTime


func before_each() -> void:
	_scripted = ScriptedMusicTime.new()
	_scripted.start()


func test_bar_and_beat_in_bar_are_unaffected_by_which_tempo_reads_them() -> void:
	# Deep into a long session — the #74 regression scenario, where the old
	# seconds-based formula would have disagreed sharply between tempos.
	_scripted.advance(350.5)
	var beats := _scripted.get_beats()
	var before := MusicClock.new(70.0, 4)
	var after := MusicClock.new(72.0, 4)
	assert_eq(before.bar_at(beats), after.bar_at(beats), "Tempo does not move bar boundaries")
	assert_almost_eq(
		before.beat_in_bar_at(beats),
		after.beat_in_bar_at(beats),
		0.000001,
		"Tempo does not move phase inside the bar"
	)


func test_a_tempo_change_mid_song_does_not_jump_bar_or_beat_in_bar() -> void:
	var clock := MusicClock.new(70.0, 4)
	_scripted.advance(350.5)
	var bar_before := clock.bar_at(_scripted.get_beats())
	var beat_before := clock.beat_in_bar_at(_scripted.get_beats())

	# #72's repeated ±2 bpm taps, applied on the spot: only the clock used for
	# future wall-time conversions changes, never the accumulated position.
	clock = MusicClock.new(72.0, 4)

	assert_eq(clock.bar_at(_scripted.get_beats()), bar_before, "No jump in bar across the change")
	assert_almost_eq(
		clock.beat_in_bar_at(_scripted.get_beats()),
		beat_before,
		0.000001,
		"No jump in beat-in-bar across the change"
	)


func test_a_tempo_change_does_not_double_fire_or_skip_grid_steps() -> void:
	var clock := MusicClock.new(70.0, 4)
	var sequencer := StepSequencer.new(clock)
	var fired: Array[int] = []
	var sixteenth := 0.25  # A step, in beats: tempo-independent (#74).

	for i in 8:
		_scripted.advance(sixteenth)
		fired.append_array(sequencer.update(_scripted.get_beats()))

	# Tempo nudges up mid-song, same as #72's repeated taps.
	sequencer.set_clock(MusicClock.new(72.0, 4))

	for i in 24:
		_scripted.advance(sixteenth)
		fired.append_array(sequencer.update(_scripted.get_beats()))

	var expected: Array[int] = []
	for i in 32:
		expected.append(i)
	assert_eq(fired, expected, "Every step fires exactly once, in order, across the tempo change")


func test_a_tempo_change_does_not_release_a_pending_layer_request_early() -> void:
	var clock := MusicClock.new(70.0, 4)
	var scheduler := LoopLayerScheduler.new(clock)
	scheduler.update(_scripted.get_beats())  # Establish bar 0.
	scheduler.request("pad", true)

	_scripted.advance(2.0)  # Halfway through bar 0 (4 beats/bar).
	scheduler.set_clock(MusicClock.new(72.0, 4))
	var immediately_after_swap := scheduler.update(_scripted.get_beats())
	assert_true(
		immediately_after_swap.is_empty(), "Swapping tempo mid-bar must not itself release anything"
	)

	_scripted.advance(2.0)  # Now bar 1: a real crossing.
	var changes := scheduler.update(_scripted.get_beats())
	assert_eq(changes, {"pad": true})

extends GutTest
## Covers the [MusicTimeSource] adapters, and that [AudioManager] and
## [StepClock] take all their timing from whichever one they are given — the
## seam that lets the base timing be replaced later.
##
## Also covers the property #74 exists for: a tempo change during playback is
## continuous, because position is in beats and what has already elapsed keeps
## the tempo it was played at.

const TEMPO := 70.0
const BEATS_PER_BAR := 4

var _scripted: ScriptedMusicTime


func before_each() -> void:
	_scripted = ScriptedMusicTime.new()


func after_each() -> void:
	AudioManager.stop_loops()
	AudioManager.set_music_time_source(WallClockMusicTime.new())
	var no_layers: Array[LoopLayer] = []
	AudioManager.configure_loop_layers(no_layers)
	AudioManager.set_tempo(120.0, 4)


func test_the_default_time_source_is_the_wall_clock() -> void:
	assert_is(AudioManager.get_music_time_source(), WallClockMusicTime)


func test_a_wall_clock_reads_zero_until_started_and_after_stopping() -> void:
	var wall := WallClockMusicTime.new()
	wall.set_tempo(120.0)  # Two beats a second.
	assert_eq(wall.get_beats(), 0.0, "Before start")
	wall.start()
	assert_true(wall.is_running(), "Running")
	await wait_seconds(0.05)
	assert_gt(wall.get_beats(), 0.06, "Climbs while running")
	wall.stop()
	assert_eq(wall.get_beats(), 0.0, "Zero once stopped")
	assert_eq(wall.get_lookahead(), 0.0, "No lookahead while stopped")


## The heart of it. Changing tempo banks what has elapsed at the old tempo
## first, so the position does not move at the moment of the change — it only
## starts moving at a different rate. Computing beats from a running seconds
## total instead would rewrite everything already played: measured under the
## old clock, five minutes into a 70 bpm song a nudge to 72 bpm moved bar 87
## beat 2.0 to bar 90 beat 0.0.
func test_a_tempo_change_does_not_move_the_wall_clock_position() -> void:
	var wall := WallClockMusicTime.new()
	wall.set_tempo(60.0)  # One beat a second.
	wall.start()
	await wait_seconds(0.1)

	var before := wall.get_beats()
	wall.set_tempo(600.0)
	var after := wall.get_beats()
	assert_almost_eq(after, before, 0.02, "The change itself moves nothing")

	await wait_seconds(0.1)
	assert_gt(wall.get_beats() - after, 0.5, "And from there it runs ten times faster")


func test_scripted_time_moves_only_when_told() -> void:
	_scripted.start()
	_scripted.advance(1.5)
	assert_eq(_scripted.get_beats(), 1.5, "Advanced")
	_scripted.set_beats(4.0)
	assert_eq(_scripted.get_beats(), 4.0, "Jumped")
	_scripted.start()
	assert_eq(_scripted.get_beats(), 0.0, "Start rewinds")


func test_audio_manager_bar_changes_follow_the_injected_time_source() -> void:
	AudioManager.set_music_time_source(_scripted)
	AudioManager.set_tempo(TEMPO, BEATS_PER_BAR)
	var layer := LoopLayer.new()
	layer.layer_name = "pad"
	layer.stream = _looping_tone()
	var layers: Array[LoopLayer] = [layer]
	AudioManager.configure_loop_layers(layers)
	AudioManager.play_loops()
	await wait_frames(2)

	_scripted.set_beats(BEATS_PER_BAR * 0.4)
	AudioManager.set_layer_active("pad", true)
	await wait_frames(3)
	assert_false(
		AudioManager.is_layer_active("pad"), "Mid-bar request waits, however long it takes"
	)
	assert_eq(AudioManager.get_current_bar(), 0, "Bar comes from the scripted time")

	_scripted.set_beats(BEATS_PER_BAR * 1.01)
	await wait_frames(2)
	assert_true(AudioManager.is_layer_active("pad"), "Lands when the scripted time crosses the bar")
	assert_eq(AudioManager.get_current_bar(), 1)


## The same continuity, through [AudioManager]: retuning mid-bar leaves the
## music exactly where it was, and a pending layer change still waits for a
## real bar line rather than releasing on the retune.
func test_retuning_mid_bar_moves_neither_the_bar_nor_the_beat() -> void:
	AudioManager.set_music_time_source(_scripted)
	AudioManager.set_tempo(TEMPO, BEATS_PER_BAR)
	var layer := LoopLayer.new()
	layer.layer_name = "pad"
	layer.stream = _looping_tone()
	var layers: Array[LoopLayer] = [layer]
	AudioManager.configure_loop_layers(layers)
	AudioManager.play_loops()
	_scripted.set_beats(BEATS_PER_BAR * 87.5)  # Deep into the song, mid-bar.
	await wait_frames(2)
	AudioManager.set_layer_active("pad", true)

	var bar_before := AudioManager.get_current_bar()
	var beat_before := AudioManager.get_current_beat()
	AudioManager.set_tempo(TEMPO + 2.0, BEATS_PER_BAR)
	assert_eq(AudioManager.get_current_bar(), bar_before, "Same bar after the retune")
	assert_almost_eq(AudioManager.get_current_beat(), beat_before, 0.000001, "Same beat in it")
	assert_eq(AudioManager.get_tempo(), TEMPO + 2.0, "But the tempo did change")

	await wait_frames(3)
	assert_false(AudioManager.is_layer_active("pad"), "The retune is not a bar boundary")


## set_tempo_bpm() is what a player-facing tempo control (#72) wants: the
## tempo alone, the current bar length left as it is — unlike set_tempo(),
## whose default parameter would silently reset it.
func test_set_tempo_bpm_changes_tempo_alone() -> void:
	AudioManager.set_tempo(TEMPO, 3)
	AudioManager.set_tempo_bpm(TEMPO + 10.0)
	assert_eq(AudioManager.get_tempo(), TEMPO + 10.0)
	assert_eq(AudioManager.get_music_clock().beats_per_bar, 3, "Bar length untouched")


func test_tempo_changed_fires_on_either_setter() -> void:
	watch_signals(AudioManager)
	AudioManager.set_tempo(96.0, 4)
	assert_signal_emitted_with_parameters(AudioManager, "tempo_changed", [96.0])
	AudioManager.set_tempo_bpm(100.0)
	assert_signal_emitted_with_parameters(AudioManager, "tempo_changed", [100.0])


func test_step_clock_fires_steps_from_the_injected_time_source() -> void:
	var clock: StepClock = autofree(StepClock.new())
	clock.set_time_source(_scripted)
	clock.set_music_clock(MusicClock.new(TEMPO, BEATS_PER_BAR))
	watch_signals(clock)
	clock.advance()
	assert_signal_not_emitted(clock, "step", "Nothing while stopped")

	_scripted.start()
	for i in 18:
		clock.advance()
		_scripted.advance(0.25)  # A sixteenth.
	assert_signal_emit_count(clock, "step", 18, "One per step")
	assert_signal_emitted_with_parameters(clock, "step", [17, 1, 1], 17)


func _looping_tone() -> AudioStreamWAV:
	var stream := AudioTestTone.generate(220.0, 0.2, 0.2)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream

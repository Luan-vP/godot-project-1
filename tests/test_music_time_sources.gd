extends GutTest
## Covers the [MusicTimeSource] adapters, and that [AudioManager] and
## [StepClock] take all their timing from whichever one they are given — the
## seam that lets the base timing be replaced later.

const TEMPO := 70.0

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
	assert_eq(wall.get_seconds(), 0.0, "Before start")
	wall.start()
	assert_true(wall.is_running(), "Running")
	await wait_seconds(0.05)
	assert_gt(wall.get_seconds(), 0.03, "Climbs while running")
	wall.stop()
	assert_eq(wall.get_seconds(), 0.0, "Zero once stopped")
	assert_eq(wall.get_lookahead(), 0.0, "No lookahead while stopped")


func test_scripted_time_moves_only_when_told() -> void:
	_scripted.start()
	_scripted.advance(1.5)
	assert_eq(_scripted.get_seconds(), 1.5, "Advanced")
	_scripted.set_seconds(4.0)
	assert_eq(_scripted.get_seconds(), 4.0, "Jumped")
	_scripted.start()
	assert_eq(_scripted.get_seconds(), 0.0, "Start rewinds")


func test_audio_manager_bar_changes_follow_the_injected_time_source() -> void:
	AudioManager.set_music_time_source(_scripted)
	AudioManager.set_tempo(TEMPO, 4)
	var layer := LoopLayer.new()
	layer.layer_name = "pad"
	layer.stream = _looping_tone()
	var layers: Array[LoopLayer] = [layer]
	AudioManager.configure_loop_layers(layers)
	AudioManager.play_loops()
	await wait_frames(2)

	var bar := 60.0 / TEMPO * 4.0
	_scripted.set_seconds(bar * 0.4)
	AudioManager.set_layer_active("pad", true)
	await wait_frames(3)
	assert_false(
		AudioManager.is_layer_active("pad"), "Mid-bar request waits, however long it takes"
	)
	assert_eq(AudioManager.get_current_bar(), 0, "Bar comes from the scripted time")

	_scripted.set_seconds(bar * 1.01)
	await wait_frames(2)
	assert_true(AudioManager.is_layer_active("pad"), "Lands when the scripted time crosses the bar")
	assert_eq(AudioManager.get_current_bar(), 1)


func test_step_clock_fires_steps_from_the_injected_time_source() -> void:
	var clock: StepClock = autofree(StepClock.new())
	clock.set_time_source(_scripted)
	clock.set_music_clock(MusicClock.new(TEMPO, 4))
	watch_signals(clock)
	clock.advance()
	assert_signal_not_emitted(clock, "step", "Nothing while stopped")

	_scripted.start()
	var step := 60.0 / TEMPO / 4.0
	for i in 18:
		clock.advance()
		_scripted.advance(step)
	assert_signal_emit_count(clock, "step", 18, "One per step")
	assert_signal_emitted_with_parameters(clock, "step", [17, 1, 1], 17)


func _looping_tone() -> AudioStreamWAV:
	var stream := AudioTestTone.generate(220.0, 0.2, 0.2)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream

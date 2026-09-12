extends GutTest
## Covers [AudioManager]'s loop layering: layers configured as data, brought
## in and out without restarting playback, and landing on a bar boundary
## rather than instantly once loops are already running.
##
## Tempo is set unrealistically fast (0.05s bars) purely so the "next bar"
## test can observe a real boundary pass within the test timeout instead of
## waiting on a musically sensible tempo. The no-drift-over-ten-minutes
## acceptance criterion in #31 is a manual_verification concern — see
## core/audio/README.md — not something this suite waits ten minutes to
## prove.

const FRAME_TIMEOUT := 5.0


func before_each() -> void:
	AudioManager.set_tempo(1200.0, 1)  # 0.05s per bar.
	var layer := LoopLayer.new()
	layer.layer_name = "bass"
	layer.stream = _looping_tone()
	var layers: Array[LoopLayer] = [layer]
	AudioManager.configure_loop_layers(layers)


func after_each() -> void:
	var no_layers: Array[LoopLayer] = []
	AudioManager.configure_loop_layers(no_layers)
	AudioManager.set_tempo(120.0, 4)


func _looping_tone() -> AudioStreamWAV:
	var stream := AudioTestTone.generate(440.0, 0.2, 0.3)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream


func test_configured_layer_starts_inactive() -> void:
	assert_false(AudioManager.is_layer_active("bass"))


func test_layer_activated_before_play_takes_effect_immediately() -> void:
	AudioManager.set_layer_active("bass", true)
	assert_true(AudioManager.is_layer_active("bass"))


func test_play_loops_starts_playback() -> void:
	AudioManager.play_loops()
	assert_true(AudioManager.is_loops_playing())
	AudioManager.stop_loops()
	assert_false(AudioManager.is_loops_playing())


func test_layer_requested_while_playing_lands_on_a_later_bar_not_immediately() -> void:
	AudioManager.play_loops()
	AudioManager.set_layer_active("bass", true)
	assert_false(AudioManager.is_layer_active("bass"), "Should still be pending, not applied yet")
	var bass_became_active := func(): return AudioManager.is_layer_active("bass")
	var arrived: bool = await wait_until(bass_became_active, FRAME_TIMEOUT)
	assert_true(arrived, "Layer should become active once a bar boundary passes")


func test_unknown_layer_does_not_crash() -> void:
	AudioManager.set_layer_active("nonexistent", true)
	assert_false(AudioManager.is_layer_active("nonexistent"))


## Regression: the clock originally read AudioStreamPlayer.get_playback_position(),
## which wraps back to 0 every time the underlying stream loops. A bar longer
## than the loop then never arrived, since the scheduler kept being handed a
## position from earlier in the same loop cycle. Configure the inverse of
## before_each's setup - a loop much shorter than the bar - so several loop
## wraps must pass before the first bar does.
func test_bar_advances_past_several_stream_loop_wraps() -> void:
	var short_loop := LoopLayer.new()
	short_loop.layer_name = "short"
	var stream := AudioTestTone.generate(440.0, 0.05, 0.3)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	short_loop.stream = stream
	var layers: Array[LoopLayer] = [short_loop]
	AudioManager.configure_loop_layers(layers)
	AudioManager.set_tempo(200.0, 1)  # 0.3s per bar: six loop wraps first.

	AudioManager.play_loops()
	var reached_bar_one := func(): return AudioManager.get_current_bar() >= 1
	var arrived: bool = await wait_until(reached_bar_one, FRAME_TIMEOUT)
	assert_true(arrived, "Bar should advance past 0 despite the stream looping many times first")

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

extends GutTest
## Covers #72's live tempo control on [AudioManager]: [method
## AudioManager.get_tempo], [method AudioManager.set_tempo_bpm] and [signal
## AudioManager.tempo_changed], plus the pitch-scale trick that keeps rendered
## drum loops in time with a tempo change instead of re-rendering them (see
## docs/music-player-controls-scope.md §2). [MusicClock]'s own guard against a
## non-positive tempo is covered in test_music_clock.gd.


func before_each() -> void:
	AudioManager.set_tempo(70.0, 4)


func after_each() -> void:
	var no_layers: Array[LoopLayer] = []
	AudioManager.configure_loop_layers(no_layers)
	AudioManager.set_tempo(120.0, 4)


func test_get_tempo_reflects_the_last_tempo_set() -> void:
	assert_almost_eq(AudioManager.get_tempo(), 70.0, 0.001)
	AudioManager.set_tempo_bpm(72.0)
	assert_almost_eq(AudioManager.get_tempo(), 72.0, 0.001)


func test_set_tempo_bpm_leaves_beats_per_bar_alone() -> void:
	AudioManager.set_tempo(70.0, 3)
	AudioManager.set_tempo_bpm(80.0)
	assert_eq(AudioManager.get_music_clock().beats_per_bar, 3, "Only the tempo nudge should change")


func test_set_tempo_bpm_emits_tempo_changed() -> void:
	watch_signals(AudioManager)
	AudioManager.set_tempo_bpm(72.0)
	assert_signal_emitted_with_parameters(AudioManager, "tempo_changed", [72.0])


func test_set_tempo_resets_the_pitch_scale_baseline() -> void:
	# configure_loop_layers is documented to assume the tempo set_tempo was
	# last called with is what the layers were rendered at.
	var layers: Array[LoopLayer] = []
	AudioManager.configure_loop_layers(layers)
	AudioManager.set_tempo_bpm(140.0)
	assert_almost_eq(AudioManager.get_loop_pitch_scale(), 2.0, 0.001, "Double tempo, double pitch")

	# Starting a new session at the doubled tempo should read as the new
	# baseline, not carry the old one forward.
	AudioManager.set_tempo(140.0, 4)
	assert_almost_eq(
		AudioManager.get_loop_pitch_scale(), 1.0, 0.001, "Freshly rendered, no scaling yet"
	)


func test_set_tempo_bpm_scales_loop_pitch_relative_to_the_rendered_tempo() -> void:
	var layers: Array[LoopLayer] = []
	AudioManager.configure_loop_layers(layers)  # Rendered at 70 bpm, from before_each.
	assert_almost_eq(AudioManager.get_loop_pitch_scale(), 1.0, 0.001, "Unscaled at the rendered tempo")

	AudioManager.set_tempo_bpm(35.0)
	assert_almost_eq(AudioManager.get_loop_pitch_scale(), 0.5, 0.001, "Half tempo, half pitch")

extends GutTest
## Covers swing end to end: the warp itself, the clock that carries it, the
## step grids that fire on it, the one global setting, and the slider.

const _TEST_SETTINGS_PATH := "user://test_swing_settings.cfg"


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	AudioManager.set_swing(Swing.STRAIGHT)
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	AudioManager.set_tempo(120.0, 4)


func test_straight_moves_nothing() -> void:
	for beats: float in [0.0, 0.25, 1.3, 7.75]:
		assert_eq(Swing.heard(beats, Swing.STRAIGHT), beats)
		assert_eq(Swing.score(beats, Swing.STRAIGHT), beats)


func test_the_off_sixteenth_lands_late_and_nothing_else_on_the_grid_moves() -> void:
	assert_almost_eq(Swing.heard(0.25, Swing.TRIPLET), 1.0 / 3.0, 0.000001, "A triplet's third")
	assert_almost_eq(Swing.heard(0.75, Swing.MAX), 0.875, 0.000001, "Dotted")
	for eighth in 16:
		var beats := eighth * 0.5
		assert_almost_eq(Swing.heard(beats, Swing.MAX), beats, 0.000001, "Eighths stay put")


func test_score_undoes_heard_everywhere() -> void:
	for ratio: float in [0.5, 0.58, Swing.TRIPLET, Swing.MAX]:
		for i in 97:
			var beats := i * 0.0617
			assert_almost_eq(Swing.score(Swing.heard(beats, ratio), ratio), beats, 0.00001)


func test_time_never_runs_backwards() -> void:
	var last := -1.0
	for i in 200:
		var heard := Swing.heard(i * 0.01, Swing.MAX)
		assert_gt(heard, last)
		last = heard


func test_the_ratio_is_kept_in_range() -> void:
	assert_eq(Swing.clamp_ratio(0.2), Swing.STRAIGHT)
	assert_eq(Swing.clamp_ratio(0.9), Swing.MAX)
	assert_eq(MusicClock.new(120.0, 4, 4, 2.0).swing, Swing.MAX)


func test_a_clock_on_another_grid_keeps_the_swing() -> void:
	var clock := MusicClock.new(84.0, 4, 4, Swing.TRIPLET)
	var grid := clock.with_steps_per_beat(3)
	assert_eq(grid.steps_per_beat, 3)
	assert_eq(grid.tempo_bpm, 84.0)
	assert_eq(grid.swing, Swing.TRIPLET)


func test_swung_steps_are_long_then_short_and_a_pair_is_still_two() -> void:
	var clock := MusicClock.new(60.0, 4, 4, Swing.TRIPLET)
	assert_almost_eq(clock.seconds_across_steps(0, 1), 1.0 / 3.0, 0.000001, "The long one")
	assert_almost_eq(clock.seconds_across_steps(1, 1), 1.0 / 6.0, 0.000001, "The short one")
	assert_almost_eq(clock.seconds_across_steps(0, 2), 0.5, 0.000001)
	var straight := MusicClock.new(60.0)
	assert_almost_eq(straight.seconds_across_steps(3, 1.5), 0.375, 0.000001)


func test_the_sequencer_fires_the_off_sixteenth_late() -> void:
	var sequencer := StepSequencer.new(MusicClock.new(120.0, 4, 4, Swing.TRIPLET))
	assert_eq(sequencer.update(0.0), [0] as Array[int])
	assert_eq(sequencer.update(0.3), [] as Array[int], "Past where it is written, not yet heard")
	assert_eq(sequencer.update(0.34), [1] as Array[int], "A third of a beat in")
	assert_eq(sequencer.update(0.5), [2] as Array[int], "The eighth is where it always was")


func test_every_step_still_fires_once_in_order_with_swing() -> void:
	var sequencer := StepSequencer.new(MusicClock.new(120.0, 4, 4, Swing.MAX))
	var fired: Array[int] = []
	for frame in 400:
		fired.append_array(sequencer.update(frame * 0.013))
	assert_eq(fired, range(fired.size()), "No step missed, doubled or out of order")
	assert_gt(fired.size(), 16)


func test_lookahead_is_measured_where_the_music_is_heard() -> void:
	var sequencer := StepSequencer.new(MusicClock.new(120.0, 4, 4, Swing.TRIPLET))
	sequencer.update(0.0)
	assert_eq(sequencer.update(0.3, 0.02), [] as Array[int])
	assert_eq(sequencer.update(0.3, 0.04), [1] as Array[int])


func test_changing_the_swing_mid_bar_refires_nothing() -> void:
	var sequencer := StepSequencer.new(MusicClock.new(120.0, 4, 4, Swing.STRAIGHT))
	sequencer.update(0.0)
	assert_eq(sequencer.update(0.26), [1] as Array[int])
	sequencer.set_clock(MusicClock.new(120.0, 4, 4, Swing.MAX))
	assert_eq(sequencer.update(0.3), [] as Array[int], "Step 1 already played")
	assert_eq(sequencer.update(0.5), [2] as Array[int])


func test_audio_manager_holds_one_swing_for_everything() -> void:
	watch_signals(AudioManager)
	AudioManager.set_tempo(84.0, 4)
	AudioManager.set_swing(0.6)
	assert_almost_eq(AudioManager.get_swing(), 0.6, 0.000001)
	assert_almost_eq(AudioManager.get_music_clock().swing, 0.6, 0.000001, "On the clock")
	assert_eq(AudioManager.get_tempo(), 84.0, "Tempo untouched")
	assert_signal_emit_count(AudioManager, "swing_changed", 1)
	AudioManager.set_swing(0.6)
	assert_signal_emit_count(AudioManager, "swing_changed", 1, "Nothing changed")
	AudioManager.set_bpm(90.0)
	assert_almost_eq(AudioManager.get_music_clock().swing, 0.6, 0.000001, "Survives a new tempo")
	assert_almost_eq(SaveManager.get_value("audio", "swing", 0.0), 0.6, 0.000001, "And is kept")


func test_swing_is_clamped() -> void:
	AudioManager.set_swing(3.0)
	assert_eq(AudioManager.get_swing(), Swing.MAX)


func test_a_step_clock_follows_the_swing_live() -> void:
	var scripted := ScriptedMusicTime.new()
	var clock := StepClock.new()
	clock.set_time_source(scripted)
	add_child_autofree(clock)
	clock.set_process(false)
	var steps: Array[int] = []
	clock.step.connect(func(index: int, _bar: int, _in_bar: int) -> void: steps.append(index))
	scripted.start()
	clock.advance()
	AudioManager.set_swing(Swing.MAX)
	scripted.set_beats(0.3)
	clock.advance()
	assert_eq(steps, [0] as Array[int], "The off sixteenth waits")
	scripted.set_beats(0.38)
	clock.advance()
	assert_eq(steps, [0, 1] as Array[int])


func test_a_rendered_pattern_bakes_the_swing_in() -> void:
	assert_eq(StepPattern.step_offset(1, 16, 16000), 1000)
	assert_eq(StepPattern.step_offset(1, 16, 16000, Swing.MAX, 4), 1500)
	assert_eq(StepPattern.step_offset(2, 16, 16000, Swing.MAX, 4), 2000)


func test_the_swing_panel_sets_the_swing_and_follows_it() -> void:
	var panel := SwingPanel.new()
	add_child_autofree(panel)
	var slider: HSlider = panel._slider
	assert_eq(slider.min_value, 50.0)
	assert_eq(slider.max_value, 75.0)
	assert_eq(slider.value, 50.0, "Straight to begin with")
	slider.value = 62.0
	assert_almost_eq(AudioManager.get_swing(), 0.62, 0.000001)
	AudioManager.set_swing(Swing.TRIPLET)
	assert_eq(slider.value, 67.0, "Shown to the nearest percent")
	assert_almost_eq(AudioManager.get_swing(), Swing.TRIPLET, 0.000001, "Not rounded to it")


func test_the_overlay_has_the_mix_and_the_swing_and_each_folds() -> void:
	var overlay := LevelMeterOverlay.new()
	add_child_autofree(overlay)
	var mix := overlay.get_node("Panels/MixPanel") as MixPanel
	var swing := overlay.get_node("Panels/SwingPanel") as SwingPanel
	assert_not_null(mix)
	assert_not_null(swing)
	assert_false(swing.is_collapsed())
	swing.set_collapsed(true)
	assert_true(swing.is_collapsed())
	assert_false(mix.is_collapsed(), "One at a time")

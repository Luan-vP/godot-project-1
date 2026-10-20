extends GutTest
## Covers the key and scale buttons every level shares ([KeyScaleButtons]) and
## the shake that moves the band on to its next song ([SongShake]).

var _shared: SharedLayers


func before_each() -> void:
	_shared = SharedLayers.new()
	add_child_autofree(_shared)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func _button(button_name: String) -> Button:
	return _shared.key_scale_buttons.find_child(button_name, true, false) as Button


func test_the_host_keeps_the_buttons_so_every_level_has_them() -> void:
	assert_not_null(_shared.key_scale_buttons)
	assert_eq(_shared.key_scale_buttons.band, _shared.band)
	for button_name in ["KeyDown", "KeyUp", "NextScale"]:
		var button := _button(button_name)
		assert_not_null(button, button_name)
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "Never steals the pad's focus")
	assert_false(
		_shared.stage.is_ancestor_of(_shared.key_scale_buttons),
		"Off the stage, so a slide leaves them put"
	)


func test_the_buttons_move_the_bands_key_and_scale() -> void:
	var band := _shared.band
	_button("KeyUp").pressed.emit()
	assert_eq(band.get_key_offset(), KeyShiftInput.FOURTH)
	_button("KeyDown").pressed.emit()
	_button("KeyDown").pressed.emit()
	assert_eq(band.get_key_offset(), -KeyShiftInput.FOURTH)
	var before := band.scale_name()
	_button("NextScale").pressed.emit()
	assert_ne(band.scale_name(), before)
	assert_false(band.follows_key_scale())


func test_two_hard_jogs_close_together_are_a_shake() -> void:
	var shake := SongShake.new()
	autofree(shake)
	assert_false(shake.jog(1.0), "One jog is a nudge")
	assert_true(shake.jog(1.0 + SongShake.WINDOW * 0.5), "Back and forth")
	assert_false(shake.jog(1.6), "Resting")
	assert_false(shake.jog(1.0 + SongShake.COOLDOWN + 0.5), "A fresh first jog")
	assert_true(shake.jog(1.0 + SongShake.COOLDOWN + 0.7), "And a second shake")


func test_jogs_far_apart_are_not_a_shake() -> void:
	var shake := SongShake.new()
	autofree(shake)
	assert_false(shake.jog(1.0))
	assert_false(shake.jog(1.0 + SongShake.WINDOW + 0.1))
	assert_true(shake.jog(1.0 + SongShake.WINDOW + 0.3), "The second counts from the one before it")


func test_a_shake_is_harder_than_the_tanks_nudge() -> void:
	assert_gt(SongShake.JOG_THRESHOLD, MotionInput.new().jog_threshold)
	assert_eq(_shared.song_shake.motion.jog_threshold, SongShake.JOG_THRESHOLD)


func test_the_keyboards_space_jog_never_changes_the_song() -> void:
	var shake := _shared.song_shake
	shake.motion.set_source(KeyboardMotionSource.new())
	watch_signals(shake)
	shake._on_jogged(Vector2.RIGHT)
	shake._clock += 0.1
	shake._on_jogged(Vector2.LEFT)
	assert_signal_not_emitted(shake, "shaken")
	assert_false(_shared.band.has_next_song())


func test_a_sensor_shake_asks_the_band_for_the_next_song() -> void:
	var shake := _shared.song_shake
	shake.motion.set_source(ScriptedMotionSource.new())
	shake._on_jogged(Vector2.RIGHT)
	shake._clock += 0.1
	shake._on_jogged(Vector2.LEFT)
	assert_true(_shared.band.has_next_song())

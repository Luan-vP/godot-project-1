extends GutTest
## Covers the birds level as a whole: it opens with a 3 and a 4 flying, a snare
## tap is read and its ghost lands a bar later on the pulse it was read as, and
## what the taps favour reaches the flocks as weight.

var _level: BoidsLevel


func before_each() -> void:
	_level = load("res://features/levels/boids/boids_level.tscn").instantiate()
	add_child_autofree(_level)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func test_the_sky_opens_with_three_against_four() -> void:
	assert_eq(_level.sim.birds.size(), BoidsLevel.BIRD_COUNT, "Every bird")
	assert_eq(_level.sim.pulses_on_screen(), [3, 4] as Array[int], "A 3 and a 4")
	assert_eq(AudioManager.get_tempo(), BoidsLevel.START_BPM, "Its own tempo")
	assert_true(AudioManager.get_music_time_source().is_running(), "Music clock running")


func test_a_tap_ghosts_a_bar_later_on_the_pulse_it_reads_as() -> void:
	_level.reader.clear()
	_level.tap(100.0)
	_level.tap(100.0 + 4.0 / 3.0)
	var ghost := _level.tap(100.0 + 8.0 / 3.0 + 0.05)
	assert_eq(_level.reading.winner, 3, "Reads as 3")
	assert_almost_eq(ghost, 100.0 + 8.0 / 3.0 + 4.0, 0.0001, "Snapped to the pulse, a bar on")


func test_favoured_rhythms_weigh_more() -> void:
	_level.reader.clear()
	for k in 4:
		_level.tap(200.0 + k)
	_level.reading = _level.reader.read(203.5, _level.table)
	for i in 30:
		_level._ease_weights(0.1)
	assert_gt(_level.sim.weight_for(4), 1.3, "4 is favoured")
	assert_lt(_level.sim.weight_for(3), 0.9, "3 is not")


func test_weight_from_fit() -> void:
	assert_eq(BoidsLevel.weight_for_fit(1.0), BoidsLevel.WEIGHT_HIGH, "Perfect")
	assert_eq(BoidsLevel.weight_for_fit(0.3), BoidsLevel.WEIGHT_LOW, "Below the floor")


func test_the_snare_hears_a_gamepad_on_any_device() -> void:
	# Steam's virtual gamepad is rarely device 0.
	for device in [0, 1, 3]:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_B
		button.pressed = true
		button.device = device
		assert_true(button.is_action_pressed(BoidsLevel.SNARE), "Pad on device %d" % device)


func test_the_snare_hears_b_space_and_a_click() -> void:
	for keycode in [KEY_B, KEY_SPACE]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		key.pressed = true
		assert_true(key.is_action_pressed(BoidsLevel.SNARE), OS.get_keycode_string(keycode))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_true(click.is_action_pressed(BoidsLevel.SNARE), "Left click")

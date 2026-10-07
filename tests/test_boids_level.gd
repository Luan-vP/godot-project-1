extends GutTest
## Covers the birds level as a whole: it opens with a 3 and a 4 flying, a snare
## tap is read and its ghost lands a bar later on the pulse it was read as, and
## what the taps favour reaches the flocks as weight.

const BIRDS_SCENE := "res://features/levels/boids/birds_level.tscn"

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


func test_the_snare_hears_the_deck_in_desktop_mode() -> void:
	# Run outside Steam, the Deck's B, Y and triggers arrive as keys and clicks.
	for keycode in [KEY_B, DeckDesktopLayout.B, DeckDesktopLayout.Y]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		key.pressed = true
		assert_true(key.is_action_pressed(BoidsLevel.SNARE), OS.get_keycode_string(keycode))
	for button_index in [DeckDesktopLayout.R2, DeckDesktopLayout.L2]:
		var click := InputEventMouseButton.new()
		click.button_index = button_index
		click.pressed = true
		assert_true(click.is_action_pressed(BoidsLevel.SNARE), "Mouse button %d" % button_index)


func _birds_level() -> BoidsLevel:
	var birds: BoidsLevel = load(BIRDS_SCENE).instantiate()
	add_child_autofree(birds)
	return birds


func test_a_flying_level_builds_and_steps() -> void:
	var birds := _birds_level()
	assert_eq(birds.motion, FlockSim.Motion.FLY, "The scene flies")
	assert_eq(birds.sim.motion, FlockSim.Motion.FLY, "The sim was told before it populated")
	assert_eq(birds.sim.pulses_on_screen(), [3, 4] as Array[int], "Still 3-against-4")
	for i in 30:
		birds.sim.step(1.0 / 60.0, i / 60.0)
		birds._stir(1.0 / 60.0)
	birds.queue_redraw()
	await get_tree().process_frame
	for bird in birds.sim.birds:
		assert_between(
			bird.velocity.length(), FlockSim.FLY_MIN_SPEED - 0.01, FlockSim.SCATTER_SPEED
		)


func test_the_waterboatmen_level_still_rows() -> void:
	assert_eq(_level.motion, FlockSim.Motion.ROW, "Rows by default")
	assert_eq(_level.sim.motion, FlockSim.Motion.ROW, "Sim rows")


func test_the_wake_gain_depends_on_the_motion() -> void:
	assert_eq(_level.wake_gain(), BoidsLevel.WAKE_GAIN_ROW, "Rowing")
	var birds := _birds_level()
	assert_eq(birds.wake_gain(), BoidsLevel.WAKE_GAIN_FLY, "Flying")
	assert_ne(BoidsLevel.WAKE_GAIN_FLY, BoidsLevel.WAKE_GAIN_ROW, "They differ")

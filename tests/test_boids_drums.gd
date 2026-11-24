extends GutTest
## Covers the rhythm level's three drums and its shuffle ([BoidsLevel]): a pad
## in three corners, each drum read on its own, the charge only for a rhythm
## the drums agree on, and holding the dial to swap the three rhythms in play
## for three others, flocks and favour carried over.
##
## The level is hosted in a [SubViewport] the size of the game's canvas, so
## the pads and the dial are where they are on a screen; the tests' own window
## is too small to tell them apart.

const SCREEN := Vector2i(1152, 648)

var _viewport: SubViewport
var _level: BoidsLevel


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SCREEN
	add_child_autofree(_viewport)
	var shared := SharedLayers.new()
	_viewport.add_child(shared)
	_level = load("res://features/levels/boids/boids_level.tscn").instantiate()
	shared.stage.add_child(_level)
	for pad in DrumPads.ALL:
		_level.readers[pad].clear()


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func _pad_centre(pad: int) -> Vector2:
	return DrumPads.centre(pad, Vector2(SCREEN), _level.safe_insets())


func test_it_opens_on_three_four_and_six() -> void:
	assert_eq(_level.table.pulse_counts(), BoidsLevel.START_PULSES)


func test_a_touch_on_a_pad_plays_its_drum() -> void:
	for pad in DrumPads.ALL:
		assert_eq(_level.press(0, _pad_centre(pad), true), pad, DrumPads.name_of(pad))
		assert_eq(_level.readings[pad].tap_count, 1, "Read as a tap on its own drum")
		assert_eq(_level.dial.pad_flash(pad), 1.0, "Its ring lights")


func test_a_touch_away_from_the_pads_and_dial_plays_nothing() -> void:
	var gap := Vector2(SCREEN.x * 0.5, 10.0)
	assert_eq(_level.press(0, gap, true), -1)


func test_the_decks_r2_click_is_the_snare_away_from_the_pads_and_dial() -> void:
	# R2 is a left click in the Deck's desktop layout: wherever the pointer is.
	var gap := Vector2(SCREEN.x * 0.5, 10.0)
	assert_eq(_level.press(BoidsLevel.MOUSE_INDEX, gap, false), DrumPads.Pad.SNARE)


func test_a_tap_on_the_menu_is_the_menus() -> void:
	await get_tree().process_frame
	var button := _level._shared.game_menu.find_child("MenuButton", true, false) as Control
	assert_eq(_level.press(0, button.get_global_rect().get_center(), true), -1)


func test_each_drum_is_read_on_its_own() -> void:
	# The kick plays a 3 while the hi-hat plays a 4.
	for k in 3:
		_level.tap(300.0 + k * 4.0 / 3.0, DrumPads.Pad.KICK)
	for k in 4:
		_level.tap(300.0 + k, DrumPads.Pad.HAT)
	_level._read_all(303.5)
	assert_eq(_level.readings[DrumPads.Pad.KICK].winner, 3, "The kick reads as 3")
	assert_eq(_level.readings[DrumPads.Pad.HAT].winner, 4, "The hi-hat reads as 4")
	assert_eq(_level.readings[DrumPads.Pad.SNARE].tap_count, 0, "The snare heard nothing")
	assert_eq(_level.agreed_winner(), 0, "Two rhythms at once build no charge")
	for i in 30:
		_level._ease_weights(0.1)
	assert_gt(_level.sim.weight_for(3), 1.3, "The kick favours its 3")
	assert_gt(_level.sim.weight_for(4), 1.3, "The hi-hat favours its 4")
	assert_lt(_level.sim.weight_for(6), 1.0, "Neither fits 6")


func test_drums_agreeing_on_a_rhythm_build_the_charge() -> void:
	for k in 4:
		_level.tap(400.0 + k, DrumPads.Pad.KICK)
		_level.tap(400.0 + k, DrumPads.Pad.SNARE)
	_level._read_all(403.5)
	assert_eq(_level.agreed_winner(), 4)


func test_a_shuffle_carries_flocks_and_favour_to_the_rhythms_taking_over() -> void:
	_level.sim.weights[3] = 1.5
	_level.sim.weights[4] = 0.8
	_level._weights[3] = 1.5
	_level._weights[4] = 0.8
	var flocks_before := _level.sim.flocks.size()
	_level.shuffle([3, 5, 7] as Array[int])
	assert_eq(_level.table.pulse_counts(), [3, 5, 7] as Array[int])
	assert_eq(_level.sim.flocks.size(), flocks_before, "Every flock stays")
	assert_eq(_level.sim.pulses_on_screen(), [3, 5] as Array[int], "3 stays 3; 4 becomes 5")
	assert_almost_eq(_level.sim.weight_for(3), 1.5, 0.0001, "3 keeps its favour")
	assert_almost_eq(_level.sim.weight_for(5), 0.8, 0.0001, "5 takes over 4's")
	assert_eq(_level._grid, 420, "The grid holds 3, 5 and 7 in 4/4")
	assert_eq(_level.dial.fade(), 1.0, "The old rings fade out")


func test_a_shuffle_with_no_set_given_picks_three_others() -> void:
	var before := _level.table.pulse_counts()
	_level.shuffle()
	var after := _level.table.pulse_counts()
	assert_eq(after.size(), RhythmTable.IN_PLAY)
	assert_ne(after, before)
	for pulses in _level.sim.pulses_on_screen():
		assert_has(after, pulses, "Every flock plays a rhythm in play")


func test_holding_the_dial_shuffles() -> void:
	var before := _level.table.pulse_counts()
	var centre := Vector2(SCREEN) * 0.5
	assert_eq(_level.press(0, centre, true), -1, "The dial plays nothing")
	assert_true(_level.hold.is_holding(), "The dial is held")
	_level.hold._since -= _level.hold.hold_seconds + 0.1
	_level._process(1.0 / 60.0)
	assert_ne(_level.table.pulse_counts(), before, "Shuffled")
	assert_false(_level.hold.is_holding(), "Once per hold")


func test_the_s_key_shuffles() -> void:
	var before := _level.table.pulse_counts()
	var key := InputEventKey.new()
	key.keycode = BoidsLevel.SHUFFLE_KEY
	key.pressed = true
	_level._unhandled_input(key)
	assert_ne(_level.table.pulse_counts(), before)

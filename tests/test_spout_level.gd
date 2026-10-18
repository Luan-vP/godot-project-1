extends GutTest
## Covers #114: the spout level's shell — it loads, binds an emitter through
## its slot, lays the pins out on a fretboard (or the staggered rows), and a
## key move scrolls the pins over to the new key's pentatonic.

const Hosting := preload("res://tests/hosting.gd")

var _level: SpoutLevel


func before_each() -> void:
	_level = load("res://features/levels/spout/spout_level.tscn").instantiate()
	Hosting.host(self, _level)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func test_the_shell_builds_its_pieces() -> void:
	assert_not_null(_level.band, "Band")
	assert_not_null(_level.spout, "Spout")
	assert_gt(_level.pins.pin_count(), 0, "Pins")
	assert_true(_level.emitter is DebugSpoutEmitter, "Debug emitter in the empty slot")
	assert_eq(_level.emitter.pins, _level.pins, "Emitter bound to the pins")
	assert_eq(_level.emitter.spout, _level.spout, "And the spout")


func test_the_shell_lays_the_pins_out_on_a_fretboard() -> void:
	assert_eq(_level.pins.layout, PinField.Layout.FRETBOARD, "The guitar layout by default")
	assert_true(_level.peg_scale is FretboardScale)
	assert_eq(_level.pins.pin_count(), 6 * 13, "Six strings by thirteen frets of sites")


func test_pins_start_on_the_songs_pentatonic() -> void:
	var intervals := PegScale.pentatonic_for(_level.band.is_minor())
	assert_gt(_level.pins.live_pins().size(), 0, "Some pins")
	for pin in _level.pins.live_pins():
		var degree := posmod(_level.pins.note_for(pin) - _level.band.key_root(), 12)
		assert_has(intervals, degree, "Pin %d" % pin)


func test_a_key_move_moves_the_pins_to_the_new_key() -> void:
	var before := _level.pins.live_pins()
	_level.band.set_key_offset(5)
	assert_true(_level.peg_scale.is_scrolling(), "The new key scrolls in")
	var frets := _level.pins.frets
	for i in frets:
		_level._on_band_stepped(0, i)
	assert_false(_level.peg_scale.is_scrolling(), "One fret per step")
	var intervals := PegScale.pentatonic_for(_level.band.is_minor())
	for pin in _level.pins.live_pins():
		var degree := posmod(_level.pins.note_for(pin) - _level.band.key_root(), 12)
		assert_has(intervals, degree, "Pin %d" % pin)
	assert_ne(_level.pins.live_pins(), before, "The pins moved on the neck")


func test_the_staggered_layout_still_scrolls_column_by_column() -> void:
	var level: SpoutLevel = SpoutLevel.new()
	level.pin_layout = PinField.Layout.STAGGERED
	Hosting.host(self, level)
	assert_false(level.peg_scale is FretboardScale)
	level.band.set_key_offset(5)
	for i in level.peg_scale.pin_count():
		level._on_band_stepped(0, i)
	assert_false(level.peg_scale.is_scrolling(), "One column per step")
	var expected := PegScale.notes_for(
		level.band.key_root(),
		PegScale.pentatonic_for(level.band.is_minor()),
		level.pins.low_note,
		level.peg_scale.pin_count()
	)
	for column in level.peg_scale.pin_count():
		assert_eq(level.peg_scale.note_for(column), expected[column], "Column %d" % column)


func test_cycle_scale_swaps_and_scrolls() -> void:
	var before := _level.peg_scale.scale_name()
	_level.cycle_scale()
	assert_ne(_level.peg_scale.scale_name(), before)
	assert_true(_level.peg_scale.is_scrolling())


func test_a_custom_emitter_goes_in_the_slot() -> void:
	var level: SpoutLevel = SpoutLevel.new()
	level.emitter_script = DebugSpoutEmitter
	Hosting.host(self, level)
	assert_true(level.emitter is DebugSpoutEmitter)


func test_scale_is_on_y_and_enter_not_tab() -> void:
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	assert_true(SpoutLevel.is_scale_press(y), "Pad Y")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	assert_true(SpoutLevel.is_scale_press(enter), "Enter: the Deck's A outside Steam")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	assert_false(SpoutLevel.is_scale_press(tab), "Tab is the Deck's View: it leaves the level")


func test_touch_buttons_move_the_key_and_the_scale() -> void:
	var up: Button = _level.find_child("KeyUp", true, false)
	var down: Button = _level.find_child("KeyDown", true, false)
	var next: Button = _level.find_child("NextScale", true, false)
	assert_not_null(up, "Key up button")
	assert_eq(up.focus_mode, Control.FOCUS_NONE, "Never steals the pad's focus")
	up.pressed.emit()
	assert_eq(_level.band.get_key_offset(), 5)
	down.pressed.emit()
	down.pressed.emit()
	assert_eq(_level.band.get_key_offset(), -5)
	var before := _level.peg_scale.scale_name()
	next.pressed.emit()
	assert_ne(_level.peg_scale.scale_name(), before)


func test_the_spout_follows_the_levels_pointer() -> void:
	assert_eq(_level.spout.pointer, _level.pointer)

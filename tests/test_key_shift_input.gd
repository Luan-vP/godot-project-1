extends GutTest
## Covers #71: [KeyShiftInput] mapping shoulders, triggers and their keyboard
## stand-ins to fourths and fifths, one move per press.

var _input: KeyShiftInput


func before_each() -> void:
	_input = KeyShiftInput.new()


func _button(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _trigger(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _key(keycode: Key, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	return event


func test_shoulders_move_a_fourth() -> void:
	assert_eq(_input.step_for(_button(JOY_BUTTON_LEFT_SHOULDER)), -5, "L1 down a fourth")
	assert_eq(_input.step_for(_button(JOY_BUTTON_RIGHT_SHOULDER)), 5, "R1 up a fourth")


func test_releasing_a_shoulder_does_nothing() -> void:
	assert_eq(_input.step_for(_button(JOY_BUTTON_RIGHT_SHOULDER, false)), 0)


func test_triggers_move_a_fifth_once_per_pull() -> void:
	assert_eq(_input.step_for(_trigger(JOY_AXIS_TRIGGER_RIGHT, 0.7)), 7, "R2 up a fifth")
	assert_eq(_input.step_for(_trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)), 0, "Held: no repeat")
	assert_eq(_input.step_for(_trigger(JOY_AXIS_TRIGGER_RIGHT, 0.5)), 0, "Not yet released")
	assert_eq(_input.step_for(_trigger(JOY_AXIS_TRIGGER_RIGHT, 0.1)), 0, "Released")
	assert_eq(_input.step_for(_trigger(JOY_AXIS_TRIGGER_RIGHT, 0.9)), 7, "Pulled again")
	assert_eq(_input.step_for(_trigger(JOY_AXIS_TRIGGER_LEFT, 0.9)), -7, "L2 down a fifth")


func test_keyboard_stand_ins_match_the_pad_and_ignore_echo() -> void:
	assert_eq(_input.step_for(_key(KEY_Q)), -5)
	assert_eq(_input.step_for(_key(KEY_E)), 5)
	assert_eq(_input.step_for(_key(KEY_Z)), -7)
	assert_eq(_input.step_for(_key(KEY_X)), 7)
	assert_eq(_input.step_for(_key(KEY_E, true)), 0, "Key repeat is not another press")


func test_other_input_is_not_a_key_move() -> void:
	assert_eq(_input.step_for(_button(JOY_BUTTON_A)), 0)
	assert_eq(_input.step_for(_trigger(JOY_AXIS_LEFT_X, 1.0)), 0)
	assert_eq(_input.step_for(_key(KEY_R)), 0)


func test_display_offset_is_the_smallest_signed_move() -> void:
	assert_eq(KeyShiftInput.display_offset(0), 0)
	assert_eq(KeyShiftInput.display_offset(5), 5, "Up a fourth")
	assert_eq(KeyShiftInput.display_offset(7), -5, "Up a fifth is down a fourth")
	assert_eq(KeyShiftInput.display_offset(10), -2, "Two fourths up is a tone down")
	assert_eq(KeyShiftInput.display_offset(-5), -5)
	assert_eq(KeyShiftInput.display_offset(6), 6)


func test_triggers_can_be_handed_to_something_else() -> void:
	_input.use_triggers = false
	assert_eq(
		_input.step_for(_trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)), 0, "R2 no longer moves the key"
	)
	assert_eq(_input.step_for(_button(JOY_BUTTON_RIGHT_SHOULDER)), 5, "R1 still does")

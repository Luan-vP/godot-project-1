extends GutTest
## Covers [DeckDesktopLayout] — the keys and clicks the Deck's controls send
## under Steam's Desktop Mode layout — and that [method InputActions.describe]
## names the Deck control behind one.


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key


func _click(button_index: MouseButton) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = button_index
	click.pressed = true
	return click


func test_the_face_buttons_send_keys() -> void:
	assert_eq(DeckDesktopLayout.control_for(_key(KEY_ENTER)), "A", "Return is A")
	assert_eq(DeckDesktopLayout.control_for(_key(KEY_ESCAPE)), "B", "Escape is B")
	assert_eq(DeckDesktopLayout.control_for(_key(KEY_SPACE)), "Y", "Space is Y")
	assert_eq(DeckDesktopLayout.control_for(_key(KEY_UP)), "D-pad up", "Arrows are the d-pad")


func test_the_triggers_are_mouse_buttons() -> void:
	assert_eq(DeckDesktopLayout.control_for(_click(MOUSE_BUTTON_LEFT)), "R2", "Left click is R2")
	assert_eq(DeckDesktopLayout.control_for(_click(MOUSE_BUTTON_RIGHT)), "L2", "Right is L2")


func test_other_input_is_no_deck_control() -> void:
	assert_eq(DeckDesktopLayout.control_for(_key(KEY_Q)), "", "Q")
	assert_eq(DeckDesktopLayout.control_for(_click(MOUSE_BUTTON_MIDDLE)), "", "Middle click")


func test_describe_names_the_deck_control() -> void:
	assert_eq(InputActions.describe(_key(KEY_ESCAPE)), "key Escape (Deck B in Desktop Mode)")
	assert_eq(InputActions.describe(_key(KEY_Q)), "key Q", "No Deck control")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	button.device = 2
	assert_eq(InputActions.describe(button), "pad 2 button 1", "A gamepad button")

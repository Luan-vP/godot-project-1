class_name InputActions
extends RefCounted
## Named input actions registered from code, next to the feature that owns
## them, rather than in [code]project.godot[/code] — the project has no
## [code][input][/code] section, and a feature bringing its own bindings keeps
## them where they can be read alongside what they do.
##
## Registering is idempotent: an action that already exists (e.g. rebound in
## the editor) is left exactly as it is.


## Make sure [param action] exists, bound to [param keys] (physical keycodes,
## so the binding sits in the same place on any keyboard layout) and
## [param joy_buttons].
static func ensure(
	action: StringName, keys: Array[Key], joy_buttons: Array[JoyButton] = []
) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keys:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event(action, key)
	for button_index in joy_buttons:
		var button := InputEventJoypadButton.new()
		button.button_index = button_index
		InputMap.action_add_event(action, button)

class_name InputActions
extends RefCounted
## Named input actions registered from code, next to the feature that owns
## them, rather than in [code]project.godot[/code] — the project has no
## [code][input][/code] section, and a feature bringing its own bindings keeps
## them where they can be read alongside what they do.
##
## Registering is idempotent: an action that already exists (e.g. rebound in
## the editor) is left exactly as it is.

## [InputMap]'s device id for "any device".
const ALL_DEVICES := -1


## Make sure [param action] exists, bound to [param keys] (physical keycodes,
## so the binding sits in the same place on any keyboard layout),
## [param joy_buttons] and [param mouse_buttons].
##
## Every binding listens to [i]all[/i] devices, as the editor's own bindings do.
## An event made in code defaults to device 0, which would only ever hear the
## first gamepad — and with Steam running, the Deck's pad reaches the game as
## Steam's virtual gamepad, which is rarely device 0.
static func ensure(
	action: StringName,
	keys: Array[Key],
	joy_buttons: Array[JoyButton] = [],
	mouse_buttons: Array[MouseButton] = []
) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keys:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		_add(action, key)
	for button_index in joy_buttons:
		var button := InputEventJoypadButton.new()
		button.button_index = button_index
		_add(action, button)
	for button_index in mouse_buttons:
		var click := InputEventMouseButton.new()
		click.button_index = button_index
		_add(action, click)


## A short, readable name for an input the player just pressed — which key,
## which pad and button, which mouse button — or an empty string for anything
## else (releases, motion). For showing what a device actually sends, e.g. the
## Deck's buttons under a Steam Input desktop layout.
static func describe(event: InputEvent) -> String:
	if not event.is_pressed() or event.is_echo():
		return ""
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key %s" % OS.get_keycode_string(code)
	var button := event as InputEventJoypadButton
	if button != null:
		return "pad %d button %d" % [button.device, button.button_index]
	var click := event as InputEventMouseButton
	if click != null:
		return "mouse button %d" % click.button_index
	return ""


static func _add(action: StringName, event: InputEvent) -> void:
	event.device = ALL_DEVICES
	InputMap.action_add_event(action, event)

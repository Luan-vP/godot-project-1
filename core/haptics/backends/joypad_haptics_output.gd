class_name JoypadHapticsOutput
extends HapticsOutput
## Rumble on every connected gamepad through Godot's own
## [method Input.start_joy_vibration]. Godot stops the motors itself after the
## duration. A short, strong-ish pulse on the light motor reads as a tick; the
## heavy motor is kept lower so a stream of them does not turn into a drone.

## Heavy motor as a fraction of the light one.
const STRONG_SHARE := 0.45


func is_available() -> bool:
	return not Input.get_connected_joypads().is_empty()


func pulse(strength: float, duration_s: float, _tree: SceneTree) -> void:
	var weak := clampf(strength, 0.0, 1.0)
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, weak * STRONG_SHARE, duration_s)


func describe() -> String:
	return "gamepad rumble (%d pads)" % Input.get_connected_joypads().size()

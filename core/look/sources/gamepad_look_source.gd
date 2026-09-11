class_name GamepadLookSource
extends LookSource
## Adapter: the right stick.
##
## Unlike the mouse, a stick reports a held deflection rather than a discrete
## motion event, so it is a rate rather than an amount: [method poll] scales it
## by [param delta] itself instead of relying on a caller to.

## Which joypad to read. Godot numbers connected pads from 0.
@export var device: int = 0

## Deflection below this is treated as centred. Sticks rarely rest at exactly
## zero.
@export_range(0.0, 0.9, 0.01) var deadzone: float = 0.2

## Radians/second at full deflection.
@export_range(0.5, 10.0, 0.1) var sensitivity: float = 3.0


func poll(delta: float) -> Vector2:
	var raw := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
	# The dead-zone rescale is the same shape of problem MotionInput's tilt
	# has, so it reuses that helper rather than a second copy of it.
	return MotionFilter.apply_deadzone(raw, deadzone) * sensitivity * delta


func is_available() -> bool:
	return Input.get_connected_joypads().size() > 0


func describe() -> String:
	return "gamepad stick"

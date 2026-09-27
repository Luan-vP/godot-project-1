class_name KeyShiftInput
extends RefCounted
## Turns controller and keyboard presses into key moves for [EyeBand] (#71):
## L1/R1 down/up a fourth, L2/R2 down/up a fifth. Each press is one whole
## interval at once — the caller hands it straight to
## [method EyeBand.set_key_offset], so the band is in the new key from the
## next step.
##
## Keyboard equivalents, since CI and a desktop have no pad: [kbd]Q[/kbd]/
## [kbd]E[/kbd] down/up a fourth, [kbd]Z[/kbd]/[kbd]X[/kbd] down/up a fifth.

const FOURTH := 5
const FIFTH := 7

## How far an analog trigger must travel to count as a press, and how far back
## it must come before it can press again. The gap keeps a trigger resting near
## the threshold from firing a burst of moves.
const TRIGGER_PRESS := 0.6
const TRIGGER_RELEASE := 0.3

const BUTTON_STEPS := {
	JOY_BUTTON_LEFT_SHOULDER: -FOURTH,
	JOY_BUTTON_RIGHT_SHOULDER: FOURTH,
}
const TRIGGER_STEPS := {
	JOY_AXIS_TRIGGER_LEFT: -FIFTH,
	JOY_AXIS_TRIGGER_RIGHT: FIFTH,
}
const KEY_STEPS := {
	KEY_Q: -FOURTH,
	KEY_E: FOURTH,
	KEY_Z: -FIFTH,
	KEY_X: FIFTH,
}

## Axis -> whether that trigger is currently past [constant TRIGGER_PRESS].
var _trigger_down := {}


## Semitones [param event] moves the key by, or 0 if it is not a key move.
## Echoed keys and held buttons or triggers move only once per press.
func step_for(event: InputEvent) -> int:
	var button := event as InputEventJoypadButton
	if button != null:
		return BUTTON_STEPS.get(button.button_index, 0) if button.pressed else 0
	var motion := event as InputEventJoypadMotion
	if motion != null:
		return _trigger_step(motion)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		return KEY_STEPS.get(key.keycode, 0)
	return 0


## A trigger's step on the edge where it passes [constant TRIGGER_PRESS], and
## 0 until it has come back under [constant TRIGGER_RELEASE].
func _trigger_step(motion: InputEventJoypadMotion) -> int:
	if not TRIGGER_STEPS.has(motion.axis):
		return 0
	var was_down: bool = _trigger_down.get(motion.axis, false)
	if not was_down and motion.axis_value >= TRIGGER_PRESS:
		_trigger_down[motion.axis] = true
		return TRIGGER_STEPS[motion.axis]
	if was_down and motion.axis_value <= TRIGGER_RELEASE:
		_trigger_down[motion.axis] = false
	return 0


## [param offset] as the smallest signed move from the song's own key, -5 to
## +6: what [method EyeBand.set_key_offset] actually applies, since it only
## ever uses the offset's pitch class.
static func display_offset(offset: int) -> int:
	return posmod(offset + 5, 12) - 5

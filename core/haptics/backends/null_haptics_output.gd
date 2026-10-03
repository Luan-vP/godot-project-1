class_name NullHapticsOutput
extends HapticsOutput
## A haptics output that is never felt, but remembers every pulse asked of it.
## What [Haptics] falls back to with no pad, and what tests read.

## Each pulse as [code][strength, duration_s][/code], oldest first.
var pulses: Array = []
## Whether to report itself available, so a test can make [Haptics] pick it.
var available := false


func is_available() -> bool:
	return available


func pulse(strength: float, duration_s: float, _tree: SceneTree) -> void:
	pulses.append([strength, duration_s])


func describe() -> String:
	return "null (%d pulses)" % pulses.size()

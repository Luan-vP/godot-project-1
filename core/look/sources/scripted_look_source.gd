class_name ScriptedLookSource
extends LookSource
## Adapter: a queued look delta, for tests and replays.
##
## Mirrors [ScriptedMotionSource]: nothing that reads real input can be driven
## from CI, so a fake source is what makes composition and the camera testable
## at all.

var _next: Vector2 = Vector2.ZERO
var _available: bool = true


## Queue the delta the next [method poll] should return.
func push(delta: Vector2) -> void:
	_next = delta


func poll(_delta: float) -> Vector2:
	var out := _next
	_next = Vector2.ZERO
	return out


func set_available(value: bool) -> void:
	_available = value


func is_available() -> bool:
	return _available


func describe() -> String:
	return "scripted"

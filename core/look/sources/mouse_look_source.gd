class_name MouseLookSource
extends LookSource
## Adapter: relative mouse motion.
##
## Motion is captured as events arrive, via [method feed_event], rather than
## sampled once a frame from a velocity — a fast flick that happens between two
## frames would otherwise be blurred out. [method poll] just drains whatever
## has piled up since the last call.

## Radians of rotation per pixel of mouse motion.
@export var sensitivity: float = 0.0025

var _accumulated: Vector2 = Vector2.ZERO


## Feed one mouse-motion event. Call this from wherever unhandled input is
## already being watched — [LookInput] does, for its default sources.
func feed_event(event: InputEventMouseMotion) -> void:
	_accumulated += event.relative


func poll(_delta: float) -> Vector2:
	var delta := _accumulated * sensitivity
	_accumulated = Vector2.ZERO
	return delta


func is_available() -> bool:
	return true


func describe() -> String:
	return "mouse"

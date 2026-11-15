class_name TouchHold
extends RefCounted
## Fires once when [member fingers] touches have been held down together for
## [member hold_seconds], and not again until every finger has lifted.
##
## The way to the debug overlay on a phone ([LevelMeterOverlay]), which has no
## F8. A shake was the first thought, but a shake already moves the band on
## to its next song ([SongShake]); three fingers held still is something no
## level asks for, so it cannot be done by accident while playing.

var fingers := 3
var hold_seconds := 1.5

var _down := {}
var _since := -1.0
var _fired := false


## Feed every [InputEventScreenTouch]; anything else is ignored.
## [param now] is the time in seconds.
func track(event: InputEvent, now: float) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_down[touch.index] = true
	else:
		_down.erase(touch.index)
	if _down.size() >= fingers:
		if _since < 0.0:
			_since = now
	else:
		_since = -1.0
	if _down.is_empty():
		_fired = false


## Whether the hold has just completed: true once per hold, at [param now].
func poll(now: float) -> bool:
	if _fired or _since < 0.0 or now - _since < hold_seconds:
		return false
	_fired = true
	return true

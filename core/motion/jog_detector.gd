class_name JogDetector
extends RefCounted
## Turns a sharp lateral shake into a single discrete nudge.
##
## A Schmitt trigger plus a cooldown. Both are needed: a bare threshold fires
## several times per physical shake as the reading rattles across it, and a
## bare cooldown still fires again the moment it lapses if the player is still
## shaking. Here it fires once on crossing [member threshold], then stays quiet
## until the motion has settled below [member release] [i]and[/i] the cooldown
## has elapsed.
##
## Input is already flattened onto the screen plane, so a shake along the view
## axis does nothing. That is deliberate — a jog is a sideways shove.

## Planar acceleration, m/s^2, at which a nudge fires. Roughly a brisk flick.
var threshold: float = 11.0

## The motion must fall below this before another nudge can fire.
var release: float = 5.0

## Minimum seconds between nudges.
var cooldown: float = 0.32

## Ceiling on how hard one nudge can be, in multiples of [member threshold], so
## a violent shake cannot fling the tank.
var max_strength: float = 3.0

var _armed: bool = true
var _remaining: float = 0.0


## Feed one frame of planar acceleration. Returns the nudge to apply, or
## [constant Vector2.ZERO] on the overwhelming majority of frames.
func feed(planar_acceleration: Vector2, delta: float) -> Vector2:
	_remaining = maxf(_remaining - delta, 0.0)
	var magnitude := planar_acceleration.length()
	if not _armed:
		if magnitude < release:
			_armed = true
		return Vector2.ZERO
	if magnitude < threshold or _remaining > 0.0:
		return Vector2.ZERO
	_armed = false
	_remaining = cooldown
	return (planar_acceleration / maxf(threshold, 0.001)).limit_length(max_strength)


## Forget the trigger state, as after a calibration or a scene change.
func reset() -> void:
	_armed = true
	_remaining = 0.0

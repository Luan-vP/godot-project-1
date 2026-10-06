class_name Flock
extends RefCounted
## A group of [Bird]s playing one polyrhythm together. Its members each sing
## their own voice, on this flock's pulses.

var id: int = 0

## The rhythm this flock plays: see [member Rhythm.pulses].
var pulses: int = 4

var members: Array[Bird] = []

## Mean member position, refreshed every step.
var centroid: Vector2 = Vector2.ZERO

## Rotates through [member members] so each pulse sounds different birds.
var next_voice: int = 0

## Visual kick on a pulse, decaying to 0.
var flash: float = 0.0

## Index of the last pulse the flock rowed on, so each pulse strokes once.
var last_pulse: int = -1


func size() -> int:
	return members.size()


## The next [param count] members to sing, round-robin, never the same bird
## twice in one call.
func take_voices(count: int) -> Array[Bird]:
	var voices: Array[Bird] = []
	if members.is_empty():
		return voices
	for i in mini(count, members.size()):
		voices.append(members[(next_voice + i) % members.size()])
	next_voice = (next_voice + voices.size()) % members.size()
	return voices

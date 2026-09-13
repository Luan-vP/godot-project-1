class_name MusicTimeSource
extends RefCounted
## Port: where musical time comes from.
##
## Everything that happens "on the beat" — loop layers changing on a bar,
## [StepClock] firing sixteenths — asks one of these what time it is, and
## nothing else. So the timing underneath can be replaced without touching any
## of it: the current adapter is a wall clock, and a sample-accurate one
## driven from the audio thread would be a new adapter, not a rewrite. The same
## shape as [MotionSource] and [LookSource].
##
## Seconds are musical time since [method start]: they keep climbing across
## loop repeats, and [MusicClock] turns them into bars and steps.


## Music has started now; [method get_seconds] counts from here.
func start() -> void:
	pass


## Music has stopped; [method get_seconds] reads 0 until the next start.
func stop() -> void:
	pass


func is_running() -> bool:
	return false


## Seconds of musical time since [method start].
func get_seconds() -> float:
	return 0.0


## How far ahead of [method get_seconds] an event may be triggered so that it
## is heard closer to on time. An adapter that already reports audible time
## exactly would return 0.
func get_lookahead() -> float:
	return 0.0


## Short human-readable name, for debug readouts and logs.
func describe() -> String:
	return "none"

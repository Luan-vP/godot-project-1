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
## Beats of musical time since [method start]: they keep climbing across loop
## repeats and tempo changes alike, accumulating against whatever tempo was in
## force at the time via [method set_tempo_bpm] — so a tempo change only
## affects what accumulates next, never the position already reached.
## [MusicClock] turns beats into bars and steps; wall seconds survive only
## where audio genuinely needs them (note hold lengths, mix lookahead), via
## [method get_lookahead].


## Music has started now; [method get_beats] counts from here.
func start() -> void:
	pass


## Music has stopped; [method get_beats] reads 0 until the next start.
func stop() -> void:
	pass


func is_running() -> bool:
	return false


## Beats of musical time since [method start].
func get_beats() -> float:
	return 0.0


## Changes the tempo beats accumulate at, effective from now. Beats already
## reached are unaffected — only the rate future ones accumulate at changes —
## which is what keeps a tempo change from reinterpreting the song's history.
func set_tempo_bpm(_tempo_bpm: float) -> void:
	pass


## How far ahead of [method get_beats] an event may be triggered so that it
## is heard closer to on time. An adapter that already reports audible time
## exactly would return 0. In seconds: a genuinely wall-clock quantity, unlike
## [method get_beats].
func get_lookahead() -> float:
	return 0.0


## Short human-readable name, for debug readouts and logs.
func describe() -> String:
	return "none"

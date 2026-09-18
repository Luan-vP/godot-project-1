class_name MusicTimeSource
extends RefCounted
## Port: where musical time comes from.
##
## Everything that happens "on the beat" — loop layers changing on a bar,
## [StepClock] firing sixteenths — asks one of these what time it is, and
## nothing else. So the timing underneath can be replaced without touching any
## of it: the current adapter is a wall clock, and a sample-accurate one driven
## from the audio thread would be a new adapter, not a rewrite. The same shape
## as [MotionSource] and [LookSource].
##
## [b]Position is reported in beats[/b], accumulated against whatever tempo was
## in force at the time, and it keeps climbing across loop repeats.
## [MusicClock] turns beats into bars and steps. An adapter is told the tempo
## through [method set_tempo] and is responsible for integrating against it —
## scaling an elapsed-seconds total by the current tempo instead would make a
## tempo change rewrite the past, and the music would jump. See [MusicClock].


## Music has started now; [method get_beats] counts from here.
func start() -> void:
	pass


## Music has stopped; [method get_beats] reads 0 until the next start.
func stop() -> void:
	pass


func is_running() -> bool:
	return false


## The tempo to accumulate at from now on. Whatever has already elapsed keeps
## the tempo it was played at.
func set_tempo(_tempo_bpm: float) -> void:
	pass


## Beats of musical time since [method start].
func get_beats() -> float:
	return 0.0


## How far ahead of [method get_beats] an event may be triggered so that it is
## heard closer to on time, in [b]wall seconds[/b] — this is a property of the
## audio pipeline, not of the music, so it does not scale with tempo. Callers
## convert with [method MusicClock.beats_in]. An adapter that already reports
## audible time exactly would return 0.
func get_lookahead() -> float:
	return 0.0


## Short human-readable name, for debug readouts and logs.
func describe() -> String:
	return "none"

class_name MusicClock
extends RefCounted
## A readable musical clock: turns an elapsed-seconds position into a bar and
## a beat within that bar, given a tempo and a bar length.
##
## Deliberately pure and [AudioServer]-free — every method takes the elapsed
## seconds it should answer for, rather than reading a clock itself. That is
## what makes it possible for a test to "advance" it deterministically: call
## [method bar_at] with whatever seconds value the test wants, instead of
## waiting on real playback. Production code (see [AudioManager]) is
## responsible for supplying an accurate seconds value; see
## [method AudioManager._get_loop_playback_seconds] for why that is not as
## simple as [method AudioStreamPlayer.get_playback_position].
##
## Tempo and bar length are constructor arguments, not constants, so both are
## configurable rather than baked in.

var tempo_bpm: float
var beats_per_bar: int

## Grid steps per beat. 4 is a sixteenth-note grid in 4/4.
var steps_per_beat: int


func _init(p_tempo_bpm: float = 120.0, p_beats_per_bar: int = 4, p_steps_per_beat: int = 4) -> void:
	tempo_bpm = p_tempo_bpm
	beats_per_bar = p_beats_per_bar
	steps_per_beat = p_steps_per_beat


func seconds_per_beat() -> float:
	return 60.0 / tempo_bpm


func seconds_per_bar() -> float:
	return seconds_per_beat() * beats_per_bar


## The bar containing [param seconds]. Bar 0 is the first bar.
func bar_at(seconds: float) -> int:
	return int(floor(seconds / seconds_per_bar()))


## Position within the current bar, in beats, from 0 (inclusive) up to
## [member beats_per_bar] (exclusive).
func beat_in_bar_at(seconds: float) -> float:
	return fposmod(seconds, seconds_per_bar()) / seconds_per_beat()


func seconds_per_step() -> float:
	return seconds_per_beat() / steps_per_beat


func steps_per_bar() -> int:
	return beats_per_bar * steps_per_beat


## The grid step containing [param seconds], counted from the start of
## playback. Step 0 is the first sixteenth of bar 0.
func step_at(seconds: float) -> int:
	return int(floor(seconds / seconds_per_step()))


## When grid step [param step] begins, in seconds from the start of playback.
func seconds_at_step(step: int) -> float:
	return step * seconds_per_step()


## How many seconds remain until the next bar boundary strictly after
## [param seconds].
func seconds_until_next_bar(seconds: float) -> float:
	var bar_length := seconds_per_bar()
	var into_bar := fposmod(seconds, bar_length)
	return bar_length - into_bar

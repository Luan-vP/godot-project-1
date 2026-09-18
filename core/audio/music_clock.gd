class_name MusicClock
extends RefCounted
## A readable musical clock: turns a position in beats into a bar, a beat
## within that bar, and a grid step, given a bar length and a step grid.
##
## [b]Position is measured in beats, not seconds, and that is load-bearing.[/b]
## Derived from seconds, a position means something different at every tempo:
## changing tempo mid-song would reinterpret the whole elapsed time at the new
## scale and the music would jump. Five minutes into a 70 bpm song, a nudge to
## 72 bpm moved bar 87 beat 2.0 to bar 90 beat 0.0. Beats accumulate against
## whatever tempo was in force at the time (see [MusicTimeSource]), so a tempo
## change only affects what happens next and the position never jumps.
##
## That is also why nothing here needs rebasing when the tempo changes: bars
## and steps sit at fixed beat positions, so a new clock agrees with the old
## one about where the music is.
##
## Deliberately pure and [AudioServer]-free — every method takes the position
## it should answer for rather than reading a clock itself, which is what lets
## a test "advance" it deterministically.
##
## Tempo survives here only to convert beats to wall seconds, for the things
## that genuinely need them: how long a note sounds, and how far ahead of the
## audible position an event may be triggered.

## Tempo is clamped to at least this, so a control that winds it down (see
## #72) can never reach a division by zero in [method seconds_per_beat].
const MIN_TEMPO_BPM := 1.0

var tempo_bpm: float
var beats_per_bar: int

## Grid steps per beat. 4 is a sixteenth-note grid in 4/4.
var steps_per_beat: int


func _init(p_tempo_bpm: float = 120.0, p_beats_per_bar: int = 4, p_steps_per_beat: int = 4) -> void:
	tempo_bpm = maxf(p_tempo_bpm, MIN_TEMPO_BPM)
	beats_per_bar = p_beats_per_bar
	steps_per_beat = p_steps_per_beat


## The bar containing [param beats]. Bar 0 is the first bar.
func bar_at(beats: float) -> int:
	return int(floor(beats / beats_per_bar))


## Position within the current bar, in beats, from 0 (inclusive) up to
## [member beats_per_bar] (exclusive).
func beat_in_bar_at(beats: float) -> float:
	return fposmod(beats, float(beats_per_bar))


## How many beats remain until the next bar boundary strictly after
## [param beats].
func beats_until_next_bar(beats: float) -> float:
	return beats_per_bar - beat_in_bar_at(beats)


func steps_per_bar() -> int:
	return beats_per_bar * steps_per_beat


func beats_per_step() -> float:
	return 1.0 / steps_per_beat


## The grid step containing [param beats], counted from the start of playback.
## Step 0 is the first sixteenth of bar 0.
func step_at(beats: float) -> int:
	return int(floor(beats * steps_per_beat))


## Where grid step [param step] begins, in beats from the start of playback.
func beats_at_step(step: int) -> float:
	return step * beats_per_step()


func seconds_per_beat() -> float:
	return 60.0 / tempo_bpm


func seconds_per_bar() -> float:
	return seconds_per_beat() * beats_per_bar


func seconds_per_step() -> float:
	return seconds_per_beat() * beats_per_step()


## [param seconds] of wall time as beats at the current tempo.
func beats_in(seconds: float) -> float:
	return seconds / seconds_per_beat()


## [param beats] as wall seconds at the current tempo.
func seconds_in(beats: float) -> float:
	return beats * seconds_per_beat()

class_name MusicClock
extends RefCounted
## A readable musical clock: turns an elapsed-beats position into a bar and a
## beat within that bar, given a bar length; and, separately, converts to and
## from wall seconds for the few things that genuinely need them (note hold
## lengths, mix lookahead), given a tempo.
##
## Deliberately pure and [AudioServer]-free — every method takes the elapsed
## beats (or seconds) it should answer for, rather than reading a clock
## itself. That is what makes it possible for a test to "advance" it
## deterministically: call [method bar_at] with whatever beats value the test
## wants, instead of waiting on real playback. Production code (see
## [AudioManager]) is responsible for supplying an accurate beats value from a
## [MusicTimeSource]; see [method AudioManager._get_loop_playback_beats] for
## why that is not as simple as [method AudioStreamPlayer.get_playback_position].
##
## Bar/beat/step math (see [method bar_at], [method beat_in_bar_at], [method
## step_at]) never touches [member tempo_bpm]: beats already carry the tempo
## that was in force while they accumulated, so a tempo change moves nothing
## already reached — see [MusicTimeSource]. [member tempo_bpm] matters only
## for converting to or from wall seconds.
##
## Tempo and bar length are constructor arguments, not constants, so both are
## configurable rather than baked in.
##
## [member swing] is the one place score and sound part ways: the score — bars,
## beats, steps — is straight, and [method score_beats] says where in it the
## music is for a position on the [MusicTimeSource], with the swing taken out.
## Everything that plays or reads a rhythm goes through that (see
## [StepSequencer]), so one swing holds for all of it. See [Swing].

## Never at or below zero: [method seconds_per_beat] divides by it, and a
## live tempo control (see #72) can be nudged all the way down to nothing.
const MIN_TEMPO_BPM := 1.0

var tempo_bpm: float
var beats_per_bar: int

## Grid steps per beat. 4 is a sixteenth-note grid in 4/4.
var steps_per_beat: int

## How far through a pair of sixteenths the off one lands: [constant
## Swing.STRAIGHT] up to [constant Swing.MAX].
var swing: float


func _init(
	p_tempo_bpm: float = 120.0,
	p_beats_per_bar: int = 4,
	p_steps_per_beat: int = 4,
	p_swing: float = Swing.STRAIGHT
) -> void:
	tempo_bpm = maxf(p_tempo_bpm, MIN_TEMPO_BPM)
	beats_per_bar = p_beats_per_bar
	steps_per_beat = p_steps_per_beat
	swing = Swing.clamp_ratio(p_swing)


## This clock on another grid: the same tempo, bar and swing, with
## [param p_steps_per_beat] steps to the beat.
func with_steps_per_beat(p_steps_per_beat: int) -> MusicClock:
	return MusicClock.new(tempo_bpm, beats_per_bar, p_steps_per_beat, swing)


## Where in the score the music is when the time source reads
## [param heard_beats]: the same position with the swing taken out.
func score_beats(heard_beats: float) -> float:
	return Swing.score(heard_beats, swing)


## Where score position [param p_score_beats] is heard, on the time source's
## beats: later than written for anything off the beat, once there is swing.
func heard_beats(p_score_beats: float) -> float:
	return Swing.heard(p_score_beats, swing)


## Wall seconds from grid step [param step] to [param length] steps later, as
## heard: with swing, steps are not all the same length. Both may be
## fractional.
func seconds_across_steps(step: float, length: float) -> float:
	var from := heard_beats(step / steps_per_beat)
	var to := heard_beats((step + length) / steps_per_beat)
	return (to - from) * seconds_per_beat()


func seconds_per_beat() -> float:
	return 60.0 / tempo_bpm


func seconds_per_bar() -> float:
	return seconds_per_beat() * beats_per_bar


func seconds_per_step() -> float:
	return seconds_per_beat() / steps_per_beat


func steps_per_bar() -> int:
	return beats_per_bar * steps_per_beat


## Converts a duration in wall seconds to the equivalent number of beats at
## this clock's tempo — for combining a [MusicTimeSource]'s wall-clock
## [method MusicTimeSource.get_lookahead] with a beats position.
func beats_from_seconds(seconds: float) -> float:
	return seconds / seconds_per_beat()


## The bar containing [param beats]. Bar 0 is the first bar.
func bar_at(beats: float) -> int:
	return int(floor(beats / beats_per_bar))


## Position within the current bar, in beats, from 0 (inclusive) up to
## [member beats_per_bar] (exclusive).
func beat_in_bar_at(beats: float) -> float:
	return fposmod(beats, float(beats_per_bar))


## The grid step containing [param beats], counted from the start of
## playback. Step 0 is the first sixteenth of bar 0.
func step_at(beats: float) -> int:
	return int(floor(beats * steps_per_beat))


## Where grid step [param step] begins, in beats from the start of playback.
func beats_at_step(step: int) -> float:
	return float(step) / steps_per_beat


## How many beats remain until the next bar boundary strictly after
## [param beats].
func beats_until_next_bar(beats: float) -> float:
	var bar_length := float(beats_per_bar)
	var into_bar := fposmod(beats, bar_length)
	return bar_length - into_bar

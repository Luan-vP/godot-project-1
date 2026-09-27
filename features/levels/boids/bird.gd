class_name Bird
extends RefCounted
## One bird in a [FlockSim]. Plain data, stepped by the sim.
##
## A bird's voice — [member note] and [member waveform] — is fixed at birth
## and never changes. Joining a flock changes only when it plays (the flock's
## rhythm), never what it sounds like.

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO

## The flock this bird belongs to, or null for a silent loner.
var flock: Flock = null

## MIDI note this bird sings.
var note: int = 69

## [enum SynthWavetable.Waveform] this bird sings with.
var waveform: int = SynthWavetable.Waveform.SINE

## Seconds this loner has spent in a clump big enough to become a flock.
var gather: float = 0.0

## Visual kick when this bird sings, decaying to 0. Set and decayed by
## whoever plays the sound; the sim never reads it.
var glow: float = 0.0

## Seconds left of being thrown clear by a scatter: until then it cannot join
## a flock, and may fly faster than usual.
var stunned: float = 0.0


func is_loner() -> bool:
	return flock == null

class_name Swing
extends RefCounted
## Swing, as a warp of musical time: where a position in the score is
## [i]heard[/i], and back.
##
## The score stays straight. Every pair of sixteenths ([constant PAIR_BEATS])
## is stretched so its midpoint — the off sixteenth — lands [param ratio] of
## the way through the pair instead of halfway: 0.5 is straight, 2/3 a triplet
## shuffle, 0.75 a dotted one. Time in between is stretched to match, so
## anything that is not on the sixteenth grid at all — a flock's three pulses
## to a bar, a tap — moves with the notes round it rather than being left
## behind. Beats and bar lines never move.
##
## Pure and static: [MusicClock] carries the ratio in force and is what
## everything else asks ([method MusicClock.score_beats],
## [method MusicClock.heard_beats]).

const STRAIGHT := 0.5
const TRIPLET := 2.0 / 3.0
## The hardest swing on offer: a dotted sixteenth and a thirty-second.
const MAX := 0.75

## Beats in one swung pair: two sixteenths. The songs sit at 70-92 bpm with
## their movement in the sixteenths, so that is where the swing goes.
const PAIR_BEATS := 0.5


## [param ratio] kept within [constant STRAIGHT] and [constant MAX].
static func clamp_ratio(ratio: float) -> float:
	return clampf(ratio, STRAIGHT, MAX)


## Where score position [param score_beats] is heard, in beats.
static func heard(score_beats: float, ratio: float) -> float:
	if ratio == STRAIGHT:
		return score_beats
	var pairs := score_beats / PAIR_BEATS
	var whole := floorf(pairs)
	var part := pairs - whole
	if part < 0.5:
		part *= 2.0 * ratio
	else:
		part = ratio + (part - 0.5) * 2.0 * (1.0 - ratio)
	return (whole + part) * PAIR_BEATS


## The score position heard at [param heard_beats]: [method heard], undone.
static func score(heard_beats: float, ratio: float) -> float:
	if ratio == STRAIGHT:
		return heard_beats
	var pairs := heard_beats / PAIR_BEATS
	var whole := floorf(pairs)
	var part := pairs - whole
	if part < ratio:
		part /= 2.0 * ratio
	else:
		part = 0.5 + (part - ratio) / (2.0 * (1.0 - ratio))
	return (whole + part) * PAIR_BEATS

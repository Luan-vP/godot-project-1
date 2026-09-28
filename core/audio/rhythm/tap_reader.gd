class_name TapReader
extends RefCounted
## Reads a player's taps as a rhythm: which of a [RhythmTable]'s polyrhythms
## the last bar of taps sounds most like, and how sure that reading is.
##
## Taps are kept in beats and read as bar phase, 0 at the downbeat up to 1 at
## the next, since every rhythm shares the downbeat. Distance between phases
## wraps around the bar line: a tap just before the downbeat is close to it.
##
## A rhythm's error is a two-way least-squares distance, not one-way:
##
## [codeblock]
## error = mean over taps of (distance to nearest pulse)^2
##       + mean over pulses of (distance to nearest tap)^2
## [/codeblock]
##
## One-way (taps to pulses) would fail on nesting. The pulses of 3 are a subset
## of 6's and the downbeat is in every rhythm, so a clean 3 would fit 6
## perfectly. The second term charges every pulse nobody tapped, so a 3 reads
## as 3 and a 6 only reads as 6 once all six are there.
##
## With only one or two taps the second term favours the rhythm with fewest
## pulses (fewest left untapped), so a reading only counts as [i]unambiguous[/i]
## with at least [method RhythmTable.min_pulses] taps in the window — see
## [method read].


## What the last bar of taps sounds like.
class Reading:
	extends RefCounted
	## pulses -> fit in 0..1, 1 a perfect match.
	var fits: Dictionary = {}
	## Pulses of the best fit, or 0 with no taps in the window.
	var winner: int = 0
	var winner_fit: float = 0.0
	var runner_up_fit: float = 0.0
	var tap_count: int = 0
	## Enough taps, a good enough fit, and a clear margin over second best.
	var unambiguous: bool = false

	## How much the taps should count for at all, 0 with none and 1 once
	## there are enough to read: [method fits] scaled by this is what a
	## caller should steer with.
	var confidence: float = 0.0


## How fast fit falls off with error. At 100, a clean 3 read as 6 (error
## about 0.014) fits 0.42, and timing wobble of a few percent of a bar costs
## almost nothing.
var sharpness: float = 100.0

## A winner below this fit is not unambiguous.
var fit_threshold: float = 0.75

## A winner must beat second best by at least this much to be unambiguous.
var margin: float = 0.15

var _beats_per_bar: float = 4.0
var _taps: PackedFloat64Array = PackedFloat64Array()


func _init(beats_per_bar: float = 4.0) -> void:
	_beats_per_bar = beats_per_bar


func set_beats_per_bar(beats_per_bar: float) -> void:
	_beats_per_bar = beats_per_bar


## Record a tap at [param beats], musical time from the start of the music.
func add_tap(beats: float) -> void:
	_taps.append(beats)


func clear() -> void:
	_taps.clear()


## Bar phases, 0..1, of every tap in the last bar before [param now_beats].
## Older taps are forgotten.
func window(now_beats: float) -> PackedFloat32Array:
	var oldest := now_beats - _beats_per_bar
	while not _taps.is_empty() and _taps[0] <= oldest:
		_taps.remove_at(0)
	var phases := PackedFloat32Array()
	for tap in _taps:
		if tap <= now_beats:
			phases.append(phase_of(tap))
	return phases


## Where [param beats] falls in its bar, from 0 up to (not including) 1.
func phase_of(beats: float) -> float:
	return fposmod(beats, _beats_per_bar) / _beats_per_bar


## Score the last bar of taps against every rhythm in [param table].
func read(now_beats: float, table: RhythmTable) -> Reading:
	var reading := Reading.new()
	var phases := window(now_beats)
	reading.tap_count = phases.size()
	if phases.is_empty():
		for pulses in table.pulse_counts():
			reading.fits[pulses] = 0.0
		return reading
	for pulses in table.pulse_counts():
		var fit := fit_from_error(fit_error(phases, pulses), sharpness)
		reading.fits[pulses] = fit
		if fit > reading.winner_fit:
			reading.runner_up_fit = reading.winner_fit
			reading.winner_fit = fit
			reading.winner = pulses
		elif fit > reading.runner_up_fit:
			reading.runner_up_fit = fit
	var needed := maxi(table.min_pulses(), 1)
	reading.confidence = minf(float(reading.tap_count) / needed, 1.0)
	reading.unambiguous = (
		reading.tap_count >= needed
		and reading.winner_fit >= fit_threshold
		and reading.winner_fit - reading.runner_up_fit >= margin
	)
	return reading


## The beats position of the pulse of a [param pulses]-pulse rhythm nearest
## [param beats] — where a tap at [param beats] was heard as landing.
func quantise(beats: float, pulses: int) -> float:
	var pulse_beats := _beats_per_bar / pulses
	return round(beats / pulse_beats) * pulse_beats


## Two-way least-squares error of [param phases] against a rhythm of
## [param pulses] pulses; see the class description.
static func fit_error(phases: PackedFloat32Array, pulses: int) -> float:
	if phases.is_empty() or pulses <= 0:
		return INF
	var points := PackedFloat32Array()
	for k in pulses:
		points.append(float(k) / pulses)
	return _mean_nearest_sq(phases, points) + _mean_nearest_sq(points, phases)


## Fit in 0..1 from an error: 1 at no error, halving by an error of
## 1 / [param sharpness].
static func fit_from_error(error: float, sharpness: float) -> float:
	if is_inf(error):
		return 0.0
	return 1.0 / (1.0 + sharpness * error)


## Distance between two bar phases, wrapping round the bar line: 0 to 0.5.
static func circular_distance(a: float, b: float) -> float:
	var d := fposmod(a - b, 1.0)
	return minf(d, 1.0 - d)


static func _mean_nearest_sq(from: PackedFloat32Array, to: PackedFloat32Array) -> float:
	var total := 0.0
	for a in from:
		var nearest := 1.0
		for b in to:
			nearest = minf(nearest, circular_distance(a, b))
		total += nearest * nearest
	return total / from.size()

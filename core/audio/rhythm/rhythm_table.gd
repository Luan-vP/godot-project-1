class_name RhythmTable
extends RefCounted
## The set of polyrhythms in play, and the grid they all fit on.
##
## Every rhythm divides one shared bar evenly, so the smallest grid that holds
## every pulse of every rhythm exactly is the least common multiple of their
## pulse counts — and of the bar's beats, so beats land on the grid too. That
## grid is derived here and never written down anywhere else: 3, 4 and 6 in 4/4
## need 12 steps a bar, adding 5 makes it 60, adding 7 makes it 420.

var rhythms: Array[Rhythm] = []


func _init(p_rhythms: Array[Rhythm] = []) -> void:
	rhythms = p_rhythms


## 3, 4 and 6: the 3-against-4 the level is built around, plus 6 as a rarer
## third voice that nests over the 3.
static func default_table() -> RhythmTable:
	var table: Array[Rhythm] = [
		Rhythm.create(3, 1.0, Color(0.98, 0.62, 0.36)),
		Rhythm.create(4, 1.0, Color(0.42, 0.78, 0.96)),
		Rhythm.create(6, 0.5, Color(0.80, 0.56, 0.96)),
	]
	return RhythmTable.new(table)


## Every rhythm's pulse count, in table order.
func pulse_counts() -> Array[int]:
	var counts: Array[int] = []
	for rhythm in rhythms:
		counts.append(rhythm.pulses)
	return counts


## The rhythm with [param pulses] pulses, or null if the table has none.
func get_rhythm(pulses: int) -> Rhythm:
	for rhythm in rhythms:
		if rhythm.pulses == pulses:
			return rhythm
	return null


## The fewest pulses any rhythm has. A tap reading needs at least this many
## taps before it can mean anything.
func min_pulses() -> int:
	var fewest := 0
	for rhythm in rhythms:
		fewest = rhythm.pulses if fewest == 0 else mini(fewest, rhythm.pulses)
	return fewest


## Grid steps in one bar of [param beats_per_bar] beats: the least common
## multiple of every rhythm's pulses and the beat count.
func grid_steps(beats_per_bar: int) -> int:
	var steps := maxi(beats_per_bar, 1)
	for rhythm in rhythms:
		steps = lcm(steps, rhythm.pulses)
	return steps


## Grid steps, out of [param grid], that a rhythm of [param pulses] pulses
## lands on. [param grid] must be a multiple of [param pulses].
static func pulse_steps(pulses: int, grid: int) -> Array[int]:
	var steps: Array[int] = []
	var spacing := grid / pulses
	for k in pulses:
		steps.append(k * spacing)
	return steps


## Picks a rhythm for a new group by [member Rhythm.spawn_weight], boosted by
## [param bias] (pulses -> 0..1, e.g. how well recent tapping fits it) — but
## only for rhythms not in [param on_screen]. Tapping a rhythm that is missing
## makes it likelier to appear; tapping one that is already there does not
## stack more of it. [param bias_gain] is how far a bias of 1 multiplies the
## weight. Returns the chosen pulse count, or 0 for an empty table.
func roll(
	rng: RandomNumberGenerator,
	on_screen: Array[int] = [],
	bias: Dictionary = {},
	bias_gain: float = 4.0
) -> int:
	var weights := spawn_weights(on_screen, bias, bias_gain)
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return rhythms[rng.randi() % rhythms.size()].pulses if not rhythms.is_empty() else 0
	var pick := rng.randf() * total
	for i in rhythms.size():
		pick -= weights[i]
		if pick < 0.0:
			return rhythms[i].pulses
	return rhythms[-1].pulses


## The weights [method roll] draws from, in table order.
func spawn_weights(
	on_screen: Array[int] = [], bias: Dictionary = {}, bias_gain: float = 4.0
) -> Array[float]:
	var weights: Array[float] = []
	for rhythm in rhythms:
		var weight := rhythm.spawn_weight
		if not rhythm.pulses in on_screen:
			weight *= 1.0 + bias_gain * clampf(bias.get(rhythm.pulses, 0.0), 0.0, 1.0)
		weights.append(weight)
	return weights


static func lcm(a: int, b: int) -> int:
	return a / gcd(a, b) * b


static func gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return absi(a)

class_name RhythmTable
extends RefCounted
## The set of polyrhythms in play, and the grid they all fit on.
##
## Every rhythm divides one shared bar evenly, so the smallest grid that holds
## every pulse of every rhythm exactly is the least common multiple of their
## pulse counts — and of the bar's beats, so beats land on the grid too. That
## grid is derived here and never written down anywhere else: 3, 4 and 6 in 4/4
## need 12 steps a bar, adding 5 makes it 60, adding 7 makes it 420.
##
## A level plays [constant IN_PLAY] rhythms at a time, drawn from
## [constant POOL]; [method shuffled] picks another set and [method swap_to]
## moves the table over to it in place, so whoever holds the table follows.

## Every rhythm a table can hold, by pulses.
const POOL: Array[int] = [3, 4, 5, 6, 7, 8]
## How many rhythms a level plays at once.
const IN_PLAY := 3
## Rhythms that nest over another (6 over 3, 8 over 4) form half as often:
## they are a rarer extra voice. Every other rhythm weighs 1.
const NESTED_SPAWN_WEIGHT := 0.5

var rhythms: Array[Rhythm] = []


func _init(p_rhythms: Array[Rhythm] = []) -> void:
	rhythms = p_rhythms


## 3, 4 and 6: the 3-against-4 the level is built around, plus 6 as a rarer
## third voice that nests over the 3.
static func default_table() -> RhythmTable:
	return of([3, 4, 6])


## A table of the rhythms with [param pulse_counts] pulses, lowest first, each
## with its colour ([method ArtPalette.rhythm]) and spawn weight
## ([method pool_spawn_weight]).
static func of(pulse_counts: Array[int]) -> RhythmTable:
	return RhythmTable.new(_rhythms_for(pulse_counts))


## The spawn weight a rhythm of [param pulses] pulses gets in [method of].
static func pool_spawn_weight(pulses: int) -> float:
	for other in POOL:
		if other * 2 == pulses:
			return NESTED_SPAWN_WEIGHT
	return 1.0


## [constant IN_PLAY] rhythms from [constant POOL], picked at random, lowest
## first, and never the same set as [param current].
static func shuffled(rng: RandomNumberGenerator, current: Array[int] = []) -> Array[int]:
	var now := current.duplicate()
	now.sort()
	while true:
		var pool := POOL.duplicate()
		var picked: Array[int] = []
		for i in IN_PLAY:
			picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		picked.sort()
		if picked != now:
			return picked
	return []


## Move the table over to the rhythms with [param pulse_counts] pulses, in
## place. Old and new are paired lowest to lowest, up to highest to highest;
## returns that pairing, old pulses -> new pulses, so whoever keeps something
## per rhythm can carry it over to the rhythm taking its place.
func swap_to(pulse_counts: Array[int]) -> Dictionary:
	var old := pulse_counts()
	old.sort()
	var incoming := _rhythms_for(pulse_counts)
	var pairing := {}
	for i in mini(old.size(), incoming.size()):
		pairing[old[i]] = incoming[i].pulses
	rhythms.assign(incoming)
	return pairing


static func _rhythms_for(pulse_counts: Array[int]) -> Array[Rhythm]:
	var sorted := pulse_counts.duplicate()
	sorted.sort()
	var made: Array[Rhythm] = []
	for pulses in sorted:
		made.append(Rhythm.create(pulses, pool_spawn_weight(pulses), ArtPalette.rhythm(pulses)))
	return made


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

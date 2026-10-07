class_name FlockSim
extends RefCounted
## Boids flocking, in explicit flocks that each play one rhythm. They move in
## one of two ways ([enum Motion]): as waterboatmen row — a hard stroke of the
## oars, then a glide that the water's drag eats, then another — or as the
## original birds fly, steered continuously at a speed that never drops below a
## minimum.
##
## Pure: no nodes, no drawing, no sound. [method step] is handed the frame's
## seconds and the music's beats, so a test can drive it deterministically. The
## level reads [member birds] and [member flocks] to draw and to play.
##
## [b]Flying[/b] ([constant Motion.FLY]) is the first version of this sim:
## flocking accelerates a bird's velocity directly, which is clamped between
## [constant FLY_MIN_SPEED] and [constant FLY_MAX_SPEED]. There are no strokes
## and no rests, and a bird's [member Bird.heading] simply follows its
## velocity. Everything below about flocks (joining, leaving, forming,
## pulsing, weights) is the same in both motions.
##
## [b]Rowing[/b] ([constant Motion.ROW], the default). Flocking steers a
## boatman's [member Bird.heading] but never its speed; speed comes only from
## strokes. A loner rows on its own irregular timer and often clings to the
## bottom for a while instead, so it darts, stops and darts. A flock's members
## all row together on each of the flock's pulses (a few milliseconds apart),
## so a 3-flock lurches forward three times a bar and a 4-flock four, and the
## polyrhythm can be seen as well as heard.
##
## [b]Loners[/b] are silent. They wander, loosely flock with other loners, and
## drift towards flocks the player's tapping currently favours.
##
## [b]Joining.[/b] A loner within [constant SNAP_RADIUS] of a flock's member
## snaps into that flock, at a chance of [member snap_rate] a second, taking
## its rhythm and keeping its own voice — unless the flock is out of favour
## (weight below [constant SNAP_MIN_WEIGHT]) or full.
##
## [b]Leaving.[/b] A member that strays past [constant LEAVE_RADIUS] from its
## flock's centre, scaled by the flock's weight, drops out and goes silent, and
## now and then one just wanders off ([member restless_rate]), which keeps
## the sky from settling. A flock down to one bird dissolves, and two flocks of
## the same rhythm that meet merge.
##
## [b]Forming.[/b] Loners that stay clumped, at least [constant FORM_SIZE] of
## them within [constant FORM_RADIUS], for [constant FORM_DWELL] seconds become
## a new flock with a rhythm rolled from the [RhythmTable] (see
## [method RhythmTable.roll] for how tapping biases the roll). At most
## [constant MAX_FLOCKS] flocks fly at once.
##
## [b]Pulsing.[/b] A flock's cohesion and alignment surge on each of its pulses
## (see [method surge]), so a 3-flock visibly draws together three times a bar
## and a 4-flock four.
##
## [b]Weights[/b] ([member weights], pulses -> weight, 1 neutral) are how the
## player's tapping steers the sky: above 1 a rhythm's flocks tighten, hold
## their members further out and pull loners in; below 1 they loosen and shed.

signal flock_formed(flock: Flock)
signal flock_dissolved(flock: Flock)
signal bird_joined(bird: Bird, flock: Flock)
signal scattered(survivor: int, bird_count: int)

## How birds move: rowed in strokes and glides, or flown continuously.
enum Motion { ROW, FLY }

const MAX_FLOCKS := 5
const MAX_FLOCK_SIZE := 14

const FORM_SIZE := 4
const FORM_RADIUS := 60.0
const FORM_DWELL := 1.5

const SNAP_RADIUS := 26.0

## Same-rhythm flocks whose centres come this close merge.
const MERGE_RADIUS := 60.0

## How long a bird that wandered off stays unable to rejoin.
const RESTLESS_STUN_SECONDS := 1.0
const SNAP_MIN_WEIGHT := 0.6
const LEAVE_RADIUS := 140.0

const NEIGHBOUR_RADIUS := 80.0
const SEPARATION_RADIUS := 22.0

## Speed one stroke adds along the heading, and the speed the water lets a
## boatman reach however fast it rows. Drag (per second) is what makes it glide
## rather than cruise: a stroke carries about STROKE_SPEED / DRAG px.
const STROKE_SPEED := 230.0
const MAX_SPEED := 300.0
const DRAG := 3.0

## Flying speeds: a bird never slows below the minimum or (unless thrown by a
## scatter) exceeds the maximum.
const FLY_MIN_SPEED := 70.0
const FLY_MAX_SPEED := 150.0

## How fast a heading swings towards where the flocking steers it, per second.
const TURN_RATE := 6.0

## Fraction of the flocking's push that also shoves a boatman bodily (the rest
## only steers it), so crowded boatmen are still pushed apart.
const DRIFT := 0.25

## A loner's gap between strokes, and its chance of clinging still instead of
## rowing, and for how long. A stroke is aimed this many radians off true.
const LONER_STROKE_GAP := Vector2(0.5, 1.2)
const REST_CHANCE := 0.35
const REST_SECONDS := Vector2(0.8, 2.4)
const STROKE_AIM_JITTER := 0.35

## A flock member rows on its flock's pulse, within this many seconds; if no
## pulse arrives (the clock stopped) it still rows at this gap.
const PULSE_SPREAD := 0.06
const PULSE_FALLBACK_GAP := 1.4

## A scattered boatman flees in quick strokes this far apart.
const FLEE_STROKE_GAP := 0.3

## Speed a scatter throws birds clear at, and how long they stay thrown.
const SCATTER_SPEED := 340.0
const STUN_SECONDS := 2.0

## Accelerations, in px/s^2 (or px/s^2 per px of offset for the _GAINs that
## multiply a distance).
const SEPARATION_ACCEL := 420.0
const COHESION_GAIN := 1.1
const ALIGNMENT_GAIN := 1.6
## Speed that a unit difference of headings counts as when aligning, in px/s.
const ALIGN_SPEED := 100.0
const CENTROID_GAIN := 0.35
const LONER_GAIN := 0.35
const WANDER_ACCEL := 220.0
## A flying loner wanders far less than a rowing one: a stroke is a lot of speed
## to steer, a flier only ever has its acceleration.
const FLY_WANDER_ACCEL := 70.0
const ATTRACT_ACCEL := 140.0
const ATTRACT_RADIUS := 260.0
const EDGE_MARGIN := 90.0
const EDGE_ACCEL := 520.0

## How sharply a pulse's surge dies away across the gap to the next pulse.
const SURGE_DECAY := 5.0

## D major pentatonic over two octaves: any handful of these sounds fine
## together, so a flock of any size stays musical rather than a cluster.
const VOICE_NOTES: Array[int] = [62, 64, 66, 69, 71, 74, 76, 78, 81, 83, 86]

var bounds: Rect2
var table: RhythmTable
var rng: RandomNumberGenerator
var birds: Array[Bird] = []
## How the birds move. Set before [method populate], which seeds velocities to
## suit it.
var motion: Motion = Motion.ROW
var flocks: Array[Flock] = []

## pulses -> attraction weight, 1 neutral. Set by whoever reads the taps.
var weights: Dictionary = {}

## pulses -> 0..1, how much a new flock's roll should favour each rhythm not
## already on screen. See [method RhythmTable.roll].
var spawn_bias: Dictionary = {}

var beats_per_bar: int = 4

## How much a pulse multiplies cohesion and alignment at its peak, over 1.
var surge_gain: float = 1.6

## Chance per second that a loner in reach of a flock joins it, at weight 1.
var snap_rate: float = 1.2

## Chance per second that a member wanders off, at weight 1; divided by the
## square of the weight, so favoured flocks hold on and others fray.
var restless_rate: float = 0.06

## Chance that a loner clings still instead of rowing, at each stroke.
var rest_chance: float = REST_CHANCE

var _next_id := 1


func _init(p_table: RhythmTable, p_bounds: Rect2, p_rng: RandomNumberGenerator = null) -> void:
	table = p_table
	bounds = p_bounds
	rng = p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


## Scatter [param count] birds across the sky, then gather some of them into a
## starting flock per entry of [param seed_pulses], so there is music from the
## first bar.
func populate(count: int, seed_pulses: Array[int] = []) -> void:
	for i in count:
		var position := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		add_bird(position, Vector2.from_angle(rng.randf() * TAU) * _initial_speed(false))
	var per_flock := FORM_SIZE + 3
	var index := 0
	for pulses in seed_pulses:
		if index + per_flock > birds.size() or flocks.size() >= MAX_FLOCKS:
			break
		var inner := bounds.grow(-EDGE_MARGIN * 1.5)
		var centre := Vector2(
			rng.randf_range(inner.position.x, inner.end.x),
			rng.randf_range(inner.position.y, inner.end.y)
		)
		var heading := Vector2.from_angle(rng.randf() * TAU)
		var members: Array[Bird] = []
		for j in per_flock:
			var bird := birds[index]
			index += 1
			bird.position = centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * 30.0
			bird.heading = heading
			bird.velocity = heading * _initial_speed(true)
			members.append(bird)
		make_flock(members, pulses)


## Speed a bird starts at: a rower coasts at half what a stroke carries it, a
## loner flier at the slowest it may fly and a flock of fliers at the middle of
## its range, so a flock starts out as one.
func _initial_speed(in_flock: bool) -> float:
	if motion == Motion.FLY:
		return (FLY_MIN_SPEED + FLY_MAX_SPEED) * 0.5 if in_flock else FLY_MIN_SPEED
	return STROKE_SPEED / DRAG * 0.5


## A new loner with a voice of its own.
func add_bird(position: Vector2, velocity: Vector2) -> Bird:
	var bird := Bird.new()
	bird.position = position
	bird.velocity = velocity
	bird.heading = (
		velocity.normalized()
		if velocity.length_squared() > 0.001
		else Vector2.from_angle(rng.randf() * TAU)
	)
	bird.stroke_timer = rng.randf_range(0.0, LONER_STROKE_GAP.y)
	bird.note = VOICE_NOTES[rng.randi() % VOICE_NOTES.size()]
	var roll := rng.randf()
	if roll < 0.5:
		bird.waveform = SynthWavetable.Waveform.SINE
	elif roll < 0.8:
		bird.waveform = SynthWavetable.Waveform.SQUARE
	else:
		bird.waveform = SynthWavetable.Waveform.SAW
	birds.append(bird)
	return bird


## Gather [param members] into a new flock playing [param pulses]. Members
## leave whatever flock they were in first.
func make_flock(members: Array[Bird], pulses: int) -> Flock:
	var flock := Flock.new()
	flock.id = _next_id
	_next_id += 1
	flock.pulses = pulses
	flocks.append(flock)
	for bird in members:
		join(bird, flock)
	_refresh_centroid(flock)
	flock_formed.emit(flock)
	return flock


## [param bird] joins [param flock] and plays its rhythm from now on. Its voice
## is untouched.
func join(bird: Bird, flock: Flock) -> void:
	if bird.flock == flock:
		return
	if bird.flock != null:
		leave(bird)
	bird.flock = flock
	bird.gather = 0.0
	flock.members.append(bird)
	bird_joined.emit(bird, flock)


## [param bird] drops out of its flock and goes silent.
func leave(bird: Bird) -> void:
	if bird.flock == null:
		return
	bird.flock.members.erase(bird)
	bird.flock = null
	bird.gather = 0.0


## Burst every flock not playing [param survivor] apart: members are thrown
## clear of their flock's centre, go silent, and cannot join anything for
## [constant STUN_SECONDS]. Returns how many birds were scattered.
func scatter(survivor: int) -> int:
	var count := 0
	for flock: Flock in flocks.duplicate():
		if flock.pulses == survivor:
			continue
		_refresh_centroid(flock)
		for bird: Bird in flock.members.duplicate():
			var away := bird.position - flock.centroid
			if away.length_squared() < 0.01:
				away = Vector2.from_angle(rng.randf() * TAU)
			bird.heading = away.normalized()
			bird.velocity = bird.heading * SCATTER_SPEED
			if motion == Motion.ROW:
				bird.stroke_timer = FLEE_STROKE_GAP
			bird.stunned = STUN_SECONDS
			leave(bird)
			count += 1
		_remove_flock(flock)
	scattered.emit(survivor, count)
	return count


## Rhythms with at least one flock, each listed once.
func pulses_on_screen() -> Array[int]:
	var on_screen: Array[int] = []
	for flock in flocks:
		if not flock.pulses in on_screen:
			on_screen.append(flock.pulses)
	return on_screen


func weight_for(pulses: int) -> float:
	return weights.get(pulses, 1.0)


## How hard a [param pulses]-pulse rhythm is surging at [param beats]: 1 on
## each pulse, dying away towards the next.
static func surge(beats: float, pulses: int, p_beats_per_bar: int) -> float:
	var phase := fposmod(beats * pulses / p_beats_per_bar, 1.0)
	return exp(-phase * SURGE_DECAY)


## Move every bird on by [param delta] seconds, with the music at [param beats],
## then settle who belongs to which flock.
func step(delta: float, beats: float) -> void:
	for flock in flocks:
		_refresh_centroid(flock)
		flock.flash = maxf(flock.flash - delta * 3.0, 0.0)
		if motion == Motion.ROW:
			_row_on_pulse(flock, beats)
	var accelerations: Array[Vector2] = []
	for bird in birds:
		accelerations.append(_steer(bird, beats))
	for i in birds.size():
		_integrate(birds[i], accelerations[i], delta)
	update_membership(delta)


func _steer(bird: Bird, beats: float) -> Vector2:
	var separation := Vector2.ZERO
	var heading := Vector2.ZERO
	var centre := Vector2.ZERO
	var neighbours := 0
	for other in birds:
		if other == bird:
			continue
		var offset := other.position - bird.position
		var distance := offset.length()
		if distance < SEPARATION_RADIUS and distance > 0.001:
			separation -= offset / distance * (1.0 - distance / SEPARATION_RADIUS)
		if distance < NEIGHBOUR_RADIUS and other.flock == bird.flock:
			heading += other.velocity if motion == Motion.FLY else other.heading
			centre += other.position
			neighbours += 1

	var accel := separation * SEPARATION_ACCEL
	var gain := LONER_GAIN
	if bird.flock != null:
		var weight := weight_for(bird.flock.pulses)
		gain = weight * (1.0 + surge_gain * surge(beats, bird.flock.pulses, beats_per_bar))
		accel += (bird.flock.centroid - bird.position) * CENTROID_GAIN * weight
	else:
		var wander := FLY_WANDER_ACCEL if motion == Motion.FLY else WANDER_ACCEL
		accel += Vector2.from_angle(rng.randf() * TAU) * wander
		accel += _attraction(bird)
	if neighbours > 0:
		accel += (centre / neighbours - bird.position) * COHESION_GAIN * gain
		if motion == Motion.FLY:
			accel += (heading / neighbours - bird.velocity) * ALIGNMENT_GAIN * gain
		else:
			accel += (heading / neighbours - bird.heading) * ALIGN_SPEED * ALIGNMENT_GAIN * gain
	return accel + _edge_push(bird.position)


## Pull on a loner towards the nearest flock, by how much that flock's rhythm
## is in favour. At a neutral weight there is still a faint pull, so flocks
## recruit slowly on their own.
func _attraction(bird: Bird) -> Vector2:
	if bird.stunned > 0.0:
		return Vector2.ZERO
	var nearest: Flock = null
	var nearest_distance := ATTRACT_RADIUS
	for flock in flocks:
		var distance := bird.position.distance_to(flock.centroid)
		if distance < nearest_distance:
			nearest = flock
			nearest_distance = distance
	if nearest == null:
		return Vector2.ZERO
	var pull := maxf(weight_for(nearest.pulses) - 0.7, 0.0)
	return (nearest.centroid - bird.position).normalized() * ATTRACT_ACCEL * pull


func _edge_push(position: Vector2) -> Vector2:
	var push := Vector2.ZERO
	push.x += maxf(1.0 - (position.x - bounds.position.x) / EDGE_MARGIN, 0.0)
	push.x -= maxf(1.0 - (bounds.end.x - position.x) / EDGE_MARGIN, 0.0)
	push.y += maxf(1.0 - (position.y - bounds.position.y) / EDGE_MARGIN, 0.0)
	push.y -= maxf(1.0 - (bounds.end.y - position.y) / EDGE_MARGIN, 0.0)
	return push * EDGE_ACCEL


## Row on every pulse of [param flock] that has not yet been rowed on: each
## member's next stroke falls within [constant PULSE_SPREAD] of it.
func _row_on_pulse(flock: Flock, beats: float) -> void:
	var pulse := floori(beats * flock.pulses / beats_per_bar)
	if pulse == flock.last_pulse:
		return
	flock.last_pulse = pulse
	for bird in flock.members:
		bird.stroke_timer = rng.randf_range(0.0, PULSE_SPREAD)


func _integrate(bird: Bird, accel: Vector2, delta: float) -> void:
	if motion == Motion.FLY:
		_fly(bird, accel, delta)
	else:
		_row_step(bird, accel, delta)


## One step of a bird in flight: the flocking accelerates it directly, and its
## speed is kept within [constant FLY_MIN_SPEED] and [constant FLY_MAX_SPEED]
## (up to [constant SCATTER_SPEED] while thrown by a scatter, easing back).
func _fly(bird: Bird, accel: Vector2, delta: float) -> void:
	bird.velocity += accel * delta
	var top := FLY_MAX_SPEED
	if bird.stunned > 0.0:
		top = lerpf(FLY_MAX_SPEED, SCATTER_SPEED, bird.stunned / STUN_SECONDS)
	var speed := bird.velocity.length()
	if speed > top:
		bird.velocity *= top / speed
	elif speed < FLY_MIN_SPEED:
		bird.velocity = (
			bird.velocity / speed * FLY_MIN_SPEED
			if speed > 0.001
			else Vector2.from_angle(rng.randf() * TAU) * FLY_MIN_SPEED
		)
	bird.heading = bird.velocity.normalized()
	bird.position += bird.velocity * delta
	bird.position = bird.position.clamp(bounds.position, bounds.end)


## One step of a boatman: steer the heading, row if it is time, then let the
## water slow it. [param accel] never changes the speed directly beyond
## [constant DRIFT]; only [method _row] does.
func _row_step(bird: Bird, accel: Vector2, delta: float) -> void:
	if accel.length_squared() > 1.0:
		var turn := clampf(TURN_RATE * delta, 0.0, 1.0)
		bird.heading = bird.heading.slerp(accel.normalized(), turn).normalized()
	bird.velocity += accel * DRIFT * delta
	bird.stroke_timer -= delta
	if bird.stroke_timer <= 0.0:
		_row(bird)
	bird.stroke = maxf(bird.stroke - delta * 5.0, 0.0)
	bird.velocity *= exp(-DRAG * delta)
	var top := MAX_SPEED
	if bird.stunned > 0.0:
		top = lerpf(MAX_SPEED, SCATTER_SPEED, bird.stunned / STUN_SECONDS)
	var speed := bird.velocity.length()
	if speed > top:
		bird.velocity *= top / speed
	bird.position += bird.velocity * delta
	bird.position = bird.position.clamp(bounds.position, bounds.end)


## A stroke of the oars along the heading, a little off true — or, for a
## loner now and then, a rest instead. Flock members never rest, and wait for
## their flock's next pulse (see [method _row_on_pulse]) before rowing again.
func _row(bird: Bird) -> void:
	if bird.stunned > 0.0:
		bird.stroke_timer = FLEE_STROKE_GAP
	elif bird.flock != null:
		bird.stroke_timer = PULSE_FALLBACK_GAP
	elif rng.randf() < rest_chance:
		bird.stroke_timer = rng.randf_range(REST_SECONDS.x, REST_SECONDS.y)
		return
	else:
		bird.stroke_timer = rng.randf_range(LONER_STROKE_GAP.x, LONER_STROKE_GAP.y)
	var aim := bird.heading.rotated(rng.randf_range(-STROKE_AIM_JITTER, STROKE_AIM_JITTER))
	bird.velocity += aim * STROKE_SPEED
	bird.stroke = 1.0


## Settle who belongs where, without moving anyone: strays and restless birds
## leave, flocks down to one bird dissolve, loners in reach join, and clumps
## that have held long enough become flocks. [method step] calls this after
## moving everyone; a test can call it alone.
func update_membership(delta: float) -> void:
	for bird in birds:
		bird.stunned = maxf(bird.stunned - delta, 0.0)
	for flock in flocks:
		_refresh_centroid(flock)
	_shed(delta)
	for flock: Flock in flocks.duplicate():
		if flock.size() < 2:
			for bird: Bird in flock.members.duplicate():
				leave(bird)
			_remove_flock(flock)
	_merge_flocks()
	_snap_loners(delta)
	_form_flocks(delta)


## Members drop out when they stray too far from their flock's centre, and now
## and then out of restlessness — more often from a flock out of favour.
func _shed(delta: float) -> void:
	for flock in flocks:
		var weight := weight_for(flock.pulses)
		var reach := LEAVE_RADIUS * clampf(weight, 0.5, 1.5)
		var restless := restless_rate * delta / maxf(weight * weight, 0.1)
		for bird: Bird in flock.members.duplicate():
			if bird.position.distance_to(flock.centroid) > reach:
				leave(bird)
			elif rng.randf() < restless:
				leave(bird)
				bird.stunned = RESTLESS_STUN_SECONDS


## Two flocks of the same rhythm that fly into each other become one, as long
## as the result fits in [constant MAX_FLOCK_SIZE]; the smaller joins the
## larger. Otherwise they would overlap and read as one flock anyway.
func _merge_flocks() -> void:
	for a: Flock in flocks.duplicate():
		for b: Flock in flocks.duplicate():
			if a == b or a.pulses != b.pulses or not a in flocks or not b in flocks:
				continue
			if a.size() < b.size() or a.size() + b.size() > MAX_FLOCK_SIZE:
				continue
			if a.centroid.distance_to(b.centroid) > MERGE_RADIUS:
				continue
			for bird: Bird in b.members.duplicate():
				join(bird, a)
			_remove_flock(b)
			_refresh_centroid(a)


## A loner within [constant SNAP_RADIUS] of a flock's member joins it with a
## chance of [member snap_rate] a second, scaled by the flock's weight. Joins
## are decided before any is applied, so a bird that joins this step cannot
## drag its neighbours in after it in the same step.
func _snap_loners(delta: float) -> void:
	var joins := {}
	for bird in birds:
		if bird.flock != null or bird.stunned > 0.0:
			continue
		var target: Flock = null
		var nearest := SNAP_RADIUS
		for other in birds:
			var flock := other.flock
			if flock == null or flock.size() >= MAX_FLOCK_SIZE:
				continue
			if weight_for(flock.pulses) < SNAP_MIN_WEIGHT:
				continue
			var distance := bird.position.distance_to(other.position)
			if distance < nearest:
				nearest = distance
				target = flock
		if target != null and rng.randf() < snap_rate * weight_for(target.pulses) * delta:
			joins[bird] = target
	for bird: Bird in joins:
		var flock: Flock = joins[bird]
		if flock.size() < MAX_FLOCK_SIZE and flock in flocks:
			join(bird, flock)


## Loners that stay clumped long enough become a flock — one per step at most,
## so two clumps never race for the last free flock slot.
func _form_flocks(delta: float) -> void:
	for bird in birds:
		if bird.flock != null or bird.stunned > 0.0:
			bird.gather = 0.0
			continue
		var clump := _loners_near(bird)
		if clump.size() + 1 < FORM_SIZE:
			bird.gather = 0.0
			continue
		bird.gather += delta
		if bird.gather < FORM_DWELL or flocks.size() >= MAX_FLOCKS:
			continue
		var members: Array[Bird] = [bird]
		for other in clump:
			if members.size() >= MAX_FLOCK_SIZE:
				break
			members.append(other)
		make_flock(members, table.roll(rng, pulses_on_screen(), spawn_bias))
		return


func _loners_near(bird: Bird) -> Array[Bird]:
	var near: Array[Bird] = []
	for other in birds:
		if other == bird or other.flock != null or other.stunned > 0.0:
			continue
		if bird.position.distance_to(other.position) < FORM_RADIUS:
			near.append(other)
	return near


func _refresh_centroid(flock: Flock) -> void:
	if flock.members.is_empty():
		return
	var sum := Vector2.ZERO
	for bird in flock.members:
		sum += bird.position
	flock.centroid = sum / flock.members.size()


func _remove_flock(flock: Flock) -> void:
	flocks.erase(flock)
	flock_dissolved.emit(flock)

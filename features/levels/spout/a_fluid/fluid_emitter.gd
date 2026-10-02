class_name FluidEmitter
extends SpoutEmitter
## Version A: the spout pours the eye tank's fluid.
##
## The tank is the eye band's own — a [FluidSimulation] with a default
## [FluidConfig] the size of the screen and a [FluidRenderer] painting it —
## so the level reads as the same water the eyes float in. Three things make
## that water pour and play:
##
## 1. [b]The stream.[/b] Every physics frame the spout pushes the fluid along
##    its aim from the nozzle and paints into it, so a painted jet swings with
##    the aim. The solve has no gravity; the jet's own momentum and a gentle
##    downward lean on the whole tank carry it down.
## 2. [b]Droplets.[/b] The solve has no particles, so it cannot hit anything
##    itself. Small [SpoutDroplet]s ride the jet, dragged by the real current,
##    and they are what strike the pins: each contact plays the pin, at a
##    strength from how fast the droplet was closing on it, and bounces the
##    droplet off.
## 3. [b]Pins part the water.[/b] The solve has no solid obstacles either, so
##    each pin pushes back against whatever current runs through it, and a
##    droplet striking one splashes outwards. The painted stream visibly
##    divides around the pins instead of flowing through them.

## Acceleration the jet gives the fluid at the nozzle, pixels/second^2.
const JET_ACCELERATION := 2600.0
const JET_RADIUS := 34.0
## Pigment laid at the nozzle, density/second.
const JET_PAINT := 2.4
const JET_PAINT_RADIUS := 26.0
## The tank's standing lean, so the stream carries on downward.
const DOWNWARD_LEAN := Vector2(0.0, 45.0)

## Droplets leaving the nozzle per second, their speed, and how far their
## direction is scattered either side of the aim.
const DROPLET_RATE := 16.0
const DROPLET_SPEED := 340.0
const DROPLET_SPREAD := deg_to_rad(7.0)
const MAX_DROPLETS := 96

## Fraction of a droplet's speed kept after striking a pin.
const RESTITUTION := 0.5
## Closing speed, pixels/second, that plays a pin at full strength.
const FULL_STRENGTH_SPEED := 420.0
## How hard a pin pushes back on the current through it (1/second), and the
## splash a struck pin makes (pixels/second^2).
const PIN_RESISTANCE := 5.0
const PIN_SPLASH := 1400.0

## The palette the stream cycles through, slowly — the eye tank's own.
const PALETTE: Array[Color] = [
	Color(0.36, 0.70, 0.68),
	Color(0.85, 0.45, 0.38),
	Color(0.53, 0.44, 0.76),
	Color(0.93, 0.74, 0.36),
	Color(0.30, 0.55, 0.80),
]
## Seconds to drift from one palette colour to the next.
const PALETTE_SECONDS := 9.0

var simulation: FluidSimulation
var _droplets: Array[SpoutDroplet] = []
var _spawn_debt := 0.0
var _elapsed := 0.0
var _hits := 0
var _rng := RandomNumberGenerator.new()


func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	super(level_node, the_spout, the_pins)
	var extent := get_viewport_rect().size
	var config := FluidConfig.new()
	config.world_size = extent
	simulation = FluidSimulation.new()
	simulation.name = "Fluid"
	simulation.config = config
	add_child(simulation)
	simulation.set_current_bias(DOWNWARD_LEAN)

	var renderer := FluidRenderer.new()
	renderer.name = "FluidRenderer"
	renderer.z_index = -100
	add_child(renderer)

	make_pool(MAX_DROPLETS)
	_rng.randomize()


## Fill the droplet pool. Done by [method bind]; separate so tests can have a
## pool without a tank.
func make_pool(size: int) -> void:
	for i in size:
		var droplet := SpoutDroplet.new()
		droplet.name = "Droplet%d" % i
		droplet.z_index = 10
		droplet.retire()
		add_child(droplet)
		_droplets.append(droplet)


func _physics_process(delta: float) -> void:
	if spout == null:
		return
	_elapsed += delta
	var tint := stream_color(_elapsed)
	var muzzle := spout.muzzle_position()
	var dir := spout.direction()
	simulation.add_velocity_impulse(muzzle, dir * JET_ACCELERATION, JET_RADIUS, delta)
	simulation.add_paint(muzzle, tint, JET_PAINT, JET_PAINT_RADIUS, delta)

	_spawn_debt += DROPLET_RATE * delta
	while _spawn_debt >= 1.0:
		_spawn_debt -= 1.0
		var angle := _rng.randf_range(-DROPLET_SPREAD, DROPLET_SPREAD)
		spawn_droplet(muzzle, dir.rotated(angle) * DROPLET_SPEED, tint)

	_resist_at_pins(delta)
	collide_droplets()


## A droplet from the pool, launched; the oldest in play is recycled when
## the pool is spent. Returns it.
func spawn_droplet(at: Vector2, initial: Vector2, tint: Color) -> SpoutDroplet:
	var chosen: SpoutDroplet = null
	for droplet in _droplets:
		if not droplet.active:
			chosen = droplet
			break
		if chosen == null or droplet.age > chosen.age:
			chosen = droplet
	chosen.launch(at, initial, tint)
	return chosen


func active_count() -> int:
	var count := 0
	for droplet in _droplets:
		if droplet.active:
			count += 1
	return count


## Retire droplets that have left the field, and bounce live ones off pins,
## playing each pin struck.
func collide_droplets() -> void:
	# Anything well clear of the field, below or to either side, is spent.
	var field := Rect2(pins.to_global(pins.area.position), pins.area.size)
	var bounds := field.grow_individual(field.size.x, 100000.0, field.size.x, 80.0)
	for droplet in _droplets:
		if not droplet.active:
			continue
		var at := droplet.global_position
		if droplet.age > droplet.lifetime or not bounds.has_point(at):
			droplet.retire()
			continue
		var pin := pins.pin_at(at, droplet.radius)
		if pin < 0:
			continue
		var centre := pins.to_global(pins.pin_position(pin))
		var contact := resolve_contact(
			at, droplet.velocity, centre, pins.pin_radius + droplet.radius
		)
		if contact.is_empty():
			continue
		droplet.global_position = contact["position"]
		droplet.velocity = contact["velocity"]
		if pins.hit(pin, contact["strength"]):
			_hits += 1
		if simulation != null:
			simulation.add_velocity_impulse(
				contact["position"], contact["normal"] * PIN_SPLASH, 30.0, 1.0 / 30.0
			)


## Each pin leans against the current running through it, so the stream
## parts around the pins rather than passing through them.
func _resist_at_pins(delta: float) -> void:
	for pin in pins.pin_count():
		var centre := pins.to_global(pins.pin_position(pin))
		var current := simulation.sample_velocity(centre)
		if current.length_squared() > 400.0:
			simulation.add_velocity_impulse(
				centre, -current * PIN_RESISTANCE, pins.pin_radius * 2.2, delta
			)


## A droplet at [param at], moving at [param velocity], against a pin at
## [param centre] they touch within [param reach] of. Empty if the droplet is
## not closing on the pin; else the droplet's new [code]position[/code] (just
## clear of the pin) and [code]velocity[/code] (bounced), the contact
## [code]normal[/code], and the hit's [code]strength[/code], 0..1.
static func resolve_contact(
	at: Vector2, velocity: Vector2, centre: Vector2, reach: float
) -> Dictionary:
	var offset := at - centre
	if offset.length() > reach:
		return {}
	var normal := offset.normalized() if offset.length() > 0.001 else Vector2.UP
	var closing := -velocity.dot(normal)
	if closing <= 0.0:
		return {}
	return {
		"position": centre + normal * reach,
		"velocity": velocity.bounce(normal) * RESTITUTION,
		"normal": normal,
		"strength": clampf(closing / FULL_STRENGTH_SPEED, 0.15, 1.0),
	}


## The stream's colour at [param seconds]: drifting round [constant PALETTE].
static func stream_color(seconds: float) -> Color:
	var position := fposmod(seconds / PALETTE_SECONDS, float(PALETTE.size()))
	var from := int(position)
	var to := (from + 1) % PALETTE.size()
	return PALETTE[from].lerp(PALETTE[to], position - from)


func dark_backdrop() -> bool:
	return true


func hit_count() -> int:
	return _hits


func describe() -> String:
	return "A: fluid · %d droplets · %d pin hits" % [active_count(), _hits]

class_name FluidEmitter
extends SpoutEmitter
## The spout pours the eye tank's fluid.
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
##
## [b]How hard it pours[/b] is up to the player, in steps of the bar
## ([SpoutFlow]): 2 droplets a bar at the gentlest, up to 16. RT sets the step
## by depth; a touch (or held click) by how far from the spout it is, with
## [SpoutFlowOverlay] drawing the steps as rings round the nozzle. Droplets
## leave on the bar's grid, so the stream plays in time with the band, and the
## jet's push and paint grow with the step. With neither held the spout is
## closed.

## Acceleration the jet gives the fluid at the nozzle, pixels/second^2, at
## the gentlest and fullest steps.
const JET_ACCELERATION_MIN := 1400.0
const JET_ACCELERATION_MAX := 3200.0
const JET_RADIUS := 34.0
## Pigment laid at the nozzle, density/second.
const JET_PAINT := 2.4
const JET_PAINT_RADIUS := 26.0
## The tank's standing lean, so the stream carries on downward.
const DOWNWARD_LEAN := Vector2(0.0, 45.0)

## Droplets' speed leaving the nozzle at the gentlest and fullest steps, and
## how far their direction is scattered either side of the aim.
const DROPLET_SPEED_MIN := 280.0
const DROPLET_SPEED_MAX := 420.0
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
var overlay: SpoutFlowOverlay
## Whether to read the pad and keyboard; off for tests, which set the depth.
var reads_input := true
var _droplets: Array[SpoutDroplet] = []
var _fired := 0
var _depth := 0.0
var _step := -1
## Where the music was last frame, in bars; NAN while closed.
var _last_bars := NAN
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

	overlay = SpoutFlowOverlay.new()
	overlay.name = "FlowOverlay"
	overlay.z_index = 30
	overlay.pivot = spout.global_position
	overlay.max_aim = spout.max_aim
	overlay.inner = flow_inner()
	overlay.reach = flow_reach()
	add_child(overlay)


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
	if reads_input:
		_depth = SpoutFlow.read_depth()
	var touching := _pointer_active()
	set_step(current_step())
	overlay.show_flow(_step, touching, _pointer().point() if touching else Vector2.ZERO)
	if _step >= 0:
		var now := SpoutFlow.music_bars()
		var due := 0 if is_nan(_last_bars) else SpoutFlow.due(_last_bars, now, flow_per_bar())
		_last_bars = now
		_pour(delta, due)
	_resist_at_pins(delta)
	collide_droplets()


## The step to pour at now: the higher of the trigger's and a touch's, or -1
## when neither is held.
func current_step() -> int:
	var step := SpoutFlow.step_for_depth(_depth)
	if _pointer_active():
		var distance := spout.global_position.distance_to(_pointer().point())
		step = maxi(step, SpoutFlow.step_for_distance(distance, flow_inner(), flow_reach()))
	return step


## Pour at [param step] from now on (-1 closes the spout). Opening, or moving
## to a new step, starts counting the grid from this moment, so the change
## never releases a burst.
func set_step(step: int) -> void:
	if step == _step:
		return
	_step = step
	_last_bars = NAN


func flow_step() -> int:
	return _step


func flow_per_bar() -> int:
	return SpoutFlow.per_bar(_step)


## Set the trigger depth by hand, for tests or another input.
func set_depth(depth: float) -> void:
	_depth = clampf(depth, 0.0, 1.0)


## Radius round the spout inside which a touch pours at the gentlest step:
## just past the nozzle's tip.
func flow_inner() -> float:
	return spout.barrel_length + 30.0


## Radius at which a touch pours at the fullest step: down at the bottom of
## the pins, so the whole drop from the spout is the dial.
func flow_reach() -> float:
	var bottom := pins.to_global(pins.area.end).y
	return maxf(bottom - spout.global_position.y, flow_inner() + 1.0)


## How far up the steps the spout is, 0 at the gentlest, 1 at the fullest.
func flow_fraction() -> float:
	return float(maxi(_step, 0)) / (SpoutFlow.STEPS.size() - 1)


## One frame of pouring: the jet's push and paint, scaled to the step, and
## [param due] droplets launched on the grid.
func _pour(delta: float, due: int) -> void:
	var strength := flow_fraction()
	var tint := stream_color(_elapsed)
	var muzzle := spout.muzzle_position()
	var dir := spout.direction()
	var push := lerpf(JET_ACCELERATION_MIN, JET_ACCELERATION_MAX, strength)
	if simulation != null:
		simulation.add_velocity_impulse(muzzle, dir * push, JET_RADIUS, delta)
		simulation.add_paint(muzzle, tint, JET_PAINT * (0.5 + strength), JET_PAINT_RADIUS, delta)
	var speed := lerpf(DROPLET_SPEED_MIN, DROPLET_SPEED_MAX, strength)
	for i in due:
		var angle := _rng.randf_range(-DROPLET_SPREAD, DROPLET_SPREAD)
		spawn_droplet(muzzle, dir.rotated(angle) * speed, tint)
		overlay.pulse()
		var haptics: Haptics = level.get("haptics") if level != null else null
		if haptics != null:
			haptics.pulse(0.25 + 0.35 * strength, 0.02)


func _pointer() -> SpoutPointer:
	return level.get("pointer") if level != null else null


func _pointer_active() -> bool:
	var pointer := _pointer()
	return pointer != null and pointer.is_active()


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
	_fired += 1
	return chosen


## Droplets launched since the level began.
func fired_count() -> int:
	return _fired


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


## RT pours here, so L2/R2 stay out of key moves; L1/R1 still walk all twelve
## keys.
func leaves_triggers_free() -> bool:
	return false


func hit_count() -> int:
	return _hits


func describe() -> String:
	var flow := "closed" if _step < 0 else "%d / bar" % flow_per_bar()
	return "pouring %s · %d droplets · %d pin hits" % [flow, active_count(), _hits]


func controls_hint() -> String:
	return "RT or touch pours, 2–16 a bar (touch further away = more; Space full, 1–5)"

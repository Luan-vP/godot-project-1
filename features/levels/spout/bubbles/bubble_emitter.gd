class_name BubbleEmitter
extends SpoutEmitter
## The spout fires bubbles that stick to the ducks they hit and pop in time.
##
## [b]Firing.[/b] Bubbles ([SpoutBubble]) leave the nozzle along its aim in
## steps of the bar ([SpoutFlow], run by [SpoutEmitter]): 8, 12, 16 or 20 a
## bar ([constant STEPS]), set by RT's depth or by which ring round the spout
## a touch is in, each on the bar's grid and each with a haptic tick. They
## fall under gravity and bounce off the pins, the side walls and each other.
##
## [b]Sticking.[/b] A bubble that hits a free pin sticks to it: it snaps
## round the pin's duck and waits. Only one bubble to a pin; one that hits a
## pin already holding one bounces off in silence. On the next sixteenth of
## the music the pin plays (at the strength the bubble struck it with), the
## bubble pops, and the pin is gone until the start of the next bar, bubbles
## falling straight through where it was. Every pin waiting plays on that
## sixteenth together, so bubbles that stick at once sound as a chord.
##
## [b]The delay.[/b] Every pin played echoes ([PinEcho]): a bar later, as
## the popped pins come back, and a bar after that, while the bar's notes
## drift up over the pins as a constellation and are printed into the water.
##
## [b]The water.[/b] The tank is the host's ([SharedLayers]). While the spout
## is open it pushes the water along its aim from the nozzle and paints into
## it, so a painted jet swings with the aim, and the whole tank leans gently
## downward to carry it. The pins part the current running through them.
## Each bubble pushes a wake into the water and paints a trail as it goes,
## and splashes it when it strikes a pin or pops. None of this comes back:
## the current never moves a bubble.

## Bubbles a bar at each step.
const STEPS: Array[int] = [8, 12, 16, 20]
const MUZZLE_SPEED := 1040.0
## Scatter either side of the aim, so a stream of bubbles fans a little.
const SPREAD := deg_to_rad(2.5)
## At most this many bubbles in play; the oldest goes first.
const MAX_BUBBLES := 60
const LIFETIME := 14.0
## Closing speed, pixels/second, that plays a stuck pin at full strength,
## and the strength the softest of hits plays at: every stuck bubble sounds,
## so even a roll on to a pin is heard.
const FULL_STRENGTH_SPEED := 1300.0
const MIN_STRENGTH := 0.25
## How far back the music has to jump, in bars, to count as starting over,
## which drops every echo still waiting.
const RESTART_BARS := 0.25
## How far a stuck bubble's rim sits outside its duck, in pixels.
const WRAP_MARGIN := 3.0

## Physics layers: pins (from [PinField]), bubbles, the side walls.
const BUBBLE_LAYER := 1 << 3
const WALL_LAYER := 1 << 4

## Acceleration the jet gives the water at the nozzle, pixels/second^2, at
## the gentlest and fullest steps.
const JET_ACCELERATION_MIN := 2800.0
const JET_ACCELERATION_MAX := 6400.0
const JET_RADIUS := 34.0
## Pigment laid at the nozzle, density/second.
const JET_PAINT := 2.4
const JET_PAINT_RADIUS := 26.0
## The tank's standing lean, so the stream carries on downward.
const DOWNWARD_LEAN := Vector2(0.0, 45.0)
## How hard a pin pushes back on the current through it (1/second), and the
## splash a bubble striking a pin, or popping, makes (pixels/second^2).
const PIN_RESISTANCE := 5.0
const PIN_SPLASH := 1400.0
const POP_SPLASH := 900.0

## The palette the stream cycles through, slowly: the dyes.
const PALETTE: Array[Color] = ArtPalette.DYES
## Seconds to drift from one palette colour to the next.
const PALETTE_SECONDS := 9.0
## How far towards white the stream is lifted from the dyes, so what pours
## out stands bright against the tank.
const STREAM_LIFT := 0.3

## The tank the bubbles stir; none outside a host, and they only move.
var simulation: FluidSimulation
## The delay on every pin played, and its constellations.
var echo: PinEcho

var _bubbles: Array[SpoutBubble] = []
var _bubble_material := PhysicsMaterial.new()
var _fired := 0
var _played := 0
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
## Pin to the bubble stuck to it.
var _stuck := {}
## Pin to the strength it will play at.
var _strengths := {}
## Pins with a bubble stuck, in the order they stuck: the next sixteenth
## plays them all.
var _waiting: Array[int] = []
## Where the music was last frame, in bars; NAN until the first frame.
var _clock_bars := NAN


func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	super(level_node, the_spout, the_pins)
	var shared := SharedLayers.find(level_node)
	if shared != null:
		simulation = shared.fluid
	_bubble_material.bounce = 0.3
	_bubble_material.friction = 0.05
	_rng.randomize()
	_build_walls()
	echo = PinEcho.new()
	echo.name = "Echo"
	echo.pins = pins
	echo.fluid = simulation
	add_child(echo)
	start_flow()


func flow_steps() -> Array[int]:
	return STEPS


func _physics_process(delta: float) -> void:
	if spout == null:
		return
	_elapsed += delta
	if simulation != null:
		# Re-asserted every frame, not just at bind: a shared tank has its
		# currents reset at each carousel transition, and this level only
		# runs once it has arrived. It is a stored vector, so this costs
		# nothing.
		simulation.set_current_bias(DOWNWARD_LEAN)
	for i in tick_flow():
		fire()
	if simulation != null:
		if flow_step() >= 0:
			_pour(delta)
		_resist_at_pins(delta)
	_retire_spent()
	tick_clock(heard_bars())


## Fire one bubble from the nozzle, with a haptic tick. Returns it.
func fire() -> SpoutBubble:
	if _bubbles.size() >= MAX_BUBBLES:
		_retire(_bubbles[0])
	var bubble := SpoutBubble.new()
	bubble.pins = pins
	bubble.simulation = simulation
	bubble.tint = stream_color(_elapsed).lightened(STREAM_LIFT)
	bubble.collision_layer = BUBBLE_LAYER
	bubble.collision_mask = pins.pin_layer | BUBBLE_LAYER | WALL_LAYER
	bubble.physics_material_override = _bubble_material
	bubble.z_index = 10
	bubble.struck_pin.connect(_on_struck_pin)
	add_child(bubble)
	var dir := spout.direction().rotated(_rng.randf_range(-SPREAD, SPREAD))
	bubble.global_position = spout.muzzle_position()
	bubble.linear_velocity = dir * MUZZLE_SPEED
	_bubbles.append(bubble)
	_fired += 1
	var haptics: Haptics = level.get("haptics") if level != null else null
	if haptics != null:
		haptics.pulse(0.35 + 0.45 * flow_fraction(), 0.025)
	return bubble


## Where the music is, in bars, as the band schedules it: ahead of the raw
## position by the source's lookahead, as [StepClock] reads it, so a stuck
## pin sounds on the same sixteenth as the band rather than a mix late.
static func heard_bars() -> float:
	var source := AudioManager.get_music_time_source()
	if not source.is_running():
		return 0.0
	var clock := AudioManager.get_music_clock()
	var lookahead := clock.beats_from_seconds(source.get_lookahead())
	return SpoutFlow.music_bars() + lookahead / maxi(1, clock.beats_per_bar)


## Move the music on to [param now_bars] (bars from the start): a bar line
## crossed brings every popped pin back, then a sixteenth crossed plays
## every pin waiting. The bar comes first, so a pin played on a downbeat
## stays gone that whole bar. Echoes due by then sound too.
func tick_clock(now_bars: float) -> void:
	if is_nan(_clock_bars) or now_bars < _clock_bars:
		# A clock that jitters back a hair is not the music starting over.
		if not is_nan(_clock_bars) and now_bars < _clock_bars - RESTART_BARS:
			echo.reset()
		_clock_bars = now_bars
		return
	if floori(now_bars) > floori(_clock_bars):
		pins.restore_all()
	var due := SpoutFlow.due(_clock_bars, now_bars, sixteenths_per_bar())
	_clock_bars = now_bars
	echo.tick(now_bars, sixteenths_per_bar())
	if due > 0:
		play_waiting()


## Sixteenth notes in a bar of the band's metre.
static func sixteenths_per_bar() -> int:
	return maxi(1, AudioManager.get_music_clock().beats_per_bar * 4)


## Play every pin waiting, together, and pop each with its bubble. Returns
## the pins played, in the order they stuck.
func play_waiting() -> Array[int]:
	var played := _waiting.duplicate()
	_waiting.clear()
	for pin in played:
		var bubble: SpoutBubble = _stuck[pin]
		var strength: float = _strengths[pin]
		_stuck.erase(pin)
		_strengths.erase(pin)
		var centre := pins.to_global(pins.pin_position(pin))
		if pins.hit(pin, strength):
			echo.record(
				pins.note_for(pin),
				strength,
				centre,
				floori((0.0 if is_nan(_clock_bars) else _clock_bars) * sixteenths_per_bar()),
				sixteenths_per_bar()
			)
		pins.pop(pin)
		_played += 1
		_pop(bubble, centre)
	return played


## Stick [param bubble] to [param pin], struck at [param closing_speed], if
## the pin is free. Returns whether it stuck.
func stick(bubble: SpoutBubble, pin: int, closing_speed: float) -> bool:
	if bubble.is_stuck() or _stuck.has(pin) or not pins.is_live(pin):
		return false
	_stuck[pin] = bubble
	_strengths[pin] = clampf(closing_speed / FULL_STRENGTH_SPEED, MIN_STRENGTH, 1.0)
	_waiting.append(pin)
	var centre := pins.to_global(pins.pin_position(pin))
	bubble.stick_to(pin, centre, wrap_radius())
	return true


## How big a stuck bubble grows: round the duck, with a little room.
func wrap_radius() -> float:
	return pins.duck_size * 0.5 + WRAP_MARGIN


## The stream's colour at [param seconds]: drifting round [constant PALETTE].
static func stream_color(seconds: float) -> Color:
	var position := fposmod(seconds / PALETTE_SECONDS, float(PALETTE.size()))
	var from := int(position)
	var to := (from + 1) % PALETTE.size()
	return PALETTE[from].lerp(PALETTE[to], position - from)


func in_play() -> int:
	return _bubbles.size()


func fired_count() -> int:
	return _fired


func stuck_count() -> int:
	return _stuck.size()


func played_count() -> int:
	return _played


## The bubble stuck to [param pin], or null.
func bubble_on(pin: int) -> SpoutBubble:
	return _stuck.get(pin)


func _on_struck_pin(bubble: SpoutBubble, pin: int, closing_speed: float) -> void:
	if simulation != null:
		var centre := pins.to_global(pins.pin_position(pin))
		var normal := (bubble.global_position - centre).normalized()
		simulation.add_velocity_impulse(
			bubble.global_position, normal * PIN_SPLASH, 30.0, 1.0 / 30.0
		)
	stick(bubble, pin, closing_speed)


## One frame of the open spout in the water: the jet's push and paint, both
## growing with the step.
func _pour(delta: float) -> void:
	var strength := flow_fraction()
	var muzzle := spout.muzzle_position()
	var push := lerpf(JET_ACCELERATION_MIN, JET_ACCELERATION_MAX, strength)
	var tint := stream_color(_elapsed).lightened(STREAM_LIFT)
	simulation.add_velocity_impulse(muzzle, spout.direction() * push, JET_RADIUS, delta)
	simulation.add_paint(muzzle, tint, JET_PAINT * (0.5 + strength), JET_PAINT_RADIUS, delta)


## Each pin leans against the current running through it, so the stream
## parts around the pins rather than passing through them.
func _resist_at_pins(delta: float) -> void:
	for pin in pins.live_pins():
		var centre := pins.to_global(pins.pin_position(pin))
		var current := simulation.sample_velocity(centre)
		if current.length_squared() > 400.0:
			simulation.add_velocity_impulse(
				centre, -current * PIN_RESISTANCE, pins.pin_radius * 2.2, delta
			)


## Burst [param bubble] over the pin at [param centre], splashing the water
## outwards round it.
func _pop(bubble: SpoutBubble, centre: Vector2) -> void:
	_bubbles.erase(bubble)
	bubble.pop()
	if simulation == null:
		return
	var reach := wrap_radius()
	for k in 4:
		var out := Vector2.from_angle(TAU * k / 4.0)
		simulation.add_velocity_impulse(centre + out * reach, out * POP_SPLASH, 20.0, 1.0 / 30.0)


func _retire_spent() -> void:
	var floor_y := get_viewport_rect().size.y + 60.0
	for bubble in _bubbles.duplicate():
		if bubble.age > LIFETIME or bubble.global_position.y > floor_y:
			_retire(bubble)


func _retire(bubble: SpoutBubble) -> void:
	# The pool's cap can take a stuck bubble; its pin is free again.
	if bubble.is_stuck() and _stuck.get(bubble.stuck_to) == bubble:
		_stuck.erase(bubble.stuck_to)
		_strengths.erase(bubble.stuck_to)
		_waiting.erase(bubble.stuck_to)
	_bubbles.erase(bubble)
	bubble.queue_free()


## Cushions down both sides of the screen, so bubbles fired wide come back
## into play like a billiard table's rails. The floor is left open.
func _build_walls() -> void:
	var extent := get_viewport_rect().size
	var material := PhysicsMaterial.new()
	material.bounce = 0.45
	material.friction = 0.05
	for side in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.name = "Wall%s" % ("Left" if side < 0.0 else "Right")
		wall.collision_layer = WALL_LAYER
		wall.collision_mask = 0
		wall.physics_material_override = material
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(40.0, extent.y * 2.0)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector2(-20.0 if side < 0.0 else extent.x + 20.0, extent.y * 0.5)
		add_child(wall)


func describe() -> String:
	return (
		"bubbles · firing %s · %d in play · %d stuck · %d popped · %d played · %d echoing"
		% [
			describe_flow(),
			in_play(),
			stuck_count(),
			pins.popped_count(),
			_played,
			echo.pending_count(),
		]
	)


func controls_hint() -> String:
	return "RT or touch fires, 8–20 a bar (touch further away = more; Space full, 1–5)"

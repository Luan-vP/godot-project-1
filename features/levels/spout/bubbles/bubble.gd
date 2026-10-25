class_name SpoutBubble
extends RigidBody2D
## One of the spout's bubbles. It moves like a small, hard billiard ball: it
## leaves the nozzle along the aim, falls, clacks off the pins and the other
## bubbles, and tells its [BubbleEmitter] about every pin it strikes, with
## the speed it struck at.
##
## It is drawn in vectors: a thin rim in its tint over a clear fill, with a
## highlight. When it sticks to a pin it snaps round the pin's duck, growing
## to enclose it; when the pin plays, it pops.
##
## It stirs the tank but the tank does not stir it: every physics frame it
## pushes the water by how fast it is slipping through it, and paints a
## trail in its tint, but it never reads the current into its own motion.
## Its path is the physics engine's alone.

## Emitted when the bubble strikes a pin, with how fast it was closing on it.
signal struck_pin(bubble: SpoutBubble, pin: int, closing_speed: float)

const RADIUS := 8.0
## Seconds a stuck bubble takes to snap round its duck, and to pop.
const SNAP_SECONDS := 0.12
const POP_SECONDS := 0.22
## The push its slip through the water gives the tank (1/second), and over
## what radius, in pixels.
const WAKE_STRENGTH := 1.6
const WAKE_RADIUS := 36.0
## The trail it paints: density/second, and its radius.
const PAINT_AMOUNT := 0.5
const PAINT_RADIUS := 18.0

var pins: PinField
## The tank it stirs and paints; none, and it only moves.
var simulation: FluidSimulation
var age := 0.0
## Its rim and its trail.
var tint := ArtPalette.DYES[0]
## The pin this bubble is stuck to, or -1 while it is loose.
var stuck_to := -1
## Velocity at the end of the previous physics step: by the time
## [signal RigidBody2D.body_entered] fires the bounce has already happened, so
## the speed it hit at has to come from before it.
var _approach := Vector2.ZERO
## How big it is drawn: [constant RADIUS] while loose, the duck's size once
## stuck.
var _radius := RADIUS
var _wrap_radius := RADIUS
## 0 when it sticks, rising to 1 as it closes round the duck.
var _snap := 1.0
## 0 when it pops, rising to 1 as it goes; -1 while whole.
var _pop := -1.0


func _init() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp = 0.08
	angular_damp = 0.5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# A stuck bubble is waiting to play, so it does not age out meanwhile.
	if stuck_to < 0:
		age += delta
		_stir(delta)
	_approach = linear_velocity


func _process(delta: float) -> void:
	if _pop >= 0.0:
		_pop += delta / POP_SECONDS
		if _pop >= 1.0:
			queue_free()
	elif _snap < 1.0:
		_snap = minf(1.0, _snap + delta / SNAP_SECONDS)
		_radius = lerpf(RADIUS, _wrap_radius, ease(_snap, 0.4))
	else:
		return
	queue_redraw()


## Stop dead on [param pin], centred on [param centre] (global), and close
## round its duck at [param wrap_radius]. Safe to call from a physics
## callback: the freeze lands after it.
func stick_to(pin: int, centre: Vector2, wrap_radius: float) -> void:
	stuck_to = pin
	_wrap_radius = wrap_radius
	_snap = 0.0
	_settle.call_deferred(centre)


func is_stuck() -> bool:
	return stuck_to >= 0


## Burst, and free itself once the burst has played.
func pop() -> void:
	if _pop >= 0.0:
		return
	_pop = 0.0
	_radius = _wrap_radius
	collision_layer = 0
	collision_mask = 0


func is_popping() -> bool:
	return _pop >= 0.0


## How big it is drawn now, in pixels.
func drawn_radius() -> float:
	return _radius


func _settle(centre: Vector2) -> void:
	# Out of play: it sits over the pin, which does the colliding.
	collision_layer = 0
	collision_mask = 0
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = centre
	rotation = 0.0


## Push and paint the tank. The current is read only to know the slip; it
## never moves the bubble.
func _stir(delta: float) -> void:
	if simulation == null or not is_instance_valid(simulation):
		return
	var at := global_position
	var slip := linear_velocity - simulation.sample_velocity(at)
	simulation.add_velocity_impulse(at, slip * WAKE_STRENGTH, WAKE_RADIUS, delta)
	simulation.add_paint(at, tint, PAINT_AMOUNT, PAINT_RADIUS, delta)


func _on_body_entered(body: Node) -> void:
	if pins == null:
		return
	var pin := pins.pin_for_body(body)
	if pin < 0:
		return
	var centre := pins.to_global(pins.pin_position(pin))
	struck_pin.emit(self, pin, closing_speed(_approach, global_position, centre))


## How fast a bubble moving at [param velocity], at [param at], was closing
## on a pin at [param centre]: the part of its speed along the line between
## them. A glancing roll closes slowly; a straight drop at full speed.
static func closing_speed(velocity: Vector2, at: Vector2, centre: Vector2) -> float:
	var normal := (at - centre).normalized()
	return maxf(0.0, -velocity.dot(normal))


func _draw() -> void:
	# Drawn upright, whatever the body's spin.
	draw_set_transform(Vector2.ZERO, -rotation)
	var rim := tint.lerp(ArtPalette.LIGHT, 0.45)
	if _pop >= 0.0:
		_draw_pop(rim)
		return
	draw_circle(Vector2.ZERO, _radius, Color(tint, 0.14))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(rim, 0.9), 1.5, true)
	# A highlight up and to the left, and a glint beside it.
	var shine := Color(ArtPalette.LIGHT, 0.8)
	draw_arc(Vector2.ZERO, _radius * 0.68, PI * 1.08, PI * 1.42, 10, shine, 1.5, true)
	draw_circle(Vector2(-0.18, -0.55) * _radius, maxf(1.0, _radius * 0.1), shine)


## The burst: the rim flies apart in pieces, with a spray of drops, all
## fading as they go.
func _draw_pop(rim: Color) -> void:
	var t := clampf(_pop, 0.0, 1.0)
	var spread := _radius * (1.0 + 0.6 * t)
	var fade := 1.0 - t
	var pieces := 8
	for k in pieces:
		var from := TAU * k / pieces
		draw_arc(Vector2.ZERO, spread, from, from + TAU / pieces * 0.45, 4, Color(rim, fade), 1.5)
	for k in pieces:
		var angle := TAU * (k + 0.5) / pieces
		var drop := Vector2.from_angle(angle) * _radius * (1.1 + 0.9 * t)
		draw_circle(drop, 1.4 * fade + 0.3, Color(ArtPalette.LIGHT, fade * 0.8))

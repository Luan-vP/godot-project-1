class_name FluidBody
extends Node2D
## Something that floats in a [FluidSimulation], and stirs it back.
##
## The exchange runs both ways, which is the whole point: the body is dragged
## towards whatever the current is doing, and the difference between where it
## is going and where the water is going gets pushed back into the tank as a
## wake. Two bodies passing close therefore shove each other around without
## either one knowing the other exists.
##
## Movement is pure drift. Anything self-propelled should add its own force in
## [method _physics_process] before calling [code]super[/code], or just write to
## [member velocity].

## How hard the current grabs the body, in 1/second. High values pin it to the
## flow; low values let it coast through eddies with its own momentum.
@export var drag: float = 3.2

## How heavily the fluid fails to hold this body up, in pixels/second^2:
## everything left over once the water has pushed back. Positive sinks,
## negative rises, zero floats wherever the current leaves it. It is an
## acceleration rather than a mass because nothing here integrates forces —
## the drift law takes what the body does per second and nothing else needs
## to know how heavy it is.
##
## The pull runs along the tank's own down ([method FluidSimulation.get_gravity]),
## so a tilted tank sends every body with weight sliding the way the device is
## being held, not down the screen.
@export var weight: float = 0.0

## Speed ceiling in pixels/second, so a violent eddy cannot fling the body.
@export var max_speed: float = 420.0

## Bounce off the tank walls instead of drifting out of the painted area.
@export var contained: bool = true

@export_group("Wake")
## Acceleration pushed back into the tank per unit of slip speed, in 1/second.
## Zero makes the body a passive float that disturbs nothing.
@export var wake_strength: float = 6.0

## Radius of that push, in pixels.
@export var wake_radius: float = 90.0

@export_group("Paint")
## Pigment laid into the water, in density/second. Zero paints nothing.
@export var paint_amount: float = 0.0

@export var paint_color: Color = Color(0.42, 0.68, 0.66)

@export var paint_radius: float = 70.0

@export_group("Tank")
## Tank to float in. Left empty, the first tank in the scene is used.
@export var simulation_path: NodePath

## Current motion in pixels/second. Safe to write to.
var velocity: Vector2 = Vector2.ZERO

var _simulation: FluidSimulation


func _ready() -> void:
	_simulation = _resolve_simulation()


func _physics_process(delta: float) -> void:
	if _simulation == null:
		_simulation = _resolve_simulation()
		if _simulation == null:
			return

	var current := _simulation.sample_velocity(global_position)
	var slip := velocity - current
	velocity = drift(velocity, current, drag, _simulation.get_gravity() * weight, max_speed, delta)
	global_position += velocity * delta

	if contained:
		_contain()

	if wake_strength > 0.0:
		_simulation.add_velocity_impulse(global_position, slip * wake_strength, wake_radius, delta)
	if paint_amount > 0.0:
		_simulation.add_paint(global_position, paint_color, paint_amount, paint_radius, delta)


## The drift law, kept pure so it can be checked on its own: pull the body
## towards the flow at a rate set by [param drag_rate], add [param pull], cap
## the result. A [param drag_rate] * [param delta] of 1 or more snaps the body
## straight onto the current, which is what keeps large steps stable.
##
## [param pull] is a vector rather than a sink rate because down is wherever
## the tank is being held. It is added after the drag term, so weight is what
## the current cannot carry away: a body pinned hard to the flow still creeps
## along it, and one that coasts falls through it.
static func drift(
	body_velocity: Vector2,
	flow: Vector2,
	drag_rate: float,
	pull: Vector2,
	speed_limit: float,
	delta: float
) -> Vector2:
	var pulled := body_velocity - (body_velocity - flow) * clampf(drag_rate * delta, 0.0, 1.0)
	return (pulled + pull * delta).limit_length(speed_limit)


## Kick the body, in pixels/second.
func apply_impulse(impulse: Vector2) -> void:
	velocity += impulse


## The tank this body is floating in, or [code]null[/code] before it is found.
func get_simulation() -> FluidSimulation:
	return _simulation


func _contain() -> void:
	var rect := _simulation.get_world_rect()
	var limit := rect.end
	if global_position.x < rect.position.x:
		global_position.x = rect.position.x
		velocity.x = absf(velocity.x)
	elif global_position.x > limit.x:
		global_position.x = limit.x
		velocity.x = -absf(velocity.x)
	if global_position.y < rect.position.y:
		global_position.y = rect.position.y
		velocity.y = absf(velocity.y)
	elif global_position.y > limit.y:
		global_position.y = limit.y
		velocity.y = -absf(velocity.y)


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation

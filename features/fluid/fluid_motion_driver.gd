class_name FluidMotionDriver
extends Node
## Joins [MotionInput] to a [FluidSimulation]: tilt leans the current, a jog
## shoves the tank.
##
## Deliberately the only file that knows about both. [code]core/motion[/code]
## has no idea a fluid exists and the fluid has no idea an accelerometer does;
## this is the seam where they meet, and keeping it this small is what lets
## either side be replaced without touching the other.

## Current bias at full tilt, in pixels/second^2.
@export_range(0.0, 4000.0, 10.0) var tilt_acceleration: float = 900.0

## Tank speed added per unit of jog strength, in pixels/second.
@export_range(0.0, 1500.0, 10.0) var nudge_speed: float = 260.0

## Pigment stirred up by a jog, so a shake is visible and not merely felt.
@export_range(0.0, 8.0, 0.1) var nudge_paint: float = 1.1

@export var paint_color: Color = Color(0.62, 0.70, 0.88)

@export_group("Wiring")
## Tank to drive. Left empty, the first one in the scene is used.
@export var simulation_path: NodePath

## Motion input to read. Left empty, the first one in the scene is used.
@export var motion_path: NodePath

var _simulation: FluidSimulation
var _motion: MotionInput


func _ready() -> void:
	_simulation = _resolve_simulation()
	_motion = _resolve_motion()
	if _motion == null:
		push_warning("FluidMotionDriver found no MotionInput; tilt and jog are inert.")
		return
	_motion.tilt_changed.connect(_on_tilt_changed)
	_motion.jogged.connect(_on_jogged)


func _on_tilt_changed(tilt: Vector2) -> void:
	if _simulation == null:
		return
	_simulation.set_current_bias(tilt * tilt_acceleration)


func _on_jogged(direction: Vector2) -> void:
	if _simulation == null:
		return
	_simulation.nudge(direction * nudge_speed)
	if nudge_paint <= 0.0:
		return
	# A shake that only moves invisible water reads as nothing happening.
	var rect := _simulation.get_world_rect()
	_simulation.add_paint(rect.get_center(), paint_color, nudge_paint, rect.size.y * 0.4, 1.0)


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation


func _resolve_motion() -> MotionInput:
	if not motion_path.is_empty():
		return get_node_or_null(motion_path) as MotionInput
	return get_tree().get_first_node_in_group(MotionInput.GROUP_NAME) as MotionInput

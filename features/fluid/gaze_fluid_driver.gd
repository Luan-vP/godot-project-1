class_name GazeFluidDriver
extends Node
## Joins [PanoramaLookCamera] to a [FluidSimulation]: turning the eyes stirs
## whatever is floating in front of them.
##
## The counterpart to [FluidMotionDriver], which does the same job for device
## tilt and jog. Kept as a separate file rather than a second source on that
## one because the two have nothing in common except the tank they push on —
## one reads an accelerometer, this one reads a camera, and neither side
## should have to know the other exists.
##
## [b]The mapping[/b] (a first attempt — see the class's own note on
## retuning): [member PanoramaLookCamera.angular_velocity] already points the
## way a [i]stationary[/i] scene would appear to sweep across the screen while
## the eye turns — panning right sweeps the view left, tilting up sweeps it
## down, and this project's yaw/pitch sign convention already lines up with
## that without a flip (turning right reports a negative yaw rate, and a
## leftward screen sweep is negative too). Floaters lag a turning eye the same
## direction a fixed background would seem to, for the same reason: both are
## "everything else" failing to keep up with how fast the eye moved. So the
## camera's angular velocity is used directly, unflipped, as the screen-space
## drive vector — which is what makes the sweep run opposite the look
## direction rather than with it.
##
## Split two ways, one per frame:
## - The (deadzoned) angular velocity itself, scaled by [member
##   hold_sensitivity], becomes the standing [method
##   FluidSimulation.set_current_bias]. Hold a turn and the current leans that
##   way for as long as the turn lasts; let go and the bias drops out, leaving
##   whatever the tank was already doing to decay on its own.
## - The [i]change[/i] in that angular velocity since last frame, scaled by
##   [member flick_sensitivity], is [method FluidSimulation.nudge]d every
##   frame. This is near zero holding a steady turn or holding still — nothing
##   is changing — and spikes exactly when a turn starts or stops, which is
##   what makes a flick overshoot and settle instead of the field snapping to
##   a new speed and stopping dead. It is a change rather than a rate (no
##   dividing by delta): [method nudge] is an instantaneous shove applied once
##   per call regardless of frame length, so summing a rate over more frames
##   at a higher refresh rate would make one physical flick add up to a bigger
##   total shove than the same flick at a lower one. Summing a plain
##   frame-to-frame change avoids that — it telescopes to the same total
##   regardless of how many frames the turn was sampled over.

## Angular speed below this, in radians/second, is treated as holding still
## and produces no bias or nudge. Real look input never reads exactly zero —
## a resting hand or an idle stick still jitters — so without this a player
## trying to hold still and watch floaters settle would never quite get
## there. Reuses [MotionFilter]'s dead-zone rescale so the effect ramps in
## smoothly at the edge instead of lurching the moment it engages.
@export_range(0.0, 0.99, 0.01) var deadzone_rad_per_sec: float = 0.05

## Current bias per radian/second of held turn rate, in pixels/second^2.
@export_range(0.0, 4000.0, 10.0) var hold_sensitivity: float = 300.0

## Nudge speed added per radian/second of frame-to-frame change in turn rate,
## in pixels/second.
@export_range(0.0, 20000.0, 50.0) var flick_sensitivity: float = 250.0

@export_group("Wiring")
## Tank to drive. Left empty, the first one in the scene is used.
@export var simulation_path: NodePath

## Camera to read. Left empty, the first one in the scene is used.
@export var camera_path: NodePath

var _simulation: FluidSimulation
var _camera: PanoramaLookCamera
var _previous_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_simulation = _resolve_simulation()
	_camera = _resolve_camera()
	if _camera == null:
		push_warning("GazeFluidDriver found no PanoramaLookCamera; the medium will not swish.")


func _process(_delta: float) -> void:
	if _simulation == null or _camera == null:
		return
	var velocity := _camera.angular_velocity
	var deadzone := deadzone_rad_per_sec
	_simulation.set_current_bias(hold_bias(velocity, deadzone, hold_sensitivity))
	_simulation.nudge(flick_nudge(velocity, _previous_velocity, deadzone, flick_sensitivity))
	_previous_velocity = velocity


## The hold half of the mapping, kept pure so it can be checked without a
## camera or a tank: dead-zone the angular velocity, then scale it into a
## current bias.
static func hold_bias(angular_velocity: Vector2, deadzone: float, sensitivity: float) -> Vector2:
	return MotionFilter.apply_deadzone(angular_velocity, deadzone) * sensitivity


## The flick half of the mapping: the frame-to-frame change in (deadzoned)
## angular velocity, scaled into a one-shot nudge. Dead-zoning both readings
## before differencing them, rather than differencing raw values and
## dead-zoning the result, is what keeps ordinary jitter below the zone from
## ever producing a nudge at all.
static func flick_nudge(
	angular_velocity: Vector2, previous_velocity: Vector2, deadzone: float, sensitivity: float
) -> Vector2:
	var now := MotionFilter.apply_deadzone(angular_velocity, deadzone)
	var before := MotionFilter.apply_deadzone(previous_velocity, deadzone)
	return (now - before) * sensitivity


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation


func _resolve_camera() -> PanoramaLookCamera:
	if not camera_path.is_empty():
		return get_node_or_null(camera_path) as PanoramaLookCamera
	return get_tree().get_first_node_in_group(PanoramaLookCamera.GROUP_NAME) as PanoramaLookCamera

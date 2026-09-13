class_name FluidSimulation
extends Node2D
## A grid-based (Eulerian) fluid tank the game world floats in.
##
## Each frame the solve runs as a chain of compute passes:
## [codeblock lang=text]
## velocity -> divergence -> pressure x N -> project -> dye -> downsample
## [/codeblock]
## advect the field along itself and add impulses, measure how much it is
## compressing, relax that away, subtract the correction, then carry the
## pigment on the result.
##
## This node owns the state and the API; [FluidGPU] owns the device resources
## and dispatches the passes. The split matters because every field is a pair
## of textures that take turns being read and written — a step reads last
## frame's field while writing this frame's, and that only works when the
## targets are ours to schedule.
##
## Gameplay never touches the GPU field. A small grid is copied back into a
## [FluidField] every few frames and everything else samples that; see
## [method sample_velocity]. Bodies push back through
## [method add_velocity_impulse], which is what makes the tank feel inhabited
## rather than decorative.

## Emitted after the CPU mirror is refreshed from the GPU.
signal field_updated(field: FluidField)

## Concurrent stirrers the solve can take. Past this the weakest impulses are
## dropped, so a busy frame degrades by losing the faintest wakes.
const MAX_SPLATS := FluidGPU.MAX_SPLATS

## Nodes register here so [FluidBody] can find its tank without wiring.
const GROUP_NAME := "fluid_simulation"

## How the tank moves. A default is created if none is assigned.
@export var config: FluidConfig

## Runs the solve. Turn it off to freeze the tank without tearing it down.
@export var simulating: bool = true:
	set = set_simulating

var _field := FluidField.new()
var _gpu := FluidGPU.new()
var _velocity_slots: Array[Vector4] = []
var _velocity_shapes: Array[Vector4] = []
var _velocity_weights: Array[float] = []
var _dye_slots: Array[Vector4] = []
var _dye_paints: Array[Vector4] = []
var _dye_weights: Array[float] = []
var _elapsed: float = 0.0
var _current_bias: Vector2 = Vector2.ZERO
var _pending_nudge: Vector2 = Vector2.ZERO
var _clear_requested: bool = false
var _frames_to_readback: int = 1
var _configured: bool = false


func _ready() -> void:
	add_to_group(GROUP_NAME)
	if config == null:
		config = FluidConfig.new()
	_field.configure_world(get_world_rect(), config.cell_size())
	_field.resize(config.readback_resolution, config.readback_resolution)
	_gpu.readback_ready.connect(_on_readback)
	_gpu.build(config)
	_configured = true


func _exit_tree() -> void:
	_gpu.destroy()


func _process(delta: float) -> void:
	if not _configured or not simulating or not _gpu.is_built():
		return
	_elapsed += delta
	# Cheap, and it means moving the tank node is not a silent footgun.
	_field.configure_world(get_world_rect(), config.cell_size())
	var step := minf(delta, config.max_time_step)
	_gpu.submit(_frame(step))
	_consume_queues()


## The slab of world the tank covers. The node's own position is its top-left
## corner.
func get_world_rect() -> Rect2:
	var size := Vector2(1920.0, 1080.0) if config == null else config.world_size
	return Rect2(global_position, size)


## Current at a world position, in pixels/second, from the CPU mirror.
func sample_velocity(world_position: Vector2) -> Vector2:
	return _field.sample_world(world_position)


## The CPU mirror itself, for code that wants to sample in bulk.
func get_field() -> FluidField:
	return _field


## Pigment field, premultiplied: [code].rgb[/code] is pigment * density and
## [code].a[/code] is density. This is what the painterly pass reads.
func get_dye_texture() -> Texture2D:
	return _gpu.dye_texture()


## Divergence-free velocity field, in cells/second in the red and green
## channels.
func get_velocity_texture() -> Texture2D:
	return _gpu.velocity_texture()


## Push the fluid. [param world_acceleration] is in pixels/second^2, applied
## for [param duration] seconds, and [param radius_pixels] is the Gaussian
## falloff of the push.
##
## Pass the [b]caller's own[/b] delta as the duration, never the rendered
## frame's. The queue is filled from physics and flushed on render, so scaling
## by the render step would under-integrate when rendering outruns physics and
## double-count when it lags.
func add_velocity_impulse(
	world_position: Vector2, world_acceleration: Vector2, radius_pixels: float, duration: float
) -> void:
	if not _configured or duration <= 0.0:
		return
	var uv := _field.world_to_uv(world_position)
	var cells := _field.world_to_cell_velocity(world_acceleration * duration)
	var radius := _radius_to_uv(radius_pixels)
	_push_splat(
		_velocity_slots,
		_velocity_shapes,
		_velocity_weights,
		Vector4(uv.x, uv.y, cells.x, cells.y),
		Vector4(radius, 1.0, 0.0, 0.0),
		cells.length() * radius
	)


## Deposit pigment. [param amount] is density laid down per second, applied for
## [param duration] seconds, so a body that sits still keeps staining the water
## under it. As with [method add_velocity_impulse], the duration is the
## caller's own delta.
func add_paint(
	world_position: Vector2, color: Color, amount: float, radius_pixels: float, duration: float
) -> void:
	if not _configured or amount <= 0.0 or duration <= 0.0:
		return
	var deposited := amount * duration
	var uv := _field.world_to_uv(world_position)
	var radius := _radius_to_uv(radius_pixels)
	_push_splat(
		_dye_slots,
		_dye_paints,
		_dye_weights,
		Vector4(uv.x, uv.y, radius, 1.0),
		Vector4(color.r, color.g, color.b, deposited),
		deposited * radius
	)


## Lean the whole current one way, in pixels/second^2, until changed. This is
## a bias on the ambient drift rather than gravity: the tank leans, it does not
## pour, so what floats in it stays floating.
func set_current_bias(world_acceleration: Vector2) -> void:
	_current_bias = world_acceleration


## Shove the entire tank at once, in pixels/second, as if the container were
## jerked sideways. Applied uniformly for one frame; the walls turn it into
## slosh.
func nudge(world_velocity: Vector2) -> void:
	_pending_nudge += world_velocity


## The standing lean on the current, in pixels/second^2.
func get_current_bias() -> Vector2:
	return _current_bias


## Blank the tank: velocity, pressure and pigment all go back to rest. The
## current bias survives, since it is the caller's state rather than the tank's.
func reset() -> void:
	_clear_requested = true
	_field.clear()
	_elapsed = 0.0
	# The pending nudge is a queued one-shot that has not landed yet, so it goes
	# with the rest of the tank state. The current bias does not: it belongs to
	# whoever set it — a held tilt is still held after a reset — and the tank
	# has no way to ask for it again. Clearing it would leave tilt inert until
	# the player happened to move.
	_pending_nudge = Vector2.ZERO


func set_simulating(value: bool) -> void:
	simulating = value


## One frame of work for the device, in the shape [FluidGPU] expects.
func _frame(step: float) -> Dictionary:
	var wants_readback := _should_read_back()
	# Retention has to be recomputed per step: the solve runs once per rendered
	# frame with a variable delta, so a fixed multiplier would decay far faster
	# at 144 fps than at 30.
	return {
		"texel_size": Vector2.ONE / Vector2(config.simulation_size()),
		"splat_aspect": Vector2(config.world_size.x / maxf(config.world_size.y, 1.0), 1.0),
		# Pixels-to-cells is a ratio, so the velocity conversion is also the
		# right one for an acceleration.
		"ambient_drift": _field.world_to_cell_velocity(_current_bias),
		"uniform_impulse": _field.world_to_cell_velocity(_pending_nudge),
		"time_step": step,
		"velocity_dissipation": FluidConfig.retention_over(config.velocity_dissipation, step),
		"dye_dissipation": FluidConfig.retention_over(config.dye_dissipation, step),
		"vorticity": config.vorticity,
		"viscous_alpha": config.viscous_coefficients(step),
		"wall_friction": config.wall_friction,
		"ambient_strength": config.ambient_current,
		"ambient_scale": config.ambient_scale,
		"elapsed": _elapsed,
		"velocity_splats": _pack_splats(_velocity_slots, _velocity_shapes),
		"velocity_splat_count": _velocity_slots.size(),
		"dye_splats": _pack_splats(_dye_slots, _dye_paints),
		"dye_splat_count": _dye_slots.size(),
		"clear": _clear_requested,
		"readback": wants_readback,
	}


## The nudge and the splats are one-frame impulses: once submitted they are
## spent. The current bias is not — it holds until someone changes it.
func _consume_queues() -> void:
	_pending_nudge = Vector2.ZERO
	_clear_requested = false
	_velocity_slots.clear()
	_velocity_shapes.clear()
	_velocity_weights.clear()
	_dye_slots.clear()
	_dye_paints.clear()
	_dye_weights.clear()


func _should_read_back() -> bool:
	if not config.readback_enabled:
		return false
	_frames_to_readback -= 1
	if _frames_to_readback > 0:
		return false
	_frames_to_readback = maxi(config.readback_interval, 1)
	return true


func _on_readback(bytes: PackedByteArray) -> void:
	var size := config.readback_size()
	if bytes.size() < size.x * size.y * 8:
		return
	_field.update_from_image(
		Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAH, bytes)
	)
	field_updated.emit(_field)


func _push_splat(
	slots: Array[Vector4],
	shapes: Array[Vector4],
	weights: Array[float],
	slot: Vector4,
	shape: Vector4,
	weight: float
) -> void:
	if slots.size() < MAX_SPLATS:
		slots.append(slot)
		shapes.append(shape)
		weights.append(weight)
		return
	# Full. Keep the strongest impulses rather than whichever arrived first, so
	# a crowd of idle drifters cannot starve out a real disturbance.
	var weakest := 0
	for i in weights.size():
		if weights[i] < weights[weakest]:
			weakest = i
	if weight <= weights[weakest]:
		return
	slots[weakest] = slot
	shapes[weakest] = shape
	weights[weakest] = weight


## Two vec4s per slot, laid out to match the Splat struct the passes read.
func _pack_splats(slots: Array[Vector4], shapes: Array[Vector4]) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(MAX_SPLATS * FluidGPU.SPLAT_BYTES)
	for i in slots.size():
		var at := i * FluidGPU.SPLAT_BYTES
		bytes.encode_float(at, slots[i].x)
		bytes.encode_float(at + 4, slots[i].y)
		bytes.encode_float(at + 8, slots[i].z)
		bytes.encode_float(at + 12, slots[i].w)
		bytes.encode_float(at + 16, shapes[i].x)
		bytes.encode_float(at + 20, shapes[i].y)
		bytes.encode_float(at + 24, shapes[i].z)
		bytes.encode_float(at + 28, shapes[i].w)
	return bytes


func _radius_to_uv(radius_pixels: float) -> float:
	return radius_pixels / maxf(config.world_size.y, 1.0)

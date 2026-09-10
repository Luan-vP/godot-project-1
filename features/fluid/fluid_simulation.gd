class_name FluidSimulation
extends Node2D
## A grid-based (Eulerian) fluid tank the game world floats in.
##
## Each frame the solve runs as a chain of full-screen shader passes:
## [codeblock lang=text]
## velocity -> divergence -> pressure x N -> project -> readback -> dye
## [/codeblock]
## advect the field along itself and add impulses, measure how much it is
## compressing, relax that away, subtract the correction, then carry the
## pigment on the result.
##
## The chain is built by [b]nesting[/b] each pass's [SubViewport] inside the
## next one. Godot renders a child viewport before its parent, so nesting is
## what makes the whole solve land in one frame and in order; siblings would
## give no such guarantee and the tank would advance one stage per frame. The
## single deliberate exception is the loop back from [code]project[/code] into
## [code]velocity[/code], which reads last frame's result — that is the time
## step.
##
## Gameplay never touches the GPU field. A small grid is copied back into a
## [FluidField] every few frames and everything else samples that; see
## [method sample_velocity]. Bodies push back through
## [method add_velocity_impulse], which is what makes the tank feel inhabited
## rather than decorative.

## Emitted after the CPU mirror is refreshed from the GPU.
signal field_updated(field: FluidField)

## Concurrent stirrers the shaders can take. Past this the weakest impulses are
## dropped, so a busy frame degrades by losing the faintest wakes.
const MAX_SPLATS := 16

## Nodes register here so [FluidBody] can find its tank without wiring.
const GROUP_NAME := "fluid_simulation"

const VELOCITY_SHADER := preload("res://features/fluid/shaders/velocity.gdshader")
const DIVERGENCE_SHADER := preload("res://features/fluid/shaders/divergence.gdshader")
const PRESSURE_SHADER := preload("res://features/fluid/shaders/pressure.gdshader")
const PROJECT_SHADER := preload("res://features/fluid/shaders/project.gdshader")
const DYE_SHADER := preload("res://features/fluid/shaders/dye.gdshader")
const COPY_SHADER := preload("res://features/fluid/shaders/copy.gdshader")

## Pressure relaxation needs at least two targets to ping-pong between.
const MIN_PRESSURE_PASSES := 2

## Frames the chain is forced to write zeros for when emptying. One is enough:
## every pass blanks in the same frame, so the next frame reads zeros from all
## of its sources.
const BLANK_FRAMES := 1

## How the tank moves. A default is created if none is assigned.
@export var config: FluidConfig

## Runs the solve. Turn it off to freeze the tank without tearing it down.
@export var simulating: bool = true:
	set = set_simulating

var _field := FluidField.new()
var _velocity: FluidPass
var _divergence: FluidPass
var _pressure: Array[FluidPass] = []
var _project: FluidPass
var _readback: FluidPass
var _dye_advect: FluidPass
var _dye_store: FluidPass
var _chain: Array[FluidPass] = []
var _velocity_slots: Array[Vector4] = []
var _velocity_shapes: Array[Vector4] = []
var _velocity_weights: Array[float] = []
var _dye_slots: Array[Vector4] = []
var _dye_paints: Array[Vector4] = []
var _dye_weights: Array[float] = []
var _elapsed: float = 0.0
var _current_bias: Vector2 = Vector2.ZERO
var _pending_nudge: Vector2 = Vector2.ZERO
var _blank_frames: int = 0
var _blanking: bool = false
var _frames_to_readback: int = 1
var _built: bool = false


func _ready() -> void:
	add_to_group(GROUP_NAME)
	if config == null:
		config = FluidConfig.new()
	_field.configure_world(get_world_rect(), config.cell_size())
	_field.resize(config.readback_resolution, config.readback_resolution)
	_build()
	set_simulating(simulating)


func _process(delta: float) -> void:
	if not _built or not simulating:
		return
	_elapsed += delta
	# Cheap, and it means moving the tank node is not a silent footgun.
	_field.configure_world(get_world_rect(), config.cell_size())
	_update_blanking()
	var step := minf(delta, config.max_time_step)
	_velocity.set_param("time_step", step)
	_velocity.set_param("elapsed", _elapsed)
	_dye_advect.set_param("time_step", step)
	# Retention has to be recomputed per step: the solve runs once per rendered
	# frame with a variable delta, so a fixed multiplier would decay far faster
	# at 144 fps than at 30.
	_velocity.set_param(
		"dissipation", FluidConfig.retention_over(config.velocity_dissipation, step)
	)
	_dye_advect.set_param("dissipation", FluidConfig.retention_over(config.dye_dissipation, step))
	# Pixels-to-cells is a ratio, so the velocity conversion is also the right
	# one for an acceleration.
	_velocity.set_param("ambient_drift", _field.world_to_cell_velocity(_current_bias))
	_flush_splats()
	_read_back()


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
	return null if not _built else _dye_store.texture()


## Divergence-free velocity field, in cells/second in the red and green
## channels.
func get_velocity_texture() -> Texture2D:
	return null if not _built else _project.texture()


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
	if not _built or duration <= 0.0:
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
	if not _built or amount <= 0.0 or duration <= 0.0:
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


## Blank the tank: velocity, pressure and pigment all go back to rest.
##
## Clearing the render targets does not do this. Every pass repaints its target
## in full from its source in the same frame, and each source is cleared later
## in the nested chain, so the old field is simply redrawn. The chain has to be
## told to write zeros instead.
func reset() -> void:
	if not _built:
		return
	_blank_frames = BLANK_FRAMES
	_field.clear()
	_elapsed = 0.0
	_current_bias = Vector2.ZERO
	_pending_nudge = Vector2.ZERO


func set_simulating(value: bool) -> void:
	simulating = value
	if not _built:
		return
	var mode := SubViewport.UPDATE_ALWAYS if simulating else SubViewport.UPDATE_DISABLED
	for step in _chain:
		step.viewport.render_target_update_mode = mode


func _update_blanking() -> void:
	var wanted := _blank_frames > 0
	if wanted != _blanking:
		_blanking = wanted
		for step in _chain:
			step.set_param("blank", _blanking)
	if _blank_frames > 0:
		_blank_frames -= 1


func _build() -> void:
	var resolution := config.simulation_size()
	_velocity = FluidPass.new("Velocity", VELOCITY_SHADER, resolution)
	_divergence = FluidPass.new("Divergence", DIVERGENCE_SHADER, resolution)
	_pressure.clear()
	var iterations := maxi(config.pressure_iterations, MIN_PRESSURE_PASSES)
	for i in iterations:
		_pressure.append(FluidPass.new("Pressure%d" % i, PRESSURE_SHADER, resolution))
	_project = FluidPass.new("Project", PROJECT_SHADER, resolution)
	_readback = FluidPass.new("Readback", COPY_SHADER, config.readback_size())
	_dye_advect = FluidPass.new("DyeAdvect", DYE_SHADER, resolution)
	_dye_store = FluidPass.new("DyeStore", COPY_SHADER, resolution)

	_chain.clear()
	_chain.append(_velocity)
	_chain.append(_divergence)
	_chain.append_array(_pressure)
	_chain.append(_project)
	_chain.append(_readback)
	_chain.append(_dye_advect)
	_chain.append(_dye_store)

	# Deepest first: the last pass hangs off this node and every earlier pass
	# nests one level further in, so Godot renders them in solve order.
	add_child(_chain[-1].viewport)
	for i in range(_chain.size() - 2, -1, -1):
		_chain[i + 1].viewport.add_child(_chain[i].viewport)

	_built = true
	_wire()
	# Targets are never cleared during the solve, so their first-frame contents
	# would otherwise be whatever the driver left there — and a single NaN in a
	# field that feeds itself never washes out. Blanking writes real zeros.
	reset()


func _wire() -> void:
	var texel := Vector2.ONE / Vector2(config.simulation_size())
	var aspect := Vector2(config.world_size.x / maxf(config.world_size.y, 1.0), 1.0)

	# Advection reads last frame's projected field: that loop is the time step.
	_velocity.set_param("velocity_tex", _project.texture())
	_velocity.set_param("texel_size", texel)
	_velocity.set_param("vorticity_strength", config.vorticity)
	_velocity.set_param("ambient_strength", config.ambient_current)
	_velocity.set_param("ambient_scale", config.ambient_scale)
	_velocity.set_param("splat_aspect", aspect)

	_divergence.set_param("velocity_tex", _velocity.texture())
	_divergence.set_param("texel_size", texel)

	# Each relaxation reads the one before it, and the first reads the last —
	# so pressure keeps converging across frames instead of restarting at zero.
	for i in _pressure.size():
		var previous: FluidPass = _pressure[(i + _pressure.size() - 1) % _pressure.size()]
		_pressure[i].set_param("pressure_tex", previous.texture())
		_pressure[i].set_param("divergence_tex", _divergence.texture())
		_pressure[i].set_param("texel_size", texel)

	_project.set_param("velocity_tex", _velocity.texture())
	_project.set_param("pressure_tex", _pressure[-1].texture())
	_project.set_param("texel_size", texel)

	_readback.set_param("source_tex", _project.texture())

	_dye_advect.set_param("velocity_tex", _project.texture())
	_dye_advect.set_param("dye_tex", _dye_store.texture())
	_dye_advect.set_param("texel_size", texel)
	_dye_advect.set_param("splat_aspect", aspect)

	_dye_store.set_param("source_tex", _dye_advect.texture())


func _flush_splats() -> void:
	# The nudge is a one-frame impulse, so it is uploaded and cleared alongside
	# the splats rather than persisting like the drift.
	_velocity.set_param("uniform_impulse", _field.world_to_cell_velocity(_pending_nudge))
	_pending_nudge = Vector2.ZERO
	_velocity.set_param("splats", _padded(_velocity_slots))
	_velocity.set_param("splat_shape", _padded(_velocity_shapes))
	_dye_advect.set_param("splats", _padded(_dye_slots))
	_dye_advect.set_param("splat_paint", _padded(_dye_paints))
	_velocity_slots.clear()
	_velocity_shapes.clear()
	_velocity_weights.clear()
	_dye_slots.clear()
	_dye_paints.clear()
	_dye_weights.clear()


func _read_back() -> void:
	if not config.readback_enabled:
		return
	_frames_to_readback -= 1
	if _frames_to_readback > 0:
		return
	_frames_to_readback = maxi(config.readback_interval, 1)
	var texture := _readback.texture()
	if texture == null:
		return
	# Synchronous, and the reason the readback grid is kept small and the
	# interval configurable: this is the one place the CPU waits on the GPU.
	_field.update_from_image(texture.get_image())
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


func _padded(slots: Array[Vector4]) -> PackedVector4Array:
	var packed := PackedVector4Array(slots)
	packed.resize(MAX_SPLATS)
	return packed


func _radius_to_uv(radius_pixels: float) -> float:
	return radius_pixels / maxf(config.world_size.y, 1.0)

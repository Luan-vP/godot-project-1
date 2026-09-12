class_name FluidGPU
extends RefCounted
## The fluid solve, as compute shaders on the rendering device.
##
## Each frame the whole step is dispatched in one compute list:
## [codeblock lang=text]
## velocity -> divergence -> pressure x N -> project -> dye -> downsample
## [/codeblock]
## advect each field along itself and add this frame's impulses, measure how
## much the result is compressing, relax that away, subtract the correction,
## carry the pigment on what comes out, then resample a small grid for the CPU.
##
## Every field is a pair of textures that take turns being read and written,
## which is the whole reason this is compute and not a chain of viewports:
## a pass must read last frame's field while writing this frame's, and that
## cross-frame read is something we can only rely on when we own the targets.
## [FluidSimulation] holds the state and the API; this holds the RIDs.
##
## All device work happens on the render thread via
## [method RenderingServer.call_on_render_thread], so nothing here may be
## called from a thread that expects an answer immediately — the readback
## comes back through [signal readback_ready] instead.

## Carries a [param bytes] blob of the downsampled velocity grid, RGBA16F, on
## the main thread.
signal readback_ready(bytes: PackedByteArray)

## Concurrent stirrers a single dispatch can take.
const MAX_SPLATS := 16

## Two vec4s per splat.
const SPLAT_BYTES := 32

## The push constant block shared by every pass; see fluid_params.glslinc.
const PARAM_BYTES := 80

## Matches local_size_x/y in the shaders.
const GROUP_SIZE := 8

## Ceiling on pigment density, so a body parked in one spot cannot drive the
## field to infinity.
const MAX_DYE_DENSITY := 6.0

## Pressure relaxation needs at least two targets to ping-pong between.
const MIN_PRESSURE_PASSES := 2

const VELOCITY_SHADER := preload("res://features/fluid/shaders/compute/velocity.glsl")
const DIVERGENCE_SHADER := preload("res://features/fluid/shaders/compute/divergence.glsl")
const PRESSURE_SHADER := preload("res://features/fluid/shaders/compute/pressure.glsl")
const PROJECT_SHADER := preload("res://features/fluid/shaders/compute/project.glsl")
const DYE_SHADER := preload("res://features/fluid/shaders/compute/dye.glsl")
const DOWNSAMPLE_SHADER := preload("res://features/fluid/shaders/compute/downsample.glsl")

var _rd: RenderingDevice
var _size := Vector2i.ZERO
var _readback_size := Vector2i.ZERO
var _iterations: int = MIN_PRESSURE_PASSES
var _groups := Vector2i.ZERO
var _readback_groups := Vector2i.ZERO

# [0] is the projected field everything else reads; [1] is the scratch the
# advection writes into. Fixed roles, so the texture handed to the renderer
# never changes identity.
var _velocity: Array[RID] = []
var _pressure: Array[RID] = []
var _dye: Array[RID] = []
var _divergence := RID()
var _obstacle := RID()
var _obstacle_walls := PackedByteArray()
var _readback := RID()
var _sampler := RID()
var _velocity_splat_buffer := RID()
var _dye_splat_buffer := RID()
var _shaders: Array[RID] = []
var _pipelines := {}
var _pass_shaders := {}
var _sets := {}
var _velocity_texture := Texture2DRD.new()
var _dye_texture := Texture2DRD.new()
var _built: bool = false


## Whether this build of the engine exposes a device to run on. False under
## [code]--headless[/code], where there is no renderer at all.
static func is_available() -> bool:
	return RenderingServer.get_rendering_device() != null


func is_built() -> bool:
	return _built


## Pigment field, premultiplied. Empty until the device has finished building.
func dye_texture() -> Texture2DRD:
	return _dye_texture if _built else null


## Divergence-free velocity field, in cells/second in red and green.
func velocity_texture() -> Texture2DRD:
	return _velocity_texture if _built else null


## Allocate everything. Returns immediately; [method is_built] flips once the
## render thread has caught up.
func build(config: FluidConfig) -> void:
	if _built or not is_available():
		return
	_size = config.simulation_size()
	_readback_size = config.readback_size()
	_iterations = maxi(config.pressure_iterations, MIN_PRESSURE_PASSES)
	_groups = _group_count(_size)
	_readback_groups = _group_count(_readback_size)
	RenderingServer.call_on_render_thread(_build_resources)


## Hand the render thread one frame of work. See [FluidSimulation] for what the
## keys mean; they are packed straight into the push constant block.
func submit(frame: Dictionary) -> void:
	if not _built:
		return
	RenderingServer.call_on_render_thread(_run_step.bind(frame))


## Release every RID. Safe to call more than once.
func destroy() -> void:
	if _rd == null:
		return
	_built = false
	_velocity_texture.texture_rd_rid = RID()
	_dye_texture.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_free_resources)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		destroy()


func _group_count(size: Vector2i) -> Vector2i:
	return Vector2i(
		int(ceilf(float(size.x) / float(GROUP_SIZE))), int(ceilf(float(size.y) / float(GROUP_SIZE)))
	)


# ---------------------------------------------------------------------------
# Everything below runs on the render thread.
# ---------------------------------------------------------------------------


func _build_resources() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return

	var state := RDSamplerState.new()
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _rd.sampler_create(state)

	var rgba := RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	var scalar := RenderingDevice.DATA_FORMAT_R16_SFLOAT
	_velocity = [_make_texture(_size, rgba), _make_texture(_size, rgba)]
	_dye = [_make_texture(_size, rgba), _make_texture(_size, rgba)]
	_pressure = [_make_texture(_size, scalar), _make_texture(_size, scalar)]
	_divergence = _make_texture(_size, scalar)
	_obstacle = _make_texture(_size, scalar)
	_readback = _make_texture(_readback_size, rgba)

	# The only obstacle today is the tank itself. Baked once and re-stamped
	# after every clear, since nothing else writes into the mask yet -- a body
	# stamping itself in is deliberate follow-up work.
	_obstacle_walls = _make_wall_mask(_size)
	_rd.texture_update(_obstacle, 0, _obstacle_walls)

	_velocity_splat_buffer = _rd.storage_buffer_create(MAX_SPLATS * SPLAT_BYTES)
	_dye_splat_buffer = _rd.storage_buffer_create(MAX_SPLATS * SPLAT_BYTES)

	_make_pass("velocity", VELOCITY_SHADER)
	_make_pass("divergence", DIVERGENCE_SHADER)
	_make_pass("pressure", PRESSURE_SHADER)
	_make_pass("project", PROJECT_SHADER)
	_make_pass("dye", DYE_SHADER)
	_make_pass("downsample", DOWNSAMPLE_SHADER)

	# Advection reads the projected field and writes the scratch; projection
	# reads the scratch back and writes the projected field. Fixed roles.
	_sets["velocity"] = _make_set(
		"velocity",
		[
			_sampler_uniform(0, _velocity[0]),
			_image_uniform(1, _velocity[1]),
			_buffer_uniform(2, _velocity_splat_buffer),
		]
	)
	_sets["divergence"] = _make_set(
		"divergence",
		[
			_sampler_uniform(0, _velocity[1]),
			_image_uniform(1, _divergence),
			_sampler_uniform(2, _obstacle),
		]
	)
	# One set per parity of the relaxation, so nothing is allocated per frame.
	_sets["pressure"] = [
		_make_set(
			"pressure",
			[
				_sampler_uniform(0, _pressure[0]),
				_image_uniform(1, _pressure[1]),
				_sampler_uniform(2, _divergence),
			]
		),
		_make_set(
			"pressure",
			[
				_sampler_uniform(0, _pressure[1]),
				_image_uniform(1, _pressure[0]),
				_sampler_uniform(2, _divergence),
			]
		),
	]
	_sets["project"] = _make_set(
		"project",
		[
			_sampler_uniform(0, _velocity[1]),
			_image_uniform(1, _velocity[0]),
			_sampler_uniform(2, _pressure[_iterations % 2]),
			_sampler_uniform(3, _obstacle),
		]
	)
	_sets["dye"] = _make_set(
		"dye",
		[
			_sampler_uniform(0, _dye[0]),
			_image_uniform(1, _dye[1]),
			_sampler_uniform(2, _velocity[0]),
			_buffer_uniform(3, _dye_splat_buffer),
		]
	)
	_sets["downsample"] = _make_set(
		"downsample",
		[
			_sampler_uniform(0, _velocity[0]),
			_image_uniform(1, _readback),
		]
	)

	_publish.call_deferred()


func _publish() -> void:
	_velocity_texture.texture_rd_rid = _velocity[0]
	_dye_texture.texture_rd_rid = _dye[0]
	_built = true


func _run_step(frame: Dictionary) -> void:
	if _rd == null:
		return
	if frame.get("clear", false):
		for texture in _velocity + _dye + _pressure + [_divergence, _obstacle, _readback]:
			_rd.texture_clear(texture, Color(0.0, 0.0, 0.0, 0.0), 0, 1, 0, 1)
		# The clear wipes the mask along with everything else; the walls are the
		# only thing in it, so they are the only thing that needs putting back.
		_rd.texture_update(_obstacle, 0, _obstacle_walls)

	_rd.buffer_update(_velocity_splat_buffer, 0, MAX_SPLATS * SPLAT_BYTES, frame["velocity_splats"])
	_rd.buffer_update(_dye_splat_buffer, 0, MAX_SPLATS * SPLAT_BYTES, frame["dye_splats"])

	var solve := _pack_params(
		frame, _size, frame["velocity_dissipation"], frame["velocity_splat_count"]
	)
	var pigment := _pack_params(frame, _size, frame["dye_dissipation"], frame["dye_splat_count"])
	var resample := _pack_params(frame, _readback_size, 1.0, 0)

	var list := _rd.compute_list_begin()
	_dispatch(list, "velocity", _sets["velocity"], solve, _groups)
	_dispatch(list, "divergence", _sets["divergence"], solve, _groups)
	for i in _iterations:
		_dispatch(list, "pressure", _sets["pressure"][i % 2], solve, _groups)
	_dispatch(list, "project", _sets["project"], solve, _groups)
	_dispatch(list, "dye", _sets["dye"], pigment, _groups)
	_dispatch(list, "downsample", _sets["downsample"], resample, _readback_groups)
	_rd.compute_list_end()

	# The dye pass cannot read and write one texture, so it writes the scratch
	# and the result is copied home. Keeping the field in a fixed texture is
	# what lets the renderer hold one binding for the life of the tank.
	_rd.texture_copy(
		_dye[1], _dye[0], Vector3.ZERO, Vector3.ZERO, Vector3(_size.x, _size.y, 1), 0, 0, 0, 0
	)

	if frame.get("readback", false):
		# The one place the CPU waits on the GPU, which is why it runs over the
		# small grid and only every few frames.
		_deliver_readback.call_deferred(_rd.texture_get_data(_readback, 0))


func _deliver_readback(bytes: PackedByteArray) -> void:
	readback_ready.emit(bytes)


func _free_resources() -> void:
	if _rd == null:
		return
	for value in _sets.values():
		if value is Array:
			for rid in value:
				_free(rid)
		else:
			_free(value)
	for pipeline in _pipelines.values():
		_free(pipeline)
	for shader in _shaders:
		_free(shader)
	for texture in _velocity + _dye + _pressure + [_divergence, _obstacle, _readback]:
		_free(texture)
	_free(_velocity_splat_buffer)
	_free(_dye_splat_buffer)
	_free(_sampler)
	_sets.clear()
	_pass_shaders.clear()
	_pipelines.clear()
	_shaders.clear()
	_velocity.clear()
	_dye.clear()
	_pressure.clear()
	_rd = null


func _free(rid: RID) -> void:
	if rid.is_valid():
		_rd.free_rid(rid)


func _dispatch(
	list: int, pass_name: String, set_rid: RID, params: PackedByteArray, groups: Vector2i
) -> void:
	_rd.compute_list_bind_compute_pipeline(list, _pipelines[pass_name])
	_rd.compute_list_bind_uniform_set(list, set_rid, 0)
	_rd.compute_list_set_push_constant(list, params, params.size())
	_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
	# Every pass reads what the one before it wrote.
	_rd.compute_list_add_barrier(list)


func _make_pass(pass_name: String, file: RDShaderFile) -> void:
	var shader := _rd.shader_create_from_spirv(file.get_spirv())
	_shaders.append(shader)
	_pipelines[pass_name] = _rd.compute_pipeline_create(shader)
	_pass_shaders[pass_name] = shader


func _make_set(pass_name: String, uniforms: Array) -> RID:
	return _rd.uniform_set_create(uniforms, _pass_shaders[pass_name], 0)


func _make_texture(size: Vector2i, format: int) -> RID:
	var format_info := RDTextureFormat.new()
	format_info.width = size.x
	format_info.height = size.y
	format_info.format = format
	format_info.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	var texture := _rd.texture_create(format_info, RDTextureView.new(), [])
	_rd.texture_clear(texture, Color(0.0, 0.0, 0.0, 0.0), 0, 1, 0, 1)
	return texture


## A single-channel R16F mask, 1.0 where a cell is solid and 0.0 where it is
## fluid. The tank walls are the outermost ring of cells -- one boundary
## concept for [code]divergence.glsl[/code] and [code]project.glsl[/code] to
## read instead of each hardcoding "the edge of the texture".
func _make_wall_mask(size: Vector2i) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y * 2)
	for y in size.y:
		for x in size.x:
			var wall := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			bytes.encode_half((y * size.x + x) * 2, 1.0 if wall else 0.0)
	return bytes


func _sampler_uniform(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(_sampler)
	uniform.add_id(texture)
	return uniform


func _image_uniform(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform


func _buffer_uniform(binding: int, buffer: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform


## Lay the frame out to match the push constant block in fluid_params.glslinc.
func _pack_params(
	frame: Dictionary, size: Vector2i, dissipation: float, splat_count: int
) -> PackedByteArray:
	var texel: Vector2 = frame["texel_size"]
	var aspect: Vector2 = frame["splat_aspect"]
	var drift: Vector2 = frame["ambient_drift"]
	var impulse: Vector2 = frame["uniform_impulse"]
	var bytes := PackedByteArray()
	bytes.resize(PARAM_BYTES)
	bytes.encode_float(0, texel.x)
	bytes.encode_float(4, texel.y)
	bytes.encode_float(8, aspect.x)
	bytes.encode_float(12, aspect.y)
	bytes.encode_float(16, drift.x)
	bytes.encode_float(20, drift.y)
	bytes.encode_float(24, impulse.x)
	bytes.encode_float(28, impulse.y)
	bytes.encode_float(32, frame["time_step"])
	bytes.encode_float(36, dissipation)
	bytes.encode_float(40, frame["vorticity"])
	bytes.encode_float(44, frame["ambient_strength"])
	bytes.encode_float(48, frame["ambient_scale"])
	bytes.encode_float(52, frame["elapsed"])
	bytes.encode_float(56, MAX_DYE_DENSITY)
	bytes.encode_s32(60, splat_count)
	bytes.encode_s32(64, size.x)
	bytes.encode_s32(68, size.y)
	return bytes

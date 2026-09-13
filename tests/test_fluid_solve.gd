extends GutTest
## Regression test that a field actually survives across frames on the real
## compute solve.
##
## The old nested-SubViewport chain rendered every pass with no errors while
## carrying zero state forward: a velocity impulse collapsed to zero within
## four frames and pigment never accumulated past one dab. The only visible
## motion was the ambient swell, a closed-form function of elapsed that needs
## no feedback at all, so nothing in the suite noticed the solve underneath
## was dead. This drives [FluidGPU] for real via [FluidSimulation] in the
## scene tree and checks that both fields are still there many frames later.

const FRAME_TIMEOUT := 5.0
const STEP_FRAMES := 30
const RETENTION_FLOOR := 0.3

const IMPULSE_POINT := Vector2(100.0, 100.0)
const IMPULSE_ACCEL := Vector2(1500.0, 0.0)
const IMPULSE_RADIUS := 40.0
const IMPULSE_DURATION := 1.0

const PAINT_POINT := Vector2(60.0, 140.0)
const PAINT_COLOR := Color(1.0, 0.3, 0.2)
const PAINT_RATE := 3.2
const PAINT_RADIUS := 60.0
const PAINT_DURATION := 1.0 / 60.0
const PAINT_REPEATS := 5

const WALL_IMPULSE_ACCEL := Vector2(-1500.0, 900.0)
const WALL_IMPULSE_RADIUS := 12.0
const WALL_SLIDE_FLOOR := 5.0

var _simulation: FluidSimulation
var _dye_bytes := PackedByteArray()
var _velocity_bytes := PackedByteArray()


func before_each() -> void:
	if not FluidGPU.is_available():
		return
	var config := FluidConfig.new()
	config.world_size = Vector2(200.0, 200.0)
	config.simulation_resolution = 32
	config.readback_resolution = 16
	config.pressure_iterations = 2
	config.velocity_dissipation = 1.0
	config.dye_dissipation = 1.0
	config.ambient_current = 0.0
	config.vorticity = 0.0
	config.readback_enabled = true
	config.readback_interval = 1
	_simulation = FluidSimulation.new()
	_simulation.config = config
	add_child_autofree(_simulation)


func test_a_velocity_impulse_survives_thirty_frames() -> void:
	if not FluidGPU.is_available():
		pending("No rendering device available; the GPU solve cannot run headless here.")
		return

	_simulation.add_velocity_impulse(IMPULSE_POINT, IMPULSE_ACCEL, IMPULSE_RADIUS, IMPULSE_DURATION)
	await _step_frames(1)
	var peak := _simulation.get_field().sample_world(IMPULSE_POINT).length()
	assert_gt(peak, 0.0, "The impulse should have produced velocity")

	await _step_frames(STEP_FRAMES - 1)
	var after := _simulation.get_field().sample_world(IMPULSE_POINT).length()
	var message := "Retention after %d frames: %.1f of peak %.1f" % [STEP_FRAMES, after, peak]
	assert_gt(after, peak * RETENTION_FLOOR, message)


func test_paint_accumulates_instead_of_plateauing() -> void:
	if not FluidGPU.is_available():
		pending("No rendering device available; the GPU solve cannot run headless here.")
		return

	_simulation.add_paint(PAINT_POINT, PAINT_COLOR, PAINT_RATE, PAINT_RADIUS, PAINT_DURATION)
	await _step_frames(1)
	var after_one := await _dye_density_at(PAINT_POINT)
	assert_gt(after_one, 0.0, "A single dab should have deposited some pigment")

	for i in PAINT_REPEATS:
		_simulation.add_paint(PAINT_POINT, PAINT_COLOR, PAINT_RATE, PAINT_RADIUS, PAINT_DURATION)
		await _step_frames(1)
	var after_several := await _dye_density_at(PAINT_POINT)

	assert_gt(
		after_several,
		after_one * 1.5,
		"Repeated dabs should accumulate rather than plateau at one frame's deposit"
	)


## The only masked cells today are the tank walls, so this is also the
## regression test for the obstacle mask itself: a wall cell must come out of
## the solve at rest, and the fluid cell right beside it must keep moving
## along the wall rather than also being killed.
func test_masked_wall_cells_zero_velocity_and_neighbours_slide() -> void:
	if not FluidGPU.is_available():
		pending("No rendering device available; the GPU solve cannot run headless here.")
		return

	var size := _simulation.config.simulation_size()
	var row := size.y / 2
	var wall_point := _cell_center_world(Vector2i(0, row), size)

	_simulation.add_velocity_impulse(
		wall_point, WALL_IMPULSE_ACCEL, WALL_IMPULSE_RADIUS, IMPULSE_DURATION
	)
	await _step_frames(1)

	var wall_velocity := await _velocity_cell(Vector2i(0, row))
	assert_eq(
		wall_velocity,
		Vector2.ZERO,
		(
			"Velocity seeded in a masked wall cell should be zero after projection, got %s"
			% wall_velocity
		)
	)

	var beside_velocity := await _velocity_cell(Vector2i(1, row))
	assert_gt(
		absf(beside_velocity.y),
		WALL_SLIDE_FLOOR,
		"Fluid beside the wall should keep sliding, not also be killed, got %s" % beside_velocity
	)


## Steps [param count] real engine frames, each confirmed by a fresh readback
## landing in the CPU mirror. Frame-counting has to go through the readback
## signal rather than a fixed wait: the solve runs on the render thread and
## the mirror only updates once that work reports back, deferred.
func _step_frames(count: int) -> void:
	for i in count:
		var arrived: bool = await wait_for_signal(_simulation.field_updated, FRAME_TIMEOUT)
		assert_true(arrived, "Expected a readback within %s seconds" % FRAME_TIMEOUT)


## Pigment has no CPU mirror — only velocity is copied back for gameplay — so
## this pulls the dye texture straight off the device the same way
## [FluidGPU] does its own readback: queued to the render thread, delivered
## back deferred.
func _dye_density_at(world_position: Vector2) -> float:
	_dye_bytes = PackedByteArray()
	var texture: Texture2DRD = _simulation.get_dye_texture()
	var rd := RenderingServer.get_rendering_device()
	var rid := texture.texture_rd_rid
	RenderingServer.call_on_render_thread(
		func(): _receive_dye_bytes.call_deferred(rd.texture_get_data(rid, 0))
	)
	var arrived: bool = await wait_until(func(): return not _dye_bytes.is_empty(), FRAME_TIMEOUT)
	assert_true(arrived, "Expected the dye texture readback to arrive")

	var size: Vector2i = _simulation.config.simulation_size()
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAH, _dye_bytes)
	var uv := _simulation.get_field().world_to_uv(world_position)
	var x := clampi(int(uv.x * size.x), 0, size.x - 1)
	var y := clampi(int(uv.y * size.y), 0, size.y - 1)
	return image.get_pixel(x, y).a


func _receive_dye_bytes(bytes: PackedByteArray) -> void:
	_dye_bytes = bytes


## World position of the centre of simulation cell [param coord], for landing
## a splat squarely inside a single cell instead of straddling several.
func _cell_center_world(coord: Vector2i, size: Vector2i) -> Vector2:
	var uv := (Vector2(coord) + Vector2(0.5, 0.5)) / Vector2(size)
	return _simulation.get_field().uv_to_world(uv)


## Raw velocity at a simulation cell, straight off the device the same way
## [method _dye_density_at] reads the dye texture -- the CPU mirror is a
## downsampled, bilinearly-filtered readback and cannot tell a wall cell from
## its neighbour.
func _velocity_cell(coord: Vector2i) -> Vector2:
	_velocity_bytes = PackedByteArray()
	var texture: Texture2DRD = _simulation.get_velocity_texture()
	var rd := RenderingServer.get_rendering_device()
	var rid := texture.texture_rd_rid
	RenderingServer.call_on_render_thread(
		func(): _receive_velocity_bytes.call_deferred(rd.texture_get_data(rid, 0))
	)
	var arrived: bool = await wait_until(
		func(): return not _velocity_bytes.is_empty(), FRAME_TIMEOUT
	)
	assert_true(arrived, "Expected the velocity texture readback to arrive")

	var size: Vector2i = _simulation.config.simulation_size()
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAH, _velocity_bytes)
	var pixel := image.get_pixel(coord.x, coord.y)
	return Vector2(pixel.r, pixel.g)


func _receive_velocity_bytes(bytes: PackedByteArray) -> void:
	_velocity_bytes = bytes

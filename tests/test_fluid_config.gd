extends GutTest
## Covers the unit conversions [FluidConfig] hands to the rest of the system.

const EPSILON := 0.0001

var _config: FluidConfig


func before_each() -> void:
	_config = FluidConfig.new()


func test_grid_sizes_are_square() -> void:
	_config.simulation_resolution = 128
	_config.readback_resolution = 32
	assert_eq(_config.simulation_size(), Vector2i(128, 128), "Simulation grid")
	assert_eq(_config.readback_size(), Vector2i(32, 32), "Readback grid")


func test_cell_size_divides_the_world_by_the_grid() -> void:
	_config.simulation_resolution = 64
	_config.world_size = Vector2(1280.0, 640.0)
	var cell := _config.cell_size()
	assert_almost_eq(cell.x, 20.0, EPSILON, "Cell width")
	assert_almost_eq(cell.y, 10.0, EPSILON, "Cell height")


func test_defaults_are_usable() -> void:
	assert_gt(_config.max_time_step, 0.0, "A zero step would freeze the tank")
	assert_gt(_config.pressure_iterations, 0, "The pressure solve needs iterations")
	assert_gt(_config.readback_interval, 0, "A zero interval would never read back")
	assert_gt(_config.world_size.x, 0.0, "The tank needs width")
	assert_gt(_config.world_size.y, 0.0, "The tank needs height")

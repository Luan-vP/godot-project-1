extends GutTest
## Weight, end to end: the tank owns a down, a body with weight falls along it,
## and tilting the device is what moves it.

const EPSILON := 0.001


func _tank() -> FluidSimulation:
	var simulation := FluidSimulation.new()
	add_child_autofree(simulation)
	return simulation


func test_a_tank_falls_down_the_screen_until_told_otherwise() -> void:
	assert_eq(_tank().get_gravity(), Vector2.DOWN, "A tank knows which way is down")


func test_a_tank_keeps_its_down_when_handed_nothing() -> void:
	var simulation := _tank()
	simulation.set_gravity(Vector2(1.0, 1.0))
	simulation.set_gravity(Vector2.ZERO)
	assert_almost_eq(
		simulation.get_gravity().angle(),
		Vector2(1.0, 1.0).normalized().angle(),
		EPSILON,
		"A zero direction is not a direction, so the last one stands"
	)


func test_down_is_a_direction_however_long_the_vector_handed_over() -> void:
	var simulation := _tank()
	simulation.set_gravity(Vector2(0.0, 400.0))
	assert_almost_eq(simulation.get_gravity().length(), 1.0, EPSILON, "Normalised")


## The body asks the tank rather than assuming: this is what makes weight work
## for anything floating in the fluid, not just the eyes it was added for.
func test_a_body_with_weight_sinks_along_the_tanks_down() -> void:
	var simulation := _tank()
	simulation.set_gravity(Vector2(1.0, 1.0))
	var body := FluidBody.new()
	body.weight = 100.0
	body.drag = 0.0
	body.wake_strength = 0.0
	body.contained = false
	simulation.add_child(body)
	body._physics_process(0.1)
	assert_almost_eq(
		body.velocity.angle(),
		Vector2(1.0, 1.0).normalized().angle(),
		EPSILON,
		"Falls towards the tank's low corner"
	)
	assert_almost_eq(body.velocity.length(), 10.0, EPSILON, "At its own weight")


func test_a_weightless_body_is_carried_and_nothing_more() -> void:
	var simulation := _tank()
	simulation.set_gravity(Vector2(1.0, 1.0))
	var body := FluidBody.new()
	body.drag = 0.0
	body.wake_strength = 0.0
	body.contained = false
	simulation.add_child(body)
	body._physics_process(0.1)
	assert_eq(body.velocity, Vector2.ZERO, "No weight, no fall")


func test_tilting_the_device_moves_the_tanks_down() -> void:
	var simulation := _tank()
	var driver := FluidMotionDriver.new()
	driver.tilt_gravity_authority = 1.0
	simulation.add_child(driver)
	driver._on_tilt_changed(Vector2(1.0, 0.0))
	assert_gt(simulation.get_gravity().x, 0.0, "Leaning right sends weight right")
	assert_gt(simulation.get_gravity().y, 0.0, "Without ever tipping past sideways")


func test_a_level_device_leaves_down_alone() -> void:
	var simulation := _tank()
	var driver := FluidMotionDriver.new()
	simulation.add_child(driver)
	driver._on_tilt_changed(Vector2.ZERO)
	assert_almost_eq(simulation.get_gravity().y, 1.0, EPSILON, "Straight down")
	assert_almost_eq(simulation.get_gravity().x, 0.0, EPSILON, "And no sideways")

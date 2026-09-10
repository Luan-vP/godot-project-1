extends GutTest
## Covers the tank state that survives a reset, and the state that does not.
##
## Only the bookkeeping — the solve itself is GPU-side and cannot run headless.

const EPSILON := 0.001

var _simulation: FluidSimulation


func before_each() -> void:
	# Deliberately not added to the tree: the render pipeline needs a GPU, and
	# none of the state under test does.
	_simulation = FluidSimulation.new()
	autofree(_simulation)


func test_a_reset_keeps_an_externally_held_current_bias() -> void:
	# The bias belongs to whoever set it. A player holding a steady tilt is
	# still holding it after pressing reset, and a steady hold emits no fresh
	# signal — so clearing it here would leave tilt inert until they moved.
	_simulation.set_current_bias(Vector2(120.0, -40.0))
	_simulation.reset()
	assert_almost_eq(_simulation.get_current_bias().x, 120.0, EPSILON, "Bias x")
	assert_almost_eq(_simulation.get_current_bias().y, -40.0, EPSILON, "Bias y")


func test_the_current_bias_is_replaced_not_accumulated() -> void:
	_simulation.set_current_bias(Vector2(100.0, 0.0))
	_simulation.set_current_bias(Vector2(0.0, 50.0))
	assert_almost_eq(_simulation.get_current_bias().x, 0.0, EPSILON, "Bias x")
	assert_almost_eq(_simulation.get_current_bias().y, 50.0, EPSILON, "Bias y")


func test_a_reset_clears_the_field_mirror() -> void:
	var field := _simulation.get_field()
	field.resize(2, 2)
	field.set_cell_velocity(0, 0, Vector2(9.0, 9.0))
	_simulation.reset()
	assert_almost_eq(field.get_cell_velocity(0, 0).length(), 0.0, EPSILON, "Cleared")

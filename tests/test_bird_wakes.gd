extends GutTest
## Covers how birds become wakes in the fluid: birds sharing a cell push as
## one, with their summed momentum, and the strongest wake comes first.


func _bird(position: Vector2, velocity: Vector2) -> Bird:
	var bird := Bird.new()
	bird.position = position
	bird.velocity = velocity
	return bird


func _white(_bird_unused: Bird) -> Color:
	return Color.WHITE


func test_birds_in_one_cell_push_as_one() -> void:
	var birds: Array[Bird] = [
		_bird(Vector2(10, 10), Vector2(100, 0)),
		_bird(Vector2(30, 50), Vector2(100, 20)),
	]
	var wakes := BirdWakes.gather(birds, 100.0, _white)
	assert_eq(wakes.size(), 1, "One cell")
	assert_eq(wakes[0].count, 2, "Both birds")
	assert_eq(wakes[0].position, Vector2(20, 30), "At their average")
	assert_eq(wakes[0].momentum, Vector2(200, 20), "With their summed momentum")
	assert_eq(wakes[0].color, Color.WHITE, "In their colour")


func test_the_strongest_wake_comes_first() -> void:
	var birds: Array[Bird] = [
		_bird(Vector2(10, 10), Vector2(80, 0)),
		_bird(Vector2(510, 10), Vector2(100, 0)),
		_bird(Vector2(520, 20), Vector2(100, 0)),
	]
	var wakes := BirdWakes.gather(birds, 100.0, _white)
	assert_eq(wakes.size(), 2, "Two cells")
	assert_eq(wakes[0].count, 2, "The pair first")
	assert_eq(wakes[1].count, 1, "The lone bird after")


func test_the_level_has_a_tank_behind_the_birds() -> void:
	var level: BoidsLevel = load("res://features/levels/boids/boids_level.tscn").instantiate()
	add_child_autofree(level)
	var fluid := level.get_node_or_null("Fluid") as FluidSimulation
	assert_not_null(fluid, "A fluid tank")
	assert_eq(fluid.get_world_rect().size, level.get_viewport_rect().size, "Filling the window")
	var renderer := level.get_node_or_null("FluidRenderer") as FluidRenderer
	assert_not_null(renderer, "Painted")
	assert_lt(renderer.z_index, 0, "Behind the birds")
	AudioManager.set_tempo(120.0, 4)

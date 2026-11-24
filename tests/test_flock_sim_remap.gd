extends GutTest
## Covers [method FlockSim.remap_rhythms]: when the rhythm level shuffles its
## rhythms, every flock, and the weight and spawn bias kept for its rhythm,
## move over to the rhythm taking its place.

const SKY := Rect2(0.0, 0.0, 1000.0, 600.0)

var _sim: FlockSim


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_sim = FlockSim.new(RhythmTable.default_table(), SKY, rng)


func test_remapping_moves_flocks_weights_and_bias_to_the_new_rhythms() -> void:
	_sim.populate(30, [3, 4] as Array[int])
	_sim.weights = {3: 1.4, 4: 0.8, 6: 1.1}
	_sim.spawn_bias = {4: 0.5}
	var members := 0
	for flock in _sim.flocks:
		members += flock.size()
	_sim.remap_rhythms({3: 5, 4: 7, 6: 8})
	assert_eq(_sim.pulses_on_screen(), [5, 7] as Array[int])
	assert_eq(_sim.weights, {5: 1.4, 7: 0.8, 8: 1.1})
	assert_eq(_sim.spawn_bias, {7: 0.5})
	var after := 0
	for flock in _sim.flocks:
		after += flock.size()
	assert_eq(after, members, "Nobody left a flock")


func test_a_flock_with_no_new_rhythm_breaks_up() -> void:
	_sim.populate(30, [3, 4] as Array[int])
	_sim.remap_rhythms({3: 3})
	assert_eq(_sim.pulses_on_screen(), [3] as Array[int])
	for bird in _sim.birds:
		if bird.flock != null:
			assert_eq(bird.flock.pulses, 3, "Only the 3s are still flocked")

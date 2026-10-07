extends GutTest
## Covers [FlockSim]'s membership rules — joining keeps a bird's voice and
## takes the flock's rhythm, scatters silence every flock but the survivor,
## clumps of loners become flocks, the flock cap — and the pulse surge. The
## rules are checked through [method FlockSim.update_membership], without
## moving anyone, so nothing depends on where the flocking takes the birds.

const SKY := Rect2(0.0, 0.0, 1000.0, 600.0)

var _sim: FlockSim


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_sim = FlockSim.new(RhythmTable.default_table(), SKY, rng)
	_sim.restless_rate = 0.0


func _bird_at(position: Vector2) -> Bird:
	return _sim.add_bird(position, Vector2.RIGHT * 60.0)


func _flock_at(centre: Vector2, pulses: int, size: int = 4) -> Flock:
	var members: Array[Bird] = []
	for i in size:
		members.append(_bird_at(centre + Vector2(i * 10.0, 0.0)))
	return _sim.make_flock(members, pulses)


func test_surge_peaks_on_each_pulse() -> void:
	assert_almost_eq(FlockSim.surge(0.0, 3, 4), 1.0, 0.0001, "Downbeat")
	assert_almost_eq(FlockSim.surge(4.0 / 3.0, 3, 4), 1.0, 0.0001, "Second pulse of 3")
	assert_almost_eq(FlockSim.surge(1.0, 4, 4), 1.0, 0.0001, "Second pulse of 4")
	assert_lt(FlockSim.surge(0.66, 3, 4), 0.2, "Halfway between pulses of 3")


func test_joining_takes_the_rhythm_and_keeps_the_voice() -> void:
	var flock := _flock_at(Vector2(500, 300), 3)
	var bird := _bird_at(Vector2(100, 100))
	var note := bird.note
	var waveform := bird.waveform
	_sim.join(bird, flock)
	assert_eq(bird.flock, flock, "In the flock")
	assert_eq(bird.flock.pulses, 3, "Plays the flock's rhythm")
	assert_eq(bird.note, note, "Same note")
	assert_eq(bird.waveform, waveform, "Same timbre")


func test_a_loner_in_reach_snaps_into_the_flock() -> void:
	_sim.snap_rate = 1.0e6
	var flock := _flock_at(Vector2(500, 300), 4)
	var bird := _bird_at(Vector2(500, 315))
	_sim.update_membership(0.1)
	assert_eq(bird.flock, flock, "Snapped in")


func test_a_flock_out_of_favour_does_not_recruit() -> void:
	_sim.snap_rate = 1.0e6
	_flock_at(Vector2(500, 300), 4)
	_sim.weights[4] = FlockSim.SNAP_MIN_WEIGHT - 0.1
	var bird := _bird_at(Vector2(500, 315))
	_sim.update_membership(0.1)
	assert_true(bird.is_loner(), "Still alone")


func test_a_stunned_bird_cannot_join() -> void:
	_sim.snap_rate = 1.0e6
	_flock_at(Vector2(500, 300), 4)
	var bird := _bird_at(Vector2(500, 315))
	bird.stunned = 1.0
	_sim.update_membership(0.1)
	assert_true(bird.is_loner(), "Still thrown clear")


func test_a_stray_leaves_and_goes_silent() -> void:
	var flock := _flock_at(Vector2(300, 300), 4, 5)
	var stray := flock.members[4]
	stray.position = Vector2(900, 300)
	_sim.update_membership(0.1)
	assert_true(stray.is_loner(), "Strayed out")
	assert_eq(flock.size(), 4, "The rest stay")


func test_a_flock_of_one_dissolves() -> void:
	var flock := _flock_at(Vector2(300, 300), 3, 1)
	_sim.update_membership(0.1)
	assert_false(flock in _sim.flocks, "Gone")
	assert_true(_sim.birds[0].is_loner(), "Its bird is a loner")


func test_scatter_silences_every_flock_but_the_survivor() -> void:
	var threes := _flock_at(Vector2(200, 200), 3)
	var fours := _flock_at(Vector2(700, 200), 4)
	var sixes := _flock_at(Vector2(500, 450), 6)
	watch_signals(_sim)
	var scattered := _sim.scatter(4)
	assert_eq(scattered, 8, "Two flocks of four thrown clear")
	assert_eq(_sim.flocks, [fours] as Array[Flock], "Only the 4 is left")
	for bird in _sim.birds:
		if bird.flock == null:
			assert_gt(bird.stunned, 0.0, "Stunned")
			assert_almost_eq(bird.velocity.length(), FlockSim.SCATTER_SPEED, 0.01, "Thrown")
	assert_eq(threes.size(), 0, "3 emptied")
	assert_eq(sixes.size(), 0, "6 emptied")
	assert_signal_emitted_with_parameters(_sim, "scattered", [4, 8])


func test_a_clump_of_loners_that_holds_becomes_a_flock() -> void:
	for i in FlockSim.FORM_SIZE:
		_bird_at(Vector2(500 + i * 8.0, 300))
	watch_signals(_sim)
	_sim.update_membership(FlockSim.FORM_DWELL * 0.5)
	assert_eq(_sim.flocks.size(), 0, "Not held long enough yet")
	_sim.update_membership(FlockSim.FORM_DWELL * 0.6)
	assert_eq(_sim.flocks.size(), 1, "Formed")
	assert_eq(_sim.flocks[0].size(), FlockSim.FORM_SIZE, "All of the clump")
	assert_has(_sim.table.pulse_counts(), _sim.flocks[0].pulses, "A rhythm from the table")
	assert_signal_emitted(_sim, "flock_formed")


func test_too_small_a_clump_stays_loners() -> void:
	for i in FlockSim.FORM_SIZE - 1:
		_bird_at(Vector2(500 + i * 8.0, 300))
	_sim.update_membership(FlockSim.FORM_DWELL * 2.0)
	assert_eq(_sim.flocks.size(), 0, "Not enough birds")


func test_no_new_flock_past_the_cap() -> void:
	for i in FlockSim.MAX_FLOCKS:
		_flock_at(Vector2(80 + i * 180.0, 80), 4, 2)
	for i in FlockSim.FORM_SIZE:
		_bird_at(Vector2(500 + i * 8.0, 450))
	_sim.update_membership(FlockSim.FORM_DWELL * 2.0)
	assert_eq(_sim.flocks.size(), FlockSim.MAX_FLOCKS, "Held at the cap")


func test_populate_seeds_the_starting_flocks() -> void:
	_sim.populate(40, [3, 4] as Array[int])
	assert_eq(_sim.birds.size(), 40, "Every bird")
	assert_eq(_sim.pulses_on_screen(), [3, 4] as Array[int], "A 3 and a 4 flying")


func test_stepping_keeps_birds_in_the_sky() -> void:
	_sim.populate(30, [3, 4] as Array[int])
	for i in 240:
		_sim.step(1.0 / 60.0, i / 60.0)
	for bird in _sim.birds:
		assert_true(SKY.grow(0.01).has_point(bird.position), "Inside the sky")
		assert_between(bird.velocity.length(), 0.0, FlockSim.SCATTER_SPEED + 0.01)


func test_same_rhythm_flocks_that_meet_merge() -> void:
	var big := _flock_at(Vector2(500, 300), 4, 5)
	var small := _flock_at(Vector2(510, 310), 4, 3)
	var other := _flock_at(Vector2(505, 305), 3, 3)
	_sim.update_membership(0.01)
	assert_eq(big.size(), 8, "The smaller joined the larger")
	assert_false(small in _sim.flocks, "The smaller is gone")
	assert_eq(other.size(), 3, "A different rhythm never merges")


func test_a_stroke_kicks_the_boatman_along_its_heading_then_it_glides_to_rest() -> void:
	_sim.rest_chance = 0.0
	var bird := _sim.add_bird(Vector2(500, 300), Vector2.ZERO)
	bird.heading = Vector2.RIGHT
	bird.stroke_timer = 0.0
	_sim.step(0.001, 0.0)
	assert_gt(bird.velocity.x, FlockSim.STROKE_SPEED * 0.5, "Pushed forward")
	assert_gt(bird.stroke, 0.9, "Oars at the pull")
	var top := bird.velocity.length()
	bird.stroke_timer = 100.0
	for i in 120:
		_sim.step(1.0 / 60.0, 0.0)
	assert_lt(bird.velocity.length(), top * 0.1, "The water ate the glide")


func test_flock_members_row_on_their_flocks_pulse() -> void:
	var flock := _flock_at(Vector2(500, 300), 4, 3)
	_sim.step(0.1, 0.0)
	for bird in flock.members:
		bird.stroke_timer = 100.0
		bird.stroke = 0.0
	_sim.step(0.1, 0.5)
	for bird in flock.members:
		assert_eq(bird.stroke, 0.0, "Between pulses nobody rows")
	# Beat 1 is the next pulse of a 4-flock; the spread is under a step.
	_sim.step(0.1, 1.0)
	for bird in flock.members:
		assert_gt(bird.stroke, 0.0, "On the pulse everybody rows")

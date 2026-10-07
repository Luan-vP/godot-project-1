extends GutTest
## Covers [FlockSim]'s flying motion ([constant FlockSim.Motion.FLY]), the
## original birds: speed stays within the flying limits, birds keep moving,
## and nothing of the rowing's strokes reaches them. Kept apart from
## test_flock_sim.gd, which is at gdlint's limit of public methods.

const SKY := Rect2(0.0, 0.0, 1000.0, 600.0)

var _sim: FlockSim


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_sim = FlockSim.new(RhythmTable.default_table(), SKY, rng)
	_sim.restless_rate = 0.0


func _flock_at(centre: Vector2, pulses: int, size: int = 4) -> Flock:
	var members: Array[Bird] = []
	for i in size:
		members.append(_sim.add_bird(centre + Vector2(i * 10.0, 0.0), Vector2.RIGHT * 60.0))
	return _sim.make_flock(members, pulses)


func _flying_sim() -> FlockSim:
	_sim.motion = FlockSim.Motion.FLY
	return _sim


func test_fliers_never_slow_below_the_minimum_or_exceed_the_maximum() -> void:
	var sim := _flying_sim()
	sim.populate(30, [3, 4] as Array[int])
	for i in 300:
		sim.step(1.0 / 60.0, i / 60.0)
		for bird in sim.birds:
			assert_between(
				bird.velocity.length(), FlockSim.FLY_MIN_SPEED - 0.01, FlockSim.FLY_MAX_SPEED + 0.01
			)
			assert_true(SKY.grow(0.01).has_point(bird.position), "Inside the sky")


func test_fliers_keep_moving_and_heading_follows_velocity() -> void:
	var sim := _flying_sim()
	var bird := sim.add_bird(Vector2(500, 300), Vector2.ZERO)
	sim.step(0.1, 0.0)
	assert_almost_eq(bird.velocity.length(), FlockSim.FLY_MIN_SPEED, 0.01, "Kicked to the minimum")
	var start := bird.position
	for i in 60:
		sim.step(1.0 / 60.0, i / 60.0)
		assert_almost_eq(bird.heading.dot(bird.velocity.normalized()), 1.0, 0.001, "Faces its way")
	assert_gt(bird.position.distance_to(start), 20.0, "It flew somewhere")


func test_fliers_have_no_strokes_or_rests() -> void:
	var sim := _flying_sim()
	var flock := _flock_at(Vector2(500, 300), 4, 4)
	for bird in flock.members:
		bird.stroke_timer = 0.0
		bird.velocity = Vector2.RIGHT * 100.0
	var before := flock.members[0].velocity
	sim.step(0.001, 0.0)
	for bird in sim.birds:
		assert_eq(bird.stroke, 0.0, "No oars")
	# A stroke would add STROKE_SPEED in one step; flying changes velocity by
	# no more than the flocking's acceleration over that step.
	assert_lt(flock.members[0].velocity.distance_to(before), 5.0, "No lurch")
	# And the pulse bookkeeping of rowing never runs.
	assert_eq(flock.last_pulse, -1, "No pulse rowed on")


func test_a_flying_scatter_throws_birds_clear_and_they_settle_back() -> void:
	var sim := _flying_sim()
	_flock_at(Vector2(500, 300), 4, 4)
	sim.scatter(3)
	for bird in sim.birds:
		assert_almost_eq(bird.velocity.length(), FlockSim.SCATTER_SPEED, 0.01, "Thrown")
	for i in 240:
		sim.step(1.0 / 60.0, 0.0)
	for bird in sim.birds:
		assert_lte(bird.velocity.length(), FlockSim.FLY_MAX_SPEED + 0.01, "Back to flying speed")


func test_the_flocks_surge_in_both_motions() -> void:
	for motion in [FlockSim.Motion.ROW, FlockSim.Motion.FLY]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var sim := FlockSim.new(RhythmTable.default_table(), SKY, rng)
		sim.motion = motion
		sim.populate(30, [3, 4] as Array[int])
		assert_eq(sim.pulses_on_screen(), [3, 4] as Array[int], "Seeded flocks")
		sim.step(0.05, 0.0)
		assert_eq(FlockSim.surge(0.0, 3, 4), 1.0, "Peak on the downbeat")

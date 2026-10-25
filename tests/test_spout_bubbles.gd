extends GutTest
## Covers the spout's bubbles themselves: fired on their steps (8-20 a bar)
## with a haptic tick each, the capped pool, snapping round a duck and
## popping, and the water: stirred and painted by the spout and the bubbles,
## never moving them.

const Hosting := preload("res://tests/hosting.gd")

const _TEST_SETTINGS_PATH := "user://test_spout_bubbles_settings.cfg"
const LEVEL := preload("res://features/levels/spout/bubbles/level_three.tscn")


## A tank with no GPU: a fixed current everywhere, and a record of what is
## pushed and painted into it.
class RecordingTank:
	extends FluidSimulation
	var current := Vector2.ZERO
	var pushes: Array[Vector2] = []
	var paints := 0

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _exit_tree() -> void:
		pass

	func sample_velocity(_world_position: Vector2) -> Vector2:
		return current

	func add_velocity_impulse(
		_world_position: Vector2, world_acceleration: Vector2, _radius: float, _duration: float
	) -> void:
		pushes.append(world_acceleration)

	func add_paint(
		_world_position: Vector2, _color: Color, _amount: float, _radius: float, _duration: float
	) -> void:
		paints += 1


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	AudioManager.set_tempo(120.0, 4)
	AudioManager.set_music_time_source(WallClockMusicTime.new())


## The level, with the music held still so its own physics frames never move
## the clock under a test: the tests move it with [method tick_clock].
func _level() -> SpoutLevel:
	AudioManager.set_music_time_source(ScriptedMusicTime.new())
	var level: SpoutLevel = LEVEL.instantiate()
	Hosting.host(self, level)
	level.emitter.reads_input = false
	return level


func test_bubbles_fire_eight_to_twenty_a_bar() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	assert_eq(emitter.flow_steps(), [8, 12, 16, 20] as Array[int])
	emitter.set_depth(SpoutFlow.DEADZONE + 0.01)
	emitter.set_step(emitter.current_step())
	assert_eq(emitter.flow_per_bar(), 8, "A gentle press: 8 a bar")
	emitter.set_depth(1.0)
	emitter.set_step(emitter.current_step())
	assert_eq(emitter.flow_per_bar(), 20, "Fully pressed: 20")
	assert_eq(emitter.overlay.steps, [8, 12, 16, 20] as Array[int], "The rings show the steps")


func test_bubbles_leave_at_the_muzzle_speed() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var bubble := emitter.fire()
	assert_almost_eq(bubble.linear_velocity.length(), BubbleEmitter.MUZZLE_SPEED, 0.01)


func test_the_bubbles_have_four_steps_of_their_own() -> void:
	assert_eq(SpoutFlow.per_bar(4), 24, "The shared steps go to 24")
	assert_eq(SpoutFlow.per_bar(3, BubbleEmitter.STEPS), 20)
	assert_eq(SpoutFlow.per_bar(4, BubbleEmitter.STEPS), 0, "No fifth step")


func test_closing_speed_is_the_part_along_the_line_to_the_pin() -> void:
	var straight := SpoutBubble.closing_speed(Vector2(0, 400), Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(straight, 400.0, 0.001, "Dropped straight on")
	var glancing := SpoutBubble.closing_speed(Vector2(400, 0), Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(glancing, 0.0, 0.001, "Rolling across the top")
	var leaving := SpoutBubble.closing_speed(Vector2(0, -400), Vector2(0, -10), Vector2.ZERO)
	assert_eq(leaving, 0.0, "Moving away")


func test_every_bubble_fired_ticks_the_haptics() -> void:
	var level := _level()
	var output := NullHapticsOutput.new()
	output.available = true
	var outputs: Array[HapticsOutput] = [output]
	level.haptics.set_outputs(outputs)
	level.haptics.get_limiter().min_interval = 0.0
	var emitter: BubbleEmitter = level.emitter
	emitter.fire()
	emitter.fire()
	emitter.fire()
	assert_eq(output.pulses.size(), 3, "One tick per bubble")
	assert_eq(emitter.in_play(), 3)


func test_rt_fires_so_it_is_not_a_key_move() -> void:
	var level := _level()
	assert_false(level._key_shift.use_triggers, "RT fires, it does not move the key")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	assert_eq(level._key_shift.step_for(rt), 0)


func test_the_pool_is_capped() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	for i in BubbleEmitter.MAX_BUBBLES + 5:
		emitter.fire()
	assert_eq(emitter.in_play(), BubbleEmitter.MAX_BUBBLES)


func test_a_touch_fires() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	assert_eq(emitter.current_step(), -1, "Nothing touching: closed")
	level.pointer.press(level.spout.global_position + Vector2(0, 300))
	assert_gte(emitter.current_step(), 0, "A touch fires")
	level.pointer.release()


func test_the_level_stirs_the_hosts_tank() -> void:
	var level := _level()
	var shared := SharedLayers.find(level)
	assert_eq((level.emitter as BubbleEmitter).simulation, shared.fluid)
	assert_eq((level.emitter as BubbleEmitter).fire().simulation, shared.fluid, "And so do bubbles")


func test_stream_colour_drifts_through_the_palette() -> void:
	assert_eq(BubbleEmitter.stream_color(0.0), BubbleEmitter.PALETTE[0])
	var halfway := BubbleEmitter.stream_color(BubbleEmitter.PALETTE_SECONDS * 0.5)
	assert_ne(halfway, BubbleEmitter.PALETTE[0], "Moving on")
	assert_ne(halfway, BubbleEmitter.PALETTE[1], "Not there yet")


func test_a_bubble_snaps_round_its_duck() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var pin := level.pins.live_pins()[3]
	var bubble := emitter.fire()
	var centre := level.pins.to_global(level.pins.pin_position(pin))
	bubble.global_position = centre + Vector2(0, -30)
	emitter.stick(bubble, pin, 400.0)
	await wait_physics_frames(2)
	assert_true(bubble.freeze, "Frozen in place")
	assert_almost_eq(bubble.global_position.distance_to(centre), 0.0, 0.5, "Centred on the duck")
	assert_eq(bubble.collision_layer, 0, "Out of play: the pin does the colliding")
	bubble._process(SpoutBubble.SNAP_SECONDS)
	assert_almost_eq(bubble.drawn_radius(), emitter.wrap_radius(), 0.01, "Grown round it")
	assert_gt(emitter.wrap_radius() * 2.0, level.pins.duck_size, "Wider than the duck")


func test_a_played_bubble_pops_then_goes() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	var pin := level.pins.live_pins()[2]
	var bubble := emitter.fire()
	emitter.tick_clock(0.01)
	emitter.stick(bubble, pin, 400.0)
	assert_false(bubble.is_popping(), "Whole while it waits")
	emitter.tick_clock(sixteenth + 0.001)
	assert_true(bubble.is_popping(), "Pops on its sixteenth")
	bubble._process(SpoutBubble.POP_SECONDS + 0.01)
	assert_true(bubble.is_queued_for_deletion(), "Gone once the burst has played")


func test_the_water_never_moves_a_bubble_but_a_bubble_stirs_the_water() -> void:
	# A lone bubble with nothing to hit, in a strong current across its path.
	var tank := RecordingTank.new()
	tank.current = Vector2(900.0, -900.0)
	add_child_autofree(tank)
	var bubble := SpoutBubble.new()
	bubble.simulation = tank
	bubble.gravity_scale = 0.0
	bubble.linear_damp = 0.0
	bubble.position = Vector2(60, 60)
	bubble.linear_velocity = Vector2(0, 200)
	add_child_autofree(bubble)
	await wait_physics_frames(4)
	# Only the project's default damping slows it; the current never bends it.
	var velocity := bubble.linear_velocity
	assert_almost_eq(velocity.x, 0.0, 0.01, "Not carried sideways")
	assert_almost_eq(velocity.y, 200.0, 5.0, "Nor held back")
	assert_gt(tank.pushes.size(), 0, "It pushes the water")
	var push: Vector2 = tank.pushes[-1]
	var slip := velocity - tank.current
	assert_almost_eq(push, slip * SpoutBubble.WAKE_STRENGTH, Vector2(10, 10), "By its slip")
	assert_gt(tank.paints, 0, "And paints it")

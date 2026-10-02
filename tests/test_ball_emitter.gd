extends GutTest
## Covers #116: version B's fire rate from trigger depth, hit strength from
## impact speed, and a haptic tick per ball fired.

const _TEST_SETTINGS_PATH := "user://test_ball_emitter_settings.cfg"
const LEVEL_B := preload("res://features/levels/spout/b_balls/level_three_b.tscn")


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	AudioManager.set_tempo(120.0, 4)


func test_nothing_fires_inside_the_deadzone() -> void:
	assert_eq(SpoutFireRate.rate_for(0.0), 0.0)
	assert_eq(SpoutFireRate.rate_for(SpoutFireRate.DEADZONE), 0.0)


func test_rate_rises_in_proportion_to_depth() -> void:
	var low := SpoutFireRate.rate_for(0.3)
	var high := SpoutFireRate.rate_for(0.9)
	assert_lt(low, high)
	assert_almost_eq(SpoutFireRate.rate_for(1.0), SpoutFireRate.MAX_RATE, 0.0001, "Full press")
	var mid := SpoutFireRate.rate_for((1.0 + SpoutFireRate.DEADZONE) / 2.0)
	var expected := (SpoutFireRate.MIN_RATE + SpoutFireRate.MAX_RATE) / 2.0
	assert_almost_eq(mid, expected, 0.0001, "Linear between the ends")


func test_first_ball_of_a_press_fires_at_once() -> void:
	var rate := SpoutFireRate.new()
	assert_eq(rate.step(0.5, 0.001), 1, "Immediate")


func test_a_held_trigger_fires_at_its_rate() -> void:
	var rate := SpoutFireRate.new()
	var fired := 0
	for i in 600:  # Ten seconds at 60 fps.
		fired += rate.step(1.0, 1.0 / 60.0)
	assert_almost_eq(float(fired), SpoutFireRate.MAX_RATE * 10.0 + 1.0, 1.0)


func test_changing_depth_changes_the_rate_without_a_reset() -> void:
	var rate := SpoutFireRate.new()
	rate.step(1.0, 0.0)  # Spend the first, immediate ball.
	var fired := 0
	for i in 30:
		fired += rate.step(1.0, 1.0 / 60.0)
	for i in 30:
		fired += rate.step(0.3, 1.0 / 60.0)
	var expected := (SpoutFireRate.MAX_RATE + SpoutFireRate.rate_for(0.3)) * 0.5
	assert_almost_eq(float(fired), expected, 1.0)


func test_releasing_rearms_the_immediate_ball() -> void:
	var rate := SpoutFireRate.new()
	rate.step(1.0, 0.0)
	rate.step(0.0, 0.1)
	assert_eq(rate.step(0.4, 0.001), 1)


func test_closing_speed_is_the_part_along_the_line_to_the_pin() -> void:
	var straight := SpoutBall.closing_speed(Vector2(0, 400), Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(straight, 400.0, 0.001, "Dropped straight on")
	var glancing := SpoutBall.closing_speed(Vector2(400, 0), Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(glancing, 0.0, 0.001, "Rolling across the top")
	var leaving := SpoutBall.closing_speed(Vector2(0, -400), Vector2(0, -10), Vector2.ZERO)
	assert_eq(leaving, 0.0, "Moving away")


func test_strength_follows_impact_speed() -> void:
	assert_eq(BallEmitter.strength_for(20.0), -1.0, "A roll stays quiet")
	assert_lt(BallEmitter.strength_for(150.0), BallEmitter.strength_for(500.0))
	assert_eq(BallEmitter.strength_for(5000.0), 1.0, "Capped")


func test_every_ball_fired_ticks_the_haptics() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	add_child_autofree(level)
	var output := NullHapticsOutput.new()
	output.available = true
	var outputs: Array[HapticsOutput] = [output]
	level.haptics.set_outputs(outputs)
	level.haptics.get_limiter().min_interval = 0.0
	var emitter: BallEmitter = level.emitter
	emitter.reads_input = false
	emitter.fire()
	emitter.fire()
	emitter.fire()
	assert_eq(output.pulses.size(), 3, "One tick per ball")
	assert_eq(emitter.in_play(), 3)


func test_version_b_takes_the_triggers_from_key_moves() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	add_child_autofree(level)
	assert_false(level._key_shift.use_triggers, "RT fires, it does not move the key")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	assert_eq(level._key_shift.step_for(rt), 0)


func test_the_pool_is_capped() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	add_child_autofree(level)
	var emitter: BallEmitter = level.emitter
	emitter.reads_input = false
	for i in BallEmitter.MAX_BALLS + 5:
		emitter.fire()
	assert_eq(emitter.in_play(), BallEmitter.MAX_BALLS)

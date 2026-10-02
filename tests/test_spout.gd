extends GutTest
## Covers #111: the spout's aim — the stick and keys as turn rates, the
## deadzone and clamp, and the direction it points.

var _spout: Spout


func before_each() -> void:
	_spout = Spout.new()
	_spout.reads_input = false
	add_child_autofree(_spout)


func test_a_resting_stick_does_not_turn() -> void:
	assert_eq(SpoutAimInput.target_rate(0.1, 0.0), 0.0, "Inside the deadzone")
	assert_eq(SpoutAimInput.target_rate(-0.15, 0.0), 0.0, "On its edge")


func test_full_stick_turns_at_the_full_rate() -> void:
	assert_almost_eq(SpoutAimInput.target_rate(1.0, 0.0), SpoutAimInput.MAX_RATE, 0.0001)
	assert_almost_eq(SpoutAimInput.target_rate(-1.0, 0.0), -SpoutAimInput.MAX_RATE, 0.0001)


func test_small_deflections_turn_gently() -> void:
	var half := SpoutAimInput.target_rate(0.575, 0.0)  # Halfway past the deadzone.
	assert_almost_eq(half, SpoutAimInput.MAX_RATE * 0.25, 0.001, "Squared response")


func test_keys_turn_at_a_fixed_rate_and_the_stick_wins() -> void:
	assert_eq(SpoutAimInput.target_rate(0.0, 1.0), SpoutAimInput.KEY_RATE, "D")
	assert_eq(SpoutAimInput.target_rate(0.0, -1.0), -SpoutAimInput.KEY_RATE, "A")
	assert_lt(SpoutAimInput.target_rate(-1.0, 1.0), 0.0, "Stick overrides the keys")


func test_aim_is_clamped_either_side() -> void:
	for i in 200:
		_spout.steer(1.0, 0.0, 0.05)
	assert_almost_eq(_spout.aim, _spout.max_aim, 0.0001, "Stops at the right")
	for i in 400:
		_spout.steer(-1.0, 0.0, 0.05)
	assert_almost_eq(_spout.aim, -_spout.max_aim, 0.0001, "Stops at the left")


func test_turning_eases_in() -> void:
	_spout.steer(1.0, 0.0, 0.016)
	var first := _spout.aim
	assert_gt(first, 0.0, "Starts moving")
	assert_lt(first, SpoutAimInput.MAX_RATE * 0.016, "But not at full rate at once")


func test_direction_points_down_and_swings() -> void:
	assert_almost_eq(_spout.direction(), Vector2.DOWN, Vector2(0.0001, 0.0001), "Straight down")
	_spout.aim = _spout.max_aim
	assert_gt(_spout.direction().x, 0.0, "Positive aim swings right")
	assert_gt(_spout.direction().y, 0.0, "Still pointing downwards")
	_spout.aim = -_spout.max_aim
	assert_lt(_spout.direction().x, 0.0, "Negative swings left")


func test_muzzle_sits_at_the_end_of_the_barrel() -> void:
	_spout.position = Vector2(100, 50)
	var muzzle := _spout.muzzle_position()
	assert_almost_eq(muzzle, Vector2(100, 50 + _spout.barrel_length), Vector2(0.001, 0.001))


func test_aim_changed_fires_on_movement() -> void:
	watch_signals(_spout)
	_spout.aim = 0.3
	_spout.aim = 0.3
	assert_signal_emit_count(_spout, "aim_changed", 1)

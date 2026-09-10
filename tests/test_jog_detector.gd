extends GutTest
## Covers turning a shake into exactly one nudge.

const STEP := 1.0 / 60.0

var _detector: JogDetector


func before_each() -> void:
	_detector = JogDetector.new()
	_detector.threshold = 10.0
	_detector.release = 4.0
	_detector.cooldown = 0.3
	_detector.max_strength = 3.0


## Feed the same acceleration for a number of frames, counting the nudges.
func _feed_for(acceleration: Vector2, frames: int) -> int:
	var fired := 0
	for _i in frames:
		if _detector.feed(acceleration, STEP) != Vector2.ZERO:
			fired += 1
	return fired


func test_gentle_motion_never_fires() -> void:
	assert_eq(_feed_for(Vector2(3.0, 0.0), 120), 0, "Below the threshold")


func test_crossing_the_threshold_fires_once() -> void:
	var nudge := _detector.feed(Vector2(12.0, 0.0), STEP)
	assert_ne(nudge, Vector2.ZERO, "Should fire")
	assert_gt(nudge.x, 0.0, "Should carry the shake direction")


func test_a_sustained_shake_fires_only_once() -> void:
	# The bug a bare threshold has: one physical shake spans many frames, and
	# every one of them is over the line.
	assert_eq(_feed_for(Vector2(15.0, 0.0), 60), 1, "One shake, one nudge")


func test_it_rearms_only_after_the_motion_settles() -> void:
	assert_eq(_feed_for(Vector2(15.0, 0.0), 5), 1, "First shake")
	# Still moving hard, well past the cooldown: must stay quiet.
	assert_eq(_feed_for(Vector2(15.0, 0.0), 60), 0, "Still shaking")
	# Settle below the release level, then shake again.
	assert_eq(_feed_for(Vector2(1.0, 0.0), 30), 0, "Settling")
	assert_eq(_feed_for(Vector2(15.0, 0.0), 5), 1, "Second shake")


func test_the_cooldown_blocks_a_rapid_second_shake() -> void:
	assert_eq(_feed_for(Vector2(15.0, 0.0), 2), 1, "First shake")
	assert_eq(_feed_for(Vector2(0.0, 0.0), 2), 0, "Brief settle, still cooling down")
	assert_eq(_feed_for(Vector2(15.0, 0.0), 2), 0, "Too soon")


func test_a_harder_shake_gives_a_stronger_nudge() -> void:
	var soft := _detector.feed(Vector2(11.0, 0.0), STEP)
	_detector.reset()
	_feed_for(Vector2.ZERO, 30)
	var hard := _detector.feed(Vector2(20.0, 0.0), STEP)
	assert_gt(hard.length(), soft.length(), "Harder shake, bigger nudge")


func test_nudge_strength_is_capped() -> void:
	var violent := _detector.feed(Vector2(400.0, 0.0), STEP)
	assert_almost_eq(violent.length(), 3.0, 0.0005, "Capped at max_strength")


func test_reset_rearms_immediately() -> void:
	assert_eq(_feed_for(Vector2(15.0, 0.0), 2), 1, "First shake")
	_detector.reset()
	assert_eq(_feed_for(Vector2(15.0, 0.0), 2), 1, "Fires again after a reset")

extends GutTest
## Covers a press held still ([PressHold]), how the rhythm level's dial is
## held to shuffle.

var _hold: PressHold


func before_each() -> void:
	_hold = PressHold.new()


func test_it_fires_once_after_the_hold() -> void:
	_hold.begin(0, Vector2(100, 100), 10.0)
	assert_false(_hold.poll(10.0 + _hold.hold_seconds * 0.5), "Not yet")
	assert_almost_eq(_hold.progress(10.0 + _hold.hold_seconds * 0.5), 0.5, 0.001)
	assert_true(_hold.poll(10.0 + _hold.hold_seconds), "Held")
	assert_false(_hold.poll(20.0), "Once per press")
	assert_eq(_hold.progress(20.0), 0.0)


func test_letting_go_or_wandering_calls_it_off() -> void:
	_hold.begin(0, Vector2(100, 100), 10.0)
	_hold.end(0)
	assert_false(_hold.poll(20.0), "Let go")
	_hold.begin(1, Vector2(100, 100), 30.0)
	_hold.moved(1, Vector2(100 + _hold.wander * 0.5, 100))
	assert_true(_hold.is_holding(), "A little drift is fine")
	_hold.moved(1, Vector2(100 + _hold.wander * 2.0, 100))
	assert_false(_hold.poll(40.0), "Moved away")


func test_another_finger_does_not_take_over() -> void:
	_hold.begin(0, Vector2(100, 100), 10.0)
	_hold.begin(1, Vector2(500, 500), 10.5)
	_hold.end(1)
	assert_true(_hold.poll(10.0 + _hold.hold_seconds), "The first finger still holds")

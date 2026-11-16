extends GutTest
## Covers [TouchHold], the three-finger hold that shows the debug overlay on a
## phone.


func _touch(hold: TouchHold, index: int, pressed: bool, now: float) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = pressed
	hold.track(touch, now)


func test_three_fingers_held_fire_once() -> void:
	var hold := TouchHold.new()
	for i in 3:
		_touch(hold, i, true, 0.0)
	assert_false(hold.poll(1.0), "Not yet")
	assert_true(hold.poll(1.6), "Held long enough")
	assert_false(hold.poll(3.0), "Only once per hold")


func test_two_fingers_never_fire() -> void:
	var hold := TouchHold.new()
	_touch(hold, 0, true, 0.0)
	_touch(hold, 1, true, 0.0)
	assert_false(hold.poll(10.0))


func test_lifting_a_finger_starts_the_hold_again() -> void:
	var hold := TouchHold.new()
	for i in 3:
		_touch(hold, i, true, 0.0)
	_touch(hold, 2, false, 1.0)
	_touch(hold, 2, true, 1.2)
	assert_false(hold.poll(2.0), "Counted from the third finger's return")
	assert_true(hold.poll(2.8))


func test_it_fires_again_after_every_finger_lifts() -> void:
	var hold := TouchHold.new()
	for i in 3:
		_touch(hold, i, true, 0.0)
	assert_true(hold.poll(2.0))
	for i in 3:
		_touch(hold, i, false, 2.5)
	for i in 3:
		_touch(hold, i, true, 3.0)
	assert_true(hold.poll(5.0), "A new hold")

extends GutTest
## Covers [EyeBand]'s contact rules — which eye plays which part, when an eye
## counts as touching a wall, and that a wall silences only its own part —
## without starting any music.

const TANK := Rect2(Vector2.ZERO, Vector2(1000.0, 600.0))

var _band: EyeBand


func before_each() -> void:
	_band = EyeBand.new()
	add_child_autofree(_band)


func test_clearance_is_measured_from_the_rim_to_the_nearest_wall() -> void:
	assert_almost_eq(EyeBand.wall_clearance(Vector2(500, 300), 40.0, TANK), 260.0, 0.001, "Middle")
	assert_almost_eq(EyeBand.wall_clearance(Vector2(60, 300), 40.0, TANK), 20.0, 0.001, "Near left")
	assert_almost_eq(
		EyeBand.wall_clearance(Vector2(500, 590), 40.0, TANK), -30.0, 0.001, "Past bottom"
	)


func test_touching_takes_hold_close_and_lets_go_further_out() -> void:
	assert_false(EyeBand.next_touching(25.0, false, 10.0, 40.0), "Not yet close enough")
	assert_true(EyeBand.next_touching(5.0, false, 10.0, 40.0), "Takes hold inside 10 px")
	assert_true(EyeBand.next_touching(25.0, true, 10.0, 40.0), "Holds on out to 40 px")
	assert_false(EyeBand.next_touching(45.0, true, 10.0, 40.0), "Lets go past 40 px")


func test_parts_go_to_eyes_biggest_first() -> void:
	var radii: Array[float] = [30.0, 60.0, 45.0]
	assert_eq(EyeBand.parts_by_size(radii, 7), [2, 0, 1] as Array[int], "Biggest gets part 0")


func test_eyes_past_the_last_part_get_none() -> void:
	var radii: Array[float] = [10.0, 50.0, 40.0]
	assert_eq(EyeBand.parts_by_size(radii, 2), [-1, 0, 1] as Array[int], "Smallest left out")


func test_every_part_is_played_by_some_eye_in_the_eye_tank() -> void:
	assert_eq(EyeBand.PARTS.size(), 7, "One part per eye in the tank")
	for part in EyeBand.LOOP_PARTS:
		assert_has(EyeBand.PARTS, part, "Loop part %s is a part" % part)


func test_a_wall_silences_only_the_eye_touching_it() -> void:
	var big := _eye(60.0, Vector2(500, 300))
	var small := _eye(30.0, Vector2(300, 300))
	var eyes: Array[FloatyEye] = [big, small]
	_band.bind_eyes(eyes)
	_band.update_contacts(TANK)
	assert_eq(_band.part_for(big), "beat", "Biggest eye has the beat")
	assert_eq(_band.part_for(small), "bass", "Next has the bass")
	assert_true(_band.wants_part("beat") and _band.wants_part("bass"), "Both free, both wanted")

	watch_signals(_band)
	small.global_position = Vector2(35, 300)
	_band.update_contacts(TANK)
	assert_true(_band.is_touching(small), "Small eye is on the left wall")
	assert_false(_band.wants_part("bass"), "Its part drops out")
	assert_true(_band.wants_part("beat"), "The other part carries on")
	assert_signal_emitted_with_parameters(_band, "contact_changed", ["bass", true])


func test_a_part_with_no_eye_is_never_wanted() -> void:
	var eyes: Array[FloatyEye] = [_eye(40.0, Vector2(500, 300))]
	_band.bind_eyes(eyes)
	_band.update_contacts(TANK)
	assert_false(_band.wants_part("shimmer"), "Nobody plays the shimmer")


func test_pending_is_none_when_playing_already_matches_wanted() -> void:
	_band.bind_eyes([_eye(40.0, Vector2(500, 300))])
	_band._playing["beat"] = true
	assert_eq(_band.pending("beat"), EyeBand.Pending.NONE, "Free and already sounding")


func test_pending_is_starting_when_wanted_but_not_yet_sounding() -> void:
	_band.bind_eyes([_eye(40.0, Vector2(500, 300))])
	_band._playing["beat"] = false
	assert_eq(_band.pending("beat"), EyeBand.Pending.STARTING, "Free but waiting for the bar line")


func test_pending_is_stopping_when_sounding_but_no_longer_wanted() -> void:
	var eye := _eye(40.0, Vector2(500, 300))
	_band.bind_eyes([eye])
	eye.global_position = Vector2(35, 300)
	_band.update_contacts(TANK)
	_band._playing["beat"] = true
	assert_eq(_band.pending("beat"), EyeBand.Pending.STOPPING, "Touching but still sounding")


func test_countdown_fraction_shrinks_to_zero_at_the_bar_line() -> void:
	assert_almost_eq(EyeBand.countdown_fraction(2.0, 2.0), 1.0, 0.001, "Bar just started")
	assert_almost_eq(EyeBand.countdown_fraction(0.5, 2.0), 0.25, 0.001, "Most of the bar gone")
	assert_almost_eq(EyeBand.countdown_fraction(0.0, 2.0), 0.0, 0.001, "Right at the bar line")


func test_countdown_fraction_is_zero_without_a_bar_length() -> void:
	assert_eq(EyeBand.countdown_fraction(1.0, 0.0), 0.0, "No bar length: no crash, no countdown")


func _eye(radius: float, at: Vector2) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.radius = radius
	add_child_autofree(eye)
	eye.global_position = at
	return eye

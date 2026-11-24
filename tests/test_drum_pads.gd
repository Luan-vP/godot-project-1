extends GutTest
## Covers where the rhythm level's drums sit ([DrumPads]): a ring in three
## corners, clear of the safe area and the corner menu, and which a tap hits.

const SCREEN := Vector2(1152.0, 648.0)


func test_kick_bottom_left_snare_bottom_right_hat_top_right() -> void:
	var kick := DrumPads.centre(DrumPads.Pad.KICK, SCREEN)
	var snare := DrumPads.centre(DrumPads.Pad.SNARE, SCREEN)
	var hat := DrumPads.centre(DrumPads.Pad.HAT, SCREEN)
	assert_lt(kick.x, SCREEN.x * 0.5, "Kick on the left")
	assert_gt(kick.y, SCREEN.y * 0.5, "Kick at the bottom")
	assert_gt(snare.x, SCREEN.x * 0.5, "Snare on the right")
	assert_gt(snare.y, SCREEN.y * 0.5, "Snare at the bottom")
	assert_gt(hat.x, SCREEN.x * 0.5, "Hat on the right")
	assert_lt(hat.y, SCREEN.y * 0.5, "Hat at the top")


func test_every_ring_is_on_screen_and_the_hat_clears_the_menu() -> void:
	var reach := DrumPads.radius(SCREEN)
	for pad in DrumPads.ALL:
		var at := DrumPads.centre(pad, SCREEN)
		assert_true(Rect2(Vector2.ZERO, SCREEN).grow(-reach).has_point(at), DrumPads.name_of(pad))
	var hat := DrumPads.centre(DrumPads.Pad.HAT, SCREEN)
	assert_gte(hat.y - reach, DrumPads.MENU_CLEARANCE, "Below the menu button")


func test_the_safe_area_pushes_the_rings_in() -> void:
	var insets := Vector4(40.0, 10.0, 50.0, 20.0)
	var plain := DrumPads.centre(DrumPads.Pad.KICK, SCREEN)
	var inset := DrumPads.centre(DrumPads.Pad.KICK, SCREEN, insets)
	assert_almost_eq(inset - plain, Vector2(40.0, -20.0), Vector2.ONE * 0.001, "In and up")
	var snare := DrumPads.centre(DrumPads.Pad.SNARE, SCREEN, insets)
	var plain_snare := DrumPads.centre(DrumPads.Pad.SNARE, SCREEN)
	assert_almost_eq(snare.x, plain_snare.x - 50.0, 0.001, "In from the right")


func test_a_tap_hits_the_ring_it_lands_in() -> void:
	for pad in DrumPads.ALL:
		var at := DrumPads.centre(pad, SCREEN)
		assert_eq(DrumPads.pad_at(at, SCREEN), pad, DrumPads.name_of(pad))
		var edge := at + Vector2.RIGHT * DrumPads.radius(SCREEN) * 1.1
		assert_eq(DrumPads.pad_at(edge, SCREEN), pad, "A thumb just outside still counts")
	assert_eq(DrumPads.pad_at(SCREEN * 0.5, SCREEN), -1, "The middle is no pad")

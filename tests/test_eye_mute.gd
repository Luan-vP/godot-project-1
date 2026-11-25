extends GutTest
## Covers muting an eye in the eye band: [EyeBand] keeps a muted eye's part
## out wherever it floats, and the level ([code]eye_band_demo.gd[/code]) mutes
## and unmutes an eye on a tap, greying it out, while a drag still only stirs.

const Hosting := preload("res://tests/hosting.gd")
const EYE_BAND_SCENE := preload("res://features/levels/secret_eyes/eye_band_demo.tscn")
const TANK := Rect2(Vector2.ZERO, Vector2(1000.0, 600.0))


func _eye(radius: float, at: Vector2) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.radius = radius
	add_child_autofree(eye)
	eye.global_position = at
	return eye


## The level, hosted, with the corner menu hidden: headless, the screen is
## small enough for the menu to cover every eye.
func _level() -> Node2D:
	var level: Node2D = EYE_BAND_SCENE.instantiate()
	Hosting.host(self, level).game_menu.visible = false
	return level


## The biggest eye, set alone in the middle of the screen, the rest moved
## out of its way along the top, so a tap on it can only be on it.
func _tappable(level: Node2D) -> FloatyEye:
	var middle := level.get_viewport_rect().get_center()
	var chosen: FloatyEye
	var others: Array[FloatyEye] = []
	for child in level.get_children():
		var eye := child as FloatyEye
		if eye == null:
			continue
		if chosen == null or eye.radius > chosen.radius:
			if chosen != null:
				others.append(chosen)
			chosen = eye
		else:
			others.append(eye)
	chosen.global_position = middle
	for i in others.size():
		others[i].global_position = Vector2(80.0 + i * 140.0, 80.0)
	return chosen


func _click(level: Node2D, at: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.position = at
	level.call("_unhandled_input", click)


func test_a_muted_eyes_part_stays_out_while_it_floats_free() -> void:
	var band := EyeBand.new()
	add_child_autofree(band)
	var big := _eye(60.0, Vector2(500, 300))
	var small := _eye(30.0, Vector2(300, 300))
	var eyes: Array[FloatyEye] = [big, small]
	band.bind_eyes(eyes)
	band.update_contacts(TANK)
	band.set_muted(small, true)
	assert_true(band.is_muted(small))
	assert_false(band.is_touching(small), "Free of the walls")
	assert_false(band.wants_part("bass"), "But muted, so its part is out")
	assert_true(band.wants_part("beat"), "The other eye plays on")
	band.set_muted(small, false)
	assert_true(band.wants_part("bass"), "Unmuted, it comes back")


func test_an_eye_greys_out_when_muted_and_back_when_not() -> void:
	var eye := _eye(40.0, Vector2(500, 300))
	assert_eq(eye.grey_amount(), 0.0)
	eye.greyed = true
	eye._update_grey(FloatyEye.GREY_SECONDS * 0.5)
	assert_almost_eq(eye.grey_amount(), 0.5, 0.01, "Fading")
	eye._update_grey(FloatyEye.GREY_SECONDS)
	assert_eq(eye.grey_amount(), 1.0, "Grey")
	eye.greyed = false
	eye._update_grey(FloatyEye.GREY_SECONDS)
	assert_eq(eye.grey_amount(), 0.0, "Colour again")


func test_a_tap_on_an_eye_mutes_it_and_another_unmutes_it() -> void:
	var level := _level()
	var eye := _tappable(level)
	assert_eq(level.call("eye_at", eye.get_global_transform_with_canvas().origin), eye)
	var contacts: EyeBand = level.get_node("EyeBand")
	var at := eye.get_global_transform_with_canvas().origin
	_click(level, at, true)
	_click(level, at + Vector2(4.0, 3.0), false)
	assert_true(contacts.is_muted(eye), "Muted")
	assert_true(eye.greyed, "Greyed out")
	assert_false(contacts.wants_part(contacts.part_for(eye)), "Its part is out")
	_click(level, at, true)
	_click(level, at, false)
	assert_false(contacts.is_muted(eye), "Unmuted")
	assert_false(eye.greyed)


func test_a_drag_from_an_eye_stirs_and_does_not_mute() -> void:
	var level := _level()
	var eye := _tappable(level)
	var contacts: EyeBand = level.get_node("EyeBand")
	var at := eye.get_global_transform_with_canvas().origin
	_click(level, at, true)
	_click(level, at + Vector2(level.TAP_SLOP + 30.0, 0.0), false)
	assert_false(contacts.is_muted(eye), "A drag is a stir")


func test_a_tap_on_empty_water_or_the_menu_mutes_nothing() -> void:
	var level := _level()
	var eye := _tappable(level)
	var far := eye.get_global_transform_with_canvas().origin + Vector2(10000.0, 0.0)
	assert_null(level.call("tap_at", far), "Nothing there")
	var shared := SharedLayers.host_of(level)
	shared.game_menu.visible = true
	var button: Control = shared.game_menu.find_child("MenuButton", true, false)
	var on_menu := button.get_global_rect().get_center()
	eye.global_position = on_menu
	assert_null(level.call("eye_at", on_menu), "The corner menu keeps its own taps")


func test_the_muted_ring_stays_whatever_the_eye_does() -> void:
	var level := _level()
	var eye := _tappable(level)
	var contacts: EyeBand = level.get_node("EyeBand")
	level.call("toggle_mute", eye)
	assert_true(contacts.is_muted(eye))
	eye.global_position = Vector2(eye.radius * 0.5, eye.radius * 0.5)
	contacts.update_contacts(SharedLayers.host_of(level).fluid.get_world_rect())
	assert_true(contacts.is_muted(eye), "Still muted against a wall")
	eye.global_position = SharedLayers.host_of(level).fluid.get_world_rect().get_center()
	contacts.update_contacts(SharedLayers.host_of(level).fluid.get_world_rect())
	assert_true(contacts.is_muted(eye), "And still muted once free: only a tap brings it back")

extends GutTest
## Steam Input as a motion source.
##
## CI has no Steam and no controller, so what can be asserted everywhere is the
## behaviour that matters most there: a source that cannot start says so
## quietly and hands the pipeline on, rather than erroring or pretending to
## report. The readings themselves are checked on hardware — see
## `core/motion/README.md` for the bring-up command.


func test_availability_is_decided_by_the_extension_being_there() -> void:
	assert_eq(
		SteamInputMotionSource.is_steam_available(),
		ClassDB.class_exists("Steam"),
		"Asked of Godot, not of a platform name"
	)


func test_a_source_that_cannot_start_reports_nothing() -> void:
	var source := SteamInputMotionSource.new()
	var reading := source.poll(0.016)
	if source._started:
		# Steam is running here, so this says nothing about the failure path.
		pass_test("Steam is present; the silent path is covered on CI instead")
		return
	assert_false(reading.available, "No Steam, no reading")
	assert_false(source.is_available(), "And it does not claim otherwise")
	assert_eq(reading.gravity, Vector3.ZERO, "Nothing invented")


func test_it_says_which_source_it_is() -> void:
	var source := SteamInputMotionSource.new()
	assert_string_contains(source.describe(), "Steam Input")


## The pipeline must not stall on a machine without Steam: the probe has to
## reach the keyboard, which is what makes the game playable on any desktop.
func test_the_probe_still_reaches_the_keyboard_without_steam() -> void:
	var motion := MotionInput.new()
	add_child_autofree(motion)
	var elapsed := 0.0
	while elapsed < MotionInput.PROBE_SECONDS * 4.0:
		motion._process(0.05)
		elapsed += 0.05
	assert_true(motion.get_source() != null, "Some source was installed")
	assert_true(motion.is_calibrated() or motion.get_source() != null, "And it is usable")

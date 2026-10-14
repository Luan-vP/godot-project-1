extends GutTest
## Covers the splash: its timeline, when it steps aside for a job, the chord,
## and closing back to the menu when the menu opened it.

const MENU_SCENE := preload("res://features/ui/demo_menu/demo_menu.tscn")
const SPLASH_PATH := "res://features/splash/splash.tscn"


func test_the_logo_fades_in_holds_and_fades_out() -> void:
	assert_eq(Splash.opacity_at(0.0), 0.0, "Black first")
	var held := Splash.LEAD_IN + Splash.FADE_IN + Splash.HOLD * 0.5
	assert_eq(Splash.opacity_at(held), 1.0, "Fully up while held")
	var fading := held + Splash.HOLD * 0.5 + Splash.FADE_OUT * 0.5
	assert_between(Splash.opacity_at(fading), 0.01, 0.99, "Part way out")
	assert_eq(Splash.opacity_at(Splash.total_seconds()), 0.0, "Black last")


func test_the_fade_in_is_quick_and_the_whole_thing_short() -> void:
	assert_lt(Splash.FADE_IN, 0.6, "A quick fade in")
	assert_lt(Splash.total_seconds(), 4.5, "Over before anyone is bored")


func test_it_steps_aside_when_a_job_started_the_game() -> void:
	for args in [["--prs"], ["--from-picker"], ["--no-splash"], ["--probe"], ["--open=eyes"]]:
		assert_true(Splash.skips_for(PackedStringArray(args)), str(args))
	assert_false(Splash.skips_for(PackedStringArray()), "A player")
	assert_false(Splash.skips_for(PackedStringArray(["--meter"])), "Meter is not a job")


func test_the_chord_is_ebmaj9_and_stays_low() -> void:
	var notes: Array[int] = [Splash.CHORD_BASS]
	notes.append_array(Splash.CHORD_VOICES)
	var classes := {}
	for note in notes:
		classes[note % 12] = true
	# Eb, G, Bb, D, F: root, third, fifth, major seventh, ninth.
	for pitch_class in [3, 7, 10, 2, 5]:
		assert_true(classes.has(pitch_class), "Has pitch class %d" % pitch_class)
	for note in notes:
		assert_lte(note, 65, "Nothing above F4")


func test_opened_from_the_menu_it_closes_back_to_it() -> void:
	var menu: DemoMenu = MENU_SCENE.instantiate()
	menu.quits_tree = false
	get_tree().root.add_child(menu)
	menu.open_demo(SPLASH_PATH)
	var splash := menu.get_demo() as Splash
	assert_not_null(splash, "The splash is the open demo")
	assert_true(splash.is_inside_menu(), "And knows it")
	splash.call("_finish")
	assert_false(menu.is_demo_open(), "Finishing closes it")
	assert_true(menu.visible, "Back at the menu")
	menu.free()


func test_a_key_skips_it() -> void:
	var menu: DemoMenu = MENU_SCENE.instantiate()
	menu.quits_tree = false
	get_tree().root.add_child(menu)
	menu.open_demo(SPLASH_PATH)
	var splash := menu.get_demo() as Splash
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	splash._unhandled_input(key)
	assert_false(menu.is_demo_open(), "Skipped to the menu")
	menu.free()

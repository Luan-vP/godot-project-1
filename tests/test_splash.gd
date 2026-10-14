extends GutTest
## Covers the fluid splash: its timeline, when it steps aside for a job, the
## logo printed as pigment, the swipe, and closing back to the menu when the
## menu opened it.

const MENU_SCENE := preload("res://features/ui/demo_menu/demo_menu.tscn")
const SPLASH_PATH := "res://features/splash/splash.tscn"


func test_the_tank_comes_up_holds_and_goes_back_to_black() -> void:
	var stir := 1.4
	assert_eq(Splash.visibility_at(0.0, stir), 0.0, "Black first")
	var still := Splash.LEAD_IN + Splash.REVEAL + Splash.HOLD * 0.5
	assert_eq(Splash.visibility_at(still, stir), 1.0, "Up while the logo is still")
	assert_eq(Splash.visibility_at(Splash.total_seconds(stir), stir), 0.0, "Black last")


func test_it_leaves_the_water_a_few_seconds_to_settle() -> void:
	assert_gte(Splash.SETTLE, 2.5, "A few seconds to dissolve")
	assert_lt(Splash.total_seconds(1.4), 8.0, "Still short")


func test_it_steps_aside_when_a_job_started_the_game() -> void:
	for args in [["--prs"], ["--from-picker"], ["--no-splash"], ["--probe"], ["--open=eyes"]]:
		assert_true(Splash.skips_for(PackedStringArray(args)), str(args))
	assert_false(Splash.skips_for(PackedStringArray()), "A player")


func test_the_logo_is_printed_as_gold_pigment_where_it_is_and_nowhere_else() -> void:
	var screen := Vector2(1280, 800)
	var grid := Vector2i(128, 128)
	var rect := Splash.logo_rect_for(screen)
	var dye := Splash.logo_dye(Splash.LOGO.get_image(), rect, screen, grid)
	assert_eq(dye.get_size(), grid, "The tank's grid")
	assert_eq(dye.get_format(), Image.FORMAT_RGBAH, "The field's format")
	assert_eq(dye.get_pixel(0, 0).a, 0.0, "Nothing in the corner")
	var densest := Color(0, 0, 0, 0)
	for y in grid.y:
		for x in grid.x:
			var cell := dye.get_pixel(x, y)
			if cell.a > densest.a:
				densest = cell
	assert_almost_eq(densest.a, Splash.DENSITY, 0.05, "Solid where the logo is")
	var hue := Color(densest.r / densest.a, densest.g / densest.a, densest.b / densest.a)
	assert_almost_eq(hue.r, Splash.GOLD.r, 0.02, "Gold, premultiplied")
	assert_almost_eq(hue.b, Splash.GOLD.b, 0.02, "Gold, premultiplied")


func test_the_logo_sits_in_the_middle() -> void:
	var rect := Splash.logo_rect_for(Vector2(1280, 800))
	assert_almost_eq(rect.get_center().x, 640.0, 0.5)
	assert_almost_eq(rect.get_center().y, 400.0, 0.5)


func test_the_swipe_crosses_the_logo_left_to_right() -> void:
	var swipe := SwipeAgitation.new()
	var logo := Rect2(400, 200, 480, 420)
	assert_lt(swipe.hand_x(0.0, logo), logo.position.x, "Starts left of it")
	assert_gt(swipe.hand_x(swipe.seconds, logo), logo.end.x, "Ends right of it")
	var last := -INF
	for i in 11:
		var x := swipe.hand_x(swipe.seconds * i / 10.0, logo)
		assert_gte(x, last, "Only ever rightwards")
		last = x


func test_opened_from_the_menu_it_closes_back_to_it() -> void:
	var menu: DemoMenu = MENU_SCENE.instantiate()
	menu.quits_tree = false
	get_tree().root.add_child(menu)
	menu.open_demo(SPLASH_PATH)
	var splash := menu.get_demo() as Splash
	assert_not_null(splash, "The splash is the open demo")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	splash._unhandled_input(key)
	assert_false(menu.is_demo_open(), "A key skips back to the menu")
	assert_true(menu.visible, "Showing")
	menu.free()

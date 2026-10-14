extends GutTest
## Covers the fluid splash: its timeline, when it steps aside for a job, the
## logo printed as pigment, the swipe and the swirl, and closing back to the
## menu when the menu opened it.

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


func test_the_lockup_is_printed_in_its_own_colours_where_it_is_and_nowhere_else() -> void:
	var screen := Vector2(1280, 800)
	var grid := Vector2i(128, 128)
	var rect := Splash.logo_rect_for(screen)
	var dye := Splash.logo_dye(Splash.LOGO.get_image(), rect, screen, grid)
	assert_eq(dye.get_size(), grid, "The tank's grid")
	assert_eq(dye.get_format(), Image.FORMAT_RGBAH, "The field's format")
	assert_eq(dye.get_pixel(0, 0).a, 0.0, "Nothing in the corner")
	var gold := 0
	var white := 0
	for y in grid.y:
		for x in grid.x:
			var cell := dye.get_pixel(x, y)
			if cell.a < Splash.DENSITY * 0.9:
				continue
			var hue := Color(cell.r / cell.a, cell.g / cell.a, cell.b / cell.a)
			if hue.r > 0.9 and hue.b > 0.9:
				white += 1
			elif absf(hue.r - Splash.GOLD.r) < 0.04 and absf(hue.b - Splash.GOLD.b) < 0.04:
				gold += 1
	assert_gt(gold, 0, "The shell, and ENGINEERING, in gold")
	assert_gt(white, 0, "GOLDEN RULE in white")


func test_the_lockup_sits_in_the_middle_and_fits() -> void:
	for screen in [Vector2(1280, 800), Vector2(540, 960), Vector2(1920, 1080)]:
		var rect := Splash.logo_rect_for(screen)
		assert_almost_eq(rect.get_center().x, screen.x * 0.5, 0.5, "Centred across %s" % screen)
		assert_almost_eq(rect.get_center().y, screen.y * 0.5, 0.5, "Centred down %s" % screen)
		assert_true(Rect2(Vector2.ZERO, screen).encloses(rect), "On screen at %s" % screen)


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


func test_the_splash_swirls() -> void:
	assert_true(Splash.new().agitation is SwirlAgitation)


func test_the_swirl_swells_and_eases_off() -> void:
	var swirl := SwirlAgitation.new()
	assert_almost_eq(swirl.swell(0.0), 0.0, 0.001, "Gentle start")
	assert_almost_eq(swirl.swell(swirl.seconds * 0.5), 1.0, 0.001, "Peak midway")
	assert_almost_eq(swirl.swell(swirl.seconds), 0.0, 0.001, "Gentle end")


func test_the_swirl_pushes_round_the_centre_harder_further_out() -> void:
	var swirl := SwirlAgitation.new()
	var tank := PushRecorder.new()
	autofree(tank)
	var logo := Rect2(400, 200, 480, 420)
	swirl.stir(tank, swirl.seconds * 0.5, 1.0 / 60.0, logo)
	assert_eq(tank.pushes.size(), swirl.points * swirl.rings.size(), "Every point of every ring")
	var inner := INF
	var outer := 0.0
	for push in tank.pushes:
		var radial: Vector2 = push[0] - logo.get_center()
		var along: Vector2 = push[1]
		assert_almost_eq(radial.normalized().dot(along.normalized()), 0.0, 0.001, "Along the ring")
		if radial.length() < logo.size.y * 0.25:
			inner = minf(inner, along.length())
		else:
			outer = maxf(outer, along.length())
	assert_lt(inner, outer, "Harder further out")


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


func test_a_full_probe_leaves_the_splash_out() -> void:
	var options := DemoMenu.launch_options(PackedStringArray(["--probe"]))
	for demo: Dictionary in options["probe"]:
		assert_ne(demo["name"], "Splash", "Not probed")
	var named := DemoMenu.launch_options(PackedStringArray(["--probe=splash"]))
	assert_eq((named["probe"] as Array).size(), 1, "Unless asked for by name")


## Records the pushes it is given instead of running a solve.
class PushRecorder:
	extends FluidSimulation

	var pushes: Array = []

	func add_velocity_impulse(
		world_position: Vector2, world_acceleration: Vector2, _radius: float, _duration: float
	) -> void:
		pushes.append([world_position, world_acceleration])

class_name Splash
extends Control
## The studio logo printed into a fluid tank: it appears still, then time
## starts, the water is stirred ([member agitation]) and the logo drifts apart
## and dissolves, and the demo menu takes over.
##
## This is [code]run/main_scene[/code], so it is the first thing the game
## shows. Any key, pad button or tap skips straight to the menu. It steps
## aside entirely when the game is started for a job rather than a player
## ([method skips_for]): the pull request picker's handoff, a probe, or a
## demo opened from the command line, all of which the menu reads itself.
## It also steps aside where there is no compute device to run the tank.
##
## Opened from the demo menu's own list, it plays the same way and then closes
## back to the menu instead of replacing it.

## Emitted when the splash is over and the menu is about to take the screen.
signal finished

const MENU_PATH := "res://features/ui/demo_menu/demo_menu.tscn"
## The full lockup: the shell, GOLDEN RULE and ENGINEERING, in the brand's
## gold with the black lettering turned white for a black screen.
const LOGO := preload("res://features/splash/logo.png")

## The logo's own gold.
const GOLD := Color(0.718, 0.541, 0.282)
## How much pigment the logo is printed with. Enough to read as solid colour
## before it thins.
const DENSITY := 1.6

## The timeline, in seconds: black, the tank coming up out of black with the
## logo still in it, held still, stirred (as long as [member agitation] says),
## left to settle, and faded back to black.
const LEAD_IN := 0.2
const REVEAL := 0.6
const HOLD := 1.0
const SETTLE := 3.2
const FADE_OUT := 0.7

## The lockup's width, as a share of the screen's width, and the most of the
## screen's height it may take.
const LOGO_SCALE := 0.62
const LOGO_MAX_HEIGHT := 0.6
## Grid cells across the tank. The finest the solver takes, so the lines
## between the logo's chambers survive the printing.
const RESOLUTION := 512
## How much pigment survives each second once time starts; held at 1 (none
## lost) until then, so the logo stays crisp while it is still.
const SETTLE_RETENTION := 0.6
## The gentle drift the water has once time starts; none before.
const DRIFT := 10.0
## Curl kept in the stirred water. Lower than the levels' tanks: at this
## resolution a hand-sized push with their curl runs away.
const VORTICITY := 10.0

## Command-line arguments (after [code]--[/code]) that mean a job, not a
## player, started the game. The menu handles each of them.
const JOB_ARGS: Array[String] = ["--prs", "--from-picker", "--no-splash", "--probe"]
const JOB_PREFIXES: Array[String] = ["--open=", "--probe="]

## How the water is stirred once time starts.
@export var agitation: SplashAgitation = SwipeAgitation.new()

var fluid: FluidSimulation
var _config: FluidConfig
var _curtain: ColorRect
var _logo_rect: Rect2
var _time := 0.0
var _flowing := false
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Both lists, as the menu reads them: the iOS launch path passes its
	# options without a separator, so they arrive as engine arguments.
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	# No compute device (the Compatibility renderer), no tank: only black to
	# show, so straight on to the menu.
	if not FluidGPU.is_available() or (not is_inside_menu() and skips_for(args)):
		_finish.call_deferred()
		return
	var screen := get_viewport_rect().size
	_logo_rect = logo_rect_for(screen)
	_build_tank(screen)
	fluid.stamp_dye(logo_dye(LOGO.get_image(), _logo_rect, screen, _config.simulation_size()))

	# Black over everything, lifted to reveal the tank and lowered at the end.
	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.color = Color.BLACK
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _curtain != null:
		_curtain.color.a = 1.0 - visibility_at(_time, agitation.seconds)
	var stir_from := LEAD_IN + REVEAL + HOLD
	if not _flowing and _time >= stir_from:
		_start_time()
	var t := _time - stir_from
	if _flowing and t < agitation.seconds:
		agitation.stir(fluid, t, delta, _logo_rect)
	if _time >= total_seconds(agitation.seconds):
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var click := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var skip := (
		(key != null and key.pressed and not key.echo)
		or (pad != null and pad.pressed)
		or (click != null and click.pressed)
		or (touch != null and touch.pressed)
	)
	if skip:
		get_viewport().set_input_as_handled()
		_finish()


## The whole splash, in seconds, for a stir [param stir_seconds] long.
static func total_seconds(stir_seconds: float) -> float:
	return LEAD_IN + REVEAL + HOLD + stir_seconds + SETTLE + FADE_OUT


## How much of the tank shows through the black [param seconds] in, 0 to 1.
static func visibility_at(seconds: float, stir_seconds: float) -> float:
	var t := seconds - LEAD_IN
	if t <= 0.0:
		return 0.0
	if t < REVEAL:
		return ease(t / REVEAL, 0.6)
	var fade_from := REVEAL + HOLD + stir_seconds + SETTLE
	if t < fade_from:
		return 1.0
	return 1.0 - clampf((t - fade_from) / FADE_OUT, 0.0, 1.0)


## Where the lockup sits on a [param screen]-sized tank: centred, a share of
## the width, but never taller than a share of the height.
static func logo_rect_for(screen: Vector2) -> Rect2:
	var aspect := float(LOGO.get_height()) / LOGO.get_width()
	var width := minf(screen.x * LOGO_SCALE, screen.y * LOGO_MAX_HEIGHT / aspect)
	var height := width * aspect
	var size := Vector2(width, height)
	return Rect2((screen - size) * 0.5, size)


## The pigment field that prints [param logo] at [param rect] in a tank
## [param world] pixels wide and [param grid] cells across: each pixel's own
## colour as pigment, as much as it is opaque, premultiplied as the field is.
static func logo_dye(logo: Image, rect: Rect2, world: Vector2, grid: Vector2i) -> Image:
	var cell := world / Vector2(grid)
	var from := Vector2i((rect.position / cell).round())
	var span := Vector2i((rect.size / cell).round()).max(Vector2i.ONE)
	var shape := logo.duplicate() as Image
	shape.convert(Image.FORMAT_RGBA8)
	shape.resize(span.x, span.y, Image.INTERPOLATE_LANCZOS)

	var stamp := Image.create_empty(span.x, span.y, false, Image.FORMAT_RGBAF)
	for y in span.y:
		for x in span.x:
			var colour := shape.get_pixel(x, y)
			var density := colour.a * DENSITY
			var pigment := Color(
				colour.r * density, colour.g * density, colour.b * density, density
			)
			stamp.set_pixel(x, y, pigment)

	var field := Image.create_empty(grid.x, grid.y, false, Image.FORMAT_RGBAF)
	field.blit_rect(stamp, Rect2i(Vector2i.ZERO, span), from)
	field.convert(Image.FORMAT_RGBAH)
	return field


## Whether command-line [param args] mean a job started the game, so the
## splash should go straight to the menu.
static func skips_for(args: PackedStringArray) -> bool:
	for arg in args:
		if JOB_ARGS.has(arg):
			return true
		for prefix in JOB_PREFIXES:
			if arg.begins_with(prefix):
				return true
	return false


## Whether the demo menu opened this, rather than the game starting on it.
func is_inside_menu() -> bool:
	return _menu() != null


func _menu() -> DemoMenu:
	for child in get_tree().root.get_children():
		if child is DemoMenu:
			return child
	return null


func _build_tank(screen: Vector2) -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	_config = FluidConfig.new()
	_config.world_size = screen
	_config.simulation_resolution = RESOLUTION
	_config.readback_enabled = false
	# Still until time starts: no drift, and nothing fades.
	_config.ambient_current = 0.0
	_config.dye_dissipation = 1.0
	_config.vorticity = VORTICITY
	fluid = FluidSimulation.new()
	fluid.name = "Fluid"
	fluid.config = _config
	add_child(fluid)

	# Gold on black, like the logo itself, rather than the levels' violet paper.
	var style := PainterlyStyle.new()
	style.paper_color = Color.BLACK
	style.deep_color = Color.BLACK
	# Equal absorption, so the gold thins to a darker gold, not to olive.
	style.absorption = Vector3(1.3, 1.3, 1.3)
	var renderer := FluidRenderer.new()
	renderer.name = "FluidRenderer"
	renderer.style = style
	add_child(renderer)
	renderer.simulation_path = renderer.get_path_to(fluid)


func _start_time() -> void:
	_flowing = true
	_config.ambient_current = DRIFT
	_config.dye_dissipation = SETTLE_RETENTION


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	var menu := _menu()
	if menu != null:
		menu.close_demo()
	else:
		get_tree().change_scene_to_file(MENU_PATH)

class_name Splash
extends Control
## The studio logo printed into a fluid tank: it appears still, on a jazzy
## chord, then time
## starts, the water is swirled slowly ([member agitation]) and the logo winds
## into a spiral and dissolves, and the fluid carousel takes over, opened
## from the demo menu so that Backspace (or the corner button) leaves it for
## the menu.
##
## This is [code]run/main_scene[/code], so it is the first thing the game
## shows after Godot's own boot splash. Any key, pad button or tap skips
## straight to the carousel. It steps aside entirely when the game is started
## for a job rather than a player ([method skips_for]): the pull request
## picker's handoff, a probe, or a demo opened from the command line, all of
## which the menu reads itself, so those land on the menu. So does a device
## with no compute to run the tank, since the carousel needs one too.
##
## The tank is the game's one tank, the [code]Tank[/code] autoload, which
## the splash is usually the first to use and so starts. It does not fade to
## black at the end: the carousel takes the same water over, the logo's last
## swirls and all, and the black paper eases into the levels' own.
##
## Opened from the demo menu's own list, it plays the same way, wiping the
## tank first, and then fades out and closes back to the menu instead.

## Emitted when the splash is over and the menu is about to take the screen.
signal finished

const MENU_PATH := "res://features/ui/demo_menu/demo_menu.tscn"
## What a player lands on once the splash is over.
const START_PATH := "res://features/levels/carousel/fluid_carousel.tscn"
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
## left to settle, and (only when going back to the menu) faded back to black.
## Handing the tank to the carousel it does not wait for the stir to end: the
## carousel takes over [constant HANDOVER_STIR] of the way through it, just
## past the swirl's peak, so the logo winds into its spiral and dissolves
## under the first level rather than before it.
const LEAD_IN := 0.2
const REVEAL := 0.6
const HOLD := 1.0
const SETTLE := 3.2
const HANDOVER_STIR := 0.6
const FADE_OUT := 0.7

## The lockup's width, as a share of the screen's width, and the most of the
## screen's height it may take.
const LOGO_SCALE := 0.62
const LOGO_MAX_HEIGHT := 0.6
## How much pigment survives each second once time starts; held at 1 (none
## lost) until then, so the logo stays crisp while it is still.
const SETTLE_RETENTION := 0.6
## The grid the splash's brushwork was tuned on. On a coarser tank its brush
## is narrowed to match, so the lettering keeps its edges.
const BRUSH_RESOLUTION := 512.0
## The gentle drift the water has once time starts; none before.
const DRIFT := 10.0
## Curl kept in the stirred water. Lower than the levels' tanks: with their
## curl a push this broad runs away.
const VORTICITY := 10.0

## E-flat major 9, voiced warm and low, as MIDI notes: the root alone in the
## bass (Eb2), then the fifth, third, major seventh and ninth over it (Bb2, G3,
## D4, F4). Nothing above F4, so it is a chord, not a chime.
const CHORD_BASS := 39
const CHORD_VOICES: Array[int] = [46, 55, 62, 65]
## Seconds between each voice of the strum, low to high.
const STRUM := 0.045
## How long the keys are held before they are let go to ring out.
const CHORD_HOLD := 1.2

## Command-line arguments (after [code]--[/code]) that mean a job, not a
## player, started the game. The menu handles each of them.
const JOB_ARGS: Array[String] = ["--prs", "--from-picker", "--no-splash", "--probe"]
const JOB_PREFIXES: Array[String] = ["--open=", "--probe="]

## How the water is stirred once time starts.
@export var agitation: SplashAgitation = SwirlAgitation.new()

var fluid: FluidSimulation
var _curtain: ColorRect
var _keys: Synth
var _pad: Synth
var _logo_rect: Rect2
var _time := 0.0
var _flowing := false
var _done := false
## Whether it goes back to black at the end: only when going back to the menu.
var _fades_out := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Both lists, as the menu reads them: the iOS launch path passes its
	# options without a separator, so they arrive as engine arguments.
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	# No compute device (the Compatibility renderer), no tank: only black to
	# show, so straight on to the menu.
	if not FluidGPU.is_available() or (not is_inside_menu() and skips_for(args)):
		_finish.call_deferred(false)
		return
	_fades_out = is_inside_menu()
	var screen := get_viewport_rect().size
	_logo_rect = logo_rect_for(screen)
	_take_tank()
	var grid := fluid.config.simulation_size()
	fluid.stamp_dye(logo_dye(LOGO.get_image(), _logo_rect, fluid.config.world_size, grid))

	# Black over everything, lifted to reveal the tank and lowered at the end.
	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.color = Color.BLACK
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)
	_build_synths()


func _process(delta: float) -> void:
	if _done:
		return
	var was := _time
	_time += delta
	if was < LEAD_IN and _time >= LEAD_IN:
		_play_chord()
	if _curtain != null:
		_curtain.color.a = 1.0 - visibility_at(_time, agitation.seconds)
	var stir_from := LEAD_IN + REVEAL + HOLD
	if not _flowing and _time >= stir_from:
		_start_time()
	var t := _time - stir_from
	if _flowing and t < agitation.seconds:
		agitation.stir(fluid, t, delta, _logo_rect)
	if _time >= total_seconds(agitation.seconds, _fades_out):
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


## The whole splash, in seconds, for a stir [param stir_seconds] long: going
## back to the menu, settled and faded to black ([param fades_out]), or else
## handed to the carousel part way through the stir.
static func total_seconds(stir_seconds: float, fades_out := true) -> float:
	if not fades_out:
		return LEAD_IN + REVEAL + HOLD + stir_seconds * HANDOVER_STIR
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


## Take the game's tank, still, wiped and on black paper, for the logo.
func _take_tank() -> void:
	# Still until time starts: no drift, nothing fades, and no readback, since
	# nothing here floats on it.
	var still := FluidConfig.new()
	still.ambient_current = 0.0
	still.dye_dissipation = 1.0
	still.vorticity = VORTICITY
	still.readback_enabled = false
	# Gold on black, like the logo itself, rather than the levels' violet paper.
	var look := PainterlyStyle.new()
	look.paper_color = Color.BLACK
	look.deep_color = Color.BLACK
	# Equal absorption, so the gold thins to a darker gold, not to olive.
	look.absorption = Vector3(1.3, 1.3, 1.3)
	# The brush is measured in grid cells; keep it the width on screen it was
	# tuned at, so the lettering stays clean on a coarser grid.
	var fine := float(Tank.RESOLUTION) / BRUSH_RESOLUTION
	look.stroke_size *= fine
	look.wobble *= fine
	look.edge_width *= fine
	fluid = Tank.acquire(self, still, look)
	Tank.set_look(look, 0.0)
	# Whatever an earlier level left in it goes, so the logo prints clean.
	fluid.reset()
	fluid.set_current_bias(Vector2.ZERO)


func _build_synths() -> void:
	# Electric-piano keys: a sine struck fast and left to ring.
	var keys := SynthPatch.new()
	keys.waveform = SynthWavetable.Waveform.SINE
	keys.attack_seconds = 0.008
	keys.release_seconds = 2.2
	keys.level = 0.08
	_keys = Synth.new()
	_keys.name = "Keys"
	_keys.patch = keys
	_keys.polyphony = 8
	add_child(_keys)

	# A soft square underneath, swelling in, for warmth.
	var pad := SynthPatch.new()
	pad.waveform = SynthWavetable.Waveform.SQUARE
	pad.attack_seconds = 0.35
	pad.release_seconds = 1.6
	pad.level = 0.025
	_pad = Synth.new()
	_pad.name = "Pad"
	_pad.patch = pad
	_pad.polyphony = 8
	add_child(_pad)


func _play_chord() -> void:
	if _keys == null:
		return
	var notes: Array[int] = [CHORD_BASS]
	notes.append_array(CHORD_VOICES)
	for i in notes.size():
		var hz := Band.midi_to_hz(notes[i])
		if i == 0:
			_strike(hz)
		else:
			get_tree().create_timer(STRUM * i).timeout.connect(_strike.bind(hz))
	get_tree().create_timer(CHORD_HOLD).timeout.connect(_let_go)


func _strike(hz: float) -> void:
	if _done or _keys == null:
		return
	_keys.note_on(hz, 0.9)
	_pad.note_on(hz, 0.7)


func _let_go() -> void:
	if is_instance_valid(_keys):
		_keys.release_all()
		_pad.release_all()


func _start_time() -> void:
	_flowing = true
	fluid.config.ambient_current = DRIFT
	fluid.config.dye_dissipation = SETTLE_RETENTION


## Hand over: back to the menu that opened this, or else to a new menu,
## opening the carousel in front of it when [param to_carousel].
func _finish(to_carousel := true) -> void:
	if _done:
		return
	_done = true
	finished.emit()
	var menu := _menu()
	if menu != null:
		menu.close_demo()
		return
	var tree := get_tree()
	menu = (load(MENU_PATH) as PackedScene).instantiate() as DemoMenu
	if to_carousel:
		menu.start_demo = START_PATH
	tree.root.add_child(menu)
	tree.current_scene = menu
	queue_free()

class_name Splash
extends Control
## The studio logo on black: a quick fade in on a jazzy chord, a moment held,
## a fade out, then the demo menu.
##
## This is [code]run/main_scene[/code], so it is the first thing the game
## shows. Any key, pad button or tap skips straight to the menu. It steps
## aside entirely when the game is started for a job rather than a player
## ([method skips_for]): the pull request picker's handoff, a probe, or a
## demo opened from the command line, all of which the menu reads itself.
##
## Opened from the demo menu's own list, it plays the same way and then closes
## back to the menu instead of replacing it.

## Emitted when the splash is over and the menu is about to take the screen.
signal finished

const MENU_PATH := "res://features/ui/demo_menu/demo_menu.tscn"
const LOGO := preload("res://features/splash/logo.png")

## The timeline, in seconds: black, fade in, held, fade out, black.
const LEAD_IN := 0.3
const FADE_IN := 0.45
const HOLD := 1.8
const FADE_OUT := 0.9
const LEAD_OUT := 0.25

## The logo's width, as a share of the screen's shorter side.
const LOGO_SCALE := 0.42

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

var _logo: TextureRect
var _keys: Synth
var _pad: Synth
var _time := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not is_inside_menu() and skips_for(OS.get_cmdline_user_args()):
		_finish.call_deferred()
		return
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)

	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.modulate.a = 0.0
	add_child(_logo)
	_fit_logo()
	get_viewport().size_changed.connect(_fit_logo)

	_build_synths()


func _process(delta: float) -> void:
	if _done:
		return
	var was := _time
	_time += delta
	if was < LEAD_IN and _time >= LEAD_IN:
		_play_chord()
	if _logo != null:
		_logo.modulate.a = opacity_at(_time)
	if _time >= total_seconds():
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


## The whole splash, in seconds.
static func total_seconds() -> float:
	return LEAD_IN + FADE_IN + HOLD + FADE_OUT + LEAD_OUT


## How visible the logo is [param seconds] into the splash, 0 to 1.
static func opacity_at(seconds: float) -> float:
	var t := seconds - LEAD_IN
	if t <= 0.0:
		return 0.0
	if t < FADE_IN:
		return ease(t / FADE_IN, 0.5)
	t -= FADE_IN
	if t < HOLD:
		return 1.0
	t -= HOLD
	if t < FADE_OUT:
		return 1.0 - ease(t / FADE_OUT, 2.0)
	return 0.0


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


func _fit_logo() -> void:
	var screen := get_viewport_rect().size
	var width := minf(screen.x, screen.y) * LOGO_SCALE
	var height := width * LOGO.get_height() / LOGO.get_width()
	_logo.size = Vector2(width, height)
	_logo.position = (screen - _logo.size) * 0.5


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
	if _keys != null:
		_keys.release_all()
		_pad.release_all()


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

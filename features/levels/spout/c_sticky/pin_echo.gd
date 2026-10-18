class_name PinEcho
extends Node2D
## Version C's delay. Every pin played comes back twice more, softer each
## time, after the pins' recharge: a popped pin returns on the next bar line,
## so the delay is a bar ([member delay_bars]). An echo keeps its sixteenth,
## so the bar's phrase loops whole, in time with the band, at half and then a
## quarter of its strength ([constant ECHO_LEVELS]). It replays the note that
## was played, even if the pins have scrolled to a new key since.
##
## Each bar's phrase is drawn as a constellation: a star where every pin
## played, joined in the order they played. When the bar ends it lifts off
## the pins and drifts up over them, carried a little by the current, a star
## twinkling as its echo sounds. After the last loop it is printed into the
## water as pigment ([DyePrint]) and the ghost fades out over it, leaving the
## shape to swirl away with the tank.
##
## [StickyBallEmitter] owns one: it calls [method record] for every pin it
## plays and [method tick] as the music moves.

## Emitted for every echo that sounds; [param repeat] is 1 for the first.
signal echoed(note: int, strength: float, repeat: int)

## How loud each echo is, against the note it repeats: as many loops as
## there are entries.
const ECHO_LEVELS: Array[float] = [0.5, 0.25]
## How far a constellation rises in a bar, in pixels.
const RISE_PER_BAR := 90.0
## How much of the current at its middle a constellation drifts with.
const CURRENT_SHARE := 0.4
## Seconds the ghost takes to fade once its shape is in the water.
const FADE_SECONDS := 0.9
## Pigment at a printed star's centre, and the dots' and lines' radii.
const PRINT_DENSITY := 1.3
const PRINT_DOT := 9.0
const PRINT_LINE := 3.5
## How a star is drawn: its core, the glow round it, and the ring a twinkle
## throws out.
const STAR_RADIUS := 4.5
const GLOW_RADIUS := 14.0
const TWINKLE_RADIUS := 18.0
const TWINKLE_SECONDS := 0.5
## Seconds a note is held before it is let go to ring, as [PinField] does.
const HOLD_SECONDS := 0.04

## The pins it echoes, for their positions and loudness.
var pins: PinField
## The tank a finished constellation is printed into; none, and it only fades.
var fluid: FluidSimulation
## Bars between a note and its echo: the pins' recharge.
var delay_bars := 1

var _phrases: Array[Phrase] = []
var _echoes: Array[Echo] = []
var _synth: Synth
## Where the music was at the last [method tick], in bars.
var _now_bars := 0.0
var _sixteenths := 16


## One note played, as a star of the constellation.
class Star:
	var note: int
	var strength: float
	## Where its pin was, in this node's space, when it played.
	var at: Vector2
	var color: Color
	## 1 on a sound, easing to 0.
	var twinkle := 1.0


## A bar's notes.
class Phrase:
	var bar: int
	var stars: Array[Star] = []
	## How far it has risen and drifted since its bar ended.
	var drift := Vector2.ZERO
	var printed := false
	## 1 until it is printed, then down to 0, when it goes.
	var fade := 1.0


## A repeat waiting for its sixteenth.
class Echo:
	var due: int
	var star: Star
	var repeat: int


func _ready() -> void:
	z_index = 15
	# Added light, so the ghost glows over the pins and the water.
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	var patch := SynthPatch.new()
	patch.waveform = SynthWavetable.Waveform.SINE
	patch.attack_seconds = 0.006
	patch.release_seconds = 1.3
	patch.level = pins.pluck_level if pins != null else 0.2
	patch.glide_seconds = 0.0
	_synth = Synth.new()
	_synth.name = "EchoVoice"
	_synth.patch = patch
	_synth.polyphony = 16
	add_child(_synth)


func _process(delta: float) -> void:
	var seconds_per_bar := maxf(AudioManager.get_music_clock().seconds_per_bar(), 0.1)
	for phrase in _phrases.duplicate():
		for star in phrase.stars:
			star.twinkle = maxf(0.0, star.twinkle - delta / TWINKLE_SECONDS)
		if phrase.printed:
			phrase.fade -= delta / FADE_SECONDS
			if phrase.fade <= 0.0:
				_phrases.erase(phrase)
				continue
		if age_of(phrase) > 0.0:
			phrase.drift.y -= RISE_PER_BAR / seconds_per_bar * delta
			if fluid != null:
				phrase.drift += (
					fluid.sample_velocity(to_global(centre_of(phrase))) * CURRENT_SHARE * delta
				)
	queue_redraw()


## Echo [param note], played at [param strength] by the pin at
## [param at_global] on sixteenth [param sixteenth] (counted from the start
## of the music) of a bar of [param sixteenths_per_bar]: its repeats are
## queued, and it joins its bar's constellation.
func record(
	note: int, strength: float, at_global: Vector2, sixteenth: int, sixteenths_per_bar: int
) -> void:
	_sixteenths = maxi(1, sixteenths_per_bar)
	var bar := floori(float(sixteenth) / _sixteenths)
	var phrase := _phrase_for(bar)
	var star := Star.new()
	star.note = note
	star.strength = strength
	star.at = to_local(at_global)
	star.color = PinField.note_color(note, 1.0).lightened(0.25)
	phrase.stars.append(star)
	for i in ECHO_LEVELS.size():
		var echo := Echo.new()
		echo.due = sixteenth + (i + 1) * delay_bars * _sixteenths
		echo.star = star
		echo.repeat = i + 1
		_echoes.append(echo)


## Move the music on to [param now_bars], in bars of
## [param sixteenths_per_bar]: every echo whose sixteenth has come sounds,
## and every constellation whose last loop is over goes into the water.
func tick(now_bars: float, sixteenths_per_bar: int) -> void:
	_sixteenths = maxi(1, sixteenths_per_bar)
	_now_bars = now_bars
	var now := floori(now_bars * _sixteenths)
	for echo in _echoes.duplicate():
		if echo.due > now:
			continue
		_echoes.erase(echo)
		# One left far behind by a jump in the clock is dropped, not played late.
		if now - echo.due <= 1:
			_sound(echo)
	for phrase in _phrases:
		if not phrase.printed and age_of(phrase) >= ECHO_LEVELS.size() * delay_bars:
			print_phrase(phrase)


## The music started again: nothing waiting sounds, and every constellation
## still in the air goes into the water now.
func reset() -> void:
	_echoes.clear()
	for phrase in _phrases:
		if not phrase.printed:
			print_phrase(phrase)


## Bars since [param phrase]'s own bar ended: negative while it is still
## being played.
func age_of(phrase: Phrase) -> float:
	return _now_bars - (phrase.bar + 1)


## The middle of [param phrase]'s stars, where they are now.
func centre_of(phrase: Phrase) -> Vector2:
	var sum := Vector2.ZERO
	for star in phrase.stars:
		sum += star.at
	return sum / maxi(1, phrase.stars.size()) + phrase.drift


## Print [param phrase] into the tank where it is now, and start it fading.
func print_phrase(phrase: Phrase) -> void:
	phrase.printed = true
	if fluid == null or not is_instance_valid(fluid):
		return
	var world := fluid.get_world_rect()
	var points: Array[Vector2] = []
	var colors: Array[Color] = []
	for star in phrase.stars:
		points.append(to_global(star.at + phrase.drift) - world.position)
		colors.append(star.color)
	var grid := fluid.config.simulation_size()
	var picture := DyePrint.constellation(
		points, colors, world.size, grid, PRINT_DENSITY, PRINT_DOT, PRINT_LINE
	)
	if not picture.is_empty():
		fluid.add_dye(picture["dye"], picture["cell"])


func phrase_count() -> int:
	return _phrases.size()


func pending_count() -> int:
	return _echoes.size()


## The constellations, oldest first, for tests and the HUD.
func phrases() -> Array[Phrase]:
	return _phrases


func _phrase_for(bar: int) -> Phrase:
	for phrase in _phrases:
		if phrase.bar == bar:
			return phrase
	var phrase := Phrase.new()
	phrase.bar = bar
	_phrases.append(phrase)
	return phrase


func _sound(echo: Echo) -> void:
	var strength := echo.star.strength * ECHO_LEVELS[echo.repeat - 1]
	echo.star.twinkle = 1.0
	if _synth != null:
		var voice := _synth.note_on(Band.midi_to_hz(echo.star.note), strength)
		if voice != null and is_inside_tree():
			get_tree().create_timer(HOLD_SECONDS).timeout.connect(
				_release.bind(voice, voice.started_usec)
			)
	echoed.emit(echo.star.note, strength, echo.repeat)


func _release(voice: SynthVoice, started_usec: int) -> void:
	if is_instance_valid(voice) and voice.started_usec == started_usec:
		voice.note_off()


## How strongly [param phrase] shows: faint while it is being played, at its
## brightest as it lifts off, dimming with each loop, then fading out.
func _alpha(phrase: Phrase) -> float:
	var age := age_of(phrase)
	var loops := float(ECHO_LEVELS.size() * delay_bars)
	var shown := 0.45 if age < 0.0 else lerpf(0.85, 0.45, clampf(age / loops, 0.0, 1.0))
	return shown * clampf(phrase.fade, 0.0, 1.0)


func _draw() -> void:
	for phrase in _phrases:
		var alpha := _alpha(phrase)
		if alpha <= 0.0:
			continue
		for i in range(1, phrase.stars.size()):
			var a := phrase.stars[i - 1]
			var b := phrase.stars[i]
			var tint := a.color.lerp(b.color, 0.5)
			tint.a = alpha * 0.55
			draw_line(a.at + phrase.drift, b.at + phrase.drift, tint, 2.0, true)
		for star in phrase.stars:
			var at := star.at + phrase.drift
			var glow := star.color
			glow.a = alpha * (0.18 + 0.3 * star.twinkle)
			draw_circle(at, GLOW_RADIUS * (1.0 + 0.4 * star.twinkle), glow)
			var core := star.color.lightened(0.4 * star.twinkle)
			core.a = alpha
			draw_circle(at, STAR_RADIUS, core)
			if star.twinkle > 0.0:
				var ring := star.color
				ring.a = alpha * star.twinkle * 0.6
				draw_arc(
					at,
					TWINKLE_RADIUS * (1.0 - star.twinkle) + STAR_RADIUS,
					0.0,
					TAU,
					24,
					ring,
					1.2,
					true
				)

class_name BoidsLevel
extends Node2D
## Flocks over the eye tank's fluid, as an instrument (#90): waterboatmen or
## birds, by [member motion].
##
## [b]Rowing[/b] ([constant FlockSim.Motion.ROW], the Waterboatmen level):
## boatmen row in strokes and glides rather than flying. Boatmen in a flock row
## together on the flock's pulses and sing on the flock's rhythm — 3, 4 or 6
## pulses to a shared bar, so flocks play polyrhythms against each other — each
## with a voice of its own. Loners are silent.
##
## [b]Flying[/b] ([constant FlockSim.Motion.FLY], the Birds level): the
## original version, a sky of birds that fly continuously and sing the same
## way. Only the motion, the drawing and the strength of the wakes differ; the
## snare, the taps, the scatter and the music are shared.
##
## The player plays a snare (B, Esc, Space or a click; B on a gamepad).
## Every tap is read against every rhythm (see [TapReader]): flocks whose
## rhythm fits the last bar of taps tighten and pull loners in, and flocks that
## do not loosen and shed birds. Hold one rhythm unambiguously for long enough
## and every flock playing something else bursts apart (see [ScatterCharge]) —
## rare on purpose.
##
## The snare sounds the instant it is hit, and a quieter ghost of it lands a
## bar later on the pulse it was read as, so the player hears how they were
## heard. The dial in the corner shows the same thing: the bar going round,
## every rhythm's pulses, the last bar's taps, and the charge building.
##
## A foreground over the host's tank and band ([SharedLayers]). Birds and
## boatmen stir the tank as they move — each flock drags a broad wake through
## it and stains it faintly in its rhythm's colour — but the water never
## pushes back: the flocks move as if it were not there. See [BirdWakes].
##
## The music is the host's [Band]: its song keeps playing in full, and the
## flocks play over it, on its clock and in its key. A bird's voice is a step
## of the band's pentatonic ([method voice_note]), so a key move (L1/R1 or Q/E
## a fourth, Z/X a fifth — see [KeyShiftInput]) carries every flock with it.
## Tempo is [code]TempoControl[/code]'s, like everywhere else: the flocks, the
## pulses and the ghosts all run on [AudioManager]'s beats, so they follow a
## tempo change without knowing about it.
##
## See the README beside this file, and docs/boids-rhythm-scope.md for the
## design.

const BEATS_PER_BAR := 4
const BIRD_COUNT := 64

## A flock of each of these is already flying when the level opens, so the
## first bar is already 3-against-4.
const SEED_PULSES: Array[int] = [3, 4]

const SNARE := &"snare"

## Attraction weight a rhythm gets from a fit of 0 (after [constant FIT_FLOOR])
## up to a perfect one. See [method weight_for_fit].
const WEIGHT_LOW := 0.7
const WEIGHT_HIGH := 1.6

## Fits below this count as no fit at all. A clean 4 still fits 3 about 0.4
## and 6 about 0.55, just from sharing the downbeat and a pulse or two.
const FIT_FLOOR := 0.45

## Fraction of the gap to a new weight still left after a second: weights ease
## rather than jump as the reading changes tap to tap.
const WEIGHT_RETENTION := 0.12

const SNARE_DB := -3.0
const GHOST_DB := -17.0
## The kick under a scatter's crash.
const SCATTER_KICK_DB := -7.0
const CRASH_DB := -8.0

## Lowest note a voice can sing is the band's tonic at or above this, so the
## flocks sit in the same register whatever the key: E3 up to D#4.
const VOICE_FLOOR := 52

## A bird's note, held this long.
const NOTE_SECONDS := 0.16

## Birds are binned this many pixels across, and each occupied cell stirs the
## tank once — see [BirdWakes].
const WAKE_CELL := 110.0
## Acceleration a bird lends the water, per pixel/second of its own speed. A
## lone bird at full speed pushes about as hard as an eye does in its tank.
## Boatmen glide slower than the birds fly, so theirs is higher. See
## [method wake_gain].
const WAKE_GAIN_FLY := 6.0
const WAKE_GAIN_ROW := 9.0
## Cap on one cell's push, in pixels/second^2, so a packed flock swirls the
## water rather than blasting it.
const WAKE_MAX := 7000.0
## Gaussian radius of a wake: grows with the birds in it, from a lone bird's
## [constant WAKE_RADIUS] up to [constant WAKE_RADIUS_MAX].
const WAKE_RADIUS := 45.0
const WAKE_RADIUS_MAX := 110.0
## Pigment a flocked bird lays down per second, in its rhythm's colour. Faint:
## enough that the flocks' paths show in the wash, not enough to bury the seed
## colours. Loners lay none — at 64 pale birds they bleached the whole sky.
const WAKE_PAINT := 0.04
const LONER_COLOR := Color(0.86, 0.87, 0.93, 0.42)

## Seconds added to a tap before it is read, to cancel the time between
## hearing a pulse and a press registering. 0 until measured on a device.
@export var tap_offset_seconds: float = 0.0

## How the flocks move: rowed waterboatmen, or the original flying birds.
## Read once, when the level is ready.
@export var motion: FlockSim.Motion = FlockSim.Motion.ROW

var table: RhythmTable
var sim: FlockSim
var reader: TapReader
var charge: ScatterCharge

## The latest reading of the player's taps.
var reading: TapReader.Reading

var _rng := RandomNumberGenerator.new()
var _grid := 12
var _sequencer: StepSequencer
var _sequencer_tempo := 0.0
var _last_beats := -1.0
## Beats positions still waiting to play a ghost snare.
var _ghosts: Array[float] = []
## pulses -> weight, eased; mirrored into [member FlockSim.weights].
var _weights := {}
var _scatter_flash := 0.0
var _last_input := "nothing yet"
var _started := false

var _synths := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _snare_stream: AudioStreamWAV
var _kick_stream: AudioStreamWAV
var _crash_stream: AudioStreamWAV
var _key_shift := KeyShiftInput.new()

var _hud: Label
var _dial: Control
var _fluid: FluidSimulation
## The level's host: the tank to stir and the band to play over. See
## [SharedLayers].
var _shared: SharedLayers
var _band: Band


func _ready() -> void:
	# B on a keyboard or a gamepad, and whatever the Deck's B, Y and triggers
	# send when Steam keeps it in its Desktop Mode layout.
	InputActions.ensure(
		SNARE,
		[KEY_B, DeckDesktopLayout.B, DeckDesktopLayout.Y] as Array[Key],
		[JOY_BUTTON_B] as Array[JoyButton],
		[DeckDesktopLayout.R2, DeckDesktopLayout.L2] as Array[MouseButton]
	)
	_shared = SharedLayers.host_of(self)
	if _shared == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	_fluid = _shared.fluid
	_band = _shared.band
	# The snare has the triggers.
	_key_shift.use_triggers = false
	_rng.randomize()
	table = RhythmTable.default_table()
	_grid = table.grid_steps(BEATS_PER_BAR)
	reader = TapReader.new(BEATS_PER_BAR)
	charge = ScatterCharge.new()
	reading = reader.read(0.0, table)
	for pulses in table.pulse_counts():
		_weights[pulses] = 1.0
	sim = FlockSim.new(table, get_viewport_rect(), _rng)
	sim.beats_per_bar = BEATS_PER_BAR
	sim.motion = motion
	sim.populate(BIRD_COUNT, SEED_PULSES)
	_build_hud()
	start()


func _exit_tree() -> void:
	# The band and its clock are the host's and carry on to the next level.
	for synth in _synths.values():
		synth.release_all()


## Build the instruments and join the band. The band's clock is already
## running and the flocks follow whatever tempo it has; the song carries on
## under them with the whole arrangement, as in the spout.
func start() -> void:
	if _started:
		return
	_started = true
	_build_audio()
	for part in Band.PARTS:
		_band.set_part_wanted(part, true)


func _process(delta: float) -> void:
	var source := AudioManager.get_music_time_source()
	var beats := source.get_beats()
	var elapsed := 0.0 if _last_beats < 0.0 else maxf(beats - _last_beats, 0.0)
	_last_beats = beats

	reading = reader.read(beats, table)
	_ease_weights(delta)
	if charge.advance(elapsed, reading.winner, reading.unambiguous):
		_scatter(charge.winner)

	sim.bounds = get_viewport_rect()
	var step := minf(delta, 0.05)
	sim.step(step, beats)
	_stir(step)
	for bird in sim.birds:
		bird.glow = maxf(bird.glow - delta * 4.0, 0.0)
	_scatter_flash = maxf(_scatter_flash - delta * 1.5, 0.0)

	if source.is_running():
		_play_due(source, beats)
	queue_redraw()
	_dial.queue_redraw()
	_update_hud()


## Acceleration a bird lends the water per pixel/second of its speed, for the
## current [member motion].
func wake_gain() -> float:
	return WAKE_GAIN_FLY if motion == FlockSim.Motion.FLY else WAKE_GAIN_ROW


## Every press, before anything handles it, so the HUD can show what a device
## really sends — the Deck under a Steam Input desktop layout turns its buttons
## into keys and clicks.
func _input(event: InputEvent) -> void:
	var described := InputActions.describe(event)
	if not described.is_empty():
		_last_input = described


func _unhandled_input(event: InputEvent) -> void:
	var key_step := _key_shift.step_for(event)
	if key_step != 0:
		_band.set_key_offset(_band.get_key_offset() + key_step)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(SNARE) and not event.is_echo():
		get_viewport().set_input_as_handled()
		_play_one_shot(_snare_stream, SNARE_DB)
		var source := AudioManager.get_music_time_source()
		var seconds_per_beat := AudioManager.get_music_clock().seconds_per_beat()
		tap(source.get_beats() + tap_offset_seconds / seconds_per_beat)


## Read a snare hit at [param beats]: it joins the last bar of taps, and its
## ghost is queued a bar later on the pulse it reads as. Returns where the
## ghost will land, in beats.
func tap(beats: float) -> float:
	reader.add_tap(beats)
	reading = reader.read(beats, table)
	var pulses := reading.winner if reading.winner > 0 else table.min_pulses()
	var ghost := reader.quantise(beats, pulses) + BEATS_PER_BAR
	_ghosts.append(ghost)
	return ghost


## Attraction weight for a rhythm the taps fit [param fit] (0..1), before
## easing and before [member TapReader.Reading.confidence] scales it back
## towards neutral.
static func weight_for_fit(fit: float) -> float:
	return lerpf(WEIGHT_LOW, WEIGHT_HIGH, smoothstep(FIT_FLOOR, 1.0, fit))


func _ease_weights(delta: float) -> void:
	var keep := pow(WEIGHT_RETENTION, delta)
	for pulses in table.pulse_counts():
		var fit: float = reading.fits.get(pulses, 0.0)
		var target := lerpf(1.0, weight_for_fit(fit), reading.confidence)
		_weights[pulses] = lerpf(target, _weights[pulses], keep)
		sim.weights[pulses] = _weights[pulses]
		sim.spawn_bias[pulses] = fit * reading.confidence


func _scatter(survivor: int) -> void:
	var count := sim.scatter(survivor)
	if count == 0:
		return
	_scatter_flash = 1.0
	_play_one_shot(_crash_stream, CRASH_DB)
	_play_one_shot(_kick_stream, SCATTER_KICK_DB)


## Every grid step due now: the downbeat's soft kick, each flock's pulses, and
## any ghost snares.
func _play_due(source: MusicTimeSource, beats: float) -> void:
	var clock := AudioManager.get_music_clock()
	if _sequencer == null or clock.tempo_bpm != _sequencer_tempo:
		var grid_clock := MusicClock.new(clock.tempo_bpm, BEATS_PER_BAR, _grid / BEATS_PER_BAR)
		if _sequencer == null:
			_sequencer = StepSequencer.new(grid_clock)
		else:
			_sequencer.set_clock(grid_clock)
		_sequencer_tempo = clock.tempo_bpm
	var lookahead := clock.beats_from_seconds(source.get_lookahead())
	for step in _sequencer.update(beats, lookahead):
		var in_bar := step % _grid
		for flock in sim.flocks:
			if in_bar % (_grid / flock.pulses) == 0:
				_sing(flock, in_bar == 0)
	for ghost: float in _ghosts.duplicate():
		if beats + lookahead >= ghost:
			_ghosts.erase(ghost)
			_play_one_shot(_snare_stream, GHOST_DB)


## One pulse of [param flock]: a few of its birds sing, in turn, each in its
## own voice. The downbeat and big flocks get an extra voice.
func _sing(flock: Flock, downbeat: bool) -> void:
	var count := 1 + (1 if downbeat else 0) + (1 if flock.size() >= 8 else 0)
	var weight := sim.weight_for(flock.pulses)
	var velocity := clampf(0.3 + 0.35 * weight, 0.3, 0.95)
	for bird in flock.take_voices(count):
		var note := voice_note(bird.degree, _band.key_root(), _band.is_minor())
		var voice: SynthVoice = _synths[bird.waveform].note_on(midi_to_hz(note), velocity)
		bird.glow = 1.0
		if voice != null:
			get_tree().create_timer(NOTE_SECONDS).timeout.connect(
				_release_if_unchanged.bind(voice, voice.started_usec)
			)
	flock.flash = 1.0


func _release_if_unchanged(voice: SynthVoice, started_usec: int) -> void:
	if is_instance_valid(voice) and voice.started_usec == started_usec:
		voice.note_off()


func _play_one_shot(stream: AudioStream, volume_db: float) -> void:
	if _players.is_empty() or stream == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _build_audio() -> void:
	var rate := int(AudioServer.get_mix_rate())
	_snare_stream = DrumSynth.one_shot(DrumSynth.Hit.SNARE, rate)
	_kick_stream = DrumSynth.one_shot(DrumSynth.Hit.KICK, rate)
	_crash_stream = DrumSynth.one_shot(DrumSynth.Hit.OPEN_HAT, rate)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = AudioManager.MUSIC_BUS
		add_child(player)
		_players.append(player)
	# Plucks: quick attack, a short ring. Levels balance sine against the
	# brighter square and saw.
	var patches := {
		SynthWavetable.Waveform.SINE: 0.11,
		SynthWavetable.Waveform.SQUARE: 0.045,
		SynthWavetable.Waveform.SAW: 0.05,
	}
	for waveform in patches:
		var patch := SynthPatch.new()
		patch.waveform = waveform
		patch.attack_seconds = 0.004
		patch.release_seconds = 0.45
		patch.level = patches[waveform]
		patch.glide_seconds = 0.0
		var synth := Synth.new()
		synth.patch = patch
		synth.polyphony = 12
		_synths[waveform] = synth
		add_child(synth)


func _draw() -> void:
	var rect := get_viewport_rect()
	_draw_flock_halos()
	for bird in sim.birds:
		_draw_bird(bird)
	if _scatter_flash > 0.0:
		draw_rect(rect, Color(1.0, 0.96, 0.9, _scatter_flash * 0.25))


func _draw_flock_halos() -> void:
	var font := UiTheme.hud_font()
	for flock in sim.flocks:
		var rhythm := table.get_rhythm(flock.pulses)
		var color := rhythm.color if rhythm != null else Color.WHITE
		var reach := 20.0 + sqrt(float(flock.size())) * 12.0
		var halo := color
		halo.a = 0.05 + flock.flash * 0.1
		draw_circle(flock.centroid, reach * (1.0 + flock.flash * 0.15), halo)
		var label := color
		label.a = 0.55
		draw_string(
			font,
			flock.centroid + Vector2(-20.0, -reach - 6.0),
			str(flock.pulses),
			HORIZONTAL_ALIGNMENT_CENTER,
			40.0,
			14,
			label
		)


func _draw_bird(bird: Bird) -> void:
	var flying := motion == FlockSim.Motion.FLY
	var heading := bird.heading
	var side := heading.orthogonal()
	var at := bird.position
	var color := LONER_COLOR
	var scale := 1.0
	if bird.flock != null:
		var rhythm := table.get_rhythm(bird.flock.pulses)
		color = rhythm.color if rhythm != null else Color.WHITE
		color = color.lerp(Color.WHITE, bird.glow * 0.6)
		scale += bird.glow * (0.5 if flying else 0.3)
		# The charge shows on the flocks: those about to be scattered tremble,
		# the ones that will survive it glow.
		if charge.charge > 0.0:
			if bird.flock.pulses == charge.winner:
				color = color.lerp(Color.WHITE, charge.charge * 0.3)
			else:
				at += (
					Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * charge.charge * 3.0
				)
	if flying:
		_draw_flier(at, heading, side, scale, color)
	else:
		_draw_boatman(bird, at, heading, side, scale, color)


## The original bird: an arrowhead pointing along its heading.
func _draw_flier(at: Vector2, heading: Vector2, side: Vector2, scale: float, color: Color) -> void:
	var points := PackedVector2Array(
		[
			at + heading * 7.0 * scale,
			at - heading * 5.0 * scale + side * 5.0 * scale,
			at - heading * 2.0 * scale,
			at - heading * 5.0 * scale - side * 5.0 * scale,
		]
	)
	draw_colored_polygon(points, color)


func _draw_boatman(
	bird: Bird, at: Vector2, heading: Vector2, side: Vector2, scale: float, color: Color
) -> void:
	# Oars: folded back along the body at rest, flung out sideways on the pull.
	var oar_angle := lerpf(2.5, 1.35, bird.stroke)
	var oar_colour := color
	oar_colour.a *= 0.8
	for flank: float in [-1.0, 1.0]:
		var oar := (heading * cos(oar_angle) + side * sin(oar_angle) * flank) * 11.0 * scale
		var root := at - heading * 1.0 * scale
		draw_line(root, root + oar, oar_colour, 1.5)
		draw_line(root + oar, root + oar * 1.25 + heading * 2.0 * scale, oar_colour, 1.0)
	# Body: a long oval, the head a touch narrower.
	var body := PackedVector2Array()
	for i in 10:
		var t := TAU * i / 10.0
		var along := cos(t)
		var across := sin(t)
		body.append(at + heading * along * 8.0 * scale + side * across * 3.2 * scale)
	draw_colored_polygon(body, color)
	draw_circle(at + heading * 7.0 * scale, 2.0 * scale, color.lightened(0.25))


## Push the birds' wakes into the tank for [param delta] seconds. Nothing
## comes back the other way.
func _stir(delta: float) -> void:
	if _fluid == null or delta <= 0.0:
		return
	var wakes := BirdWakes.gather(sim.birds, WAKE_CELL, _bird_color)
	for i in mini(wakes.size(), FluidSimulation.MAX_SPLATS):
		var wake := wakes[i]
		var push := (wake.momentum * wake_gain()).limit_length(WAKE_MAX)
		var radius := minf(WAKE_RADIUS * sqrt(float(wake.count)), WAKE_RADIUS_MAX)
		_fluid.add_velocity_impulse(wake.position, push, radius, delta)
		# Alpha is the share of the cell that is flocked; loners add none.
		var share := wake.color.a
		if share > 0.0:
			var pigment := Color(wake.color / share, 1.0)
			_fluid.add_paint(wake.position, pigment, WAKE_PAINT * wake.count * share, radius, delta)


## The colour a bird paints with: its flock's rhythm, or nothing for a loner.
func _bird_color(bird: Bird) -> Color:
	if bird.flock == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var rhythm := table.get_rhythm(bird.flock.pulses)
	return rhythm.color if rhythm != null else Color.WHITE


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud = UiTheme.label("", UiTheme.HUD)
	_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.offset_left = 16.0
	_hud.offset_bottom = -12.0
	layer.add_child(_hud)

	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(180.0, 180.0)
	_dial.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dial.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_dial.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dial.offset_left = -196.0
	_dial.offset_top = -216.0
	_dial.offset_right = -16.0
	_dial.offset_bottom = -36.0
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	layer.add_child(_dial)


func _update_hud() -> void:
	var read := "·"
	if reading.tap_count > 0:
		read = (
			"%d (%.2f)%s" % [reading.winner, reading.winner_fit, "" if reading.unambiguous else "?"]
		)
	var state := "charge %d%%" % roundi(charge.charge * 100.0)
	if charge.is_cooling_down():
		state = "settling"
	_hud.text = (
		(
			"♪ %s · key %+d · ♩ %d bpm · %d flocks · %d singing, %d silent\n"
			% [
				_band.song_title(),
				KeyShiftInput.display_offset(_band.get_key_offset()),
				roundi(AudioManager.get_tempo()),
				sim.flocks.size(),
				_singing(),
				_silent(),
			]
		)
		+ "reads as %s · %s\n" % [read, state]
		+ (
			"B / Esc / Space / click snare · Q/E Z/X key · ↑↓ ±2 bpm · ←→ ±10 bpm · last input: %s"
			% _last_input
		)
	)


func _singing() -> int:
	var count := 0
	for flock in sim.flocks:
		count += flock.size()
	return count


func _silent() -> int:
	return sim.birds.size() - _singing()


## The bar as a clock face, downbeat at the top: a ring of pulses per rhythm
## (bright when in favour), the last bar of taps round the outside, the
## playhead, and the charge as an arc round everything.
func _draw_dial() -> void:
	var centre := _dial.size * 0.5
	var outer := minf(centre.x, centre.y) - 8.0
	_dial.draw_circle(centre, outer + 4.0, UiTokens.OVERLAY)
	_dial.draw_arc(centre, outer + 4.0, 0.0, TAU, 64, Color(UiTokens.SIGIL, 0.35), 1.0, true)

	var ring := outer - 14.0
	for rhythm in table.rhythms:
		var weight := sim.weight_for(rhythm.pulses)
		var color := rhythm.color
		color.a = clampf(0.25 + (weight - WEIGHT_LOW) / (WEIGHT_HIGH - WEIGHT_LOW) * 0.75, 0.2, 1.0)
		_dial.draw_arc(centre, ring, 0.0, TAU, 48, Color(color, color.a * 0.3), 1.0, true)
		for k in rhythm.pulses:
			_dial.draw_circle(centre + _dial_point(float(k) / rhythm.pulses, ring), 3.5, color)
		ring -= 16.0

	for phase in reader.window(_last_beats):
		var at := _dial_point(phase, outer)
		_dial.draw_line(centre + at * 0.9, centre + at * 1.05, UiTokens.RUNE, 2.0, true)

	var playhead := reader.phase_of(maxf(_last_beats, 0.0))
	var hand := Color(UiTokens.TEXT, 0.35)
	_dial.draw_line(centre, centre + _dial_point(playhead, outer), hand, 1.0, true)

	var start := -PI / 2.0
	if charge.is_cooling_down():
		var left := charge.cooldown / charge.cooldown_beats
		_dial.draw_arc(
			centre, outer + 3.0, start, start + TAU * left, 64, Color(UiTokens.SIGIL, 0.3), 3.0
		)
	elif charge.charge > 0.0:
		var rhythm := table.get_rhythm(charge.winner)
		var color := rhythm.color if rhythm != null else Color.WHITE
		_dial.draw_arc(
			centre, outer + 3.0, start, start + TAU * charge.charge, 64, color, 4.0, true
		)

	var font := UiTheme.hud_font()
	var label := str(reading.winner) if reading.tap_count > 0 else ""
	_dial.draw_string(
		font,
		centre + Vector2(-20.0, 7.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		40.0,
		20,
		UiTokens.HUD_TEXT
	)


## The MIDI note [param degree] sings in a key with tonic [param root] (pitch
## class, 0 = C): that step of the key's pentatonic, minor or major as the
## song is, counted up from the tonic at or above [constant VOICE_FLOOR].
static func voice_note(degree: int, root: int, minor: bool) -> int:
	var intervals := PegScale.pentatonic_for(minor)
	var tonic := VOICE_FLOOR + posmod(root - VOICE_FLOOR, 12)
	var octave := degree / intervals.size()
	return tonic + 12 * octave + intervals[degree % intervals.size()]


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


static func _dial_point(phase: float, radius: float) -> Vector2:
	return Vector2.from_angle(-PI / 2.0 + phase * TAU) * radius

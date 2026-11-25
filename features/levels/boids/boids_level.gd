class_name BoidsLevel
extends Node2D
## Flocks over the eye tank's fluid, as an instrument (#90): waterboatmen or
## birds, by [member motion].
##
## [b]Rowing[/b] ([constant FlockSim.Motion.ROW], the Waterboatmen level):
## boatmen row in strokes and glides rather than flying. Boatmen in a flock row
## together on the flock's pulses and sing on the flock's rhythm — three
## rhythms at a time out of 3 to 8 pulses to a shared bar, so flocks play
## polyrhythms against each other — each with a voice of its own. Loners are
## silent.
##
## [b]Flying[/b] ([constant FlockSim.Motion.FLY], the Birds level): the
## original version, a sky of birds that fly continuously and sing the same
## way. Only the motion, the drawing and the strength of the wakes differ; the
## drums, the taps, the scatter and the music are shared.
##
## The player plays three drums, each a faint ring pulsing in a corner
## ([DrumPads]): the kick bottom left, the snare bottom right, the hi-hat top
## right. Tap a ring to play it; on a keyboard or pad, J or A is the kick, B,
## Esc or Space the snare, H or X the hi-hat. Each drum's taps are read on
## their own against every rhythm (see [TapReader]), so the kick can play a 3
## while the hi-hat plays a 5. A rhythm takes its weight from whichever drum
## fits it best: flocks whose rhythm fits tighten and pull loners in, and
## flocks that do not loosen and shed birds. Hold one rhythm unambiguously for
## long enough, with no drum playing another, and every flock playing
## something else bursts apart (see [ScatterCharge]) — rare on purpose.
##
## Three rhythms are in play at a time ([member table]). Holding the dial
## shuffles them ([method shuffle]): three others from 3 to 8, paired with the
## old ones lowest to highest, and every flock, and the favour its rhythm had,
## carries over to the rhythm taking its place.
##
## A drum sounds the instant it is hit, and a quieter ghost of it lands a bar
## later on the pulse it was read as, so the player hears how they were heard.
## The dial shows the same thing: the bar going round, every rhythm's pulses,
## the last bar of each drum's taps (kicks as squares, snares as dashes,
## hi-hats as dots), and the charge building. It fills the middle of the
## screen, see-through, over the water and under the flocks.
##
## Swing ([method AudioManager.set_swing]) bends all of it together. The
## flocks' pulses are positions in the score like the band's notes, so they
## are heard swung with it; a tap is read where it falls in the score, so
## playing along with the swing still reads as the rhythm; and the dial's
## hand turns evenly while its pulses sit where they are heard.
##
## A foreground over the host's tank and band ([SharedLayers]). Birds and
## boatmen stir the tank as they move — each flock drags a broad wake through
## it and stains it faintly in its rhythm's colour — but the water never
## pushes back: the flocks move as if it were not there. See [BirdWakes].
##
## The music is the host's [Band]: its song keeps playing in full, and the
## flocks play over it, on its clock and in its key. A bird's voice is a step
## of the band's scale ([method voice_note]) — the song's pentatonic until the
## scale button in the corner menu ([GameMenu]) picks another — so a key
## move (L1/R1 or Q/E a fourth, Z/X a fifth — see [KeyShiftInput], or the
## corner buttons) or a new scale carries every flock with it.
## Tempo is [code]TempoControl[/code]'s, like everywhere else: the flocks, the
## pulses and the ghosts all run on [AudioManager]'s beats, so they follow a
## tempo change without knowing about it.
##
## See the README beside this file, and docs/boids-rhythm-scope.md for the
## design.

const BEATS_PER_BAR := 4
const BIRD_COUNT := 43

## The rhythms in play when the level opens.
const START_PULSES: Array[int] = [3, 4, 6]
## A flock of each of these is already flying when the level opens, so the
## first bar is already 3-against-4.
const SEED_PULSES: Array[int] = [3, 4]

const SNARE := &"snare"
const KICK := &"kick_drum"
const HAT := &"hi_hat"
## Each pad's input action.
const PAD_ACTIONS := {
	DrumPads.Pad.KICK: KICK,
	DrumPads.Pad.SNARE: SNARE,
	DrumPads.Pad.HAT: HAT,
}
## Shuffles the rhythms on a keyboard, as holding the dial does on a screen.
const SHUFFLE_KEY := KEY_S
## The mouse, as a finger, for [PressHold].
const MOUSE_INDEX := -2

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
const KICK_DB := -4.0
const HAT_DB := -10.0
## How far under its drum a ghost plays.
const GHOST_DROP_DB := -14.0
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
## Acceleration a bird lends the water, per pixel/second of its own speed.
## Light: the flocks stir the wash as they pass without hauling it along
## behind them. Boatmen glide slower than the birds fly, so theirs is higher.
## See [method wake_gain].
const WAKE_GAIN_FLY := 0.67
const WAKE_GAIN_ROW := 1.0
## Cap on one cell's push, in pixels/second^2, so a packed flock swirls the
## water rather than blasting it.
const WAKE_MAX := 850.0
## Gaussian radius of a wake: grows with the birds in it, from a lone bird's
## [constant WAKE_RADIUS] up to [constant WAKE_RADIUS_MAX].
const WAKE_RADIUS := 45.0
const WAKE_RADIUS_MAX := 110.0
## Pigment a flocked bird lays down per second, in its rhythm's colour. Faint:
## enough that the flocks' paths show in the wash, not enough to bury the seed
## colours. Loners lay none — at 64 pale birds they bleached the whole sky.
const WAKE_PAINT := 0.04
const LONER_COLOR := ArtPalette.LONER

## The dial's radius, as a share of the screen's shorter side.
const DIAL_REACH := 0.4
## How solid the dial is: the water shows through it.
const DIAL_OPACITY := 0.5

## Seconds added to a tap before it is read, to cancel the time between
## hearing a pulse and a press registering. 0 until measured on a device.
@export var tap_offset_seconds: float = 0.0

## How the flocks move: rowed waterboatmen, or the original flying birds.
## Read once, when the level is ready.
@export var motion: FlockSim.Motion = FlockSim.Motion.ROW

## The three rhythms in play. [method shuffle] swaps them in place.
var table: RhythmTable
var sim: FlockSim
## A [TapReader] per drum ([enum DrumPads.Pad]), each reading only its own taps.
var readers := {}
var charge: ScatterCharge
## Holding the dial, to shuffle the rhythms.
var hold := PressHold.new()

## The latest reading of each drum's taps, by [enum DrumPads.Pad].
var readings := {}
## The reading that says the most: the drum fitting its rhythm best, with
## enough taps to count. The snare's when no drum has been played.
var reading: TapReader.Reading
## The dial in the middle and the drum pads in the corners.
var dial: RhythmDial

var _rng := RandomNumberGenerator.new()
var _grid := 12
var _sequencer: StepSequencer
## The band's clock the sequencer's grid clock was last made from.
var _sequencer_clock: MusicClock
var _last_beats := -1.0
## Where the music is in the score: [member _last_beats] with the swing out.
var _score_beats := 0.0
## Ghosts still waiting to play: x the score beats they land on, y the pad.
var _ghosts: Array[Vector2] = []
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
var _hat_stream: AudioStreamWAV
var _crash_stream: AudioStreamWAV
var _key_shift := KeyShiftInput.new()

var _hud: Label
var _fluid: FluidSimulation
## The level's host: the tank to stir and the band to play over. See
## [SharedLayers].
var _shared: SharedLayers
var _band: Band


## What the corner menu ([GameMenu]) tells a player to do here.
func hint() -> String:
	return "Play a rhythm to strengthen that group."


## The mix rows the corner menu ([GameMenu]) shows here, over the band's.
func mix_rows() -> Array[String]:
	return [AudioManager.RHYTHM_BUS]


func _ready() -> void:
	# B on a keyboard or a gamepad, and whatever the Deck's B, Y and L2 send
	# when Steam keeps it in its Desktop Mode layout. The Deck's R2 is a left
	# click, which plays the pad under the pointer, or the snare anywhere else
	# but the dial (see [method press]).
	InputActions.ensure(
		SNARE,
		[KEY_B, DeckDesktopLayout.B, DeckDesktopLayout.Y] as Array[Key],
		[JOY_BUTTON_B] as Array[JoyButton],
		[DeckDesktopLayout.L2] as Array[MouseButton]
	)
	InputActions.ensure(
		KICK, [KEY_J, DeckDesktopLayout.A] as Array[Key], [JOY_BUTTON_A] as Array[JoyButton]
	)
	InputActions.ensure(HAT, [KEY_H] as Array[Key], [JOY_BUTTON_X] as Array[JoyButton])
	_shared = SharedLayers.host_of(self)
	if _shared == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	_fluid = _shared.fluid
	_band = _shared.band
	# The snare has the triggers.
	_key_shift.use_triggers = false
	_rng.randomize()
	table = RhythmTable.of(START_PULSES)
	_grid = table.grid_steps(BEATS_PER_BAR)
	for pad in DrumPads.ALL:
		readers[pad] = TapReader.new(BEATS_PER_BAR)
		readings[pad] = readers[pad].read(0.0, table)
	reading = readings[DrumPads.Pad.SNARE]
	charge = ScatterCharge.new()
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
	_score_beats = AudioManager.get_music_clock().score_beats(beats)

	_read_all(_score_beats)
	_ease_weights(delta)
	var agreed := agreed_winner()
	if charge.advance(elapsed, agreed, agreed > 0):
		_scatter(charge.winner)
	if hold.poll(now()):
		shuffle()

	sim.bounds = get_viewport_rect()
	# A rhythm played cleanly always has a creature playing it.
	for pad in DrumPads.ALL:
		var heard: TapReader.Reading = readings[pad]
		if heard.unambiguous and heard.winner > 0:
			sim.ensure_flock(heard.winner)
	var step := minf(delta, 0.05)
	sim.step(step, _score_beats)
	_stir(step)
	for bird in sim.birds:
		bird.glow = maxf(bird.glow - delta * 4.0, 0.0)
	_scatter_flash = maxf(_scatter_flash - delta * 1.5, 0.0)

	if source.is_running():
		_play_due(source, beats)
	queue_redraw()
	dial.queue_redraw()
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
	for pad in DrumPads.ALL:
		if event.is_action_pressed(PAD_ACTIONS[pad]) and not event.is_echo():
			get_viewport().set_input_as_handled()
			hit(pad)
			return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == SHUFFLE_KEY:
		get_viewport().set_input_as_handled()
		shuffle()
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			press(touch.index, touch.position, true)
		else:
			hold.end(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		hold.moved(drag.index, drag.position)
		return
	var click := event as InputEventMouseButton
	# Mouse events Godot makes up from a touch are skipped: the touch itself
	# was already read.
	if (
		click != null
		and click.button_index == MOUSE_BUTTON_LEFT
		and click.device != InputEvent.DEVICE_ID_EMULATION
	):
		if click.pressed:
			press(MOUSE_INDEX, click.position, false)
		else:
			hold.end(MOUSE_INDEX)
		return
	var pointer := event as InputEventMouseMotion
	if pointer != null and pointer.device != InputEvent.DEVICE_ID_EMULATION:
		hold.moved(MOUSE_INDEX, pointer.position)


## A press by finger [param index] (or [constant MOUSE_INDEX]) at [param at],
## in canvas units: a pad plays its drum, and the dial starts a hold that
## shuffles the rhythms. A click anywhere else is the snare, which keeps the
## Deck's R2 (a left click in its desktop layout) a snare wherever the pointer
## is; a touch anywhere else does nothing. Presses on the corner menu are the
## menu's. Returns the pad played, or -1.
func press(index: int, at: Vector2, is_touch: bool) -> int:
	if _shared != null and _shared.game_menu != null and _shared.game_menu.covers(at):
		return -1
	var rect := get_viewport_rect()
	var pad := DrumPads.pad_at(at, rect.size, safe_insets())
	if pad != -1:
		hit(pad)
		return pad
	if at.distance_to(rect.get_center()) <= dial_radius(rect.size):
		hold.begin(index, at, now())
		return -1
	if not is_touch:
		hit(DrumPads.Pad.SNARE)
		return DrumPads.Pad.SNARE
	return -1


## Play [param pad]'s drum now, and read the hit.
func hit(pad: int) -> void:
	_play_one_shot(_stream_for(pad), _db_for(pad))
	dial.flash_pad(pad)
	var source := AudioManager.get_music_time_source()
	var clock := AudioManager.get_music_clock()
	var heard := source.get_beats() + tap_offset_seconds / clock.seconds_per_beat()
	tap(clock.score_beats(heard), pad)


## Read a hit on [param pad] at [param beats] in the score (see [method
## MusicClock.score_beats]): it joins the last bar of that drum's taps, and its
## ghost is queued a bar later on the pulse it reads as. Returns where the
## ghost will land, in score beats.
func tap(beats: float, pad: int = DrumPads.Pad.SNARE) -> float:
	var reader: TapReader = readers[pad]
	reader.add_tap(beats)
	readings[pad] = reader.read(beats, table)
	reading = lead_reading()
	var heard: TapReader.Reading = readings[pad]
	var pulses := heard.winner if heard.winner > 0 else table.min_pulses()
	var ghost := reader.quantise(beats, pulses) + BEATS_PER_BAR
	_ghosts.append(Vector2(ghost, pad))
	return ghost


## Swap the three rhythms in play for three others ([method
## RhythmTable.shuffled]), or for [param pulse_counts] when given. Old and new
## pair up lowest to highest: every flock moves over to the rhythm taking its
## rhythm's place, and so does the favour that rhythm had (its weight, its
## pull on new flocks, and a charge building for it). The old rings fade from
## the dial as the new ones come in.
func shuffle(pulse_counts: Array[int] = []) -> void:
	var incoming := pulse_counts
	if incoming.is_empty():
		incoming = RhythmTable.shuffled(_rng, table.pulse_counts())
	var outgoing := table.rhythms.duplicate()
	var pairing := table.swap_to(incoming)
	sim.remap_rhythms(pairing)
	var moved := {}
	for old in pairing:
		moved[pairing[old]] = _weights.get(old, 1.0)
	_weights = moved
	charge.winner = pairing.get(charge.winner, 0)
	_grid = table.grid_steps(BEATS_PER_BAR)
	# The flocks' grid changes with the rhythms: start it afresh from now.
	_sequencer_clock = null
	if _sequencer != null:
		_sequencer.reset()
	_read_all(_score_beats)
	dial.fade_out(outgoing)


## The rhythm every drum that reads clearly agrees on, or 0: none reads
## clearly, or two read clearly as different rhythms. Only an agreed rhythm
## builds the charge, so a player keeping two rhythms going keeps both alive.
func agreed_winner() -> int:
	var agreed := 0
	for pad in DrumPads.ALL:
		var heard: TapReader.Reading = readings[pad]
		if not heard.unambiguous or heard.winner == 0:
			continue
		if agreed != 0 and heard.winner != agreed:
			return 0
		agreed = heard.winner
	return agreed


## The drum whose reading says the most: the best fit, weighed by how much
## its taps count ([member TapReader.Reading.confidence]). The snare's when no
## drum has any taps.
func lead_reading() -> TapReader.Reading:
	var best: TapReader.Reading = readings[DrumPads.Pad.SNARE]
	var best_score := best.winner_fit * best.confidence
	for pad in DrumPads.ALL:
		var heard: TapReader.Reading = readings[pad]
		var score := heard.winner_fit * heard.confidence
		if score > best_score:
			best = heard
			best_score = score
	return best


func _read_all(beats: float) -> void:
	for pad in DrumPads.ALL:
		readings[pad] = readers[pad].read(beats, table)
	reading = lead_reading()


func _stream_for(pad: int) -> AudioStream:
	match pad:
		DrumPads.Pad.KICK:
			return _kick_stream
		DrumPads.Pad.HAT:
			return _hat_stream
	return _snare_stream


func _db_for(pad: int) -> float:
	match pad:
		DrumPads.Pad.KICK:
			return KICK_DB
		DrumPads.Pad.HAT:
			return HAT_DB
	return SNARE_DB


## The safe area's insets, so the pads clear the phone's island and corners.
func safe_insets() -> Vector4:
	var viewport := get_viewport()
	return SafeArea.insets(SafeArea.canvas_rect(viewport), viewport.get_visible_rect().size)


## Where the music was in the score at the last frame, in beats: what the
## taps are read against.
func score_beats() -> float:
	return _score_beats


## Where the music was as heard at the last frame, in beats; 0 before it starts.
func heard_beats() -> float:
	return maxf(_last_beats, 0.0)


## Seconds on the clock holds are timed by.
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Attraction weight for a rhythm the taps fit [param fit] (0..1), before
## easing and before [member TapReader.Reading.confidence] scales it back
## towards neutral.
static func weight_for_fit(fit: float) -> float:
	return lerpf(WEIGHT_LOW, WEIGHT_HIGH, smoothstep(FIT_FLOOR, 1.0, fit))


## Ease every rhythm's weight towards what the drums say of it. Each rhythm
## listens to the drum that fits it best (fit weighed by confidence), so a
## kick playing a 3 favours the 3 whatever the hi-hat is doing; with no drum
## played, every rhythm eases back to neutral.
func _ease_weights(delta: float) -> void:
	var keep := pow(WEIGHT_RETENTION, delta)
	for pulses in table.pulse_counts():
		var fit := 0.0
		var confidence := 0.0
		for pad in DrumPads.ALL:
			var heard: TapReader.Reading = readings[pad]
			var pad_fit: float = heard.fits.get(pulses, 0.0)
			if pad_fit * heard.confidence > fit * confidence:
				fit = pad_fit
				confidence = heard.confidence
		var target := lerpf(1.0, weight_for_fit(fit), confidence)
		_weights[pulses] = lerpf(target, _weights.get(pulses, 1.0), keep)
		sim.weights[pulses] = _weights[pulses]
		sim.spawn_bias[pulses] = fit * confidence


func _scatter(survivor: int) -> void:
	var count := sim.scatter(survivor)
	if count == 0:
		return
	_scatter_flash = 1.0
	_play_one_shot(_crash_stream, CRASH_DB)
	_play_one_shot(_kick_stream, SCATTER_KICK_DB)


## Every grid step due now: each flock's pulses, and any ghost drums.
func _play_due(source: MusicTimeSource, beats: float) -> void:
	var clock := AudioManager.get_music_clock()
	if clock != _sequencer_clock:
		# The band's tempo and swing, on the flocks' grid.
		var grid_clock := clock.with_steps_per_beat(_grid / BEATS_PER_BAR)
		if _sequencer == null:
			_sequencer = StepSequencer.new(grid_clock)
		else:
			_sequencer.set_clock(grid_clock)
		_sequencer_clock = clock
	var lookahead := clock.beats_from_seconds(source.get_lookahead())
	for step in _sequencer.update(beats, lookahead):
		var in_bar := step % _grid
		for flock in sim.flocks:
			if in_bar % (_grid / flock.pulses) == 0:
				_sing(flock, in_bar == 0)
	var horizon := clock.score_beats(beats + lookahead)
	for ghost: Vector2 in _ghosts.duplicate():
		if horizon >= ghost.x:
			_ghosts.erase(ghost)
			var pad := int(ghost.y)
			_play_one_shot(_stream_for(pad), _db_for(pad) + GHOST_DROP_DB)


## One pulse of [param flock]: a few of its birds sing, in turn, each in its
## own voice. The downbeat and big flocks get an extra voice.
func _sing(flock: Flock, downbeat: bool) -> void:
	var count := 1 + (1 if downbeat else 0) + (1 if flock.size() >= 8 else 0)
	var weight := sim.weight_for(flock.pulses)
	var velocity := clampf(0.3 + 0.35 * weight, 0.3, 0.95)
	for bird in flock.take_voices(count):
		var note := voice_note(bird.degree, _band.key_root(), _band.scale_intervals())
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
	_hat_stream = DrumSynth.one_shot(DrumSynth.Hit.CLOSED_HAT, rate)
	_crash_stream = DrumSynth.one_shot(DrumSynth.Hit.OPEN_HAT, rate)
	# Three drums and their ghosts can land together.
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.bus = AudioManager.RHYTHM_BUS
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
		synth.bus = AudioManager.RHYTHM_BUS
		_synths[waveform] = synth
		add_child(synth)


func _draw() -> void:
	var rect := get_viewport_rect()
	_draw_flock_halos()
	for bird in sim.birds:
		_draw_bird(bird)
	if _scatter_flash > 0.0:
		draw_rect(rect, Color(ArtPalette.FLASH, _scatter_flash * 0.25))


func _draw_flock_halos() -> void:
	var font := UiTheme.hud_font()
	for flock in sim.flocks:
		var rhythm := table.get_rhythm(flock.pulses)
		var color := rhythm.color if rhythm != null else ArtPalette.LIGHT
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
		color = rhythm.color if rhythm != null else ArtPalette.LIGHT
		color = color.lerp(ArtPalette.LIGHT, bird.glow * 0.6)
		scale += bird.glow * (0.5 if flying else 0.3)
		# The charge shows on the flocks: those about to be scattered tremble,
		# the ones that will survive it glow.
		if charge.charge > 0.0:
			if bird.flock.pulses == charge.winner:
				color = color.lerp(ArtPalette.LIGHT, charge.charge * 0.3)
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


## Push the flocked birds' wakes into the tank for [param delta] seconds.
## Loners leave the water alone, so only the groups move it. Nothing comes
## back the other way.
func _stir(delta: float) -> void:
	if _fluid == null or delta <= 0.0:
		return
	var flocked: Array[Bird] = []
	for bird in sim.birds:
		if bird.flock != null:
			flocked.append(bird)
	var wakes := BirdWakes.gather(flocked, WAKE_CELL, _bird_color)
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
	return rhythm.color if rhythm != null else ArtPalette.LIGHT


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud = UiTheme.label("", UiTheme.HUD)
	_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.offset_left = 16.0
	_hud.offset_bottom = -12.0
	layer.add_child(_hud)
	# Readouts for working on the game; a player sees the level alone.
	layer.visible = DevTools.enabled()

	# A child drawn behind this node: over the tank, which is the host's, and
	# under the flocks, which this node draws.
	dial = RhythmDial.new()
	dial.name = "Dial"
	dial.level = self
	dial.show_behind_parent = true
	dial.modulate.a = DIAL_OPACITY
	add_child(dial)


func _update_hud() -> void:
	var reads := PackedStringArray()
	for pad in DrumPads.ALL:
		var heard: TapReader.Reading = readings[pad]
		var read := "·"
		if heard.tap_count > 0:
			read = (
				"%d (%.2f)%s" % [heard.winner, heard.winner_fit, "" if heard.unambiguous else "?"]
			)
		reads.append("%s %s" % [DrumPads.name_of(pad), read])
	var state := "charge %d%%" % roundi(charge.charge * 100.0)
	if charge.is_cooling_down():
		state = "settling"
	_hud.text = (
		(
			"♪ %s · key %+d · %s · ♩ %d bpm · %s · %d flocks · %d singing, %d silent\n"
			% [
				_band.song_title(),
				KeyShiftInput.display_offset(_band.get_key_offset()),
				_band.scale_name(),
				roundi(AudioManager.get_tempo()),
				" ".join(PackedStringArray(table.pulse_counts().map(str))),
				sim.flocks.size(),
				_singing(),
				_silent(),
			]
		)
		+ "%s · %s\n" % [" · ".join(reads), state]
		+ (
			(
				"J/A kick · B/Esc/Space snare · H/X hi-hat · S or hold the dial shuffles"
				+ " · Q/E Z/X key · ↑↓ ±2 bpm · ←→ ±10 bpm · last input: %s"
			)
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


## The dial's radius in pixels for a screen of [param screen] pixels.
static func dial_radius(screen: Vector2) -> float:
	return minf(screen.x, screen.y) * DIAL_REACH


## Where on the dial's face a bar phase in the score (0..1) is heard, with
## [param clock]'s swing: the face is the bar as it sounds, so the hand turns
## evenly and a swung pulse sits late.
static func heard_phase(score_phase: float, clock: MusicClock) -> float:
	return clock.heard_beats(score_phase * BEATS_PER_BAR) / BEATS_PER_BAR


## The MIDI note [param degree] sings in a key with tonic [param root] (pitch
## class, 0 = C): that step of [param intervals], the band's scale, counted up
## from the tonic at or above [constant VOICE_FLOOR].
static func voice_note(degree: int, root: int, intervals: Array[int]) -> int:
	var tonic := VOICE_FLOOR + posmod(root - VOICE_FLOOR, 12)
	var octave := degree / intervals.size()
	return tonic + 12 * octave + intervals[degree % intervals.size()]


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

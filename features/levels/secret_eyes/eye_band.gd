class_name EyeBand
extends Node
## Every eye in the tank plays one part of the arrangement, but only while it
## keeps clear of the tank walls. Drift one against a wall and its part drops
## out at the next bar; let it float free again and the part comes back.
##
## Parts go to eyes by size, biggest first: the heaviest eye carries the beat,
## the next the bass, down to the smallest carrying the lightest shimmer. So
## what is audible can be read off what is on screen.
##
## The music is a [Song], picked at random from [EyeBandSongs] each time the
## band starts, walked section by section by a [SongWalker] so its chord
## progression branches as it plays. Drum parts are the song's [StepPattern]s
## rendered into [AudioManager] loop layers, which already land changes on the
## next bar. Melodic parts are live [Synth] notes on a [StepClock] that follow
## whatever chord is current; whether each is on is latched once per bar, so
## both kinds change at the same moment. A fill layer plays over the beat on
## the last bar of every section.
##
## An eye near a wall uses two distances, not one, so one hovering at the
## threshold does not flicker its part on and off: it counts as touching once
## it comes within [member touch_px], and only lets go past [member release_px].

## Emitted when an eye starts or stops touching a wall.
signal contact_changed(part: String, touching: bool)

## Emitted once the band has chosen what to play.
signal song_started(title: String)

## What [method pending] reports for a part: nothing due, due to start next
## bar, or due to stop next bar.
enum Pending { NONE, STARTING, STOPPING }

## Heaviest first; eyes are matched to these by size.
const PARTS: Array[String] = ["beat", "bass", "pads", "melody", "arp", "ghost", "shimmer"]
const LOOP_PARTS: Array[String] = ["beat", "ghost", "shimmer"]

## Loop layer played over the beat on a section's last bar. Not a part: it
## belongs to whichever eye has the beat.
const FILL := "fill"

## Loop layer volumes, in dB. Seven parts at once sit about 3 dB under the
## groove demo's levels so the full arrangement does not clip.
const LOOP_DB := {"beat": -6.0, "ghost": -8.0, "shimmer": -9.0, "fill": -8.0}

## Default patch per live part: waveform, attack, release, level, voices. A
## song's [member Song.timbres] overrides any of the first four.
##
## Pads get extra voices (16, not the 8 every other part manages with): a
## key change re-voices them at once (see [method _revoice_pads]), so the
## outgoing chord's notes are still releasing when the incoming chord's notes
## start. [method Synth.pick_voice] steals a released voice before a held one,
## so without the headroom a crossfade would steal its own outgoing tail.
const PATCHES := {
	"bass": [SynthWavetable.Waveform.SAW, 0.005, 0.08, 0.16, 4],
	"pads": [SynthWavetable.Waveform.SQUARE, 0.6, 1.4, 0.045, 16],
	"arp": [SynthWavetable.Waveform.SINE, 0.005, 0.3, 0.07, 4],
	"melody": [SynthWavetable.Waveform.SQUARE, 0.08, 0.5, 0.05, 2],
}

## Within this many pixels of a wall (from the eye's rim), an eye is touching.
@export var touch_px: float = 10.0

## A touching eye lets go only once it is this far from every wall.
@export var release_px: float = 40.0

var _eyes: Array[FloatyEye] = []
## Part index for each eye in [member _eyes]; -1 for an eye with no part.
var _eye_parts: Array[int] = []
var _touching: Array[bool] = []
## Whether each part is sounding right now, per [constant PARTS].
var _playing: Dictionary = {}
var _synths := {}
var _clock: StepClock
var _effect_indices: Array[int] = []
var _started := false
var _song: Song
var _walker: SongWalker
## Section name -> the melody [MelodyWriter] wrote for it, written once and
## never transposed in place — see [member _folded_melodies].
var _melodies := {}
## Section name -> [member _melodies]'s entry shifted by [member _key_offset]
## and folded to stay in [member Song.melody_range]. Cleared whenever the
## offset changes and rebuilt lazily, section by section, as each is next
## needed.
var _folded_melodies := {}
var _bar := -1
var _step_in_bar := 0
var _fill_requested := false

## Semitones the band's key sits above the song as written. Unbounded so a
## HUD can show "how many presses", but only ever applied [code]posmod(…,
## 12)[/code] — a move round the circle of fifths — so repeated presses walk
## the circle instead of climbing until every part is shrill.
var _key_offset: int = 0


func _ready() -> void:
	for part in PARTS:
		_playing[part] = false
	if _eyes.is_empty() and get_parent() != null:
		var found: Array[FloatyEye] = []
		for child in get_parent().get_children():
			if child is FloatyEye:
				found.append(child)
		bind_eyes(found)


func _exit_tree() -> void:
	if not _started:
		return
	AudioManager.stop_loops()
	for synth in _synths.values():
		synth.release_all()
	for i in range(_effect_indices.size() - 1, -1, -1):
		AudioManager.remove_bus_effect(AudioManager.MUSIC_BUS, _effect_indices[i])


## Build the instruments and start the music. Separate from [method _ready] so
## a test can exercise the contact logic without making a sound.
## [param song] is chosen at random when left null; [param rng] likewise seeds
## itself, so every start is a different song and a different path through it.
func start(song: Song = null, rng: RandomNumberGenerator = null) -> void:
	if _started:
		return
	_started = true
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_song = song if song != null else EyeBandSongs.pick_random(rng)
	_walker = SongWalker.new(_song, rng)
	_build_synths()
	_add_space()
	AudioManager.set_tempo(_song.tempo_bpm, _song.beats_per_bar)
	var rate := int(AudioServer.get_mix_rate())
	var layers: Array[LoopLayer] = []
	for layer_name in LOOP_PARTS + [FILL]:
		layers.append(_loop_layer(layer_name, _song.drums.get(layer_name, {}), rate))
	AudioManager.configure_loop_layers(layers)
	# Before playback, loop layers switch at once; live parts follow suit so
	# the first bar is already the full arrangement.
	for part in PARTS:
		_playing[part] = wants_part(part)
		if part in LOOP_PARTS:
			AudioManager.set_layer_active(part, _playing[part])
	AudioManager.play_loops()
	_clock = StepClock.new()
	_clock.step.connect(_on_step)
	add_child(_clock)
	song_started.emit(_song.title)


## The song playing, or an empty string before [method start].
func song_title() -> String:
	return _song.title if _song != null else ""


## The section of the song playing now, or an empty string before the first
## bar.
func current_section() -> String:
	return _walker.section_at(_bar) if _walker != null and _bar >= 0 else ""


## Moves the band's key. Chords, bass and arp read this the next time any of
## them asks [method SongWalker.chords_at] for the current chord — from the
## next step, not the next bar, since a bar can be seconds away (see
## [method _on_step]). The melody transposes with its cached shape intact
## (see [method _fold_melody]) and pads crossfade to the new voicing at once
## (see [method _revoice_pads]) rather than riding out the old one or cutting.
func set_key_offset(offset: int) -> void:
	if offset == _key_offset:
		return
	_key_offset = offset
	_folded_melodies.clear()
	_revoice_pads()


func get_key_offset() -> int:
	return _key_offset


## Hand the band its eyes, and give each one a part by size.
func bind_eyes(eyes: Array[FloatyEye]) -> void:
	_eyes = eyes
	var radii: Array[float] = []
	for eye in eyes:
		radii.append(eye.radius)
	_eye_parts = parts_by_size(radii, PARTS.size())
	_touching.resize(eyes.size())
	_touching.fill(false)


## The part an eye plays, or an empty string for one with none.
func part_for(eye: FloatyEye) -> String:
	var i := _eyes.find(eye)
	if i < 0 or _eye_parts[i] < 0:
		return ""
	return PARTS[_eye_parts[i]]


## Whether the eye playing [param part] is clear of the walls, which is what
## decides if the part should sound from the next bar on. A part with no eye
## never plays.
func wants_part(part: String) -> bool:
	var index := PARTS.find(part)
	for i in _eyes.size():
		if _eye_parts[i] == index:
			return not _touching[i]
	return false


## Whether [param part] is sounding now, as opposed to wanted next bar.
func is_playing(part: String) -> bool:
	return _playing.get(part, false)


## Whether [param part] is due to start next bar, due to stop next bar, or
## settled — what is sounding now already agrees with what is wanted. A HUD
## ring counts down to the bar line while this is not [constant Pending.NONE];
## see [method countdown_fraction].
func pending(part: String) -> Pending:
	var wants := wants_part(part)
	if wants == is_playing(part):
		return Pending.NONE
	return Pending.STARTING if wants else Pending.STOPPING


func is_touching(eye: FloatyEye) -> bool:
	var i := _eyes.find(eye)
	return i >= 0 and _touching[i]


func _process(_delta: float) -> void:
	var simulation := get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME)
	if simulation != null:
		update_contacts((simulation as FluidSimulation).get_world_rect())
	# Read loop state as AudioManager applies it rather than latching it on
	# the step clock's downbeat: the clock fires ahead of the audio by the mix
	# lookahead, before a queued layer change has landed, so a latch there
	# would show every loop change a bar late.
	if _started:
		for part in LOOP_PARTS:
			_playing[part] = AudioManager.is_layer_active(part)


## Re-measure every eye against [param tank]. Loop parts are asked to follow at
## once, since [AudioManager] already holds the change for the bar line.
func update_contacts(tank: Rect2) -> void:
	for i in _eyes.size():
		var eye := _eyes[i]
		if not is_instance_valid(eye) or _eye_parts[i] < 0:
			continue
		var clearance := wall_clearance(eye.global_position, eye.radius, tank)
		var touching := next_touching(clearance, _touching[i], touch_px, release_px)
		if touching == _touching[i]:
			continue
		_touching[i] = touching
		var part: String = PARTS[_eye_parts[i]]
		if _started and part in LOOP_PARTS:
			AudioManager.set_layer_active(part, not touching)
		contact_changed.emit(part, touching)


## Pixels between [param position]'s circle of [param radius] and the nearest
## wall of [param tank]. Negative once the rim pokes past it.
static func wall_clearance(position: Vector2, radius: float, tank: Rect2) -> float:
	var to_wall := minf(
		minf(position.x - tank.position.x, tank.end.x - position.x),
		minf(position.y - tank.position.y, tank.end.y - position.y)
	)
	return to_wall - radius


## Touching from here on, given the last answer: the threshold to let go sits
## further out than the one to take hold.
static func next_touching(
	clearance: float, was_touching: bool, touch: float, release: float
) -> bool:
	return clearance < (release if was_touching else touch)


## For each radius, the index into a list of [param part_count] parts, handed
## out biggest first; -1 for radii past the last part. Ties keep their order.
static func parts_by_size(radii: Array[float], part_count: int) -> Array[int]:
	var order: Array[int] = []
	for i in radii.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int): return radii[a] > radii[b] or (radii[a] == radii[b] and a < b)
	)
	var parts: Array[int] = []
	parts.resize(radii.size())
	parts.fill(-1)
	for rank in mini(order.size(), part_count):
		parts[order[rank]] = rank
	return parts


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## Fraction of a bar left before the next bar line: 1.0 just after a bar
## starts, shrinking to 0.0 as it ends. Pure, so a countdown ring's sweep can
## be tested without playback; see [method AudioManager.get_seconds_until_next_bar]
## and [method MusicClock.seconds_per_bar] for the live values this is given.
static func countdown_fraction(seconds_until_next_bar: float, seconds_per_bar: float) -> float:
	if seconds_per_bar <= 0.0:
		return 0.0
	return clampf(seconds_until_next_bar / seconds_per_bar, 0.0, 1.0)


func _on_step(_index: int, bar: int, step_in_bar: int) -> void:
	# A bar starts on the first step heard in it, not on step 0: the clock
	# begins at whatever step is current when the music starts, so the very
	# first downbeat is usually skipped.
	var new_bar := bar != _bar
	if new_bar:
		_bar = bar
		_latch_live_parts()
	_step_in_bar = step_in_bar
	var chords := _walker.chords_at(bar)
	var chord := _song.chord_in_bar(chords, step_in_bar).transposed(_key_offset)
	var steps := _song.beats_per_bar * 4
	var chord_steps := steps / chords.size()
	var seconds_per_step := _seconds_per_step()
	if step_in_bar == steps / 2:
		_request_fill(bar + 1)

	if is_playing("pads") and (new_bar or step_in_bar % chord_steps == 0):
		var remaining := chord_steps - step_in_bar % chord_steps
		_voice_pads(chord, seconds_per_step * (remaining - 0.5))
	if is_playing("bass"):
		var note := bass_note(chord, _song.bass_line[step_in_bar], _song.bass_range.x)
		if note >= 0:
			var accent := 0.9 if step_in_bar % 4 == 0 else 0.7
			_play("bass", note, accent, seconds_per_step * (_song.bass_hold_steps - 0.4))
	if is_playing("arp"):
		var symbol := _song.arp_pattern[step_in_bar]
		if symbol.is_valid_int():
			var tones := chord.tones_between(_song.arp_range.x, _song.arp_range.y)
			if not tones.is_empty():
				var accent := 0.75 if step_in_bar % 4 == 0 else 0.55
				_play("arp", tones[symbol.to_int() % tones.size()], accent, seconds_per_step * 1.5)
	if is_playing("melody"):
		var section := _walker.section_at(bar)
		if not _melodies.has(section):
			_melodies[section] = MelodyWriter.write_section(_song, section)
		if not _folded_melodies.has(section):
			_folded_melodies[section] = _fold_melody(
				_melodies[section], _key_offset, _song.melody_range
			)
		for note in _folded_melodies[section][_walker.bar_in_section(bar)]:
			if note[0] == step_in_bar:
				_play("melody", note[1], 0.8, seconds_per_step * note[2] * 0.95)


## The bass note [param symbol] asks for over [param chord], lowest root at or
## above [param low]; -1 for a rest. R root, O octave, 5 fifth, 3 third.
static func bass_note(chord: Chord, symbol: String, low: int) -> int:
	var root := chord.root_at_or_above(low)
	match symbol:
		"R":
			return root
		"O":
			return root + 12
		"5":
			return root + 7
		"3":
			return root + chord.intervals[1] if chord.intervals.size() > 1 else root
	return -1


## Ask for the fill on [param bar] if it ends a section and the beat's eye is
## free, and for it off otherwise. Asked half a bar ahead, since a loop layer
## change lands on the next bar line after it is requested.
func _request_fill(bar: int) -> void:
	var wanted := _walker.is_last_bar_of_section(bar) and wants_part("beat")
	if wanted != _fill_requested:
		_fill_requested = wanted
		AudioManager.set_layer_active(FILL, wanted)


## On a new bar, every live part catches up with whether its eye is free.
func _latch_live_parts() -> void:
	for part in PARTS:
		if part in LOOP_PARTS:
			continue
		var wanted := wants_part(part)
		if _playing[part] and not wanted:
			_synths[part].release_all()
		_playing[part] = wanted


## Wall seconds per grid step at the live clock's current tempo — never the
## song's starting [member Song.tempo_bpm], which goes stale the moment the
## live tempo changes. Every note hold length hangs off this.
func _seconds_per_step() -> float:
	return AudioManager.get_music_clock().seconds_per_step()


func _play(part: String, note: int, velocity: float, hold_seconds: float) -> void:
	var voice: SynthVoice = _synths[part].note_on(midi_to_hz(note), velocity)
	if voice == null:
		return
	# Real seconds, deliberately: a note already sounding keeps the hold
	# length it started with even if the tempo changes mid-note. Retiming a
	# note mid-flight against the new tempo would be more jarring than
	# letting it finish on the one it was played at.
	get_tree().create_timer(hold_seconds).timeout.connect(
		_release_if_unchanged.bind(voice, voice.started_usec)
	)


func _release_if_unchanged(voice: SynthVoice, started_usec: int) -> void:
	if is_instance_valid(voice) and voice.started_usec == started_usec:
		voice.note_off()


## Voices [param chord] for the pads across [member Song.pad_range], held for
## [param hold_seconds].
func _voice_pads(chord: Chord, hold_seconds: float) -> void:
	for note in chord.voice(_song.pad_range.x, _song.pad_range.y):
		_play("pads", note, 0.8, hold_seconds)


## Fades the held pad voicing out and the current chord's voicing, at the new
## key offset, in — called the moment [method set_key_offset] changes the
## offset, rather than waiting for the chord's own next re-voice, so a key
## change does not ride out up to a bar of the old key still sounding.
## [method Synth.release_all] starts the outgoing notes fading over the pad
## patch's own release; see [constant PATCHES] for why pad polyphony has the
## headroom to let them.
func _revoice_pads() -> void:
	if not _started or _bar < 0 or not is_playing("pads"):
		return
	_synths["pads"].release_all()
	var chords := _walker.chords_at(_bar)
	var steps := _song.beats_per_bar * 4
	var chord_steps := steps / chords.size()
	var remaining := chord_steps - _step_in_bar % chord_steps
	var chord := _song.chord_in_bar(chords, _step_in_bar).transposed(_key_offset)
	_voice_pads(chord, _seconds_per_step() * (remaining - 0.5))


## [param bars] shifted by [param offset]'s pitch class and folded by a whole
## octave, if that keeps the line better inside [param register] — the same
## shape, moved as a block, rather than each note refit to the register on its
## own. Per-note folding would turn steps into leaps and change the contour a
## section is recognised by; folding the whole line preserves it. [param
## bars] is never mutated: this returns a new structure, leaving the cached,
## unshifted melody untouched for the next fold.
##
## Two octave-representatives of the same pitch-class move are compared —
## [param offset] taken up, and the same move taken down an octave instead —
## and whichever leaves the line least outside [param register] wins. With
## [member Song.melody_range] exactly an octave wide, a melody that already
## uses most of it can be pushed out one side or the other by any nonzero
## shift; comparing both keeps that to the smaller side rather than always
## folding towards it.
static func _fold_melody(bars: Array, offset: int, register: Vector2i) -> Array:
	var up := posmod(offset, 12)
	var candidates: Array[int] = [up, up - 12]
	var shift: int = candidates[0]
	var least_overshoot := INF
	for candidate in candidates:
		var highest := register.x
		var lowest := register.y
		for bar in bars:
			for note in bar:
				highest = maxi(highest, note[1] + candidate)
				lowest = mini(lowest, note[1] + candidate)
		var overshoot := maxi(0, highest - register.y) + maxi(0, register.x - lowest)
		if overshoot < least_overshoot:
			least_overshoot = overshoot
			shift = candidate
	var folded := []
	for bar in bars:
		var folded_bar := []
		for note in bar:
			folded_bar.append([note[0], note[1] + shift, note[2]])
		folded.append(folded_bar)
	return folded


func _build_synths() -> void:
	for part in PATCHES:
		var defaults: Array = PATCHES[part]
		var overrides: Dictionary = _song.timbres.get(part, {})
		var patch := SynthPatch.new()
		patch.waveform = overrides.get("waveform", defaults[0])
		patch.attack_seconds = overrides.get("attack", defaults[1])
		patch.release_seconds = overrides.get("release", defaults[2])
		patch.level = overrides.get("level", defaults[3])
		patch.glide_seconds = 0.06 if part == "melody" else 0.0
		var synth := Synth.new()
		synth.patch = patch
		synth.polyphony = defaults[4]
		_synths[part] = synth
		add_child(synth)


func _loop_layer(layer_name: String, lines: Dictionary, rate: int) -> LoopLayer:
	var layer := LoopLayer.new()
	layer.layer_name = layer_name
	var steps := _song.beats_per_bar * 4
	var pattern := StepPattern.parse(lines if not lines.is_empty() else {"kick": ".".repeat(steps)})
	layer.stream = pattern.render(_song.tempo_bpm, _song.beats_per_bar, rate)
	layer.volume_db = LOOP_DB.get(layer_name, -8.0)
	return layer


## Chorus and a long, soft reverb on the Music bus, as in the groove demo.
func _add_space() -> void:
	var chorus := AudioEffectChorus.new()
	chorus.wet = 0.35
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.85
	reverb.damping = 0.4
	reverb.wet = 0.28
	reverb.dry = 0.9
	_effect_indices.append(AudioManager.add_bus_effect(AudioManager.MUSIC_BUS, chorus))
	_effect_indices.append(AudioManager.add_bus_effect(AudioManager.MUSIC_BUS, reverb))

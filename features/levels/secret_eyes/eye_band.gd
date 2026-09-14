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
## Drum parts are [StepPattern]s rendered into [AudioManager] loop layers, which
## already land changes on the next bar. Melodic parts are live [Synth] notes on
## a [StepClock]; whether each is on is latched once per bar, on the downbeat,
## so both kinds change at the same moment.
##
## An eye near a wall uses two distances, not one, so one hovering at the
## threshold does not flicker its part on and off: it counts as touching once
## it comes within [member touch_px], and only lets go past [member release_px].

## Emitted when an eye starts or stops touching a wall.
signal contact_changed(part: String, touching: bool)

const TEMPO_BPM := 70.0
const BEATS_PER_BAR := 4

## Heaviest first; eyes are matched to these by size.
const PARTS: Array[String] = ["beat", "bass", "pads", "melody", "arp", "ghost", "shimmer"]
const LOOP_PARTS: Array[String] = ["beat", "ghost", "shimmer"]

## i - VI - III - VII in A minor, a bar each.
const CHORDS := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
const BASS_ROOTS := [33, 29, 36, 31]

## Per sixteenth: R root, O octave up, . rest.
const BASS_LINE := "R.RO.RR.OR.RO.RO"

## Eighth notes climbing the chord and its octave, and back down.
const ARP_ORDER := [0, 1, 2, 3, 2, 1, 0, 1]

## Per bar of the progression: [step, MIDI note, length in steps]. Kept below
## A4 so nothing is shrill.
const MELODY := [
	[[0, 64, 6], [6, 62, 2], [8, 60, 8]],
	[[0, 65, 8], [8, 64, 4], [12, 60, 4]],
	[[0, 64, 10], [10, 67, 6]],
	[[0, 62, 8], [8, 59, 8]],
]

const BEAT := {
	"kick": "9.......9..5....",
	"snare": "....9.......9...",
	"hat": "5.3.5.3.5.3.5.3.",
	"open_hat": "..............4.",
}
## Ghost snares and a pushed kick: bounce under the beat.
const GHOST := {
	"snare": "..2......2....2.",
	"kick": "..........4.....",
}
const SHIMMER := {
	"hat": ".3.3.3.3.3.3.3.3",
	"clap": "....5.......5..3",
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
func start() -> void:
	if _started:
		return
	_started = true
	_build_synths()
	_add_space()
	AudioManager.set_tempo(TEMPO_BPM, BEATS_PER_BAR)
	var rate := int(AudioServer.get_mix_rate())
	var layers: Array[LoopLayer] = [
		_loop_layer("beat", BEAT, rate, -6.0),
		_loop_layer("ghost", GHOST, rate, -8.0),
		_loop_layer("shimmer", SHIMMER, rate, -9.0),
	]
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


func is_touching(eye: FloatyEye) -> bool:
	var i := _eyes.find(eye)
	return i >= 0 and _touching[i]


func _process(_delta: float) -> void:
	var simulation := get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME)
	if simulation != null:
		update_contacts((simulation as FluidSimulation).get_world_rect())


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


func _on_step(_index: int, bar: int, step_in_bar: int) -> void:
	if step_in_bar == 0:
		_latch_live_parts()
	var chord: int = bar % CHORDS.size()
	var seconds_per_step := 60.0 / TEMPO_BPM / 4.0
	if is_playing("pads") and step_in_bar == 0:
		for note in CHORDS[chord]:
			_play("pads", note, 0.8, seconds_per_step * 15.0)
	if is_playing("bass"):
		var symbol := BASS_LINE[step_in_bar % BASS_LINE.length()]
		if symbol != ".":
			var note: int = BASS_ROOTS[chord] + (12 if symbol == "O" else 0)
			_play("bass", note, 0.9 if step_in_bar % 4 == 0 else 0.7, 0.09)
	if is_playing("arp") and step_in_bar % 2 == 0:
		var tones: Array = CHORDS[chord] + [CHORDS[chord][0] + 12]
		var tone: int = tones[ARP_ORDER[step_in_bar / 2]]
		_play("arp", tone, 0.75 if step_in_bar % 8 == 0 else 0.55, seconds_per_step * 1.5)
	if is_playing("melody"):
		for phrase_note in MELODY[chord]:
			if phrase_note[0] == step_in_bar:
				_play("melody", phrase_note[1], 0.8, seconds_per_step * phrase_note[2] * 0.95)


## On the downbeat, every live part catches up with whether its eye is free.
func _latch_live_parts() -> void:
	for part in PARTS:
		if part in LOOP_PARTS:
			_playing[part] = AudioManager.is_layer_active(part)
			continue
		var wanted := wants_part(part)
		if _playing[part] and not wanted:
			_synths[part].release_all()
		_playing[part] = wanted


func _play(part: String, note: int, velocity: float, hold_seconds: float) -> void:
	var voice: SynthVoice = _synths[part].note_on(midi_to_hz(note), velocity)
	if voice == null:
		return
	get_tree().create_timer(hold_seconds).timeout.connect(
		_release_if_unchanged.bind(voice, voice.started_usec)
	)


func _release_if_unchanged(voice: SynthVoice, started_usec: int) -> void:
	if is_instance_valid(voice) and voice.started_usec == started_usec:
		voice.note_off()


func _build_synths() -> void:
	# Seven parts at once: every level sits about 3 dB under the groove demo's
	# so the full arrangement does not clip.
	_synths["bass"] = _synth(SynthWavetable.Waveform.SAW, 0.005, 0.08, 0.16, 4)
	_synths["pads"] = _synth(SynthWavetable.Waveform.SQUARE, 0.6, 1.4, 0.045, 8)
	_synths["arp"] = _synth(SynthWavetable.Waveform.SINE, 0.005, 0.3, 0.07, 4)
	_synths["melody"] = _synth(SynthWavetable.Waveform.SQUARE, 0.08, 0.5, 0.05, 2)
	(_synths["melody"] as Synth).patch.glide_seconds = 0.06
	for synth in _synths.values():
		add_child(synth)


static func _synth(
	waveform: SynthWavetable.Waveform, attack: float, release: float, level: float, voices: int
) -> Synth:
	var patch := SynthPatch.new()
	patch.waveform = waveform
	patch.attack_seconds = attack
	patch.release_seconds = release
	patch.level = level
	patch.glide_seconds = 0.0
	var synth := Synth.new()
	synth.patch = patch
	synth.polyphony = voices
	return synth


static func _loop_layer(layer_name: String, lines: Dictionary, rate: int, db: float) -> LoopLayer:
	var layer := LoopLayer.new()
	layer.layer_name = layer_name
	layer.stream = StepPattern.parse(lines).render(TEMPO_BPM, BEATS_PER_BAR, rate)
	layer.volume_db = db
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

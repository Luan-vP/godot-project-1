extends Control
## Manual proof of #56: play the synth from the keyboard and listen.
##
## A S D F G H J K hold notes (a C major scale from middle C). Up and down
## glide the most recent held note an octave. 1 2 3 pick sine, saw, square.
## R plays a short phrase that overlaps more notes than the voice cap, to hear
## stealing. Space holds a high note, to hear that saw and square stay clean up
## there.

const KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
const SCALE_SEMITONES := [0, 2, 4, 5, 7, 9, 11, 12]
const MIDDLE_C_HZ := 261.63
const HIGH_NOTE_HZ := 3520.0

## The run is written on the natural harmonic series of A (55 Hz), so every
## interval in it is a pure whole-number ratio — 3:2 fifths, 5:4 thirds, the
## 7:4 harmonic seventh — rather than equal-tempered steps. That also makes it
## a fair test: beating between voices would be the synth's fault, not the
## tuning's.
const RUN_ROOT_HZ := 55.0

## One sixteenth note, in seconds (150 bpm).
const RUN_STEP_SECONDS := 0.1

## [start step, partials sounded together, length in steps, velocity]. Two
## bars of tresillo (3 + 3 + 2) with the second bar pushed off the beat, then
## a held chord. 24 note-ons with overlapping tails, so the eight-voice pool
## has to steal.
const RUN := [
	[0, [4, 6], 6, 0.9],
	[3, [8], 3, 0.55],
	[6, [10], 4, 0.7],
	[8, [12], 3, 0.8],
	[11, [9], 3, 0.55],
	[14, [10, 15], 4, 0.75],
	[16, [5, 8], 5, 0.9],
	[19, [12], 2, 0.55],
	[21, [14], 2, 0.6],
	[22, [16], 3, 0.8],
	[24, [12, 18], 4, 0.7],
	[27, [10], 1, 0.5],
	[28, [9], 2, 0.6],
	[30, [8], 2, 0.65],
	[31, [6, 4], 1, 0.5],
	[32, [4, 6, 8, 10], 10, 0.85],
]

var _synth: Synth
var _patch := SynthPatch.new()
var _held := {}
var _last_voice: SynthVoice
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_patch.glide_seconds = 0.25
	_synth = Synth.new()
	_synth.patch = _patch
	add_child(_synth)

	var help := Label.new()
	help.position = Vector2(16, 16)
	help.text = (
		"Synth voices (#56)\n\n"
		+ "A S D F G H J K  hold notes\n"
		+ "Up / Down        glide the last note an octave\n"
		+ "1 2 3            sine / saw / square\n"
		+ "R                harmonic-series phrase (past the 8-voice cap)\n"
		+ "Space            hold a high note"
	)
	add_child(help)

	_status = Label.new()
	_status.position = Vector2(16, 190)
	add_child(_status)


func _process(_delta: float) -> void:
	var names := ["sine", "saw", "square"]
	_status.text = (
		"waveform: %s   sounding voices: %d / %d"
		% [names[_patch.waveform], _synth.sounding_count(), _synth.polyphony]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var index := KEYS.find(key.keycode)
	if index >= 0:
		_hold(key.keycode, MIDDLE_C_HZ * pow(2.0, SCALE_SEMITONES[index] / 12.0), key.pressed)
	elif key.keycode == KEY_SPACE:
		_hold(KEY_SPACE, HIGH_NOTE_HZ, key.pressed)
	elif key.pressed:
		match key.keycode:
			KEY_UP, KEY_DOWN:
				if _last_voice != null and _last_voice.is_held():
					var factor := 2.0 if key.keycode == KEY_UP else 0.5
					_last_voice.set_frequency(_last_voice.target_frequency * factor)
			KEY_1, KEY_2, KEY_3:
				_set_waveform(key.keycode - KEY_1)
			KEY_R:
				_play_run()


func _hold(id: int, hz: float, pressed: bool) -> void:
	if pressed and not _held.has(id):
		_held[id] = _synth.note_on(hz)
		_last_voice = _held[id]
	elif not pressed and _held.has(id):
		_held[id].note_off()
		_held.erase(id)


func _set_waveform(waveform: int) -> void:
	_synth.release_all()
	_held.clear()
	var next := _patch.duplicate() as SynthPatch
	next.waveform = waveform
	_patch = next
	_synth.patch = _patch


func _play_run() -> void:
	for event in RUN:
		var start: float = event[0] * RUN_STEP_SECONDS
		var hold: float = event[2] * RUN_STEP_SECONDS
		for partial in event[1]:
			get_tree().create_timer(start).timeout.connect(
				_play_timed.bind(RUN_ROOT_HZ * partial, event[3], hold)
			)


func _play_timed(hz: float, velocity: float, hold: float) -> void:
	var voice := _synth.note_on(hz, velocity)
	get_tree().create_timer(hold).timeout.connect(
		_release_if_unchanged.bind(voice, voice.started_usec)
	)


## Release [param voice] only if it is still playing the note that asked. Past
## the cap the pool steals voices, and a stale timer would otherwise cut short
## whichever later note took the voice over.
func _release_if_unchanged(voice: SynthVoice, started_usec: int) -> void:
	if voice.started_usec == started_usec:
		voice.note_off()

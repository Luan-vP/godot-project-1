extends Control
## Manual proof of #56: play the synth from the keyboard and listen.
##
## A S D F G H J K hold notes (a C major scale from middle C). Up and down
## glide the most recent held note an octave. 1 2 3 pick sine, saw, square.
## R plays a fast run of sixteen notes to hear the voice cap. Space holds a
## high note, to hear that saw and square stay clean up there.

const KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
const SCALE_SEMITONES := [0, 2, 4, 5, 7, 9, 11, 12]
const MIDDLE_C_HZ := 261.63
const HIGH_NOTE_HZ := 3520.0

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
		+ "R                fast run of 16 notes (8-voice cap)\n"
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
	for i in 16:
		get_tree().create_timer(i * 0.06).timeout.connect(
			func():
				var voice := _synth.note_on(MIDDLE_C_HZ * pow(2.0, i / 12.0), 0.8)
				get_tree().create_timer(0.7).timeout.connect(voice.note_off)
		)

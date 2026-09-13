extends Control
## Manual proof of the step grid and the drum kit: a floaty synthwave loop.
##
## Drums are [StepPattern]s rendered into loop layers, so they are
## sample-accurate. Bass and pads are live [Synth] notes fired by a
## [StepClock] on the same clock, so they are within one mix block. Layer
## changes wait for the next bar.
##
## Space starts and stops. 1 and 2 toggle the two drum layers, B the bass,
## P the pads.

const TEMPO_BPM := 70.0
const BEATS_PER_BAR := 4

## i - VI - III - VII in A minor, a bar each.
const CHORDS := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
const BASS_ROOTS := [33, 29, 36, 31]

## Per sixteenth: R root, O octave up, . rest. Off-beat pushes keep it moving.
const BASS_LINE := "R.RO.RR.OR.RO.RO"

const BEAT := {
	"kick": "9.......9..5....",
	"snare": "....9.......9...",
	"hat": "5.3.5.3.5.3.5.3.",
	"open_hat": "..............4.",
}
const SHIMMER := {
	"hat": ".3.3.3.3.3.3.3.3",
	"clap": "....5.......5..3",
}

var _bass: Synth
var _pads: Synth
var _clock: StepClock
var _pad_voices: Array[SynthVoice] = []
var _bass_on := true
var _pads_on := true
var _effect_indices: Array[int] = []
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_labels()
	_build_instruments()
	_add_space()

	AudioManager.set_tempo(TEMPO_BPM, BEATS_PER_BAR)
	var rate := int(AudioServer.get_mix_rate())
	var layers: Array[LoopLayer] = [
		_drum_layer("beat", BEAT, rate, -3.0), _drum_layer("shimmer", SHIMMER, rate, -6.0)
	]
	AudioManager.configure_loop_layers(layers)
	AudioManager.set_layer_active("beat", true)

	_clock = StepClock.new()
	_clock.step.connect(_on_step)
	add_child(_clock)


func _exit_tree() -> void:
	AudioManager.stop_loops()
	for i in range(_effect_indices.size() - 1, -1, -1):
		AudioManager.remove_bus_effect(AudioManager.MUSIC_BUS, _effect_indices[i])


func _process(_delta: float) -> void:
	if not AudioManager.is_loops_playing():
		_status.text = "stopped — Space to play"
		return
	var clock := AudioManager.get_music_clock()
	var step := clock.step_at(AudioManager.get_music_time_source().get_seconds())
	_status.text = (
		"bar %d  step %2d   beat:%s shimmer:%s bass:%s pads:%s"
		% [
			step / clock.steps_per_bar() + 1,
			step % clock.steps_per_bar() + 1,
			_on_off(AudioManager.is_layer_active("beat")),
			_on_off(AudioManager.is_layer_active("shimmer")),
			_on_off(_bass_on),
			_on_off(_pads_on),
		]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			if AudioManager.is_loops_playing():
				AudioManager.stop_loops()
				_bass.release_all()
				_pads.release_all()
			else:
				AudioManager.play_loops()
		KEY_1:
			AudioManager.set_layer_active("beat", not AudioManager.is_layer_active("beat"))
		KEY_2:
			AudioManager.set_layer_active("shimmer", not AudioManager.is_layer_active("shimmer"))
		KEY_B:
			_bass_on = not _bass_on
		KEY_P:
			_pads_on = not _pads_on
			if not _pads_on:
				_pads.release_all()


func _on_step(_index: int, bar: int, step_in_bar: int) -> void:
	var chord := bar % CHORDS.size()
	if step_in_bar == 0 and _pads_on:
		for voice in _pad_voices:
			voice.note_off()
		_pad_voices.clear()
		for note in CHORDS[chord]:
			_pad_voices.append(_pads.note_on(midi_to_hz(note), 0.8))
	if not _bass_on:
		return
	var symbol := BASS_LINE[step_in_bar % BASS_LINE.length()]
	if symbol == ".":
		return
	var note: int = BASS_ROOTS[chord] + (12 if symbol == "O" else 0)
	var voice := _bass.note_on(midi_to_hz(note), 0.9 if step_in_bar % 4 == 0 else 0.7)
	get_tree().create_timer(0.09).timeout.connect(
		_release_if_unchanged.bind(voice, voice.started_usec)
	)


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _release_if_unchanged(voice: SynthVoice, started_usec: int) -> void:
	if voice.started_usec == started_usec:
		voice.note_off()


func _drum_layer(layer_name: String, lines: Dictionary, rate: int, db: float) -> LoopLayer:
	var layer := LoopLayer.new()
	layer.layer_name = layer_name
	layer.stream = StepPattern.parse(lines).render(TEMPO_BPM, BEATS_PER_BAR, rate)
	layer.volume_db = db
	return layer


func _build_instruments() -> void:
	var bass_patch := SynthPatch.new()
	bass_patch.waveform = SynthWavetable.Waveform.SAW
	bass_patch.attack_seconds = 0.005
	bass_patch.release_seconds = 0.08
	bass_patch.level = 0.22
	bass_patch.glide_seconds = 0.0
	_bass = Synth.new()
	_bass.patch = bass_patch
	_bass.polyphony = 4
	add_child(_bass)

	var pad_patch := SynthPatch.new()
	pad_patch.waveform = SynthWavetable.Waveform.SQUARE
	pad_patch.attack_seconds = 0.6
	pad_patch.release_seconds = 1.4
	pad_patch.level = 0.07
	_pads = Synth.new()
	_pads.patch = pad_patch
	_pads.polyphony = 8
	add_child(_pads)


## Chorus and a long, soft reverb on the Music bus: most of what makes it float.
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


func _build_labels() -> void:
	var help := Label.new()
	help.position = Vector2(16, 16)
	help.text = (
		"Groove demo: step grid + drum kit (70 bpm)\n\n"
		+ "Space   play / stop\n"
		+ "1       drums: beat layer\n"
		+ "2       drums: shimmer layer\n"
		+ "B       bass (live, on the step clock)\n"
		+ "P       pads (live, a chord each bar)\n\n"
		+ "Layer changes land on the next bar."
	)
	add_child(help)
	_status = Label.new()
	_status.position = Vector2(16, 270)
	add_child(_status)


func _on_off(value: bool) -> String:
	return "on" if value else "off"

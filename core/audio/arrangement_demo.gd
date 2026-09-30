extends Control
## Manual proof of #34: a full [MusicArrangement] wired to real scoring
## snapshots, with nothing simulated except the scoring itself — there is no
## scorer (#26) or edge detector (#23) yet, so this stands in for both by
## publishing [ScoringSnapshot]s through [signal EventBus.scoring_updated]
## from the keyboard, exactly the way the real ones eventually will.
##
## The layer stack is drums from the groove demo's own material (#59): kick
## and snare, then hats, then claps join as intensity climbs. A soft pad drone
## plays underneath regardless of scoring — #28's answer to "is silence a
## valid state": it is not, so the drone is a bed the stack builds on rather
## than something scoring switches on from nothing.
##
## +/- change how many simulated floaters are scoring. C toggles whether they
## stack on one edge or scatter across several, which is the one thing worth
## listening for here: the same floater count sounds fuller stacked, because
## #26's superlinear rule (see [ScoringIntensity]) rewards clustering. Watch
## the layers thin out gradually, not cut out, as intensity falls — that lag
## is [ArrangementDirector]'s hysteresis, without which a score hovering near
## a threshold would chatter a layer in and out.

const TEMPO_BPM := 70.0
const BEATS_PER_BAR := 4
const MAX_FLOATERS := 6

const LAYERS: Array[String] = ["beat", "hats", "claps"]
const THRESHOLDS: Array[float] = [1.0, 4.0, 9.0]  # 1, 2 and 3 floaters clustered.
const RELEASE_SECONDS := 3.0
const MIN_HOLD_SECONDS := 1.5

const BEAT := {"kick": "9.......9.......", "snare": "....9.......9..."}
const HATS := {"hat": "5.3.5.3.5.3.5.3."}
const CLAPS := {"clap": "....5.......5..3", "open_hat": "..............4."}

var _arrangement: MusicArrangement
var _bed: Synth
var _floater_count := 0
var _scattered := false
var _status: Label
var _effect_indices: Array[int] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_labels()
	_build_bed()

	AudioManager.set_tempo(TEMPO_BPM, BEATS_PER_BAR)
	var rate := int(AudioServer.get_mix_rate())
	var layers: Array[LoopLayer] = [
		_drum_layer("beat", BEAT, rate, -3.0),
		_drum_layer("hats", HATS, rate, -6.0),
		_drum_layer("claps", CLAPS, rate, -6.0),
	]
	AudioManager.configure_loop_layers(layers)
	AudioManager.play_loops()

	_arrangement = MusicArrangement.new()
	add_child(_arrangement)
	_arrangement.configure(LAYERS, THRESHOLDS, RELEASE_SECONDS, MIN_HOLD_SECONDS)

	_bed.note_on(midi_to_hz(45), 0.5)
	_bed.note_on(midi_to_hz(52), 0.35)


func _exit_tree() -> void:
	AudioManager.stop_loops()
	for i in range(_effect_indices.size() - 1, -1, -1):
		AudioManager.remove_bus_effect(AudioManager.MUSIC_BUS, _effect_indices[i])


func _process(_delta: float) -> void:
	var snapshot := _current_snapshot()
	EventBus.scoring_updated.emit(snapshot)

	var active := _arrangement.active_layers()
	var layers_text := ", ".join(active) if not active.is_empty() else "(bed only)"
	_status.text = (
		"floaters: %d (%s)   intensity: %.0f   layers: %s"
		% [
			_floater_count,
			"scattered" if _scattered else "clustered",
			ScoringIntensity.compute(snapshot),
			layers_text,
		]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_EQUAL, KEY_KP_ADD:
			_floater_count = mini(_floater_count + 1, MAX_FLOATERS)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_floater_count = maxi(_floater_count - 1, 0)
		KEY_C:
			_scattered = not _scattered


## Builds a snapshot the way a real scorer would: one contact per simulated
## floater. Clustered puts them all on the same edge, so [ScoringIntensity]
## scores them superlinearly; scattered spreads them one per edge.
func _current_snapshot() -> ScoringSnapshot:
	var contacts: Array[ScoringContact] = []
	for i in _floater_count:
		var edge_id := i if _scattered else 0
		contacts.append(ScoringContact.new(edge_id, i, 0.5))
	return ScoringSnapshot.new(contacts)


static func midi_to_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _drum_layer(layer_name: String, lines: Dictionary, rate: int, db: float) -> LoopLayer:
	var layer := LoopLayer.new()
	layer.layer_name = layer_name
	layer.stream = StepPattern.parse(lines).render(TEMPO_BPM, BEATS_PER_BAR, rate)
	layer.volume_db = db
	return layer


## The always-on floaty bed #28 decided silence should never fall below.
func _build_bed() -> void:
	var patch := SynthPatch.new()
	patch.waveform = SynthWavetable.Waveform.SQUARE
	patch.attack_seconds = 1.2
	patch.release_seconds = 2.0
	patch.level = 0.06
	_bed = Synth.new()
	_bed.patch = patch
	_bed.polyphony = 2
	add_child(_bed)

	var chorus := AudioEffectChorus.new()
	chorus.wet = 0.3
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.wet = 0.3
	_effect_indices.append(AudioManager.add_bus_effect(AudioManager.MUSIC_BUS, chorus))
	_effect_indices.append(AudioManager.add_bus_effect(AudioManager.MUSIC_BUS, reverb))


func _build_labels() -> void:
	var help := Label.new()
	help.position = Vector2(16, 16)
	help.text = (
		(
			"Arrangement demo: scoring drives the layer stack (#34)\n\n"
			+ "+/-     simulated floaters scoring (0-%d)\n"
			+ "C       toggle clustered on one edge / scattered across several\n\n"
			+ "A soft pad drone always plays underneath - #28's answer to silence.\n"
			+ "Layers join as intensity rises and leave gradually as it falls;\n"
			+ "watch the lag before a layer drops, that's the hysteresis."
		)
		% MAX_FLOATERS
	)
	add_child(help)
	_status = Label.new()
	_status.position = Vector2(16, 220)
	add_child(_status)

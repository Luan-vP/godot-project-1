class_name SynthVoice
extends Node
## One continuous synth tone: note on, hold, glide, note off.
##
## Plays [SynthWavetable]'s bands for its patch's waveform through a single
## [AudioStreamSynchronized], so they stay phase-locked. Each frame it moves
## its envelope and pitch towards their targets and pushes the result onto the
## player: pitch scale for frequency, per-band volume for the band crossfade,
## and player volume for envelope and level. Godot ramps volume across each mix
## block, so envelope changes land smoothly rather than as per-frame steps.
##
## The envelope and glide maths are static and pure so they can be checked
## without a scene tree or an audio device.

## Emitted when a released note has fully faded and the voice is idle again.
signal finished

## Shortest attack or release allowed. An instant start or stop is a step in
## the waveform, which is a click.
const MIN_ENVELOPE_SECONDS := 0.005

## Longest a new note waits for the audio thread to actually start mixing it
## before the envelope moves anyway. See [method advance].
const START_TIMEOUT_SECONDS := 0.25

const _SILENT_DB := -80.0

@export var patch: SynthPatch:
	set = set_patch

## Bus the voice plays through. Effects on that bus, and any [ParameterFader]
## driving them, apply to the voice unchanged.
@export var bus: StringName = &"Music"

## Current envelope, 0..1.
var envelope: float = 0.0

## Frequency currently sounding, in hertz, gliding towards [member target_frequency].
var frequency: float = 440.0

var target_frequency: float = 440.0

## Linear 0..1 scale on the patch level for this note.
var velocity: float = 1.0

## [method Time.get_ticks_usec] at the last note on, for voice stealing.
var started_usec: int = 0

var _gate := false
var _glide_from_hz: float = 440.0
var _glide_elapsed: float = 0.0
var _awaiting_start := false
var _start_wait: float = 0.0
var _player: AudioStreamPlayer
var _stream: AudioStreamSynchronized


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.bus = bus
	_player.volume_db = _SILENT_DB
	add_child(_player)
	_rebuild_stream()


func _process(delta: float) -> void:
	if not is_sounding():
		return
	advance(delta)
	_apply()


func set_patch(value: SynthPatch) -> void:
	patch = value
	if is_inside_tree():
		_rebuild_stream()


## Start a note at [param hz]. A voice already sounding restarts its envelope
## from where it is rather than from silence, so a retrigger does not click.
func note_on(hz: float, note_velocity: float = 1.0) -> void:
	_gate = true
	velocity = clampf(note_velocity, 0.0, 1.0)
	target_frequency = maxf(hz, 1.0)
	# A note starts at its own pitch, even on a voice that was still sounding
	# (a retrigger or a steal); glide is for moving a held note.
	frequency = target_frequency
	_glide_from_hz = target_frequency
	_glide_elapsed = INF
	started_usec = Time.get_ticks_usec()
	if _player != null and not _player.playing:
		_apply()
		_player.play()
		_awaiting_start = true
		_start_wait = 0.0


## Release the note; the voice fades over the patch's release and then idles.
func note_off() -> void:
	_gate = false


## Glide a sounding note to [param hz] over the patch's glide time.
func set_frequency(hz: float) -> void:
	hz = maxf(hz, 1.0)
	if hz == target_frequency:
		return
	target_frequency = hz
	_begin_glide()


func is_held() -> bool:
	return _gate


## True while held or still fading out.
func is_sounding() -> bool:
	return _gate or envelope > 0.0


## Move envelope and pitch forward by [param delta] seconds. Called every frame
## while sounding; exposed so tests can drive a voice without the audio device.
func advance(delta: float) -> void:
	var attack := patch.attack_seconds if patch else 0.01
	var release := patch.release_seconds if patch else 0.3
	var glide := patch.glide_seconds if patch else 0.0
	if _awaiting_start:
		# play() only takes effect on the audio thread's next mix, which can be
		# a frame or more away. Moving the envelope before then means the
		# attack has already finished by the time the first sample is mixed,
		# and the note starts at full level: a click. Hold at silence until
		# playback has really begun.
		_start_wait += delta
		var started := _player == null or _player.get_playback_position() > 0.0
		if not started and _start_wait < START_TIMEOUT_SECONDS:
			return
		_awaiting_start = false
	var was_sounding := envelope > 0.0
	envelope = step_envelope(envelope, _gate, attack, release, delta)
	_glide_elapsed += delta
	frequency = glide_at(_glide_from_hz, target_frequency, _glide_elapsed, glide)
	if was_sounding and not is_sounding():
		if _player != null:
			_player.stop()
		finished.emit()


## Envelope level after [param delta] seconds: linear rise to 1 over
## [param attack_seconds] while [param gate] is held, linear fall to 0 over
## [param release_seconds] once it is not. Linear, so the result after one
## second is the same whether it arrived in 30 steps or 144.
static func step_envelope(
	level: float, gate: bool, attack_seconds: float, release_seconds: float, delta: float
) -> float:
	if delta <= 0.0:
		return level
	if gate:
		return minf(level + delta / maxf(attack_seconds, MIN_ENVELOPE_SECONDS), 1.0)
	return maxf(level - delta / maxf(release_seconds, MIN_ENVELOPE_SECONDS), 0.0)


## Frequency [param elapsed] seconds into a glide from [param from_hz] to
## [param to_hz] lasting [param glide_seconds]. Eased in and out, and linear in
## log-frequency, so it covers each octave evenly whatever the register and
## arrives exactly on time.
##
## Eased rather than exponential on purpose. Pitch can only change once per
## mix block (about 10 ms), so what is heard is the largest step between
## blocks. An exponential approach is steepest at its very start and jumps
## most right when the glide begins; an eased curve starts from rest.
static func glide_at(from_hz: float, to_hz: float, elapsed: float, glide_seconds: float) -> float:
	if glide_seconds <= 0.0 or elapsed >= glide_seconds or from_hz <= 0.0 or to_hz <= 0.0:
		return to_hz
	var progress := smoothstep(0.0, 1.0, maxf(elapsed, 0.0) / glide_seconds)
	return exp(lerpf(log(from_hz), log(to_hz), progress))


func _begin_glide() -> void:
	_glide_from_hz = frequency
	_glide_elapsed = 0.0


func _rebuild_stream() -> void:
	if _player == null:
		return
	var waveform := patch.waveform if patch else SynthWavetable.Waveform.SINE
	var tables := SynthWavetable.bands(waveform, AudioServer.get_mix_rate())
	_stream = AudioStreamSynchronized.new()
	_stream.stream_count = tables.size()
	for i in tables.size():
		_stream.set_sync_stream(i, tables[i])
		_stream.set_sync_stream_volume(i, _SILENT_DB)
	var was_playing := _player.playing
	_player.stream = _stream
	if was_playing:
		_player.play()


func _apply() -> void:
	if _player == null or _stream == null:
		return
	_player.pitch_scale = frequency / SynthWavetable.base_frequency()
	var weights := SynthWavetable.band_weights(frequency, _stream.stream_count)
	for i in weights.size():
		var db := linear_to_db(weights[i]) if weights[i] > 0.0 else _SILENT_DB
		_stream.set_sync_stream_volume(i, maxf(db, _SILENT_DB))
	var level := patch.level if patch else 0.3
	var gain := envelope * level * velocity
	_player.volume_db = linear_to_db(gain) if gain > 0.0 else _SILENT_DB

class_name ContactSound
extends Node
## Turns [signal EventBus.scoring_updated] into sound (#33): one [SynthVoice]
## per scoring contact, pitched by where the floater sits along its edge.
##
## [b]New versus continuing[/b] comes straight from [method
## ScoringSnapshot.new_contacts] and [method ScoringSnapshot.ended_keys]: a
## contact whose key ([method ScoringContact.key]) is new starts a voice: one
## that persists is found by key and only has its pitch nudged. Keying off
## anything else — position, order, edge id alone — would retrigger a held
## contact every time its position changes, which is every tick; that is the
## "machine gun" failure mode the issue calls out by name.
##
## [b]Pitch[/b] is continuous, not quantised to a scale — see this feature's
## README for the reasoning. Position reaches the voice through a
## [ParameterFader] per contact ([member pitch_retention_per_second]), never
## written to [method SynthVoice.set_frequency] straight from the raw value —
## the same reasoning [ParameterFader] exists for at all (#32): a value that
## changes every scoring tick, assigned straight to a synthesis parameter,
## zippers.
##
## [b]Voices are bounded[/b] by [member voice_cap]. Past it, a new contact
## simply does not sound until a slot frees — it does not steal from a
## contact already playing. A floater already scoring has already been heard
## announcing itself; interrupting it to announce a brand new arrival would be
## more disruptive than the arrival staying quiet a moment. That also sidesteps
## needing to know which of two contacts *deserves* a voice more, and it means
## [Synth]'s own polyphony/stealing (built for interactive note-by-note
## playing) never needs to be reasoned about here: this class enforces the cap
## itself before ever asking [Synth] for a voice.
##
## [b]Headroom[/b] is whatever [SynthPatch.level] and [member voice_cap] leave
## on the bus — see [Synth]'s own docs on voices summing. Nothing here scales a
## per-voice level by how many contacts are active; loudness is capped by
## bounding voice count and keeping each voice quiet, not by attenuating with
## contact count (which would still let enough simultaneous contacts clip, and
## would quietly change level as an unrelated side effect of activity).

## What a contact's voice sounds like. Left unset, [method _ready] fills in
## [method _default_patch]: a quiet, plain sine — this is a lot of concurrent,
## sustained tones, not a one-shot cue. Its [member SynthPatch.glide_seconds]
## is zero deliberately: [method SynthVoice.set_frequency] is called every
## frame from an already-smoothed value (see [member
## pitch_retention_per_second]), so a second, hidden glide on top would just
## blur the one the fader already does, for no gain.
@export var patch: SynthPatch:
	set = set_patch

## Highest number of contacts sounding at once. See the class doc for what
## happens past it.
@export_range(1, 16) var voice_cap: int = 4:
	set = set_voice_cap

## Bus every voice plays through.
@export var bus: StringName = &"Music"

## Hertz a contact at position 0 sounds at.
@export_range(20.0, 2000.0, 1.0, "or_greater") var root_hz: float = 220.0

## Semitones above [member root_hz] a contact at position 1 sounds at.
@export_range(1.0, 36.0, 0.1) var span_semitones: float = 12.0

## Fraction of the remaining pitch gap, in the 0..1 position space, that
## survives one second — fed to each contact's [ParameterFader]. Low, so drift
## reaches the ear as a smooth glissando rather than a stepped one, without
## lagging so far behind that a contact's pitch feels disconnected from where
## it actually is.
@export_range(0.0, 1.0) var pitch_retention_per_second: float = 0.05

var _synth: Synth
var _previous_snapshot: ScoringSnapshot
var _voices_by_key: Dictionary = {}  # String -> SynthVoice
var _faders_by_key: Dictionary = {}  # String -> ParameterFader
var _positions_by_key: Dictionary = {}  # String -> float


func _ready() -> void:
	if patch == null:
		patch = _default_patch()
	_synth = Synth.new()
	_synth.name = "Synth"
	_synth.patch = patch
	_synth.polyphony = voice_cap
	_synth.bus = bus
	add_child(_synth)
	EventBus.scoring_updated.connect(apply_snapshot)


func _exit_tree() -> void:
	if EventBus.scoring_updated.is_connected(apply_snapshot):
		EventBus.scoring_updated.disconnect(apply_snapshot)


func _process(delta: float) -> void:
	advance(delta)


func set_patch(value: SynthPatch) -> void:
	patch = value
	if _synth != null:
		_synth.patch = value


## Raising this after [method _ready] tightens nothing new to steal from:
## [Synth] sizes its voice pool once, from [member voice_cap] at the time it
## is added to the tree, and does not grow it later. Lowering it at runtime is
## always safe — this class's own cap check in [method _start] is what
## actually enforces the limit tick to tick; [member Synth.polyphony] here is
## just kept in step for anything inspecting it directly.
func set_voice_cap(value: int) -> void:
	voice_cap = value
	if _synth != null:
		_synth.polyphony = value


## React to a scoring update: start voices for new contacts, release voices
## for contacts that ended, and record the latest position for everything
## still sounding. Public, and separate from the [signal
## EventBus.scoring_updated] connection, so a test can drive it directly with
## a hand-built [ScoringSnapshot] and no signal involved.
func apply_snapshot(snapshot: ScoringSnapshot) -> void:
	for key in snapshot.ended_keys(_previous_snapshot):
		_release(key)
	for contact in snapshot.new_contacts(_previous_snapshot):
		_start(contact)
	for contact in snapshot.contacts:
		var key := contact.key()
		if _positions_by_key.has(key):
			_positions_by_key[key] = contact.position
	_previous_snapshot = snapshot


## Move every sounding contact's pitch fader forward by [param delta] seconds
## and push the smoothed result into its voice. Called every frame; exposed so
## a test can drive it by hand, the same way [method SynthVoice.advance] is.
func advance(delta: float) -> void:
	for key in _voices_by_key:
		var voice: SynthVoice = _voices_by_key[key]
		var fader: ParameterFader = _faders_by_key[key]
		var position: float = _positions_by_key.get(key, 0.0)
		var smoothed := fader.advance(delta, position)
		voice.set_frequency(ContactPitch.hz_for_position(smoothed, root_hz, span_semitones))


## How many contacts are currently sounding. Never more than [member voice_cap].
func sounding_count() -> int:
	return _voices_by_key.size()


## The voice a contact is sounding on, or [code]null[/code] if it has none —
## never started, already ended, or past the cap when it arrived.
func voice_for_key(key: String) -> SynthVoice:
	return _voices_by_key.get(key)


func _start(contact: ScoringContact) -> void:
	if _voices_by_key.size() >= voice_cap:
		return
	var hz := ContactPitch.hz_for_position(contact.position, root_hz, span_semitones)
	var voice := _synth.note_on(hz)
	if voice == null:
		return
	var key := contact.key()
	_voices_by_key[key] = voice
	var fader := ParameterFader.new()
	fader.retention_per_second = pitch_retention_per_second
	fader.advance(0.0, contact.position)  # Seed it so playback starts on pitch, not fading in.
	_faders_by_key[key] = fader
	_positions_by_key[key] = contact.position


func _release(key: String) -> void:
	var voice: SynthVoice = _voices_by_key.get(key)
	if voice != null:
		voice.note_off()
	_voices_by_key.erase(key)
	_faders_by_key.erase(key)
	_positions_by_key.erase(key)


## A quiet, plain sine, tuned to sit under [member voice_cap] concurrent
## voices without needing per-contact level to depend on activity. Level 0.12
## with a cap of 4 leaves comparable headroom to [Synth]'s own measured
## default (8 saw voices at level 0.25 peaked at 0.97 on the bus).
static func _default_patch() -> SynthPatch:
	var result := SynthPatch.new()
	result.waveform = SynthWavetable.Waveform.SINE
	result.attack_seconds = 0.15
	result.release_seconds = 0.6
	result.level = 0.12
	result.glide_seconds = 0.0
	return result

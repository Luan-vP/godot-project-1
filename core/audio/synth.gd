class_name Synth
extends Node
## A bounded pool of [SynthVoice]s sharing one [SynthPatch] and one bus.
##
## Polyphony is capped at [member polyphony]. Past the cap, a new note steals a
## voice rather than being refused, in this order:
##
## 1. an idle voice, if there is one
## 2. otherwise the quietest voice that has already been released
## 3. otherwise the oldest held voice
##
## Stealing a released voice first means the note that gives way is one the
## player already let go of; choosing the quietest makes the cut least audible.
## Taking the oldest held note last is the usual synth convention — it has had
## the longest to be heard.
##
## Voices sum on the bus, so several at full level are louder than one. Keep
## [member SynthPatch.level] low and leave headroom on the bus.

@export var patch: SynthPatch:
	set = set_patch

@export_range(1, 32) var polyphony: int = 8

## Bus every voice plays through.
@export var bus: StringName = &"Music"

var _voices: Array[SynthVoice] = []


func _ready() -> void:
	for i in polyphony:
		var voice := SynthVoice.new()
		voice.name = "Voice%d" % i
		voice.bus = bus
		voice.patch = patch
		add_child(voice)
		_voices.append(voice)


func set_patch(value: SynthPatch) -> void:
	patch = value
	for voice in _voices:
		voice.patch = value


## Start a note at [param hz] and return the voice playing it, so the caller
## can glide it with [method SynthVoice.set_frequency] and release it with
## [method SynthVoice.note_off].
func note_on(hz: float, velocity: float = 1.0) -> SynthVoice:
	if _voices.is_empty():
		return null
	var voice := _voices[pick_voice(_voices)]
	voice.note_on(hz, velocity)
	return voice


## Release every held note.
func release_all() -> void:
	for voice in _voices:
		voice.note_off()


func get_voices() -> Array[SynthVoice]:
	return _voices


## How many voices are held or still fading out.
func sounding_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.is_sounding():
			count += 1
	return count


## Index of the voice a new note should use from [param voices], following the
## stealing order in the class description.
static func pick_voice(voices: Array[SynthVoice]) -> int:
	var quietest_released := -1
	var oldest_held := -1
	for i in voices.size():
		var voice := voices[i]
		if not voice.is_sounding():
			return i
		if not voice.is_held():
			if quietest_released < 0 or voice.envelope < voices[quietest_released].envelope:
				quietest_released = i
		elif oldest_held < 0 or voice.started_usec < voices[oldest_held].started_usec:
			oldest_held = i
	if quietest_released >= 0:
		return quietest_released
	return maxi(oldest_held, 0)

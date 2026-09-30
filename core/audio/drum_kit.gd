class_name DrumKit
extends Node
## A live drum kit: [DrumSynth]'s cached hit buffers, played as one-shots
## instead of mixed into a rendered [StepPattern] loop.
##
## Each hit is wrapped in an [AudioStreamWAV] once per hit per sample rate and
## cached, then played from a pool of [AudioStreamPlayer]s — [Synth]'s shape,
## with velocity standing in for a note. Past the pool size, a new hit steals
## the way [Synth] steals voices: an idle player first, then whichever has
## been sounding longest, since a one-shot has no held state to prefer
## releasing.
##
## Playing hits from script rather than mixing them at exact sample offsets
## costs onset accuracy — see [DrumSynth]'s class doc and
## core/audio/README.md for what was measured. Accepted deliberately so tempo
## changes and pattern swaps cost nothing; revisit if it sounds loose.
##
## The open-hat choke moves here too: a closed hat stops a sounding open hat's
## player outright, rather than the fade [method StepPattern.mix] used to
## write into a rendered buffer.

const _POOL_SIZE := 8

static var _stream_cache := {}

## Bus every player plays through.
@export var bus: StringName = &"Music"

## Deliberate delay behind the grid, in milliseconds, on top of whatever the
## [MusicTimeSource] already compensates for. 0 by default: hits land on the
## grid. Not what produced the "16-20 ms behind" lag (#78) — that was an
## uncompensated driver latency, now corrected for at the source — but a way
## to dial a laid-back feel back in on purpose, cheaply, once it is not a side
## effect of anything else.
@export var laid_back_offset_ms: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _started_usec: Array[int] = []
var _open_hat_index := -1


func _ready() -> void:
	for i in _POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Hit%d" % i
		player.bus = bus
		add_child(player)
		_players.append(player)
		_started_usec.append(0)


## Trigger [param hit] at [param velocity] (0..1, 0 plays nothing) and
## [param level_db] of headroom under that — a part mixed quieter than another
## is a lower [param level_db], not a different path. Delayed by
## [member laid_back_offset_ms] when that is set.
func play(hit: DrumSynth.Hit, velocity: float, level_db: float = 0.0) -> void:
	if velocity <= 0.0 or _players.is_empty():
		return
	if laid_back_offset_ms <= 0.0:
		_play_now(hit, velocity, level_db)
		return
	get_tree().create_timer(laid_back_offset_ms / 1000.0).timeout.connect(
		_play_now.bind(hit, velocity, level_db)
	)


func _play_now(hit: DrumSynth.Hit, velocity: float, level_db: float) -> void:
	if hit == DrumSynth.Hit.CLOSED_HAT and _open_hat_index >= 0:
		_players[_open_hat_index].stop()
		_open_hat_index = -1
	var index := pick_player(_playing_flags(), _started_usec)
	var player := _players[index]
	player.stream = _stream_for(hit)
	player.volume_db = level_db + linear_to_db(clampf(velocity, 0.0, 1.0))
	player.play()
	_started_usec[index] = Time.get_ticks_usec()
	if hit == DrumSynth.Hit.OPEN_HAT:
		_open_hat_index = index
	elif _open_hat_index == index:
		_open_hat_index = -1


## Stop every sounding hit at once, e.g. when the kit is torn down mid-note.
func stop_all() -> void:
	for player in _players:
		player.stop()
	_open_hat_index = -1


## Index into [param playing]/[param started_usec] a new hit should use: an
## idle player first, else whichever has been sounding the longest. Exposed
## static, like [method Synth.pick_voice], so the stealing order is testable
## without an audio device.
static func pick_player(playing: Array, started_usec: Array) -> int:
	for i in playing.size():
		if not playing[i]:
			return i
	var oldest := 0
	for i in started_usec.size():
		if started_usec[i] < started_usec[oldest]:
			oldest = i
	return oldest


func _playing_flags() -> Array:
	var flags := []
	for player in _players:
		flags.append(player.playing)
	return flags


static func _stream_for(hit: DrumSynth.Hit) -> AudioStreamWAV:
	var rate := int(AudioServer.get_mix_rate())
	var key := "%d@%d" % [hit, rate]
	if not _stream_cache.has(key):
		_stream_cache[key] = _wrap(DrumSynth.render(hit, rate), rate)
	return _stream_cache[key]


## [param samples] as a mono 16-bit one-shot stream — the same encoding
## [method StepPattern.render] uses, minus the loop points a one-shot has no
## use for.
static func _wrap(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

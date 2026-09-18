class_name DrumKit
extends Node
## A pool of one-shot players for [DrumSynth]'s hits — the live counterpart to
## playing a [StepPattern] rendered into a loop layer (see #75 and the drum
## notes in core/audio/README.md for why the eye band plays this way and what
## it costs).
##
## Triggering a hit from script lands on the next audio mix block rather than
## at an exact sample offset — audibly loose against a rendered loop, measured
## at 10-20 ms of spread depending on lookahead. Accepted for now; a
## sample-accurate [MusicTimeSource] or a streaming mixer are the ways back to
## tightness if this turns out to need it.
##
## Velocity is linear, 0 to 1, matching [method StepPattern.velocity], and
## converted to decibels at the boundary — the same rule [AudioManager]
## follows for bus volume. A closed hat cuts a sounding open hat, choked with
## a short fade rather than a click, the live equivalent of the sample-exact
## choke [method StepPattern.mix] renders.

## Silent enough that a choked or stolen voice cannot be heard resuming.
const _SILENT_DB := -80.0

static var _wav_cache := {}

## How many hits can sound at once before the oldest is cut off to make room,
## round robin — the same pooling [AudioManager] uses for one-shot SFX. Seven
## parts' worth of drums can each have a hit due on the same step, so this
## sits well above what any one song asks for at once.
@export_range(1, 32) var polyphony: int = 16

## Bus the kit plays through.
@export var bus: StringName = &"Music"

var _players: Array[AudioStreamPlayer] = []
var _tweens: Array[Tween] = []
var _next_player := 0
var _open_hat_index := -1


func _ready() -> void:
	for i in polyphony:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = bus
		add_child(player)
		_players.append(player)
		_tweens.append(null)


## Play [param hit] at [param velocity] (0 to 1) and [param volume_db] added on
## top — a part's own level, the way [EyeBand] mixes each drum part. A
## velocity of 0 or less plays nothing, matching a rest in [StepPattern].
func hit(hit_type: DrumSynth.Hit, velocity: float, volume_db: float = 0.0) -> void:
	if velocity <= 0.0:
		return
	if hit_type == DrumSynth.Hit.CLOSED_HAT:
		_choke_open_hat()
	var index := _next_player
	_next_player = (_next_player + 1) % _players.size()
	_kill_tween(index)
	if index == _open_hat_index:
		# This voice is being repurposed before it was choked; it no longer
		# holds an open hat for a later closed hat to choke.
		_open_hat_index = -1
	var player := _players[index]
	player.stream = _wav(hit_type)
	player.volume_db = linear_to_db(velocity) + volume_db
	player.play()
	if hit_type == DrumSynth.Hit.OPEN_HAT:
		_open_hat_index = index


## How many voices are sounding right now. For tests and debug readouts.
func sounding_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count


func _choke_open_hat() -> void:
	if _open_hat_index < 0:
		return
	var index := _open_hat_index
	_open_hat_index = -1
	var player := _players[index]
	if not player.playing:
		return
	var tween := create_tween()
	_tweens[index] = tween
	tween.tween_property(player, "volume_db", _SILENT_DB, StepPattern.CHOKE_FADE_SECONDS)
	tween.tween_callback(player.stop)


func _kill_tween(index: int) -> void:
	var tween: Tween = _tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens[index] = null


## [param hit_type] rendered by [DrumSynth] and wrapped for playback, once per
## hit per sample rate, cached like [method DrumSynth.render] itself.
static func _wav(hit_type: DrumSynth.Hit) -> AudioStreamWAV:
	var rate := int(AudioServer.get_mix_rate())
	var key := "%d@%d" % [hit_type, rate]
	if not _wav_cache.has(key):
		var samples := DrumSynth.render(hit_type, rate)
		var data := PackedByteArray()
		data.resize(samples.size() * 2)
		for i in samples.size():
			data.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.stereo = false
		stream.data = data
		_wav_cache[key] = stream
	return _wav_cache[key]

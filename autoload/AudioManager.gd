extends Node
## Owns audio playback and bus routing. This is the only script allowed to
## talk to [AudioServer] directly — everything else asks it to play a sound,
## change a volume, or mute a bus.
##
## Buses come from a committed layout (project setting
## `audio/buses/default_bus_layout`), not from code: [constant MASTER_BUS],
## [constant MUSIC_BUS] and [constant SFX_BUS] name buses that already exist
## by the time this node wakes up.
##
## Volume is set and read as a [b]linear[/b] fraction in [0, 1], the shape a
## UI slider produces, and converted to decibels at the boundary with
## [method @GlobalScope.linear_to_db]. A raw linear multiplier bunches all the
## perceptible range into the last stretch of a slider's travel; going
## through dB is what makes the middle of the slider sound like the middle.
##
## Bus volumes, mutes, and whether losing focus mutes are persisted through
## [SaveManager] and reloaded in [method _ready]. Nothing here knows about
## floaters, edges, or any other game concept — it is equally usable by a
## menu, a level, or a test.
##
## Loop layering (see core/audio/README.md for the reasoning) plays a set of
## [LoopLayer]s through one [AudioStreamSynchronized], so they share a single
## playback clock and cannot drift apart the way separate
## [AudioStreamPlayer]s could. [method set_layer_active] queues its change on
## a [LoopLayerScheduler] and releases it on the next bar boundary, computed
## by a [MusicClock] from an [AudioServer]-corrected playback position (see
## [method _get_loop_playback_seconds]).

## Emitted whenever a bus's volume changes, including on load. Carries the
## linear fraction, not decibels, so a slider can be driven directly.
signal bus_volume_changed(bus_name: String, linear_volume: float)

## Emitted whenever a bus's mute state changes, including on load.
signal bus_mute_changed(bus_name: String, muted: bool)

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const _ALL_BUSES: Array[String] = [MASTER_BUS, MUSIC_BUS, SFX_BUS]
const _SETTINGS_SECTION := "audio"
const _FOCUS_SETTING_KEY := "mute_on_focus_loss"

## How many overlapping one-shot sounds can play at once before the oldest is
## cut off to make room for a new one.
const _SFX_POOL_SIZE := 8

## [AudioStreamSynchronized] supports at most this many simultaneous streams.
const MAX_LOOP_LAYERS := 32

## dB floor a loop layer fades to when switched off. Not -INF, so a fade has
## a concrete value to tween from when the layer is switched back on.
const _LAYER_SILENT_DB := -80.0

## How long a layer's on/off volume change takes, so it is a short crossfade
## rather than an instant, potentially clicky jump.
const _LAYER_FADE_SECONDS := 0.05

## Whether losing window focus (alt-tab, minimizing) mutes the Master bus.
## Persisted like any other audio setting.
@export var mute_on_focus_loss: bool = true

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player := 0

var _focus_muted := false
var _master_mute_before_focus_loss := false

var _loop_player: AudioStreamPlayer
var _loop_stream: AudioStreamSynchronized
var _loop_layers: Dictionary = {}  # layer_name -> {index: int, volume_db: float}
var _loop_active_states: Dictionary = {}  # layer_name -> bool
var _loop_clock: MusicClock
var _loop_scheduler: LoopLayerScheduler


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)

	for i in _SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

	_loop_player = AudioStreamPlayer.new()
	_loop_player.name = "LoopPlayer"
	_loop_player.bus = MUSIC_BUS
	add_child(_loop_player)
	_loop_clock = MusicClock.new()
	_loop_scheduler = LoopLayerScheduler.new(_loop_clock)

	_load_settings()


func _process(_delta: float) -> void:
	if _loop_player == null or not _loop_player.playing:
		return
	var seconds := _get_loop_playback_seconds()
	var changes := _loop_scheduler.update(seconds)
	for layer_name: String in changes:
		_apply_layer_active(layer_name, changes[layer_name])


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_focus_muted(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_focus_muted(false)


## Plays a one-shot sound on the SFX bus and returns the player that ended up
## carrying it, mainly so a caller can await [signal AudioStreamPlayer.finished]
## if it cares. Players round-robin through a small pool so overlapping
## effects don't cut each other off.
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	return player


## Plays (or replaces) the current track on the Music bus.
func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func is_music_playing() -> bool:
	return _music_player.playing


## Sets the tempo and bar length the loop layer clock schedules against.
## Configurable rather than baked in; safe to call before or during
## playback, though it does not retroactively move a bar boundary a change
## has already been scheduled against.
func set_tempo(tempo_bpm: float, beats_per_bar: int = 4) -> void:
	_loop_clock = MusicClock.new(tempo_bpm, beats_per_bar)
	_loop_scheduler.set_clock(_loop_clock)


## Declares the set of loops available to layer together, as data (see
## [LoopLayer]) rather than paths hardcoded into a script. Stops playback and
## resets every layer to inactive; call [method play_loops] and
## [method set_layer_active] afterwards to start again.
func configure_loop_layers(layers: Array[LoopLayer]) -> void:
	if layers.size() > MAX_LOOP_LAYERS:
		var msg := "AudioManager: %d loop layers requested, only %d supported; the rest are dropped"
		push_warning(msg % [layers.size(), MAX_LOOP_LAYERS])

	stop_loops()
	_loop_layers.clear()
	_loop_active_states.clear()

	var sync := AudioStreamSynchronized.new()
	sync.stream_count = mini(layers.size(), MAX_LOOP_LAYERS)
	for i in sync.stream_count:
		var layer := layers[i]
		sync.set_sync_stream(i, layer.stream)
		sync.set_sync_stream_volume(i, _LAYER_SILENT_DB)
		_loop_layers[layer.layer_name] = {"index": i, "volume_db": layer.volume_db}
		_loop_active_states[layer.layer_name] = false

	_loop_stream = sync
	_loop_player.stream = _loop_stream


## Starts the configured loop layers playing together. Layers switched on
## before this call (while nothing was playing yet) are already audible from
## the first frame; layers switched on afterwards fade in on the next bar.
func play_loops() -> void:
	if _loop_player.playing:
		return
	_loop_player.play()
	_loop_scheduler.reset()


## Stops loop playback entirely and discards any pending layer changes.
func stop_loops() -> void:
	_loop_player.stop()
	_loop_scheduler.reset()


func is_loops_playing() -> bool:
	return _loop_player.playing


## Turns a loop layer on or off. Before playback has started, this takes
## effect immediately. Once loops are playing, the change is queued and only
## lands on the next bar boundary — a layer requested mid-bar enters at the
## next bar, not the instant it was asked for.
func set_layer_active(layer_name: String, active: bool) -> void:
	if not _loop_layers.has(layer_name):
		push_warning("AudioManager: unknown loop layer '%s'" % layer_name)
		return
	if not _loop_player.playing:
		_apply_layer_active(layer_name, active)
		return
	_loop_scheduler.request(layer_name, active)


func is_layer_active(layer_name: String) -> bool:
	return _loop_active_states.get(layer_name, false)


## The bar currently playing, computed from an [AudioServer]-corrected
## playback position. Bar 0 is the first bar; meaningless (0) while nothing
## is playing.
func get_current_bar() -> int:
	return _loop_clock.bar_at(_get_loop_playback_seconds())


## Position within the current bar, in beats, from 0 up to (not including)
## the configured beats per bar.
func get_current_beat() -> float:
	return _loop_clock.beat_in_bar_at(_get_loop_playback_seconds())


func get_seconds_until_next_bar() -> float:
	return _loop_clock.seconds_until_next_bar(_get_loop_playback_seconds())


func _apply_layer_active(layer_name: String, active: bool) -> void:
	_loop_active_states[layer_name] = active
	var info: Dictionary = _loop_layers[layer_name]
	var index: int = info["index"]
	var target_db: float = info["volume_db"] if active else _LAYER_SILENT_DB
	var tween := create_tween()
	tween.tween_method(
		func(db: float): _loop_stream.set_sync_stream_volume(index, db),
		_loop_stream.get_sync_stream_volume(index),
		target_db,
		_LAYER_FADE_SECONDS
	)


## [AudioStreamPlayer.get_playback_position] only updates once per mix
## buffer, so scheduling against it directly is fine in the editor and
## audibly loose on other hardware — the classic trap. Correcting it with
## [method AudioServer.get_time_since_last_mix] and
## [method AudioServer.get_output_latency] is the fix Godot's own docs
## recommend for exactly this.
func _get_loop_playback_seconds() -> float:
	if not _loop_player.playing:
		return 0.0
	var time := _loop_player.get_playback_position()
	time += AudioServer.get_time_since_last_mix()
	time -= AudioServer.get_output_latency()
	return maxf(time, 0.0)


## Sets a bus's volume from a linear fraction in [0, 1], converting to
## decibels at the boundary and persisting the choice.
func set_bus_volume_linear(bus_name: String, linear_volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return
	var clamped := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(clamped))
	SaveManager.set_value(_SETTINGS_SECTION, _volume_key(bus_name), clamped)
	bus_volume_changed.emit(bus_name, clamped)


## Reads a bus's current volume back as a linear fraction in [0, 1].
func get_bus_volume_linear(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


## Mutes or unmutes a bus. Independent of volume, so effects can be silenced
## without losing the level a player dialled in.
func set_bus_mute(bus_name: String, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return
	AudioServer.set_bus_mute(index, muted)
	SaveManager.set_value(_SETTINGS_SECTION, _mute_key(bus_name), muted)
	bus_mute_changed.emit(bus_name, muted)


func is_bus_mute(bus_name: String) -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	return index != -1 and AudioServer.is_bus_mute(index)


## Toggles and persists whether losing window focus mutes the Master bus.
func set_mute_on_focus_loss(enabled: bool) -> void:
	mute_on_focus_loss = enabled
	SaveManager.set_value(_SETTINGS_SECTION, _FOCUS_SETTING_KEY, enabled)


func _load_settings() -> void:
	for bus_name in _ALL_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index == -1:
			continue
		var volume_key := _volume_key(bus_name)
		if SaveManager.has_section_key(_SETTINGS_SECTION, volume_key):
			var linear: float = SaveManager.get_value(_SETTINGS_SECTION, volume_key, 1.0)
			AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))
		var mute_key := _mute_key(bus_name)
		if SaveManager.has_section_key(_SETTINGS_SECTION, mute_key):
			var muted: bool = SaveManager.get_value(_SETTINGS_SECTION, mute_key, false)
			AudioServer.set_bus_mute(index, muted)
	mute_on_focus_loss = SaveManager.get_value(_SETTINGS_SECTION, _FOCUS_SETTING_KEY, true)


## Only Master is touched, and only if this manager did the muting — a
## player's own mute choices on other buses must survive regaining focus.
func _set_focus_muted(losing_focus: bool) -> void:
	var index := AudioServer.get_bus_index(MASTER_BUS)
	if index == -1:
		return
	if losing_focus:
		if not mute_on_focus_loss or _focus_muted:
			return
		_master_mute_before_focus_loss = AudioServer.is_bus_mute(index)
		AudioServer.set_bus_mute(index, true)
		_focus_muted = true
	else:
		if not _focus_muted:
			return
		AudioServer.set_bus_mute(index, _master_mute_before_focus_loss)
		_focus_muted = false


func _volume_key(bus_name: String) -> String:
	return "%s_volume" % bus_name.to_lower()


func _mute_key(bus_name: String) -> String:
	return "%s_muted" % bus_name.to_lower()

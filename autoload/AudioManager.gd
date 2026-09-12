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
## [method add_bus_effect] and [method get_bus_effect] hand out effect
## instances for a caller to drive directly — typically through a
## [ParameterFader], which smooths a per-frame value into an effect's
## property instead of assigning it straight and producing zipper noise.

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

## Whether losing window focus (alt-tab, minimizing) mutes the Master bus.
## Persisted like any other audio setting.
@export var mute_on_focus_loss: bool = true

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player := 0

var _focus_muted := false
var _master_mute_before_focus_loss := false


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

	_load_settings()


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


## Adds an effect to a bus and returns its index in that bus's effect chain,
## for later use with [method get_bus_effect] — e.g. to hand the instance to a
## [ParameterFader]. Returns -1 for an unknown bus.
func add_bus_effect(bus_name: String, effect: AudioEffect) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return -1
	AudioServer.add_bus_effect(index, effect)
	return AudioServer.get_bus_effect_count(index) - 1


## Returns the effect instance at [param effect_index] on a bus, so its
## parameters can be read or driven directly — e.g. by a [ParameterFader].
## Returns null for an unknown bus or effect index.
func get_bus_effect(bus_name: String, effect_index: int) -> AudioEffect:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return null
	if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(index):
		return null
	return AudioServer.get_bus_effect(index, effect_index)


## Removes an effect from a bus, e.g. one added by [method add_bus_effect] for
## a demo that should not leave it behind.
func remove_bus_effect(bus_name: String, effect_index: int) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.remove_bus_effect(index, effect_index)


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

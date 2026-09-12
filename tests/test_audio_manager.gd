extends GutTest
## Covers [AudioManager]: the bus layout it expects to find, the linear/dB
## volume boundary, mute, and that playback actually reaches the right bus.
## Settings writes are redirected to a throwaway file so a test run never
## touches a real player's settings.

const _TEST_SETTINGS_PATH := "user://test_audio_manager_settings.cfg"


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()

	AudioManager.set_bus_volume_linear(AudioManager.MASTER_BUS, 1.0)
	AudioManager.set_bus_volume_linear(AudioManager.MUSIC_BUS, 1.0)
	AudioManager.set_bus_volume_linear(AudioManager.SFX_BUS, 1.0)
	AudioManager.set_bus_mute(AudioManager.MASTER_BUS, false)
	AudioManager.set_bus_mute(AudioManager.MUSIC_BUS, false)
	AudioManager.set_bus_mute(AudioManager.SFX_BUS, false)
	AudioManager.stop_music()


func test_the_committed_layout_provides_all_three_buses() -> void:
	assert_ne(AudioServer.get_bus_index(AudioManager.MASTER_BUS), -1, "Master bus")
	assert_ne(AudioServer.get_bus_index(AudioManager.MUSIC_BUS), -1, "Music bus")
	assert_ne(AudioServer.get_bus_index(AudioManager.SFX_BUS), -1, "SFX bus")


func test_music_and_sfx_route_to_master() -> void:
	var music_index := AudioServer.get_bus_index(AudioManager.MUSIC_BUS)
	var sfx_index := AudioServer.get_bus_index(AudioManager.SFX_BUS)
	assert_eq(AudioServer.get_bus_send(music_index), AudioManager.MASTER_BUS)
	assert_eq(AudioServer.get_bus_send(sfx_index), AudioManager.MASTER_BUS)


func test_linear_volume_round_trips_through_decibels() -> void:
	AudioManager.set_bus_volume_linear(AudioManager.MUSIC_BUS, 0.5)
	assert_almost_eq(AudioManager.get_bus_volume_linear(AudioManager.MUSIC_BUS), 0.5, 0.001)


func test_zero_linear_volume_is_far_below_a_quiet_bunched_dip() -> void:
	# The bug this guards against: treating volume as a bare linear multiplier
	# on the dB scale, which leaves "zero" audibly loud instead of silent.
	AudioManager.set_bus_volume_linear(AudioManager.MUSIC_BUS, 0.0)
	var index := AudioServer.get_bus_index(AudioManager.MUSIC_BUS)
	assert_lt(AudioServer.get_bus_volume_db(index), -60.0)


func test_full_linear_volume_is_unity_gain() -> void:
	AudioManager.set_bus_volume_linear(AudioManager.SFX_BUS, 1.0)
	var index := AudioServer.get_bus_index(AudioManager.SFX_BUS)
	assert_almost_eq(AudioServer.get_bus_volume_db(index), 0.0, 0.001)


func test_mute_is_independent_of_volume() -> void:
	AudioManager.set_bus_volume_linear(AudioManager.SFX_BUS, 0.8)
	AudioManager.set_bus_mute(AudioManager.SFX_BUS, true)
	assert_true(AudioManager.is_bus_mute(AudioManager.SFX_BUS))
	assert_almost_eq(AudioManager.get_bus_volume_linear(AudioManager.SFX_BUS), 0.8, 0.001)
	AudioManager.set_bus_mute(AudioManager.SFX_BUS, false)
	assert_false(AudioManager.is_bus_mute(AudioManager.SFX_BUS))


func test_volume_and_mute_changes_persist_through_save_manager() -> void:
	AudioManager.set_bus_volume_linear(AudioManager.MUSIC_BUS, 0.3)
	AudioManager.set_bus_mute(AudioManager.MUSIC_BUS, true)
	assert_almost_eq(float(SaveManager.get_value("audio", "music_volume", 1.0)), 0.3, 0.001)
	assert_true(SaveManager.get_value("audio", "music_muted", false))


func test_play_sfx_uses_the_sfx_bus() -> void:
	var player := AudioManager.play_sfx(AudioTestTone.generate(880.0, 0.05))
	assert_not_null(player)
	assert_eq(player.bus, AudioManager.SFX_BUS)


func test_play_music_uses_the_music_bus_and_can_be_stopped() -> void:
	AudioManager.play_music(AudioTestTone.generate(220.0, 0.05))
	assert_true(AudioManager.is_music_playing())
	AudioManager.stop_music()
	assert_false(AudioManager.is_music_playing())


func test_unknown_bus_names_do_not_crash() -> void:
	AudioManager.set_bus_volume_linear("Nonexistent", 0.5)
	AudioManager.set_bus_mute("Nonexistent", true)
	assert_eq(AudioManager.get_bus_volume_linear("Nonexistent"), 0.0)
	assert_false(AudioManager.is_bus_mute("Nonexistent"))


func test_add_and_get_bus_effect_round_trips_the_same_instance() -> void:
	var filter := AudioEffectLowPassFilter.new()
	var index := AudioManager.add_bus_effect(AudioManager.SFX_BUS, filter)
	assert_ne(index, -1, "A known bus should accept the effect")
	assert_eq(AudioManager.get_bus_effect(AudioManager.SFX_BUS, index), filter)
	AudioManager.remove_bus_effect(AudioManager.SFX_BUS, index)


func test_get_bus_effect_is_null_for_an_unknown_bus_or_index() -> void:
	assert_null(AudioManager.get_bus_effect("Nonexistent", 0))
	assert_null(AudioManager.get_bus_effect(AudioManager.SFX_BUS, 999))


func test_add_bus_effect_on_an_unknown_bus_does_not_crash() -> void:
	assert_eq(AudioManager.add_bus_effect("Nonexistent", AudioEffectLowPassFilter.new()), -1)


func test_remove_bus_effect_actually_removes_it() -> void:
	var index := AudioManager.add_bus_effect(AudioManager.SFX_BUS, AudioEffectReverb.new())
	AudioManager.remove_bus_effect(AudioManager.SFX_BUS, index)
	assert_null(AudioManager.get_bus_effect(AudioManager.SFX_BUS, index))

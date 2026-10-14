extends GutTest
## Covers [ComfortSettings]: the default is the tuned (neutral) value, the
## setter clamps and persists through [SaveManager], and apply_to_haptics
## scales a pulse. Settings writes are redirected to a throwaway file so a test
## run never touches a real player's settings.

const _TEST_SETTINGS_PATH := "user://test_comfort_settings.cfg"


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	ComfortSettings.set_haptics_strength(1.0)


func test_the_default_is_the_tuned_value() -> void:
	assert_almost_eq(ComfortSettings.haptics_strength, 1.0, 0.0001, "Full pulses by default")


func test_haptics_strength_scales_and_clamps() -> void:
	ComfortSettings.set_haptics_strength(0.5)
	assert_almost_eq(ComfortSettings.apply_to_haptics(0.8), 0.4, 0.0001)
	assert_almost_eq(ComfortSettings.apply_to_haptics(3.0), 0.5, 0.0001, "Pulse clamped first")
	ComfortSettings.set_haptics_strength(4.0)
	assert_almost_eq(ComfortSettings.haptics_strength, 1.0, 0.0001, "Never exaggerated")


func test_the_setting_survives_a_reload_from_disk() -> void:
	ComfortSettings.set_haptics_strength(0.3)
	assert_almost_eq(float(SaveManager.get_value("comfort", "haptics_strength", -1.0)), 0.3, 0.0001)
	SaveManager.reload()
	ComfortSettings._load_settings()
	assert_almost_eq(ComfortSettings.haptics_strength, 0.3, 0.0001)


func test_changing_it_emits_its_signal() -> void:
	watch_signals(ComfortSettings)
	ComfortSettings.set_haptics_strength(0.2)
	assert_signal_emitted_with_parameters(ComfortSettings, "haptics_strength_changed", [0.2])

extends GutTest
## Covers [ComfortSettings]: defaults are the tuned (neutral) values, setters
## clamp and persist through [SaveManager], and the apply_to_* helpers scale a
## level's tuned numbers the way [PanoramaLevel] expects. Settings writes are
## redirected to a throwaway file so a test run never touches a real player's
## settings.

const _TEST_SETTINGS_PATH := "user://test_comfort_settings.cfg"


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()

	ComfortSettings.set_distortion_multiplier(1.0)
	ComfortSettings.set_look_sensitivity_multiplier(1.0)
	ComfortSettings.set_overshoot_reduction(0.0)


func test_defaults_are_the_tuned_values_not_the_accessible_ones() -> void:
	assert_almost_eq(ComfortSettings.distortion_multiplier, 1.0, 0.0001, "Full bend by default")
	assert_almost_eq(
		ComfortSettings.look_sensitivity_multiplier, 1.0, 0.0001, "Untouched sensitivity"
	)
	assert_almost_eq(ComfortSettings.overshoot_reduction, 0.0, 0.0001, "Tuned lag by default")


func test_distortion_multiplier_can_reach_zero() -> void:
	ComfortSettings.set_distortion_multiplier(0.0)
	assert_almost_eq(ComfortSettings.apply_to_distortion(0.012), 0.0, 0.0001)


func test_distortion_multiplier_is_clamped_to_zero_one() -> void:
	ComfortSettings.set_distortion_multiplier(-1.0)
	assert_almost_eq(ComfortSettings.distortion_multiplier, 0.0, 0.0001)
	ComfortSettings.set_distortion_multiplier(4.0)
	assert_almost_eq(ComfortSettings.distortion_multiplier, 1.0, 0.0001, "Never exaggerated")


func test_look_sensitivity_multiplier_scales_a_levels_tuned_value() -> void:
	ComfortSettings.set_look_sensitivity_multiplier(0.5)
	assert_almost_eq(ComfortSettings.apply_to_look_sensitivity(1.2), 0.6, 0.0001)


func test_overshoot_reduction_zero_leaves_drag_untouched() -> void:
	ComfortSettings.set_overshoot_reduction(0.0)
	assert_almost_eq(ComfortSettings.apply_to_floater_drag(2.2), 2.2, 0.0001)


func test_overshoot_reduction_one_removes_lag_with_a_high_drag() -> void:
	ComfortSettings.set_overshoot_reduction(1.0)
	var drag := ComfortSettings.apply_to_floater_drag(2.2)
	# High enough that FluidBody.drift's drag*delta clamp saturates at 1 for
	# any real frame time, so the floater tracks the current with no lag.
	assert_gt(drag * (1.0 / 30.0), 1.0, "Should fully snap onto the current even at 30 fps")


func test_settings_persist_through_save_manager() -> void:
	ComfortSettings.set_distortion_multiplier(0.25)
	ComfortSettings.set_look_sensitivity_multiplier(2.0)
	ComfortSettings.set_overshoot_reduction(0.75)

	assert_almost_eq(
		float(SaveManager.get_value("comfort", "distortion_multiplier", -1.0)), 0.25, 0.0001
	)
	assert_almost_eq(
		float(SaveManager.get_value("comfort", "look_sensitivity_multiplier", -1.0)), 2.0, 0.0001
	)
	assert_almost_eq(
		float(SaveManager.get_value("comfort", "overshoot_reduction", -1.0)), 0.75, 0.0001
	)


func test_settings_survive_a_reload_from_disk() -> void:
	ComfortSettings.set_distortion_multiplier(0.4)
	ComfortSettings.set_overshoot_reduction(0.6)
	SaveManager.reload()
	ComfortSettings._load_settings()
	assert_almost_eq(ComfortSettings.distortion_multiplier, 0.4, 0.0001)
	assert_almost_eq(ComfortSettings.overshoot_reduction, 0.6, 0.0001)


func test_changing_a_setting_emits_its_signal() -> void:
	watch_signals(ComfortSettings)
	ComfortSettings.set_distortion_multiplier(0.3)
	assert_signal_emitted_with_parameters(
		ComfortSettings, "distortion_multiplier_changed", [0.3]
	)

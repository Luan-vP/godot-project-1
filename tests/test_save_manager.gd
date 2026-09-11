extends GutTest
## Covers [SaveManager]'s generic settings persistence. Runs against a
## throwaway file so it never touches real player settings.

const _TEST_PATH := "user://test_save_manager_settings.cfg"


func before_each() -> void:
	SaveManager.settings_path = _TEST_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_PATH):
		DirAccess.remove_absolute(_TEST_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()


func test_round_trips_a_value() -> void:
	SaveManager.set_value("audio", "master_volume", 0.75)
	assert_almost_eq(
		float(SaveManager.get_value("audio", "master_volume", 1.0)), 0.75, 0.0001
	)


func test_missing_key_returns_the_default() -> void:
	assert_eq(SaveManager.get_value("audio", "missing", "fallback"), "fallback")


func test_has_section_key_reflects_what_was_set() -> void:
	assert_false(SaveManager.has_section_key("audio", "master_volume"))
	SaveManager.set_value("audio", "master_volume", 1.0)
	assert_true(SaveManager.has_section_key("audio", "master_volume"))


func test_a_value_survives_a_reload_from_disk() -> void:
	SaveManager.set_value("audio", "sfx_muted", true)
	SaveManager.reload()
	assert_true(SaveManager.get_value("audio", "sfx_muted", false))

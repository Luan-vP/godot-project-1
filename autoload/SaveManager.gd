extends Node
## Generic key/value settings persistence, backed by a [ConfigFile] on disk.
## This is the only script that touches the settings file directly.
##
## Callers group values under a section (e.g. "audio") and hand over a key
## and a value; [SaveManager] does not know or care what they mean. That
## keeps it usable for any future settings, not just audio.
##
## Game-save data — state to resume a run — is a separate, later concern.
## [method save_game], [method load_game] and [method has_save] stay stubs
## until that lands; this only covers small, persistent settings.

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"

## Overridable so tests can point this at a throwaway file instead of the
## player's real settings.
var settings_path: String = DEFAULT_SETTINGS_PATH

var _config := ConfigFile.new()
var _loaded := false


## Writes a value under [param section]/[param key] and saves immediately.
## Settings are small and infrequent, so there is no reason to batch writes.
func set_value(section: String, key: String, value: Variant) -> void:
	_ensure_loaded()
	_config.set_value(section, key, value)
	_config.save(settings_path)


## Reads a value back, or [param default_value] if it was never set.
func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	_ensure_loaded()
	return _config.get_value(section, key, default_value)


func has_section_key(section: String, key: String) -> bool:
	_ensure_loaded()
	return _config.has_section_key(section, key)


## Drops the in-memory config so the next read comes from disk. Production
## code never needs this; it exists so tests can point [member settings_path]
## at a fresh file and start clean.
func reload() -> void:
	_config = ConfigFile.new()
	_loaded = false


func _ensure_loaded() -> void:
	if _loaded:
		return
	_config.load(settings_path)  # Missing file is fine; ConfigFile stays empty.
	_loaded = true


func save_game() -> void:
	pass


func load_game() -> void:
	pass


func has_save() -> bool:
	return false

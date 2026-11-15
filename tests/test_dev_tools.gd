extends GutTest
## Covers the split between the Deck's build and every other ([DevTools]):
## that only the "Steam Deck" preset carries the menu and the picker, and that
## nothing every build ships names a class those builds leave out (an export
## missing a script it names fails to parse it, and with it the scene).

const PRESETS_PATH := "res://export_presets.cfg"
## Folders never exported, so free to name anything.
const UNSHIPPED: Array[String] = ["res://tests/", "res://addons/", "res://.godot/"]


func after_each() -> void:
	DevTools.forced = null


func test_the_editor_has_the_tools() -> void:
	assert_true(DevTools.enabled(), "Tests run in the editor binary")


func test_tests_can_stand_in_for_a_phone() -> void:
	DevTools.forced = false
	assert_false(DevTools.enabled())


func test_only_the_deck_preset_carries_the_deck_tag() -> void:
	var presets := _presets()
	var deck := presets.filter(func(p: Dictionary) -> bool: return p["name"] == "Steam Deck")
	assert_eq(deck.size(), 1, "One Steam Deck preset")
	assert_eq(deck[0]["platform"], "Linux", "It is a Linux export")
	assert_true(_features(deck[0]).has(DevTools.FEATURE), "It carries the tag")
	for preset in presets:
		if preset["name"] != "Steam Deck":
			assert_false(_features(preset).has(DevTools.FEATURE), preset["name"])


func test_every_other_preset_leaves_the_deck_only_files_out() -> void:
	for preset in _presets():
		var excluded := _filters(preset["exclude_filter"])
		for path in DevTools.DECK_ONLY_PATHS:
			if preset["name"] == "Steam Deck":
				assert_false(excluded.has(path), "The Deck keeps %s" % path)
			else:
				assert_true(excluded.has(path), "%s leaves out %s" % [preset["name"], path])


func test_every_deck_only_path_matches_something() -> void:
	var files := _files("res://")
	for pattern in DevTools.DECK_ONLY_PATHS:
		var hit := files.any(func(f: String) -> bool: return f.trim_prefix("res://").match(pattern))
		assert_true(hit, "%s names real files" % pattern)


func test_nothing_shipped_everywhere_names_a_deck_only_class() -> void:
	var files := _files("res://")
	var deck_only := files.filter(_is_deck_only)
	var classes: Array[String] = []
	for path: String in deck_only:
		if path.ends_with(".gd"):
			var name := _class_name(path)
			if not name.is_empty():
				classes.append(name)
	assert_true(classes.has("DemoMenu"), "The menu is among them")
	assert_true(classes.has("PrPicker"), "So is the picker")
	for path: String in files:
		if _is_deck_only(path) or not (path.ends_with(".gd") or path.ends_with(".tscn")):
			continue
		var text := FileAccess.get_file_as_string(path)
		for name in classes:
			var pattern := RegEx.create_from_string("\\b%s\\b" % name)
			assert_null(pattern.search(_code_only(text)), "%s names %s" % [path, name])


func test_the_splash_hands_a_phone_the_game_alone() -> void:
	var next := Splash.handoff_for(false)
	assert_true(next is GameHost, "No menu")
	next.free()


func test_the_splash_hands_the_deck_its_menu_with_the_carousel_in_front() -> void:
	var next := Splash.handoff_for(true)
	assert_eq(next.scene_file_path, Splash.MENU_PATH, "The menu")
	assert_eq(next.get("start_demo"), Splash.START_PATH, "The carousel in front")
	next.free()


## Comments and docs may mention anything; only code is checked.
static func _code_only(text: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if not stripped.begins_with("#"):
			lines.append(line)
	return "\n".join(lines)


static func _class_name(path: String) -> String:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("class_name "):
			return line.trim_prefix("class_name ").strip_edges().split(" ")[0]
	return ""


static func _is_deck_only(path: String) -> bool:
	var relative := path.trim_prefix("res://")
	for pattern in DevTools.DECK_ONLY_PATHS:
		if relative.match(pattern):
			return true
	return false


static func _filters(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in text.split(",", false):
		out.append(part.strip_edges())
	return out


static func _features(preset: Dictionary) -> PackedStringArray:
	return _filters(preset["custom_features"])


static func _presets() -> Array[Dictionary]:
	var config := ConfigFile.new()
	assert(config.load(PRESETS_PATH) == OK)
	var out: Array[Dictionary] = []
	for section in config.get_sections():
		if section.ends_with(".options"):
			continue
		var preset := {
			"name": config.get_value(section, "name"),
			"platform": config.get_value(section, "platform"),
			"custom_features": config.get_value(section, "custom_features", ""),
			"exclude_filter": config.get_value(section, "exclude_filter", ""),
		}
		out.append(preset)
	return out


static func _files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for skip in UNSHIPPED:
		if dir_path == skip:
			return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(_files(dir_path.path_join(sub) + "/"))
	return out

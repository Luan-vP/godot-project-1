class_name LaunchOptions
extends RefCounted
## The launch options for a device nobody is holding, read from the command
## line: [code]--open=eye_band[/code] goes straight into a scene, and
## [code]--probe[/code] or [code]--probe=eye_band,spout[/code] hands the game to
## a [FrameProbe]. See "Building for iPhone" in the README.
##
## Both the Deck's demo menu and the game alone ([GameHost]) read them, each
## against its own list of scenes: dictionaries with a [code]name[/code], a
## [code]path[/code] and, optionally, [code]probe: false[/code] to leave one
## out of a full probe.


## The scenes in [param scenes] that a comma-separated [param names] list
## picks, matched loosely: "eyes", "Eye band" and "eye_band" all work. Empty
## picks them all.
static func named(names: String, scenes: Array[Dictionary]) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var wanted := PackedStringArray()
	for part in names.split(",", false):
		wanted.append(slug(part))
	for scene in scenes:
		if wanted.is_empty() or wanted.has(slug(scene["name"])):
			picked.append(scene)
	return picked


## Read [code]--open=[/code] and [code]--probe[=][/code] out of command-line
## [param args], against [param scenes]. Unknown arguments are left alone;
## they belong to Godot.
static func parse(args: PackedStringArray, scenes: Array[Dictionary]) -> Dictionary:
	var options := {}
	for arg in args:
		if arg.begins_with("--open="):
			var which := arg.trim_prefix("--open=")
			var found := named(which, scenes)
			if found.size() > 0 and not which.is_empty():
				options["open"] = found[0]["path"]
		elif arg == "--probe":
			options["probe"] = named("", scenes).filter(
				func(scene: Dictionary) -> bool: return scene.get("probe", true)
			)
		elif arg.begins_with("--probe="):
			options["probe"] = named(arg.trim_prefix("--probe="), scenes)
	return options


static func slug(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_")


## Both lists the options may be in: the iOS launch path passes them without
## a separator, so they arrive as engine arguments.
static func command_line() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()

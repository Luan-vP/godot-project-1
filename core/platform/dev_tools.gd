class_name DevTools
extends RefCounted
## Whether this build carries the developer tools: the demo menu, the pull
## request picker, and the menu's command-line jobs.
##
## Only the Steam Deck's own build has them. It is exported from the
## "Steam Deck" preset, which adds the [code]deck[/code] feature tag (see
## [code]scripts/deck-build.sh[/code]). Running from the editor, or from
## [code]scripts/run.sh[/code], counts too. Every other export, phones
## included, is the game alone: the splash, then the fluid carousel ([GameHost]).
## Those exports leave the menu's and the picker's files out entirely
## ([constant DECK_ONLY_PATHS]).

## The export feature tag the Deck's build carries.
const FEATURE := "deck"

## Files only the Deck's build ships: the menu, the picker, and the demos
## only the menu reaches (tools for working on the game, not levels in it).
## Every other preset's [code]exclude_filter[/code] lists them, which
## tests/test_dev_tools.gd checks, as it does that nothing shipped everywhere
## names their classes.
const DECK_ONLY_PATHS: Array[String] = [
	"features/ui/demo_menu/*",
	"features/ui/pr_picker/*",
	"features/ui/comfort_settings/*",
	"core/audio/synth_demo.*",
	"core/audio/groove_demo.*",
	"core/audio/audio_demo.*",
	"core/motion/motion_demo.*",
]

## Set by tests to stand in for a build without the tools (false) or with them
## (true). Null means read the build's own features.
static var forced: Variant = null


static func enabled() -> bool:
	if forced != null:
		return forced
	return OS.has_feature(FEATURE) or OS.has_feature("editor")

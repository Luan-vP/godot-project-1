class_name HapticsOutput
extends RefCounted
## Port: somewhere a short controller pulse can be felt. Gameplay never talks
## to one of these directly — it asks [Haptics] for a pulse, and [Haptics]
## picks whichever output is available, rate-limits, and applies the player's
## comfort setting.
##
## Adapters: [JoypadHapticsOutput] for an ordinary gamepad through Godot,
## [SteamHapticsOutput] for controllers Steam owns (the Deck), and
## [NullHapticsOutput] for everything else — keyboard, CI, a phone with no
## pad — which records what it was asked so tests can check.


## Whether a pulse sent now would be felt anywhere.
func is_available() -> bool:
	return false


## Play one pulse at [param strength] (0..1) for [param duration_s] seconds.
## [param tree] is for timing the stop on outputs that need one.
func pulse(_strength: float, _duration_s: float, _tree: SceneTree) -> void:
	pass


## A short description for debug readouts.
func describe() -> String:
	return "none"

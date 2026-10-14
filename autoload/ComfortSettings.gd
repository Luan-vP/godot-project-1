extends Node
## Player-controlled comfort options. For now just one: how strong controller
## pulses are ([member haptics_strength]), which [Haptics] scales every pulse
## by.
##
## Every setting here is a multiplier on top of tuned numbers, never a
## replacement for them: the tuning stays the default a player starts from,
## and these settings only let them pull back from it.
##
## Persisted through [SaveManager] and reloaded in [method _ready], the same
## pattern [AudioManager] uses for its bus settings.

## Emitted whenever [member haptics_strength] changes, including on load.
signal haptics_strength_changed(value: float)

const _SETTINGS_SECTION := "comfort"
const _HAPTICS_KEY := "haptics_strength"

## Scales every controller pulse [Haptics] plays: 1 as tuned, 0 off.
var haptics_strength: float = 1.0


func _ready() -> void:
	_load_settings()


## Sets and persists how strong controller pulses are, from 0 (off) to 1 (as
## tuned).
func set_haptics_strength(value: float) -> void:
	haptics_strength = clampf(value, 0.0, 1.0)
	SaveManager.set_value(_SETTINGS_SECTION, _HAPTICS_KEY, haptics_strength)
	haptics_strength_changed.emit(haptics_strength)


## Scales a pulse's [param strength] by [member haptics_strength].
func apply_to_haptics(strength: float) -> float:
	return clampf(strength, 0.0, 1.0) * haptics_strength


func _load_settings() -> void:
	haptics_strength = clampf(SaveManager.get_value(_SETTINGS_SECTION, _HAPTICS_KEY, 1.0), 0.0, 1.0)

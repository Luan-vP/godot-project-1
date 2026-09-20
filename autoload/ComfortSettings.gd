extends Node
## Player-controlled comfort options for look-driven distortion (#17): how
## strongly the medium bends the background, how sensitive looking around
## feels, and how much a floater lags and overshoots behind the current it
## drifts on.
##
## Every setting here is a multiplier or a blend on top of a level's own
## tuned numbers ([member Level.distortion_strength], [member
## Level.look_sensitivity], [member Floater.drag]), never a replacement for
## them — a level author's tuning stays the default a player starts from, and
## these settings only let them pull back from it. See [method
## PanoramaLevel._apply_level] and [method PanoramaLevel._rebuild_medium] for
## where they get applied.
##
## Persisted through [SaveManager] and reloaded in [method _ready], the same
## pattern [AudioManager] uses for its bus settings.

## Emitted whenever [member distortion_multiplier] changes, including on load.
signal distortion_multiplier_changed(value: float)

## Emitted whenever [member look_sensitivity_multiplier] changes, including on
## load.
signal look_sensitivity_multiplier_changed(value: float)

## Emitted whenever [member overshoot_reduction] changes, including on load.
signal overshoot_reduction_changed(value: float)

const _SETTINGS_SECTION := "comfort"
const _DISTORTION_KEY := "distortion_multiplier"
const _SENSITIVITY_KEY := "look_sensitivity_multiplier"
const _OVERSHOOT_KEY := "overshoot_reduction"

## Drag rate ([member FluidBody.drag]) a floater is given at full [member
## overshoot_reduction]. High enough that [method FluidBody.drift]'s
## [code]drag * delta[/code] clamp saturates at 1 for any real frame time, so
## the floater snaps straight onto the current every frame instead of lagging
## and overshooting behind it.
const _OVERSHOOT_REMOVED_DRAG := 200.0

## Scales [member Level.distortion_strength]. 1 leaves a level's tuned bend
## alone; 0 turns the medium's optical bend off entirely — floaters still
## drift, they just stop warping the background.
var distortion_multiplier: float = 1.0

## Scales [member Level.look_sensitivity] (itself a multiplier on every
## [LookSource]'s contribution). 1 leaves a level's tuned feel alone.
var look_sensitivity_multiplier: float = 1.0

## How far to pull a floater's drag from its tuned looseness towards
## [constant _OVERSHOOT_REMOVED_DRAG]: 0 leaves the tuned lag and overshoot
## alone (the default), 1 removes it entirely.
var overshoot_reduction: float = 0.0


func _ready() -> void:
	_load_settings()


## Sets and persists how strongly the medium bends the background, as a
## fraction of a level's own tuned [member Level.distortion_strength]. Clamped
## to [code][0, 1][/code] — comfort options only pull back from a level's
## tuned look, never exaggerate it.
func set_distortion_multiplier(value: float) -> void:
	distortion_multiplier = clampf(value, 0.0, 1.0)
	SaveManager.set_value(_SETTINGS_SECTION, _DISTORTION_KEY, distortion_multiplier)
	distortion_multiplier_changed.emit(distortion_multiplier)


## Sets and persists how sensitive looking around feels, as a multiplier on a
## level's own tuned [member Level.look_sensitivity]. Clamped to the same
## range [member PanoramaLookCamera.sensitivity] itself accepts.
func set_look_sensitivity_multiplier(value: float) -> void:
	look_sensitivity_multiplier = clampf(value, 0.1, 5.0)
	SaveManager.set_value(_SETTINGS_SECTION, _SENSITIVITY_KEY, look_sensitivity_multiplier)
	look_sensitivity_multiplier_changed.emit(look_sensitivity_multiplier)


## Sets and persists how much to reduce a floater's inertial lag and
## overshoot, from 0 (the tuned default) to 1 (removed entirely).
func set_overshoot_reduction(value: float) -> void:
	overshoot_reduction = clampf(value, 0.0, 1.0)
	SaveManager.set_value(_SETTINGS_SECTION, _OVERSHOOT_KEY, overshoot_reduction)
	overshoot_reduction_changed.emit(overshoot_reduction)


## Scales [param base_strength] (a level's tuned [member
## Level.distortion_strength]) by [member distortion_multiplier].
func apply_to_distortion(base_strength: float) -> float:
	return base_strength * distortion_multiplier


## Scales [param base_sensitivity] (a level's tuned [member
## Level.look_sensitivity]) by [member look_sensitivity_multiplier].
func apply_to_look_sensitivity(base_sensitivity: float) -> float:
	return base_sensitivity * look_sensitivity_multiplier


## Blends [param base_drag] (a floater's tuned [member FluidBody.drag])
## towards [constant _OVERSHOOT_REMOVED_DRAG] by [member overshoot_reduction].
func apply_to_floater_drag(base_drag: float) -> float:
	return lerpf(base_drag, _OVERSHOOT_REMOVED_DRAG, overshoot_reduction)


func _load_settings() -> void:
	distortion_multiplier = clampf(
		SaveManager.get_value(_SETTINGS_SECTION, _DISTORTION_KEY, 1.0), 0.0, 1.0
	)
	look_sensitivity_multiplier = clampf(
		SaveManager.get_value(_SETTINGS_SECTION, _SENSITIVITY_KEY, 1.0), 0.1, 5.0
	)
	overshoot_reduction = clampf(
		SaveManager.get_value(_SETTINGS_SECTION, _OVERSHOOT_KEY, 0.0), 0.0, 1.0
	)

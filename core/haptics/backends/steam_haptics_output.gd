class_name SteamHapticsOutput
extends HapticsOutput
## Rumble through Steam Input, for controllers Steam owns — above all the
## Steam Deck, whose pad reaches a Steam-launched game through Steam rather
## than as a plain gamepad. Opens Steam the same way [SteamInputMotionSource]
## does, and reuses its session when that is already open: init is guarded on
## [method Steam.get_steam_init_result], so a second caller does not start a
## second one.
##
## [method Steam.triggerVibration] leaves the motors running until told
## otherwise, so each pulse schedules its own stop. A newer pulse cancels an
## older pulse's stop by bumping [member _generation].

const DEV_APP_ID := SteamInputMotionSource.DEV_APP_ID
## Steam's full motor speed.
const MAX_SPEED := 65535
## Right (light) motor as the tick; the left (heavy) one lower.
const LEFT_SHARE := 0.45

var _started := false
var _generation := 0


func _init(app_id: int = DEV_APP_ID) -> void:
	if not SteamInputMotionSource.is_steam_available():
		return
	var status: Dictionary = Steam.get_steam_init_result()
	if status.get("status", -1) != Steam.STEAM_API_INIT_RESULT_OK:
		status = Steam.steamInitEx(app_id, false)
	if status.get("status", -1) != Steam.STEAM_API_INIT_RESULT_OK:
		return
	Steam.inputInit(true)
	_started = true


func is_available() -> bool:
	return _started and not _controllers().is_empty()


func pulse(strength: float, duration_s: float, tree: SceneTree) -> void:
	if not _started:
		return
	Steam.runFrame()
	var right := int(clampf(strength, 0.0, 1.0) * MAX_SPEED)
	var left := int(right * LEFT_SHARE)
	var handles := _controllers()
	for handle in handles:
		Steam.triggerVibration(int(handle), left, right)
	_generation += 1
	if tree != null:
		tree.create_timer(duration_s).timeout.connect(_stop.bind(_generation, handles))


func describe() -> String:
	return "Steam Input rumble (%d controllers)" % _controllers().size() if _started else "none"


func _stop(generation: int, handles: Array) -> void:
	if generation != _generation:
		return
	for handle in handles:
		Steam.triggerVibration(int(handle), 0, 0)


func _controllers() -> Array:
	return Steam.getConnectedControllers() if _started else []

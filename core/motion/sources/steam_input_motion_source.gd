class_name SteamInputMotionSource
extends MotionSource
## Adapter: motion from Steam Input, for every controller Steam supports.
##
## Godot feeds [code]Input[/code]'s sensor functions on Android and iOS only,
## and exposes no gamepad sensors at all (godot-proposals#2829), so on a Steam
## Deck — or a DualSense, or a Switch Pro pad — [DeviceMotionSource] reports
## nothing. Steam already reads those sensors for its own gyro configs, and
## [code]ISteamInput[/code] hands the result over sensor-fused and in known
## units.
##
## [b]Why this rather than reading the device.[/b] An earlier version read the
## Deck's raw HID stream directly. It worked, in the narrow sense that numbers
## arrived and changed when the device moved, but every offset and scale in it
## was reverse-engineered by fitting one resting pose, and it showed: gravity
## measured 0.92 g held upright and 0.49 g in a stand, when a resting
## accelerometer reads 1 g in every orientation. It was also one device's
## report format, on one kernel. This is the interface Valve maintains, and it
## covers the whole shelf of controllers rather than the one on the desk.
##
## [b]What Steam needs.[/b] The Steam client running, and an app ID — 480
## (Spacewar) while there is no real one. Init failing is not an error worth
## reporting: it is what happens on any machine without Steam, and
## [MotionInput] simply moves to the next source.
##
## Steam reports acceleration in g, gravity included, and Godot has no linear
## acceleration sensor to compare against, so gravity is estimated the same way
## [DeviceMotionSource] estimates it: the part of the signal that does not
## change.

## Development app ID. Valve's public test app, which is enough for Steam Input
## to hand over controller motion. Replace it with the game's own ID before
## release, and leave [code]steam_appid.txt[/code] out of the shipped build.
const DEV_APP_ID := 480

## Standard gravity, converting Steam's g into the metres per second squared
## the rest of the pipeline speaks.
const GRAVITY := 9.80665

## Seconds for the gravity estimate to settle. Matches [DeviceMotionSource], so
## the two adapters feel the same.
const GRAVITY_TIME_CONSTANT := 1.2

## Squared magnitude below which a reading is Steam saying "no motion here",
## rather than a controller lying still.
const MIN_ACCELERATION_SQUARED := 0.01

var _gravity_estimate: Vector3 = Vector3.ZERO
var _handle: int = 0
var _seen_data: bool = false
var _started: bool = false


## True when Steam is present at all. Checked before constructing one of these,
## so no Steam call is made on a machine without the extension.
static func is_steam_available() -> bool:
	return ClassDB.class_exists("Steam")


func _init(app_id: int = DEV_APP_ID) -> void:
	if not is_steam_available():
		return
	var status: Dictionary = Steam.get_steam_init_result()
	if status.get("status", -1) != Steam.STEAM_API_INIT_RESULT_OK:
		# Callbacks are pumped from poll() rather than embedded, because
		# embedding them needs a SceneTree and a source can be built before
		# there is one — a test, or a headless bring-up script.
		status = Steam.steamInitEx(app_id, false)
	if status.get("status", -1) != Steam.STEAM_API_INIT_RESULT_OK:
		return
	Steam.inputInit(true)
	Steam.enableDeviceCallbacks()
	_started = true


func poll(delta: float) -> MotionReading:
	if not _started:
		_reading.available = false
		return _reading

	Steam.run_callbacks()
	# Directly rather than waiting on the callback pump, for a reading that
	# belongs to this frame rather than the last one.
	Steam.runFrame()
	_handle = _resolve_controller(_handle)
	if _handle == 0:
		_reading.available = false
		return _reading

	var motion: Dictionary = Steam.getMotionData(_handle)
	var raw := Vector3(
		float(motion.get("pos_accel_x", 0.0)),
		float(motion.get("pos_accel_y", 0.0)),
		float(motion.get("pos_accel_z", 0.0))
	)
	if raw.length_squared() < MIN_ACCELERATION_SQUARED:
		# A controller Steam knows about but reports no motion for — a pad with
		# no IMU, or gyro switched off in its config.
		_reading.available = _seen_data
		return _reading

	_seen_data = true
	raw *= GRAVITY
	# A zero step is a reading taken out of band, such as MotionInput's
	# calibrate(), and no time has passed for the estimate to move in.
	if delta > 0.0:
		_gravity_estimate = MotionFilter.smooth3(
			_gravity_estimate, raw, GRAVITY_TIME_CONSTANT, delta
		)
	_reading.gravity = _gravity_estimate
	_reading.acceleration = raw - _gravity_estimate
	_reading.available = true
	return _reading


func is_available() -> bool:
	return _seen_data


func stop() -> void:
	if not _started:
		return
	Steam.inputShutdown()
	Steam.steamShutdown()
	_started = false
	_handle = 0
	_seen_data = false


func describe() -> String:
	if not _started:
		return "Steam Input (not running)"
	return "Steam Input (controller %d)" % _handle


## The controller motion belongs to. [param current] is kept only while Steam
## still lists it among [method Steam.getConnectedControllers] — a handle goes
## stale when its controller sleeps or disconnects, and holding onto a stale
## one would read as a live pad that has simply stopped moving, rather than
## one that is gone. Dropping it also clears [member _seen_data], so a
## different controller taking its place is not credited with data the old
## one produced.
func _resolve_controller(current: int) -> int:
	var handles: Array = Steam.getConnectedControllers()
	if current != 0 and handles.has(current):
		return current
	if current != 0:
		_seen_data = false
	if handles.is_empty():
		return 0
	return int(handles[0])

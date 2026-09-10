class_name DeviceMotionSource
extends MotionSource
## Adapter: the real accelerometer.
##
## Godot exposes these sensors where the platform has them — Android and iOS
## certainly, possibly elsewhere. Rather than allow-listing platform names,
## availability is decided by whether a non-zero reading has actually arrived,
## so a platform that reports works even though it could not be tested here,
## and one that claims sensors it never feeds is correctly treated as absent.
##
## Godot has no linear-acceleration sensor, so user acceleration is the
## accelerometer minus gravity.

## Squared magnitude below which the gravity sensor is considered silent.
const MIN_GRAVITY_SQUARED := 0.25

## Gravity is the part of the accelerometer signal that does not change. This
## is how long the fallback estimate takes to settle, in seconds.
const GRAVITY_TIME_CONSTANT := 1.2

var _gravity_estimate: Vector3 = Vector3.ZERO
var _seen_data: bool = false


func poll(delta: float) -> MotionReading:
	var gravity := Input.get_gravity()
	var raw := Input.get_accelerometer()
	if gravity.length_squared() > 0.0 or raw.length_squared() > 0.0:
		_seen_data = true

	# Some platforms feed the accelerometer but not the gravity sensor. Without
	# this the whole signal would be read as player motion and the jog detector
	# would fire on nothing but gravity.
	if gravity.length_squared() < MIN_GRAVITY_SQUARED and raw.length_squared() > 0.0:
		_gravity_estimate = _gravity_estimate.lerp(
			raw, 1.0 - exp(-maxf(delta, 0.0) / GRAVITY_TIME_CONSTANT)
		)
		gravity = _gravity_estimate

	_reading.gravity = gravity
	_reading.acceleration = raw - gravity
	_reading.available = _seen_data
	return _reading


func is_available() -> bool:
	return _seen_data


func describe() -> String:
	return "device sensors (%s)" % OS.get_name()

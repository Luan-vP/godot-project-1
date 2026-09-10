class_name ScriptedMotionSource
extends MotionSource
## Adapter: readings supplied by hand.
##
## This is the adapter that justifies the port. With it the tilt and jog
## pipeline can be driven through its whole range in a headless test — level,
## tilted, shaken, sensorless — none of which can be reached from CI or from a
## development desktop.
##
## Queued readings are returned one per poll; once the queue empties the last
## one repeats, so a test can set a pose and then step time forward.

var _queue: Array[MotionReading] = []
var _available: bool = true


## Queue one sample.
func push(gravity: Vector3, acceleration := Vector3.ZERO) -> void:
	var reading := MotionReading.new()
	reading.gravity = gravity
	reading.acceleration = acceleration
	reading.available = true
	_queue.append(reading)


## Queue the same sample [param count] times, for holding a pose across frames.
func push_repeated(gravity: Vector3, acceleration: Vector3, count: int) -> void:
	for _i in maxi(count, 0):
		push(gravity, acceleration)


## Pretend the platform has no sensors.
func set_available(value: bool) -> void:
	_available = value


func pending() -> int:
	return _queue.size()


func poll(_delta: float) -> MotionReading:
	if not _queue.is_empty():
		_reading.copy_from(_queue.pop_front())
	_reading.available = _available
	return _reading


func is_available() -> bool:
	return _available


func describe() -> String:
	return "scripted"

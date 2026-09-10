class_name MotionSource
extends RefCounted
## Port: somewhere device motion comes from.
##
## The contract is deliberately tiny — one poll per frame yielding gravity and
## user acceleration — because that is the whole of what the pipeline behind it
## needs, and a narrow port is what makes a fake one trivial to write.
##
## This port exists because the accelerometer can be read neither in CI nor on
## a development desktop. Without it the tilt pipeline would be untestable and
## undevelopable anywhere but a phone. Adapters live in [code]sources/[/code].

## The reading this source owns and refills. Subclasses write to it in
## [method poll] rather than allocating.
var _reading := MotionReading.new()


## Read the device. [param _delta] is the time since the last poll, which
## adapters need when they have to low-pass a signal themselves.
func poll(_delta: float) -> MotionReading:
	return _reading


## Whether this source is actually producing data. Adapters should answer from
## observed readings where they can, not from a platform name.
func is_available() -> bool:
	return false


## Short human-readable name, for debug overlays and logs.
func describe() -> String:
	return "none"

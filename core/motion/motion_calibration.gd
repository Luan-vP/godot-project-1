class_name MotionCalibration
extends RefCounted
## Turns raw device gravity into screen-space tilt.
##
## The reference is whatever the device was doing when the player last
## calibrated, so this works held upright, flat on a table, or anywhere
## between. Assuming a hold orientation is the usual way tilt controls end up
## feeling wrong for anyone who does not hold the device the way the developer
## did.

## Below this, a vector carries no usable direction.
const MIN_MAGNITUDE := 0.05

## How parallel a seed axis may be to the reference before it is a poor choice
## of basis.
const MAX_SEED_ALIGNMENT := 0.9

var _reference: Vector3 = Vector3.ZERO
var _right: Vector3 = Vector3.RIGHT
var _forward: Vector3 = Vector3.FORWARD
var _calibrated: bool = false


## Take the current gravity as level. Returns false if the reading was too weak
## to define a direction, in which case the previous calibration is kept.
func calibrate(gravity: Vector3) -> bool:
	if gravity.length() < MIN_MAGNITUDE:
		return false
	_reference = gravity.normalized()
	# Any axis not parallel to the reference will do. Picking the more
	# perpendicular of two keeps the basis well conditioned at any hold angle,
	# including flat on a table where the obvious choice degenerates.
	var seed_axis := Vector3.RIGHT
	if absf(_reference.dot(seed_axis)) > MAX_SEED_ALIGNMENT:
		seed_axis = Vector3.UP
	_right = (seed_axis - _reference * _reference.dot(seed_axis)).normalized()
	_forward = _reference.cross(_right).normalized()
	_calibrated = true
	return true


func is_calibrated() -> bool:
	return _calibrated


func get_reference() -> Vector3:
	return _reference


func reset() -> void:
	_reference = Vector3.ZERO
	_right = Vector3.RIGHT
	_forward = Vector3.FORWARD
	_calibrated = false


## Flatten a device-space vector onto the calibrated screen plane. Used for
## acceleration; motion along the view axis drops out, which is what makes a
## jog a lateral shove rather than a poke at the screen.
func project(vector: Vector3) -> Vector2:
	if not _calibrated:
		return Vector2.ZERO
	return Vector2(vector.dot(_right), vector.dot(_forward))


## Tilt as a unit-limited vector, where length 1 means the device is tilted
## [param span_degrees] away from the reference.
func tilt_from(gravity: Vector3, span_degrees: float) -> Vector2:
	if not _calibrated or gravity.length() < MIN_MAGNITUDE:
		return Vector2.ZERO
	# The components of the tilted gravity along the screen axes are the sines
	# of the tilt about each one, so dividing by the sine of the span maps a
	# full tilt to 1.
	var span := sin(deg_to_rad(clampf(span_degrees, 1.0, 89.0)))
	return (project(gravity.normalized()) / span).limit_length(1.0)

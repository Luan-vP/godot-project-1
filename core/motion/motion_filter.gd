class_name MotionFilter
extends RefCounted
## Pure smoothing and dead-zone helpers for a noisy analogue signal.
##
## Kept pure and separate because both of these are easy to write in a way that
## looks right and behaves differently on a 30 Hz and a 144 Hz display — and
## that difference is invisible when reading the call site.


## Exponential smoothing towards [param target] with a time constant, in
## seconds, rather than a per-frame factor.
##
## [param time_constant] is the time to close about 63% of the gap, and the
## result is exact for any step size: a signal smoothed for one second lands in
## the same place whether that second was 30 frames or 144.
static func smooth(
	previous: Vector2, target: Vector2, time_constant: float, delta: float
) -> Vector2:
	if time_constant <= 0.0 or delta <= 0.0:
		return target
	return previous.lerp(target, 1.0 - exp(-delta / time_constant))


## Suppress small readings, rescaling what is left so the output ramps from
## zero at the edge of the zone instead of jumping straight to [param deadzone].
##
## The rescale is the point. A bare threshold makes the control lurch the
## instant it engages, which reads as a broken sensor rather than a dead zone.
static func apply_deadzone(value: Vector2, deadzone: float) -> Vector2:
	var zone := clampf(deadzone, 0.0, 0.99)
	var magnitude := value.length()
	if magnitude <= zone:
		return Vector2.ZERO
	return value * ((magnitude - zone) / (1.0 - zone) / magnitude)

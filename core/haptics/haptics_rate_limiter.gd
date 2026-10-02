class_name HapticsRateLimiter
extends RefCounted
## Keeps a burst of pulse requests from queueing up behind the hardware. Pure:
## time comes in as an argument.
##
## A request is played at once if the last pulse was at least
## [member min_interval] ago. Otherwise it is held, and any further requests
## before the interval is up merge into it — the strongest wins — so a
## volley of twelve balls a second is felt as a steady, slightly coarser tick
## rather than a backlog that keeps buzzing after the trigger is let go. A held
## pulse plays from [method flush] once the interval is up.

## Seconds between pulses the hardware can render as separate ticks.
var min_interval := 0.045

var _last_at := -INF
var _held := -1.0


## [param strength] to play now, or -1 if it has been held (or merged into a
## held pulse) instead.
func request(now: float, strength: float) -> float:
	if now - _last_at >= min_interval and _held < 0.0:
		_last_at = now
		return strength
	_held = maxf(_held, strength)
	return -1.0


## The held pulse's strength if it is due at [param now], else -1.
func flush(now: float) -> float:
	if _held < 0.0 or now - _last_at < min_interval:
		return -1.0
	var strength := _held
	_held = -1.0
	_last_at = now
	return strength


func has_held() -> bool:
	return _held >= 0.0

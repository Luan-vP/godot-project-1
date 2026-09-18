class_name EyeGazeMapping
extends RefCounted
## Pure maths for turning a gaze into a look rate. See the gaze README for why
## the mapping is rate control with a dead zone, and what was rejected.
##
## Everything here is a static function of its arguments so the feel can be
## pinned by tests; [EyeGazeFilter] owns the state that strings them together.


## How far off neutral the gaze is, as a fraction of [param span] per axis.
## Length 1 along an axis means gaze at that axis's full-deflection angle.
##
## Normalising per axis before the dead zone is what makes the zone an
## ellipse in angle: a portrait phone is twice as tall as it is wide, so the
## same number of degrees means much less up and down than across.
static func deflection(gaze: Vector2, neutral: Vector2, span: Vector2) -> Vector2:
	var offset := gaze - neutral
	return Vector2(
		offset.x / span.x if span.x > 0.0 else 0.0, offset.y / span.y if span.y > 0.0 else 0.0
	)


## Dead zone, then response curve, on a normalised deflection.
##
## The length is clamped to 1 first: looking past the edge of the screen turns
## no faster than looking at the edge, so a tracker's wild off-screen reading
## cannot spin the camera. The dead zone rescales what survives it (the same
## helper tilt and the gamepad use), then [param exponent] above 1 keeps the
## turn gentle just outside the zone, where tracker noise and a relaxed gaze
## live, while still reaching full rate at the edge.
static func shape(value: Vector2, deadzone: float, exponent: float) -> Vector2:
	var clamped := value.limit_length(1.0)
	var live := MotionFilter.apply_deadzone(clamped, deadzone)
	var magnitude := live.length()
	if magnitude <= 0.0:
		return Vector2.ZERO
	return live * (pow(magnitude, maxf(exponent, 0.01)) / magnitude)


## A shaped deflection as a look rate in radians/second, in [LookSource]'s
## convention: x positive turns right, y positive pitches down. Gaze pitch is
## positive up, hence the flipped y — looking at the top of the screen should
## raise the view.
static func look_rate(shaped: Vector2, max_rate: Vector2) -> Vector2:
	return Vector2(shaped.x * max_rate.x, -shaped.y * max_rate.y)


## Whether a reading can be trusted to steer with. A closing eye's gaze
## swings wildly before the tracker gives up on it, so a blink disqualifies a
## reading even while the backend still calls it tracking.
static func is_usable(sample: EyeGazeSample, min_confidence: float, max_blink: float) -> bool:
	return sample.is_tracking() and sample.confidence >= min_confidence and sample.blink < max_blink

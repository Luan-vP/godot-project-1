class_name ClipWatch
extends RefCounted
## Turns a stream of peak readings into overs: stretches where the mix went
## to or past full scale, each reported once, when it is over.
##
## Pure, so it can be tested without a sound card. [LevelMeter] feeds it the
## peak of every sample mixed into the Master bus since the frame before.
## Readings are linear (1.0 is 0 dBFS), not dB, since that is what the samples
## are.
##
## An over is one episode however many frames it spans: it opens on the first
## reading at or past [constant OVER] and closes once readings have stayed
## under it for [constant GAP_SECONDS], so a run of loud beats a few hundred
## milliseconds apart is one over, not a dozen.
##
## Alongside overs it keeps the loudest reading in two spans: the session, and
## a segment the caller ends with [method end_segment] — a level, say — so a
## log can say how much headroom each level had even when nothing went over.

## Full scale. A reading at or past it would have clipped without the limiter.
const OVER := 1.0
## Quiet this long, under [constant OVER], ends an over.
const GAP_SECONDS := 0.5


## One over: when it started and ended, the loudest reading in it, and the
## bar it started in (-1 when the caller did not say).
class Episode:
	extends RefCounted
	var start_seconds := 0.0
	var end_seconds := 0.0
	var peak := 0.0
	var bar := -1

	func duration() -> float:
		return end_seconds - start_seconds


var session_peak := 0.0
var session_overs := 0
var segment_peak := 0.0
var segment_overs := 0

var _open: Episode
var _last_over_seconds := 0.0


## Take one [param peak] reading at [param now] seconds, in [param bar].
## Returns the over this reading ended, or null.
func feed(peak: float, now: float, bar: int = -1) -> Episode:
	session_peak = maxf(session_peak, peak)
	segment_peak = maxf(segment_peak, peak)
	if peak >= OVER:
		if _open == null:
			_open = Episode.new()
			_open.start_seconds = now
			_open.bar = bar
			session_overs += 1
			segment_overs += 1
		_open.peak = maxf(_open.peak, peak)
		_open.end_seconds = now
		_last_over_seconds = now
		return null
	if _open != null and now - _last_over_seconds >= GAP_SECONDS:
		return flush()
	return null


## Whether an over is still open.
func is_over() -> bool:
	return _open != null


## End the open over now, if there is one, and return it.
func flush() -> Episode:
	var closed := _open
	_open = null
	return closed


## The loudest reading and the overs since the last call, then start a new
## segment. Does not close an open over; [method flush] that first.
func end_segment() -> Dictionary:
	var segment := {"peak": segment_peak, "overs": segment_overs}
	segment_peak = 0.0
	segment_overs = 0
	return segment


## [param linear] as text for a log or HUD: "+1.4 dBFS", or "silent".
static func format_db(linear: float) -> String:
	if linear <= 0.0:
		return "silent"
	return "%+.1f dBFS" % linear_to_db(linear)

class_name StickyBallEmitter
extends BallEmitter
## Version C: version B's balls, but a ball that hits a free pin sticks to it.
##
## Only one ball sticks to a pin; a ball that hits a pin already holding one
## bounces off it in silence. A pin with a ball stuck to it does not sound on
## the hit: it waits for the next sixteenth of the music, plays (at the
## strength the ball struck it with), and pops — the pin and its ball are
## gone until the start of the next bar, and balls fall straight through
## where it was. Sixteenths are taken one pin each, in the order the balls
## stuck, so two balls sticking at once play on two sixteenths running.
##
## Slower than B, so a bar's worth of pins can fill and empty: 2, 4, 6 or 8
## balls a bar ([constant STEPS]), set by RT or a touch as in A and B.

## Balls a bar at each step: halves, quarters, quarter triplets, eighths.
const STEPS: Array[int] = [2, 4, 6, 8]
## Strength a stuck pin plays at for the softest of hits: every stuck ball
## sounds, so even a roll on to a pin is heard.
const MIN_STRENGTH := 0.25

## Pin to the ball stuck to it.
var _stuck := {}
## Pin to the strength it will play at.
var _strengths := {}
## Pins with a ball stuck, in the order they stuck: the next sixteenth plays
## the first.
var _waiting: Array[int] = []
var _played := 0
## Where the music was last frame, in bars; NAN until the first frame.
var _clock_bars := NAN


func flow_steps() -> Array[int]:
	return STEPS


func _physics_process(delta: float) -> void:
	super(delta)
	if spout == null:
		return
	tick_clock(SpoutFlow.music_bars())


## Move the music on to [param now_bars] (bars from the start): a bar line
## crossed brings every popped pin back, then each sixteenth crossed plays
## the next pin waiting. The bar comes first, so a pin played on a downbeat
## stays gone that whole bar.
func tick_clock(now_bars: float) -> void:
	if is_nan(_clock_bars) or now_bars < _clock_bars:
		_clock_bars = now_bars
		return
	if floori(now_bars) > floori(_clock_bars):
		pins.restore_all()
	var due := SpoutFlow.due(_clock_bars, now_bars, sixteenths_per_bar())
	_clock_bars = now_bars
	for i in due:
		if _waiting.is_empty():
			break
		play_next()


## Sixteenth notes in a bar of the band's metre.
static func sixteenths_per_bar() -> int:
	return maxi(1, AudioManager.get_music_clock().beats_per_bar * 4)


## Play the pin that has waited longest, and pop it with its ball. Returns
## the pin, or -1 if none was waiting.
func play_next() -> int:
	if _waiting.is_empty():
		return -1
	var pin: int = _waiting.pop_front()
	var ball: SpoutBall = _stuck[pin]
	var strength: float = _strengths[pin]
	_stuck.erase(pin)
	_strengths.erase(pin)
	if pins.hit(pin, strength):
		_hits += 1
	pins.pop(pin)
	_played += 1
	_retire(ball)
	return pin


## Stick [param ball] to [param pin], struck at [param closing_speed], if
## the pin is free. Returns whether it stuck.
func stick(ball: SpoutBall, pin: int, closing_speed: float) -> bool:
	if ball.is_stuck() or _stuck.has(pin) or pins.is_popped(pin):
		return false
	_stuck[pin] = ball
	_strengths[pin] = clampf(closing_speed / FULL_STRENGTH_SPEED, MIN_STRENGTH, 1.0)
	_waiting.append(pin)
	var centre := pins.to_global(pins.pin_position(pin))
	var out := (ball.global_position - centre).normalized()
	if out == Vector2.ZERO:
		out = Vector2.UP
	ball.stick_to(pin, centre + out * (pins.pin_radius + SpoutBall.RADIUS))
	return true


func stuck_count() -> int:
	return _stuck.size()


func played_count() -> int:
	return _played


## The ball stuck to [param pin], or null.
func ball_on(pin: int) -> SpoutBall:
	return _stuck.get(pin)


func _on_struck_pin(ball: SpoutBall, pin: int, closing_speed: float) -> void:
	stick(ball, pin, closing_speed)


func _retire(ball: SpoutBall) -> void:
	# The pool's cap can take a stuck ball; its pin is free again.
	if ball.is_stuck() and _stuck.get(ball.stuck_to) == ball:
		_stuck.erase(ball.stuck_to)
		_strengths.erase(ball.stuck_to)
		_waiting.erase(ball.stuck_to)
	super(ball)


func describe() -> String:
	return (
		"C: sticky balls · firing %s · %d in play · %d stuck · %d popped · %d played"
		% [describe_flow(), in_play(), stuck_count(), pins.popped_count(), _played]
	)


func controls_hint() -> String:
	return "RT or touch fires, 2–8 a bar (touch further away = more; Space full, 1–5)"

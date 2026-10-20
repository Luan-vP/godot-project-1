class_name StickyBallEmitter
extends BallEmitter
## Version C: version B's balls, but a ball that hits a free pin sticks to it.
##
## Only one ball sticks to a pin; a ball that hits a pin already holding one
## bounces off it in silence. A pin with a ball stuck to it does not sound on
## the hit: it waits for the next sixteenth of the music, plays (at the
## strength the ball struck it with), and pops — the pin and its ball are
## gone until the start of the next bar, and balls fall straight through
## where it was. Every pin waiting plays on that sixteenth together, so balls
## that stick at once sound as a chord.
##
## 8, 12, 16 or 20 balls a bar ([constant STEPS]), set by RT or a touch as in
## A and B, fired twice as fast as B's ([constant MUZZLE_SPEED_C]).
##
## Every pin played echoes ([PinEcho]): a bar later, as the popped pins come
## back, and a bar after that, softer each time, while the bar's notes drift
## up over the pins as a constellation and are printed into the water.

## Balls a bar at each step.
const STEPS: Array[int] = [8, 12, 16, 20]
## Twice version B's muzzle speed.
const MUZZLE_SPEED_C := MUZZLE_SPEED * 2.0
## Strength a stuck pin plays at for the softest of hits: every stuck ball
## sounds, so even a roll on to a pin is heard.
const MIN_STRENGTH := 0.25
## How far back the music has to jump, in bars, to count as starting over,
## which drops every echo still waiting.
const RESTART_BARS := 0.25

## The delay on every pin played, and its constellations.
var echo: PinEcho

## Pin to the ball stuck to it.
var _stuck := {}
## Pin to the strength it will play at.
var _strengths := {}
## Pins with a ball stuck, in the order they stuck: the next sixteenth plays
## them all.
var _waiting: Array[int] = []
var _played := 0
## Where the music was last frame, in bars; NAN until the first frame.
var _clock_bars := NAN


func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	super(level_node, the_spout, the_pins)
	echo = PinEcho.new()
	echo.name = "Echo"
	echo.pins = pins
	var shared := SharedLayers.find(level_node)
	if shared != null:
		echo.fluid = shared.fluid
	add_child(echo)


func flow_steps() -> Array[int]:
	return STEPS


func muzzle_speed() -> float:
	return MUZZLE_SPEED_C


func _physics_process(delta: float) -> void:
	super(delta)
	if spout == null:
		return
	tick_clock(heard_bars())


## Where the music is, in bars, as the band schedules it: ahead of the raw
## position by the source's lookahead, as [StepClock] reads it, so a stuck
## pin sounds on the same sixteenth as the band rather than a mix late.
static func heard_bars() -> float:
	var source := AudioManager.get_music_time_source()
	if not source.is_running():
		return 0.0
	var clock := AudioManager.get_music_clock()
	var lookahead := clock.beats_from_seconds(source.get_lookahead())
	return SpoutFlow.music_bars() + lookahead / maxi(1, clock.beats_per_bar)


## Move the music on to [param now_bars] (bars from the start): a bar line
## crossed brings every popped pin back, then a sixteenth crossed plays
## every pin waiting. The bar comes first, so a pin played on a downbeat
## stays gone that whole bar. Echoes due by then sound too.
func tick_clock(now_bars: float) -> void:
	if is_nan(_clock_bars) or now_bars < _clock_bars:
		# A clock that jitters back a hair is not the music starting over.
		if not is_nan(_clock_bars) and now_bars < _clock_bars - RESTART_BARS:
			echo.reset()
		_clock_bars = now_bars
		return
	if floori(now_bars) > floori(_clock_bars):
		pins.restore_all()
	var due := SpoutFlow.due(_clock_bars, now_bars, sixteenths_per_bar())
	_clock_bars = now_bars
	echo.tick(now_bars, sixteenths_per_bar())
	if due > 0:
		play_waiting()


## Sixteenth notes in a bar of the band's metre.
static func sixteenths_per_bar() -> int:
	return maxi(1, AudioManager.get_music_clock().beats_per_bar * 4)


## Play every pin waiting, together, and pop each with its ball. Returns
## the pins played, in the order they stuck.
func play_waiting() -> Array[int]:
	var played := _waiting.duplicate()
	_waiting.clear()
	for pin in played:
		var ball: SpoutBall = _stuck[pin]
		var strength: float = _strengths[pin]
		_stuck.erase(pin)
		_strengths.erase(pin)
		if pins.hit(pin, strength):
			_hits += 1
			echo.record(
				pins.note_for(pin),
				strength,
				pins.to_global(pins.pin_position(pin)),
				floori((0.0 if is_nan(_clock_bars) else _clock_bars) * sixteenths_per_bar()),
				sixteenths_per_bar()
			)
		pins.pop(pin)
		_played += 1
		_retire(ball)
	return played


## Stick [param ball] to [param pin], struck at [param closing_speed], if
## the pin is free. Returns whether it stuck.
func stick(ball: SpoutBall, pin: int, closing_speed: float) -> bool:
	if ball.is_stuck() or _stuck.has(pin) or not pins.is_live(pin):
		return false
	_stuck[pin] = ball
	_strengths[pin] = clampf(closing_speed / full_strength_speed(), MIN_STRENGTH, 1.0)
	_waiting.append(pin)
	var centre := pins.to_global(pins.pin_position(pin))
	var out := (ball.global_position - centre).normalized()
	if out == Vector2.ZERO:
		out = Vector2.UP
	ball.stick_to(pin, centre + out * (pins.pin_radius + SpoutBall.RADIUS))
	return true


## Closing speed that plays a stuck pin at full strength: B's, scaled with
## the muzzle speed, so the doubled speed still leaves room for soft hits.
func full_strength_speed() -> float:
	return FULL_STRENGTH_SPEED * muzzle_speed() / MUZZLE_SPEED


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
		"C: sticky balls · firing %s · %d in play · %d stuck · %d popped · %d played · %d echoing"
		% [
			describe_flow(),
			in_play(),
			stuck_count(),
			pins.popped_count(),
			_played,
			echo.pending_count(),
		]
	)


func controls_hint() -> String:
	return "RT or touch fires, 8–20 a bar (touch further away = more; Space full, 1–5)"

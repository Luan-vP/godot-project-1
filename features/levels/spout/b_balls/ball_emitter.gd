class_name BallEmitter
extends SpoutEmitter
## Version B: the spout fires balls, at a rate set by how far RT is pressed,
## with one haptic tick for every ball fired.
##
## Balls ([SpoutBall]) are rigid bodies: they leave the nozzle along its aim,
## fall under gravity, bounce off the pins, the side walls and each other, and
## play every pin they strike at a strength from how fast they hit it — so a
## glancing roll is quiet and a straight drop is loud. They leave through the
## open floor.
##
## RT is the fire trigger here, so this emitter keeps L2/R2 out of key moves
## ([method leaves_triggers_free]); L1/R1 still walk all twelve keys.

const MUZZLE_SPEED := 520.0
## Scatter either side of the aim, so a stream of balls fans a little.
const SPREAD := deg_to_rad(2.5)
## At most this many balls in play; the oldest goes first.
const MAX_BALLS := 60
const LIFETIME := 14.0
## Closing speed, pixels/second, that plays a pin at full strength, and below
## which a touch is a roll, not a hit, and stays quiet.
const FULL_STRENGTH_SPEED := 650.0
const QUIET_SPEED := 45.0

## Physics layers: pins (from [PinField]), balls, the side walls.
const BALL_LAYER := 1 << 3
const WALL_LAYER := 1 << 4

## Billiard colours, ivory first.
const COLORS: Array[Color] = [
	Color(0.94, 0.91, 0.82),
	Color(0.89, 0.72, 0.26),
	Color(0.27, 0.42, 0.72),
	Color(0.78, 0.3, 0.26),
	Color(0.45, 0.32, 0.55),
	Color(0.88, 0.5, 0.25),
	Color(0.3, 0.55, 0.38),
	Color(0.5, 0.25, 0.22),
]

## Whether to read the pad and keyboard; off for tests.
var reads_input := true

var _rate := SpoutFireRate.new()
var _balls: Array[SpoutBall] = []
var _ball_material := PhysicsMaterial.new()
var _depth := 0.0
var _fired := 0
var _hits := 0
var _rng := RandomNumberGenerator.new()


func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	super(level_node, the_spout, the_pins)
	_ball_material.bounce = 0.3
	_ball_material.friction = 0.05
	_rng.randomize()
	_build_walls()


func _physics_process(delta: float) -> void:
	if spout == null:
		return
	if reads_input:
		_depth = SpoutFireRate.read_depth()
	for i in _rate.step(_depth, delta):
		fire()
	_retire_spent()


## Set the trigger depth by hand, for tests or another input.
func set_depth(depth: float) -> void:
	_depth = clampf(depth, 0.0, 1.0)


## Fire one ball from the nozzle, with a haptic tick. Returns it.
func fire() -> SpoutBall:
	if _balls.size() >= MAX_BALLS:
		_retire(_balls[0])
	var ball := SpoutBall.new()
	ball.pins = pins
	ball.color = COLORS[_fired % COLORS.size()]
	ball.collision_layer = BALL_LAYER
	ball.collision_mask = pins.pin_layer | BALL_LAYER | WALL_LAYER
	ball.physics_material_override = _ball_material
	ball.z_index = 10
	ball.struck_pin.connect(_on_struck_pin)
	add_child(ball)
	var dir := spout.direction().rotated(_rng.randf_range(-SPREAD, SPREAD))
	ball.global_position = spout.muzzle_position()
	ball.linear_velocity = dir * MUZZLE_SPEED
	_balls.append(ball)
	_fired += 1
	var haptics: Haptics = level.get("haptics") if level != null else null
	if haptics != null:
		haptics.pulse(0.35 + 0.45 * _depth, 0.025)
	return ball


func in_play() -> int:
	return _balls.size()


func fired_count() -> int:
	return _fired


func hit_count() -> int:
	return _hits


## Strength 0..1 a pin is played at for a ball closing at [param speed], or
## -1 for a touch too soft to sound.
static func strength_for(speed: float) -> float:
	if speed < QUIET_SPEED:
		return -1.0
	return clampf(speed / FULL_STRENGTH_SPEED, 0.12, 1.0)


func _on_struck_pin(_ball: SpoutBall, pin: int, closing_speed: float) -> void:
	var strength := strength_for(closing_speed)
	if strength > 0.0 and pins.hit(pin, strength):
		_hits += 1


func _retire_spent() -> void:
	var floor_y := get_viewport_rect().size.y + 60.0
	for ball in _balls.duplicate():
		if ball.age > LIFETIME or ball.global_position.y > floor_y:
			_retire(ball)


func _retire(ball: SpoutBall) -> void:
	_balls.erase(ball)
	ball.queue_free()


## Cushions down both sides of the screen, so balls fired wide come back into
## play like a billiard table's rails. The floor is left open.
func _build_walls() -> void:
	var extent := get_viewport_rect().size
	var material := PhysicsMaterial.new()
	material.bounce = 0.45
	material.friction = 0.05
	for side in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.name = "Wall%s" % ("Left" if side < 0.0 else "Right")
		wall.collision_layer = WALL_LAYER
		wall.collision_mask = 0
		wall.physics_material_override = material
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(40.0, extent.y * 2.0)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector2(-20.0 if side < 0.0 else extent.x + 20.0, extent.y * 0.5)
		add_child(wall)


func leaves_triggers_free() -> bool:
	return false


func describe() -> String:
	return (
		"B: balls · RT %.2f · %.1f/s · %d in play · %d fired · %d pin hits"
		% [_depth, SpoutFireRate.rate_for(_depth), in_play(), _fired, _hits]
	)


func controls_hint() -> String:
	return "RT fires, harder = faster (Space or click: full, 1–5: depths)"

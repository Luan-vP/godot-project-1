class_name BallEmitter
extends SpoutEmitter
## Version B: the spout fires balls in steps of the bar, with one haptic tick
## for every ball fired.
##
## Balls ([SpoutBall]) are rigid bodies: they leave the nozzle along its aim,
## fall under gravity, bounce off the pins, the side walls and each other, and
## play every pin they strike at a strength from how fast they hit it — so a
## glancing roll is quiet and a straight drop is loud. They leave through the
## open floor.
##
## How fast it fires is the shared stepped pour ([SpoutFlow], run by
## [SpoutEmitter]): 8 balls a bar at the gentlest, up to 24, each fired on the
## bar's grid so the balls play in time with the band. RT sets the step by
## depth, so L2/R2 are left out of key moves; L1/R1 still walk all twelve
## keys. On a touchscreen, touching aims and fires at once: the spout points
## at the finger, and the ring the finger is in round the spout sets the step.
## The Deck's right trackpad and R2 (pointer and left click outside Steam) do
## the same.

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

## Billiard colours, ivory cue ball first.
const COLORS: Array[Color] = ArtPalette.BALLS

var _balls: Array[SpoutBall] = []
var _ball_material := PhysicsMaterial.new()
var _fired := 0
var _hits := 0
var _rng := RandomNumberGenerator.new()


func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	super(level_node, the_spout, the_pins)
	_ball_material.bounce = 0.3
	_ball_material.friction = 0.05
	_rng.randomize()
	_build_walls()
	start_flow()


func _physics_process(_delta: float) -> void:
	if spout == null:
		return
	for i in tick_flow():
		fire()
	_retire_spent()


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
	ball.linear_velocity = dir * muzzle_speed()
	_balls.append(ball)
	_fired += 1
	var haptics: Haptics = level.get("haptics") if level != null else null
	if haptics != null:
		haptics.pulse(0.35 + 0.45 * flow_fraction(), 0.025)
	return ball


## How fast a ball leaves the nozzle, pixels/second.
func muzzle_speed() -> float:
	return MUZZLE_SPEED


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


func describe() -> String:
	return (
		"B: balls · firing %s · %d in play · %d fired · %d pin hits"
		% [describe_flow(), in_play(), _fired, _hits]
	)


func controls_hint() -> String:
	return "RT or touch fires, 8–24 a bar (touch further away = more; Space full, 1–5)"

class_name SpoutBall
extends RigidBody2D
## One of version B's balls: small, hard and a little bouncy, closer to a
## billiard ball than a pachinko marble. It clacks off the pins and off other
## balls, and tells its [BallEmitter] about every pin it strikes, with the
## speed it struck at.

## Emitted when the ball strikes a pin, with how fast it was closing on it.
signal struck_pin(ball: SpoutBall, pin: int, closing_speed: float)

const RADIUS := 8.0

var pins: PinField
var age := 0.0
var color := Color(0.93, 0.89, 0.8)
## Velocity at the end of the previous physics step: by the time
## [signal RigidBody2D.body_entered] fires the bounce has already happened, so
## the speed it hit at has to come from before it.
var _approach := Vector2.ZERO


func _init() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp = 0.08
	angular_damp = 0.5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	age += delta
	_approach = linear_velocity


func _on_body_entered(body: Node) -> void:
	if pins == null:
		return
	var pin := pins.pin_for_body(body)
	if pin < 0:
		return
	var centre := pins.to_global(pins.pin_position(pin))
	struck_pin.emit(self, pin, closing_speed(_approach, global_position, centre))


## How fast a ball moving at [param velocity], at [param at], was closing on
## a pin at [param centre]: the part of its speed along the line between them.
## A glancing roll closes slowly; a straight drop at full speed.
static func closing_speed(velocity: Vector2, at: Vector2, centre: Vector2) -> float:
	var normal := (at - centre).normalized()
	return maxf(0.0, -velocity.dot(normal))


func _draw() -> void:
	draw_circle(Vector2(1.5, 2.0), RADIUS, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_circle(Vector2(-2.6, -2.6), RADIUS * 0.32, Color(1, 1, 1, 0.55))

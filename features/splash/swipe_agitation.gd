class_name SwipeAgitation
extends SplashAgitation
## A hand swept once through the tank, left to right, across the logo: a
## column of pushes that travels with the hand and drags the pigment after it.

## How many pushes make up the hand.
@export var fingers: int = 4
## How much of the logo's height the hand covers, centred. Less than all of it,
## so the water spills round its ends and curls, instead of the whole logo
## sliding over as one piece.
@export var span: float = 0.55
## How fast the hand moves, as logo widths per second at its quickest.
@export var speed: float = 1.6
## Each push's reach, as a share of the logo's height.
@export var reach: float = 0.22
## How hard the hand drags the water along, against what it would take to move
## it at the hand's own speed (1).
@export var grip: float = 0.18
## A slight rise and fall as the hand passes, in logo heights, so the wake is
## not a ruled line.
@export var sway: float = 0.08


func stir(fluid: FluidSimulation, t: float, delta: float, logo: Rect2) -> void:
	var travel := hand_x(t, logo)
	var hand_speed := logo.size.x * speed
	var radius := logo.size.y * reach * span
	# The push that brings water up to the hand's speed while the hand is over
	# it: about speed / (time to cross one reach).
	var push := grip * hand_speed * hand_speed / (2.0 * maxf(radius, 1.0))
	var lift := sin(t / maxf(seconds, 0.001) * PI) * sway * logo.size.y
	for i in fingers:
		var share := 0.5 + span * ((i + 0.5) / fingers - 0.5)
		var at := Vector2(travel, logo.position.y + logo.size.y * share - lift)
		fluid.add_velocity_impulse(at, Vector2(push, 0.0), radius, delta)


## Where the hand is, [param t] seconds in: from a reach left of the logo to a
## reach right of it, easing in and out.
func hand_x(t: float, logo: Rect2) -> float:
	var margin := logo.size.y * reach
	var progress := ease(clampf(t / maxf(seconds, 0.001), 0.0, 1.0), -1.8)
	return lerpf(logo.position.x - margin, logo.end.x + margin, progress)

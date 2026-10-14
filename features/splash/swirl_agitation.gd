class_name SwirlAgitation
extends SplashAgitation
## A slow swirl about the logo's centre: rings of pushes, each along its ring
## and harder the further out it is, so the logo turns nearly as one piece
## and then, as the swirl eases off and the middle keeps going, winds into a
## spiral. The rings turn as they go and the strength swells and eases off, so
## the logo is wound round on itself rather than shoved anywhere.

## How many pushes make up each ring.
@export var points: int = 8
## Each ring's radius, as a share of the logo's larger side.
@export var rings: PackedFloat32Array = PackedFloat32Array([0.16, 0.34])
## Each push's reach, as a share of the logo's larger side.
@export var reach: float = 0.2
## The push along the outer ring at the swell's peak, in pixels/second^2;
## inner rings push in proportion to their radius.
@export var strength: float = 250.0
## Turns the ring makes over the whole swirl, so the pushes do not stay put.
@export var turns: float = 0.35
## Clockwise when true, as a hand stirring a cup from above usually would.
@export var clockwise: bool = true


func _init() -> void:
	seconds = 2.6


func stir(fluid: FluidSimulation, t: float, delta: float, logo: Rect2) -> void:
	var centre := logo.get_center()
	var side := maxf(logo.size.x, logo.size.y)
	var push := strength * swell(t)
	var turn := TAU * turns * t / maxf(seconds, 0.001)
	var sense := 1.0 if clockwise else -1.0
	var outer := rings[rings.size() - 1] if not rings.is_empty() else 1.0
	for ring in rings:
		var share := ring / maxf(outer, 0.001)
		for i in points:
			# Rings offset by half a step, so their pushes interleave.
			var angle := turn + TAU * (i + 0.5 * share) / points
			var radial := Vector2.from_angle(angle)
			var along := Vector2(-radial.y, radial.x) * sense
			fluid.add_velocity_impulse(
				centre + radial * side * ring, along * push * share, side * reach, delta
			)


## How hard the swirl is pushing [param t] seconds in, 0 to 1: up and back
## down once, gently at both ends.
func swell(t: float) -> float:
	return sin(clampf(t / maxf(seconds, 0.001), 0.0, 1.0) * PI)

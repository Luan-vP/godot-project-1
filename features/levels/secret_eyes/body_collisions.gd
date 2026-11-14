class_name BodyCollisions
extends RefCounted
## Keeps floating bodies from passing through one another, edge to edge.
##
## Each body brings a [BodyOutline] and the transform that places it in the
## world (see [method FloatyEye.outline] and [method FloatyEye.outline_transform]).
## Two bodies touch where either one's edge points fall inside the other's
## outline. The deepest such point sets how far they are pushed apart, along
## the outlines' averaged normals, shared by weight so a big painting shoves a
## small eye aside. Their closing speed along that line is taken away, with a
## small bounce.
##
## A squishy body (a plain eye) only gives way part of the distance each frame
## and is told how hard it is pressed ([method FloatyEye.press]), so it dents
## against what it touches instead of stopping dead.

## How much of an overlap is undone in one step when neither body is squishy.
const FIRM := 0.7
## The same when either is: enough overlap stays to be drawn as a dent.
const SOFT := 0.3
## Bounce kept from the closing speed.
const RESTITUTION := 0.25
## How much the line between the centres steers the push, so a clean contact
## is barely tilted but a muddled one settles instead of flipping.
const CENTRE_BIAS := 0.3
## How far the contact normals may cancel out before they are not trusted at
## all: two shapes locked into each other's bends push every which way, and
## then they are simply pushed apart along the line between their centres.
const MIN_AGREEMENT := 0.5


## One step: pushes every touching pair in [param bodies] apart.
static func resolve(bodies: Array[FloatyEye]) -> void:
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			_resolve_pair(bodies[i], bodies[j])


## How [param a] must move to stop overlapping [param b]: the direction to push
## it in, scaled by the depth of the overlap, in world pixels. Zero when apart.
static func separation(
	a_outline: BodyOutline, a_xform: Transform2D, b_outline: BodyOutline, b_xform: Transform2D
) -> Vector2:
	var a_scale := _scale_of(a_xform)
	var b_scale := _scale_of(b_xform)
	var reach := a_outline.bound * a_scale + b_outline.bound * b_scale
	if a_xform.origin.distance_squared_to(b_xform.origin) > reach * reach:
		return Vector2.ZERO
	var push := Vector2.ZERO
	var total := 0.0
	var depth := 0.0
	var b_inverse := b_xform.affine_inverse()
	for p in a_outline.points:
		var local := b_inverse * (a_xform * p)
		var d := b_outline.distance(local) * b_scale
		if d < 0.0:
			push += (b_xform.basis_xform(b_outline.normal(local))).normalized() * -d
			total -= d
			depth = maxf(depth, -d)
	var a_inverse := a_xform.affine_inverse()
	for p in b_outline.points:
		var local := a_inverse * (b_xform * p)
		var d := a_outline.distance(local) * a_scale
		if d < 0.0:
			push -= (a_xform.basis_xform(a_outline.normal(local))).normalized() * -d
			total -= d
			depth = maxf(depth, -d)
	if depth <= 0.0:
		return Vector2.ZERO
	var apart := (a_xform.origin - b_xform.origin).normalized()
	var direction := (push + apart * total * CENTRE_BIAS).normalized()
	if push.length() < total * MIN_AGREEMENT:
		direction = apart
	if direction == Vector2.ZERO:
		direction = apart if apart != Vector2.ZERO else Vector2.RIGHT
	return direction * depth


static func _resolve_pair(a: FloatyEye, b: FloatyEye) -> void:
	var push := separation(a.outline(), a.outline_transform(), b.outline(), b.outline_transform())
	if push == Vector2.ZERO:
		return
	var a_mass := a.mass()
	var b_mass := b.mass()
	var a_share := b_mass / (a_mass + b_mass)
	var b_share := 1.0 - a_share
	var give := SOFT if a.is_squishy() or b.is_squishy() else FIRM
	a.global_position += push * a_share * give
	b.global_position -= push * b_share * give

	var direction := push.normalized()
	var closing := (a.velocity - b.velocity).dot(direction)
	if closing < 0.0:
		var impulse := -(1.0 + RESTITUTION) * closing
		a.velocity += direction * impulse * a_share
		b.velocity -= direction * impulse * b_share

	var depth := push.length()
	a.press(-direction, depth)
	b.press(direction, depth)


static func _scale_of(xform: Transform2D) -> float:
	return sqrt(absf(xform.determinant()))

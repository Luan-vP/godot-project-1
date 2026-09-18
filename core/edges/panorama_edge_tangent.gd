class_name PanoramaEdgeTangent
## Tangent-plane chord: the shared math behind every [EdgeSource]'s
## [member PanoramaEdgePoint.tangent].
##
## A chord between two points on a sphere is a straight line through the
## sphere's interior, not a vector along its surface, so it needs projecting
## onto the tangent plane at the point in question before it means "the
## direction the edge runs in there". [ManualEdgeSource] and
## [CannyEdgeSource] both produce ordered points on the sphere and both need
## exactly this, so it lives here once rather than twice.


## Tangent at [param directions][[param index]], estimated from a central
## difference along the polyline and projected onto that point's own tangent
## plane so it stays perpendicular to [param directions][[param index]] even
## though the raw chord is not.
static func at(directions: Array[Vector3], index: int) -> Vector3:
	var direction: Vector3 = directions[index]
	var chord: Vector3
	if directions.size() < 2:
		# No neighbour to take a chord from. Fall back to any vector
		# perpendicular to the direction, so callers never have to
		# special-case a zero tangent.
		chord = direction.cross(Vector3.UP)
		if chord.length_squared() < 0.0001:
			chord = direction.cross(Vector3.RIGHT)
	elif index == 0:
		chord = directions[1] - direction
	elif index == directions.size() - 1:
		chord = direction - directions[index - 1]
	else:
		chord = directions[index + 1] - directions[index - 1]
	var tangent := chord - direction * chord.dot(direction)
	return tangent.normalized()

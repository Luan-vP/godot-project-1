class_name ManualEdgeSource
extends EdgeSource
## Trivial [EdgeSource]: edges placed by hand instead of detected.
##
## Enough to build and test the scorer ([code]#26[/code]) before any real
## detector exists, and it doubles as that scorer's test fixture — see
## [code]#23[/code]'s acceptance criteria. A future image-based detector is a
## different [EdgeSource] implementation behind the same port; nothing about
## [Level] or the scorer changes to swap it in (see [member Level.edge_source]).
##
## Each polyline is authored directly in panorama-space angles rather than
## image pixels, which is what sidesteps the pole distortion equirectangular
## images are notorious for: every point is turned into a unit direction on
## the sphere with the same trigonometry [PanoramaLookCamera] uses for its
## own yaw/pitch, so a fixed change in yaw produces a proportionally shorter
## chord near a pole than at the equator automatically, the same as the real
## geometry. No separate correction step is needed here because none of this
## data ever passes through a pixel grid. An [EdgeSource] built from an image
## filter would not get this for free — it would have to map its pixel
## coordinates to the same angles before calling [method _direction], at
## which point the distortion is handled the same way.

## One polyline per edge. Each point is [code](yaw_degrees, pitch_degrees)[/code]
## — the same convention as [member PanoramaLookCamera.yaw]/[member
## PanoramaLookCamera.pitch], in degrees for easier hand authoring. An edge
## with fewer than two points is legal (see [method _tangent_at]) but
## degenerate; it exists so a fixture can isolate a single point without the
## list shrinking away.
@export var edges_degrees: Array[PackedVector2Array] = []


## Edge [member PanoramaEdge.id] is this array's index — stable for as long
## as [member edges_degrees] itself is not reordered, which is this
## implementation's whole promise (see [EdgeSource]).
func get_edges() -> Array[PanoramaEdge]:
	var result: Array[PanoramaEdge] = []
	for i in edges_degrees.size():
		result.append(_build_edge(i, edges_degrees[i]))
	return result


func _build_edge(id: int, polyline_degrees: PackedVector2Array) -> PanoramaEdge:
	var directions: Array[Vector3] = []
	for point in polyline_degrees:
		directions.append(_direction(deg_to_rad(point.x), deg_to_rad(point.y)))

	var points: Array[PanoramaEdgePoint] = []
	for i in directions.size():
		points.append(PanoramaEdgePoint.new(directions[i], _tangent_at(directions, i)))
	return PanoramaEdge.new(id, points)


## Direction on the unit sphere for a given yaw/pitch, using the same
## rotation [PanoramaLookCamera] applies to itself: a point authored at
## [param yaw]/[param pitch] is the point that camera would be looking
## straight at with that yaw and pitch.
static func _direction(yaw: float, pitch: float) -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD


## Central difference along the polyline at [param index], projected onto the
## tangent plane there so it stays perpendicular to that point's own
## direction even though the chord between two sphere points is not — a
## chord is a straight line through the sphere's interior, and the tangent
## needs the part of it that actually points along the surface.
static func _tangent_at(directions: Array[Vector3], index: int) -> Vector3:
	var direction: Vector3 = directions[index]
	var chord: Vector3
	if directions.size() < 2:
		# A single-point edge has no neighbour to take a chord from. Fall
		# back to any vector perpendicular to the direction, so callers never
		# have to special-case a zero tangent.
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

class_name PanoramaEdgePoint
extends RefCounted
## One sample along a [PanoramaEdge], in panorama space.
##
## A dot has no orientation a strand could lie along; scoring a floater for
## lying along an edge (Level 2, [code]#9[/code]) needs the edge's local
## direction at that point, not just a position on it — see [code]#23[/code]'s
## acceptance criteria. Both are carried here so a scorer never has to
## re-derive one from neighbouring points itself.

## Unit vector from the panorama's centre to this point on the sphere.
var direction: Vector3

## Unit vector tangent to the sphere at [member direction], pointing along
## the edge. Perpendicular to [member direction] by construction.
var tangent: Vector3


func _init(p_direction: Vector3, p_tangent: Vector3) -> void:
	direction = p_direction.normalized()
	tangent = p_tangent.normalized()

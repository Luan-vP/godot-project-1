class_name PanoramaEdge
extends RefCounted
## One continuous edge in a panorama, as an ordered sequence of
## [PanoramaEdgePoint]s.
##
## [member id] is what [code]ScoringContact.edge_id[/code] (see
## [code]core/scoring[/code], [code]#26[/code]) keys a held note against —
## that class's docstring explains why a stable id matters across frames.
## This class only promises the id is stable for its own lifetime; keeping it
## stable across a level's separate detector runs is the owning [EdgeSource]'s
## job.

var id: int
var points: Array[PanoramaEdgePoint]


func _init(p_id: int, p_points: Array[PanoramaEdgePoint] = []) -> void:
	id = p_id
	points = p_points

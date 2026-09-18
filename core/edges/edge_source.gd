class_name EdgeSource
extends Resource
## Port: where the edges in a panorama level's background are.
##
## Level 2 scores floaters that lie along edges in the panorama
## ([code]#9[/code]); this is the seam between "where edges are" and "how
## well a floater sits on one" ([code]#26[/code]), split apart deliberately
## so each can be built, tested, and swapped independently. A consumer must
## not care whether the edges below came from an image filter run over the
## panorama texture ([CannyEdgeSource]), a hand-authored overlay
## ([ManualEdgeSource]), or something else — [method get_edges] is the entire
## contract.
##
## [b]Panorama space, not screen space.[/b] Edges are expressed as unit
## directions on the sphere the camera sits at the centre of, in world
## coordinates — never image pixels or screen coordinates. Floaters, by
## contrast, are screen-space: they sit in the player's eye and travel with
## the gaze every frame (see the floaters README). Something has to bring the
## two into one frame, and the choice made here is to project the few,
## moving floaters out into this fixed panorama space through the camera each
## frame (the scorer's job, [code]#26[/code]), rather than reprojecting every
## edge into screen space every frame only to throw that work away the next.
## That also matches the point below: edges do not move, so anything built
## from them should not need to be rebuilt every frame either.
##
## [b]Computed once, not every frame.[/b] Edges are static for the life of a
## level — nothing here polls or animates — so a consumer calls
## [method get_edges] once, when the level loads, and holds onto the result.
## This mirrors [member Level.fluid_config], which is read once to build a
## fluid tank rather than re-read every frame (see the panorama README).
##
## Extends [Resource], unlike the [RefCounted] [code]MotionSource[/code]/
## [code]LookSource[/code] ports: an [EdgeSource] is level data a [Level]
## names in the editor (see [member Level.edge_source]), not a runtime
## adapter wired up in code.


## Edges for this source, in panorama space. Order and count are stable for
## the object's lifetime; a fresh detector run should build a new
## [EdgeSource] rather than mutate one a consumer might already hold
## contacts against by [member PanoramaEdge.id].
func get_edges() -> Array[PanoramaEdge]:
	return []

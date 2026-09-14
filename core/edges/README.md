# Edges

Where the edges in a panorama level's background are, behind a port — the
seam [issue #23](https://github.com/Luan-vP/godot-project-1/issues/23) asked
for so that finding edges and scoring floaters against them
([#26](https://github.com/Luan-vP/godot-project-1/issues/26)) can be built,
tested, and swapped independently.

## The interface

[`EdgeSource`](edge_source.gd) has one method: `get_edges() -> Array[PanoramaEdge]`.
A [`PanoramaEdge`](panorama_edge.gd) is a stable `id` plus an ordered list of
[`PanoramaEdgePoint`](panorama_edge_point.gd)s, each carrying a `direction`
(unit vector on the sphere) and a `tangent` (unit vector along the edge at
that point) — a dot has no orientation a strand lying along an edge could be
scored against, so both travel together rather than the tangent being
re-derived later from neighbouring points.

[`ManualEdgeSource`](manual_edge_source.gd) is the one implementation this
issue ships: edges placed by hand, `@export`ed as polylines in
`(yaw_degrees, pitch_degrees)`. It is enough to build and test the scorer
before any real detector exists, and doubles as that scorer's test fixture.
A future image-based detector is a different `EdgeSource` behind the same
port — nothing about `Level` or the scorer changes to swap it in.

## Why `Resource`, not `RefCounted`

`core/motion`'s `MotionSource` and `core/look`'s `LookSource` are
`RefCounted` adapters wired up in code (`camera.get_look_input().add_source(...)`).
`EdgeSource` is level data instead — something a
[`Level`](../../features/levels/level.gd) resource names in the editor via
`Level.edge_source`, the same way it names a `FluidConfig` — so it extends
`Resource` and can be assigned as a `.tres` asset.

## Which space, and why

Edges live in **panorama space**: unit directions on the sphere the camera
sits at the centre of, in world coordinates. Floaters live in **screen
space** — they sit in the player's eye and travel with the gaze every frame.
Something has to bring the two into one frame for the scorer to compare them.

The choice made here is to project floaters *out* into panorama space
through the camera, each frame, rather than projecting edges *into* screen
space each frame. Two reasons:

- Edges are static for the life of a level; floaters and the camera are not.
  Reprojecting a level's edges every frame would repeat work whose answer
  never changes for as long as the level is loaded, while there are only ever
  a handful of floaters to project the other way.
- An edge can sit anywhere on the sphere, including behind the camera or
  wrapped around the seam of the equirectangular image. Projecting *edges*
  into screen space means clipping and wrap-handling for geometry that may
  not even be visible. Projecting a *floater*'s screen position out to a
  world-space ray through the camera has none of that: every floater is
  visible by definition, so the projection is always well-defined.

## Computed once, not every frame

Edges are static per level — nothing in this package polls, animates, or
takes a delta. A consumer calls `get_edges()` once, when the level loads, and
holds onto the result for as long as that level is current, the same way
`Level.fluid_config` is read once to build a fluid tank rather than re-read
every frame (see the [panorama README](../../features/levels/panorama/README.md)).

## Equirectangular distortion

A fixed pixel distance near the top of an equirectangular image is a much
smaller angle than the same distance at the equator — image pixels are not a
uniform grid on the sphere. `ManualEdgeSource` sidesteps this entirely by
authoring edges directly in angles (`yaw_degrees`, `pitch_degrees`) rather
than pixels, then embedding each point on the unit sphere with the same
trigonometry `PanoramaLookCamera` uses for its own yaw/pitch
(`Basis.from_euler`). Tangents are derived from that embedding — a chord
between two 3D points on the sphere, projected onto the tangent plane — so
the pole compression falls out of the geometry automatically: the same
`yaw_degrees` step produces a shorter chord near a pole than at the equator,
with no separate correction step.

An `EdgeSource` built from an image filter would not get this for free — its
pixels would first need mapping to the same angles (the standard, *linear*
equirectangular pixel-to-angle formula) before embedding them on the sphere
the same way. The distortion only ever needs handling once, at the sphere
embedding, which is why it belongs here rather than in every implementation.

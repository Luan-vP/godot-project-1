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

[`ManualEdgeSource`](manual_edge_source.gd) is edges placed by hand,
`@export`ed as polylines in `(yaw_degrees, pitch_degrees)`. It was enough to
build and test the scorer before any real detector existed, and doubles as
that scorer's test fixture.

[`CannyEdgeSource`](canny_edge_source.gd) ([issue #24](https://github.com/Luan-vP/godot-project-1/issues/24))
is the first real one: it runs Canny edge detection over a level's
equirectangular panorama texture and traces the result into the same
`PanoramaEdge`/`PanoramaEdgePoint` shape, so a level is a photograph plus
tuning rather than a photograph plus hand-traced geometry. Nothing about
`Level` or the scorer cares which `EdgeSource` a level points at — see
"Which space, and why" below.

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

## `CannyEdgeSource`

Runs the textbook Canny pipeline — grayscale, Gaussian blur, Sobel gradients,
non-maximum suppression, hysteresis threshold — over a working-resolution
copy of `panorama_texture`, then links the surviving pixels into ordered runs
and embeds each one on the sphere through
[`EquirectProjection`](equirect_projection.gd), giving every point a tangent
via the same [`PanoramaEdgeTangent`](panorama_edge_tangent.gd) chord-on-the-
tangent-plane math `ManualEdgeSource` uses. A binary edge mask alone cannot
answer "does this floater lie along an edge" ([#26](https://github.com/Luan-vP/godot-project-1/issues/26));
tracing is what turns detected pixels into the same connected,
tangent-carrying geometry `ManualEdgeSource` already produces.

### CPU, not a compute shader

The fluid tank's `.glsl` compute passes (see the [fluid README](../../features/fluid/README.md))
are the obvious comparison, and the blur/Sobel/suppression stages here would
parallelise the same way. Hysteresis linking and run-tracing do not: which
pixel a weak edge connects to, and which direction a traced run continues in,
both depend on a decision already made a few pixels back — inherently
sequential work a parallel pass is the wrong tool for. Splitting the pipeline
across a GPU half and a CPU half would still mean a synchronous GPU readback
once per level load, no cheaper than staying on the CPU throughout, and
without the `.glsl` import step's dependency on a real rendering device
(lavapipe in CI) or its compiled-shader-count check. Staying on the CPU also
keeps this class testable in headless GUT the same way `ManualEdgeSource` is
— a small synthetic `Image` built by hand, no rendering device required —
rather than joining the fluid solve as the project's second system that can
only be exercised with one.

### Runtime, not an import-time bake

`get_edges()` runs once, lazily, the first time a consumer asks, and caches
the result for the object's lifetime — the same "computed once, not every
frame" contract every `EdgeSource` makes. The alternative this issue asked to
weigh explicitly was baking edges at import time instead: faster level loads,
and a level ships with its edges already decided. That loses against
`CannyEdgeSource` being **tunable per level** (the issue's own acceptance
criterion) — an import bake means a reimport for every tuning pass, the same
friction the fluid README's viscosity table was gathered without needing.
`working_width` is what keeps the runtime cost bounded instead: detection
always runs against a copy downscaled to a fixed working resolution, never
the full source texture, so "once per level load" stays cheap regardless of
how large a level's panorama actually is.

### Debug overlay

`features/edges/canny_edge_debug.tscn` (`scripts/run.sh canny`, or "Canny
Edges" in the demo menu) draws a synthetic panorama — a sky/ground split plus
a few rectangles, one deliberately straddling the horizontal wrap seam — and
overlays every traced run `CannyEdgeSource` finds on top of it.
Up/Down tunes `blur_sigma`, `[`/`]` and `+`/`-` tune the two hysteresis
thresholds, and Left/Right tunes `min_run_length`, each rebuilding a fresh
`CannyEdgeSource` rather than mutating the running one — see `EdgeSource`'s
own docstring for why a fresh detector run should be a fresh source. The
issue this class implements calls this overlay "worth more than any unit
test here", and [#25](https://github.com/Luan-vP/godot-project-1/issues/25)
(comparing detectors) cannot happen without one: a unit test can check a
tangent is perpendicular to its direction, but only a human looking at the
overlay can judge whether the detector traced the picture's real edges.

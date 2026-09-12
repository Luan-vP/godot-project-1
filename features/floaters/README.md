# Floaters

*Muscae volitantes* — the translucent flecks of collagen debris in the
vitreous humour that drift across your vision. This covers both their
behaviour in the [fluid](../fluid/README.md) and how they are drawn.

## Pieces

| Script | What it is |
| --- | --- |
| `floater.gd` | `Floater` — a [`FluidBody`](../fluid/fluid_body.gd) that sinks and wraps at the edge instead of bouncing. |
| `floater_shape.gd` | `FloaterShape` — a shape family as data: dots and strands, not a scene — and the CPU rasterizer that bakes one into a soft-edged alpha mask. |
| `floater_field.gd` | `FloaterField` — drops a configurable population of floaters into a tank. |
| `shaders/floater.gdshader` | The look: translucency, refraction and blur. Shared by every floater; see "Look" below. |

## Using it

```gdscript
var field := FloaterField.new()
field.count = 80
field.radius_range = Vector2(2.0, 10.0)
add_child(field)
```

Left unset, `FloaterField.simulation_path` finds the first tank in the scene
the same way `FluidBody` does.

A single floater can also be built by hand:

```gdscript
var floater := Floater.new()
floater.shape = FloaterShape.make_strand(RandomNumberGenerator.new())
add_child(floater)
```

## Behaviour

- **Not neutrally buoyant.** `Floater` sets `buoyancy` positive by default, so
  with the tank at rest floaters sink slowly out of view, the way real
  floaters settle when you hold still.
- **Current-dominated, not current-locked.** `Floater` loosens `drag` below
  `FluidBody`'s default so a floater lags and overshoots when the medium
  swishes, rather than snapping straight onto the current.
- **Recycled, not lost.** A floater that drifts past the tank edge reappears
  from the opposite edge with its velocity untouched
  (`Floater.recycled_position`), so a population never thins out. This is a
  wrap, not the bounce `FluidBody.contained` gives everything else — `Floater`
  turns that off and does its own thing at the walls.
- **Does not stir or stain.** `wake_strength` and `paint_amount` are both zero
  by default. Real floaters are far too small to move the vitreous they sit
  in, and the medium is meant to stay clear — see the fluid README's note on
  `add_paint`. If a level wants floaters that nudge the current, that is a
  per-instance override, not the default.

## Shape as data

`FloaterShape` is a list of filled dots and open strands in local units, where
`1.0` is the floater's own `radius`. A shape family — dot, strand, cobweb — is
a difference in those numbers, produced by a static factory
(`FloaterShape.make_dot/make_strand/make_cobweb`), not a different scene or
node type. A new family is a new factory function, not a new class.

## Look

A floater is meant to read as glass debris sitting in front of the retina,
not a sprite drawn on top of the scene — see the issue this shipped against
for the exact list. Two pieces split the work the same way `FluidConfig` and
`PainterlyStyle` split the fluid's behaviour from its paint:

- **`FloaterShape.rasterize(pixel_radius)`** bakes a shape's soft edges once,
  on the CPU, into a small alpha-only `Image`: dots get a smooth radial
  falloff, strands taper towards both ends and fade at the tips. This has to
  happen here rather than in the shader because a canvas shader has no notion
  of "distance to this arbitrary vector shape" to soften against — only the
  pixels this produces. It reruns only when a floater's `shape` or `radius`
  changes, never per frame.
- **`shaders/floater.gdshader`** turns that mask into the rest of the look
  every frame: it samples the screen behind the floater through a small
  radial offset (refraction), averages a few extra taps scaled by the
  floater's radius (blur — bigger floaters are more out of focus, matching
  how a floater's blur comes from sitting close to the lens, not from its
  on-screen size), and multiplies the result by a tint colour rather than
  blending in a flat one. That last part is what makes a floater dim its
  background rather than replace it, and why the effect needs no per-level
  tuning: the same numbers read as barely-there over a near-black panorama
  and obvious over a bright one, because the dimming is proportional to
  whatever brightness is actually sampled.

Every `Floater` shares one `ShaderMaterial` instance running that shader —
only the baked mask texture and two per-instance shader parameters (tint,
blur radius) differ per node, which is what keeps a few hundred floaters
cheap. See the PR this shipped in for the individual-nodes-vs-one-pass
decision and the measured cost.

## Size distribution

`FloaterField.radius_range` and `FloaterField.size_skew` control the
population: skew above 1 biases towards the small end of the range, since real
floaters are mostly small specks with the occasional large clump. The sampling
itself (`FloaterField.sampled_radius`) is a pure static function so the
distribution can be checked without a scene tree.

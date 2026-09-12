# Floaters

*Muscae volitantes* — the translucent flecks of collagen debris in the
vitreous humour that drift across your vision. This is their behaviour in the
[fluid](../fluid/README.md); drawing them well is a separate concern.

## Pieces

| Script | What it is |
| --- | --- |
| `floater.gd` | `Floater` — a [`FluidBody`](../fluid/fluid_body.gd) that sinks and wraps at the edge instead of bouncing. |
| `floater_shape.gd` | `FloaterShape` — a shape family as data: dots and strands, not a scene. |
| `floater_field.gd` | `FloaterField` — drops a configurable population of floaters into a tank. |

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
node type. `Floater._draw()` reads whatever shape it is handed, so a new
family is a new factory function, not a new class.

## Size distribution

`FloaterField.radius_range` and `FloaterField.size_skew` control the
population: skew above 1 biases towards the small end of the range, since real
floaters are mostly small specks with the occasional large clump. The sampling
itself (`FloaterField.sampled_radius`) is a pure static function so the
distribution can be checked without a scene tree.

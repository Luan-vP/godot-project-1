# Vitreous tank

What the floaters mechanic is actually about: out-of-focus
[floaters](../../floaters/README.md) drifting in the vitreous humour, against a
bright, nearly clear field. No eyes, no pigment — just the debris and the gel
it hangs in.

## Controls

Drag to push the gel, arrows to tilt, `Space` to jog, `C` to recalibrate, `R`
to still the gel, `+`/`-` to add or remove floaters, `F` to toggle the
out-of-focus look.

Not wired to `run/main_scene`; open `vitreous_tank.tscn` and run it directly
(F6 in the editor).

## The gel

A push should move a broad region of the eye's fluid smoothly, then keep its
momentum and fade slowly through the whole volume — not stop at the walls, and
not slosh back and forth. `make_gel_config` and the stir constants hold the
numbers:

| setting | value | why |
| --- | --- | --- |
| `STIR_RADIUS` / `STIR_GAIN` | 300 px / 6 | the broad, heavy response to input lives here, not in the fluid |
| `simulation_resolution` | 128 | a gel has no fine eddies to resolve; keeps 100 pressure passes cheap |
| `pressure_iterations` | 100 | fewer leaves the solve springy, and a push sloshes back |
| `viscosity` | 1 000 px²/s | enough to keep the flow smooth; more damps the coasting |
| `wall_friction` | 0 | free-slip: the walls take no momentum out |
| `vorticity` | 0 | confinement puts swirl back in, and a gel has none |
| `velocity_dissipation` | 0.98 | barely matters here; measured within a point of 0.95 |
| `ambient_current` | 2 | the gel barely moves on its own |

The first version used viscosity 80 000 over 40 iterations with no-slip walls
and 12 pressure passes. It spread a stir nicely but stopped it within half a
second and sloshed. Measured with the same stroke (speed at a point beside the
stroke and one 200 px below it, energy relative to half a second after):

| | beside | below | energy at 1 s / 2 s / 4 s | flow reversed |
| --- | --- | --- | --- | --- |
| first version | 759 px/s | 118 px/s | 174% (slosh) / 1.5% / 0.6% | yes, −0.15 |
| this version | 682 px/s | 456 px/s | 71% / 39% / 13% | no |

Similar punch beside the stroke, four times the motion further away, and a
slow fade instead of a bounce. In the level, a floater beside a push travels
about 400 px over five seconds, slowing steadily from 140 px/s to 20 px/s
without turning back. 120 fps on an M2 Max; 100 pressure passes at 128² cost
about as much as 25 at 256².

Floaters use `drag = 12` so they are carried by the gel rather than coasting
through it, and `buoyancy = 3` so they settle only slowly.

## Not yet

- Floaters hit their 140 px/s `max_speed` for the first second of a hard
  push; raising it would let them keep up with the fluid.
- Converging pressure by brute force (100 Jacobi passes) works but is the
  expensive way; a multigrid or conjugate-gradient solve would do it in far
  fewer passes.
- The gel is viscous, not viscoelastic. Real vitreous springs back after a
  saccade; that needs an elastic restoring term the solve does not have.
- The input is a mouse stir and device tilt. The intended input is the gaze —
  `PanoramaLookCamera.angular_velocity` — with this as the overlay on the
  [panorama level](../panorama/README.md).

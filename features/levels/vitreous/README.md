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

The vitreous is a gel, so the tank is a [viscous fluid](../../fluid/README.md#viscosity):
a stir moves a broad sheet with no eddies in it, the tank walls (no-slip in the
diffusion pass) drag it to a stop, and it swings back a little as it settles.
`make_gel_config` holds the numbers:

| setting | value | why |
| --- | --- | --- |
| `simulation_resolution` | 128 | each diffusion iteration spreads twice as far in pixels, at a quarter of the cost; a gel has no fine eddies to resolve |
| `viscosity` | 80 000 px²/s | thick |
| `viscosity_iterations` | 40 | viscosity saturates at a fixed iteration count; this is what lets it actually be thick |
| `vorticity` | 0 | confinement puts swirl back in, and a gel has none |
| `ambient_current` | 2 | the gel barely moves on its own |

Measured against the default water tank with the same 120 px stir: peak speed
358 px/s against 1 250, half the tank moving together immediately against a
fifth, and a coherence length of about 176 px against 115. It is also cheaper
than the default water solve.

Floaters use `drag = 12` so they are carried by the gel rather than coasting
through it, and `buoyancy = 3` so they settle only slowly.

## Not yet

- The gel is viscous, not viscoelastic. Real vitreous springs back after a
  saccade; that needs an elastic restoring term the solve does not have.
- The input is a mouse stir and device tilt. The intended input is the gaze —
  `PanoramaLookCamera.angular_velocity` — with this as the overlay on the
  [panorama level](../panorama/README.md).

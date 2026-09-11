# Fluid

The medium the eyes float in. A grid-based (Eulerian) fluid tank simulated on
the GPU, painted to look like a wash of pigment on paper, and readable from
GDScript so gameplay can drift on it.

It is deliberately two-way. The current pushes the eyes around; the eyes leave
wakes that push each other around. Nothing in here knows what an eye is.

## Pieces

| Script | What it is |
| --- | --- |
| `fluid_simulation.gd` | `FluidSimulation` — the tank. Owns the solve, hands out impulses and paint. |
| `fluid_renderer.gd` | `FluidRenderer` — paints the tank's pigment field. |
| `fluid_field.gd` | `FluidField` — the CPU mirror gameplay samples. |
| `fluid_body.gd` | `FluidBody` — something that floats, and stirs. |
| `fluid_config.gd` | `FluidConfig` — how the water moves. |
| `painterly_style.gd` | `PainterlyStyle` — how it looks. |
| `fluid_gpu.gd` | `FluidGPU` — the device resources and the compute dispatch. |

`FluidConfig` and `PainterlyStyle` are separate resources on purpose: retuning
the palette should never be able to change the physics.

## Using it

```gdscript
var tank := FluidSimulation.new()
tank.config = preload("res://resources/tank.tres")
add_child(tank)

var paint := FluidRenderer.new()
paint.z_index = -100          # it is the backdrop
add_child(paint)
```

The renderer and any `FluidBody` find the tank through the
`fluid_simulation` group, so nothing needs wiring unless you have more than one
tank — in which case set their `simulation_path`.

The tank's node position is the **top-left** corner of the world it covers;
`config.world_size` is the rest.

Anything that should float extends `FluidBody`, or adds one as a child. Give it
a `wake_strength` above zero and it will disturb the water it moves through;
give it a `paint_amount` and it will stain it.

Reading the current directly:

```gdscript
var current: Vector2 = tank.sample_velocity(global_position)   # pixels/second
```

## How the solve is put together

Each frame runs the usual stable-fluids sequence as one compute list:

```
velocity -> divergence -> pressure x N -> project -> dye -> downsample
```

1. **velocity** — advect the field along itself, apply vorticity confinement
   and the ambient swell, add this frame's impulses
2. **divergence** — measure how much that field compresses
3. **pressure** — N Jacobi relaxations of the resulting Poisson equation
4. **project** — subtract the pressure gradient, leaving a divergence-free field
5. **dye** — carry pigment on the projected field
6. **downsample** — resample onto the CPU grid

Every field is a **pair** of textures that take turns being read and written,
because a pass has to read last frame's field while writing this frame's and no
shader may do both to one texture. `FluidGPU` gives each pair fixed roles where
it can — advection writes the velocity scratch, projection writes the field
everything else reads — so the texture handed to the renderer never changes
identity. The dye has only one stage, so it writes a scratch and the result is
copied home.

Two loops read last frame's result on purpose:

- `velocity` reads `project` — that edge *is* the time step
- the pressure pair is never cleared between frames, so pressure keeps
  converging rather than restarting from zero every step

Passes are separated by explicit barriers, since each one reads what the one
before it wrote.

This used to be a chain of nested `SubViewport`s, one full-screen canvas shader
each, relying on Godot rendering a child viewport before its parent. It ordered
the passes correctly but the cross-frame reads came back empty, so no field ever
carried forward: a velocity impulse of peak 555 collapsed to zero within four
frames instead of decaying over hundreds, and pigment never accumulated past a
single frame's deposit. Owning the targets is what fixes it.

All targets are 16-bit float. Velocity is signed and pigment density runs well
past 1.0, so an 8-bit target would clamp the simulation into uselessness.

### Building the shaders

The passes are `.glsl` compute shaders under `shaders/compute/`, sharing one
push constant block through `fluid_params.glslinc`. Godot compiles them to
SPIR-V **at import**, and that needs a real rendering device — a headless import
prints `Cannot import custom .glsl shaders when running in headless mode`,
leaves a `valid=false` stub with no `.res`, and nothing downstream notices. CI
installs lavapipe and imports under `xvfb` for exactly this reason; see
`.github/workflows/ci.yml`. Keep these files **ASCII** — the importer rejects
non-ASCII bytes, em dashes included.

## Units

Three coordinate systems, and `FluidField` is the only thing that has to know
about all of them:

- **cells/second** — inside the simulation and the shaders
- **pixels/second** — what game code uses; `sample_velocity` returns these
- **UV** — how the shaders address the grid

Splat radii are given in pixels and converted to tank-heights, with an aspect
correction passed to the shaders so a blob stays round in a non-square tank.

Two things are deliberately **not** scaled by the rendered frame's delta:

- **Retention** (`velocity_dissipation`, `dye_dissipation`) is a fraction per
  *second*, raised to the step each frame. A fixed per-frame multiplier would
  tie how long the water stays alive to the player's refresh rate.
- **Splats** carry their own duration. The queue is filled from
  `_physics_process` and flushed on render, so `add_velocity_impulse` and
  `add_paint` take the *caller's* delta and submit an already-integrated
  quantity. Scaling by the render step instead under-integrates when rendering
  outruns physics and double-counts when it lags.

## Being pushed from outside

Two entry points exist for whole-tank forces, used by `FluidMotionDriver` to
apply device tilt and jog:

- `set_current_bias(acceleration)` leans the ambient drift, continuously. It is
  a bias, not gravity — the tank leans, it does not pour, so what floats in it
  stays floating.
- `nudge(velocity)` shoves the entire field uniformly for one frame. A uniform
  field is already divergence free, so the projection step leaves it alone
  except at the walls, which is where the sloshing comes from.

## Emptying the tank

`reset()` asks for a clear, and the next frame zeroes every target on the device
before the solve runs. The current bias survives it: that belongs to whoever set
it — a player holding a steady tilt is still holding it afterwards, and a steady
hold emits no fresh signal, so clearing it would leave tilt inert until they
moved.

## Reading the fluid from gameplay

The simulation lives on the GPU, which GDScript cannot read. `FluidSimulation`
copies a small grid (`readback_resolution`, default 64²) back into a
`FluidField` every `readback_interval` frames, and everything else samples that.

Pulling the grid off the device is the one place anything waits on the GPU, and
the reason the grid is kept small and the interval configurable. It happens on
the render thread and arrives on the main thread deferred, so the mirror is a
frame behind the field it came from — fine for drifting, wrong if you ever need
the current a body is in *this* instant. For a purely decorative tank, set
`readback_enabled = false` and it costs nothing.

## Tuning

The controls that actually change the feel, roughly in order of how much:

- `vorticity` — 0 gives smooth syrupy drift, 40+ gives a restless churn
- `velocity_dissipation` — fraction surviving one *second*; below ~0.6 the
  water goes still fast
- `stroke_size` (style) — the strongest control over how abstract it looks
- `ambient_current` — the standing swell that stops the tank dying
- `pressure_iterations` — higher gives tighter, longer-lived vortices

`FluidBody.drag` is the other half: high values pin a body to the flow, low
values let it coast through eddies under its own momentum.

## The painterly pass

`painterly.gdshader`, in the order a painter would work:

1. **pigment** — density read subtractively, the way a wash sits on paper,
   with per-channel absorption so thick pigment goes cold rather than grey
2. **brushwork** — a Kuwahara filter whose kernel is stretched *along the
   flow*, so strokes follow the current instead of sitting on a fixed grid.
   Keeping the flattest quadrant is what makes colour spread within a stroke
   but stop dead at its edge
3. **edges** — the darker rim pigment leaves where a wash stops
4. **paper** — grain, fibre, and a little hand-drawn wobble on the edges

Cost is `4 * (STROKE_RADIUS + 1)^2` taps per pixel — 36 at the default radius
of 2. If it needs to be cheaper, that constant is the dial.

## Cost

At the defaults (256² grid, 12 pressure iterations) the solve is 17 compute
dispatches over a 256² grid, in one compute list. If it needs to come down,
`pressure_iterations` is the first thing to cut — the painterly pass hides a
surprising amount of a coarse solve.

The readback is the expensive part per frame, not the solve; see above.

## Known gaps

- The secret eye level (`features/levels/secret_eyes/`) uses this tank with
  placeholder art (`eye.gdshader`, `floaty_eye.gd`) so it has something
  visibly reacting in it. The parts worth keeping are the squash-along-motion
  and the gaze; both read straight off the fluid.
- Bodies do not displace the fluid geometrically — they only push it. Solid
  obstacles would need a boundary mask sampled in `divergence` and `project`.

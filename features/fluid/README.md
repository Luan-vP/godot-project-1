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
| `fluid_pass.gd` | `FluidPass` — one shader step and its render target. |

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

Each frame runs the usual stable-fluids sequence, one full-screen shader pass
each:

```
velocity -> divergence -> pressure x N -> project -> readback -> dye advect -> dye store
```

1. **velocity** — advect the field along itself, apply vorticity confinement
   and the ambient swell, add this frame's impulses
2. **divergence** — measure how much that field compresses
3. **pressure** — N Jacobi relaxations of the resulting Poisson equation
4. **project** — subtract the pressure gradient, leaving a divergence-free field
5. **readback** — downsample to the CPU grid
6. **dye** — carry pigment on the projected field, then store it for next frame

The passes are chained by **nesting** each pass's `SubViewport` inside the next
one's. Godot renders a child viewport before its parent, so nesting is what
makes the whole solve land within a single frame and in the right order. Laying
the viewports out as siblings would leave the order undefined and the tank
would advance one stage per frame instead of one step.

Two loops read last frame's result on purpose:

- `velocity` reads `project` — that edge *is* the time step
- `pressure[0]` reads `pressure[N-1]` — so pressure keeps converging across
  frames rather than restarting from zero every step

Both are between distinct viewports, which is what keeps them legal; a viewport
may not sample its own texture. That restriction is also why the dye field
needs two passes rather than one.

All targets are `use_hdr_2d`. Velocity is signed and pigment density runs well
past 1.0, so an 8-bit target would clamp the simulation into uselessness.

## Units

Three coordinate systems, and `FluidField` is the only thing that has to know
about all of them:

- **cells/second** — inside the simulation and the shaders
- **pixels/second** — what game code uses; `sample_velocity` returns these
- **UV** — how the shaders address the grid

Splat radii are given in pixels and converted to tank-heights, with an aspect
correction passed to the shaders so a blob stays round in a non-square tank.

## Reading the fluid from gameplay

The simulation lives on the GPU, which GDScript cannot read. `FluidSimulation`
copies a small grid (`readback_resolution`, default 64²) back into a
`FluidField` every `readback_interval` frames, and everything else samples that.

This readback is **synchronous** — it is the one place the CPU waits on the
GPU, and the reason the grid is kept small and the interval configurable. For a
purely decorative tank, set `readback_enabled = false` and it costs nothing.

## Tuning

The controls that actually change the feel, roughly in order of how much:

- `vorticity` — 0 gives smooth syrupy drift, 40+ gives a restless churn
- `velocity_dissipation` — below ~0.99 the water goes still very fast
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

At the defaults (256² grid, 12 pressure iterations) the solve is 19 viewports
of 256², which is a small amount of GPU work but a lot of draw calls. If it
needs to come down, `pressure_iterations` is the first thing to cut — the
painterly pass hides a surprising amount of a coarse solve.

## Known gaps

- The demo eye (`demo/eye.gdshader`, `demo/floaty_eye.gd`) is placeholder art
  so the tank has something visibly reacting in it. The parts worth keeping are
  the squash-along-motion and the gaze; both read straight off the fluid.
- Bodies do not displace the fluid geometrically — they only push it. Solid
  obstacles would need a boundary mask sampled in `divergence` and `project`.
- If the pipeline ever needs more than one solve step per frame, the viewport
  chain is the wrong shape for it and it should move to `RenderingDevice`
  compute shaders.

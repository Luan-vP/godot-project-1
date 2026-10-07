# Fluid carousel

The three fluid levels in turn — the eye band, spout A and the waterboatmen —
looping, over one tank and one band. `scripts/run.sh carousel`, or "Fluid
carousel" in the demo menu.

A second carousel, `fluid_carousel_birds.tscn` (`scripts/run.sh
carousel-birds`, "Fluid carousel (birds)" in the menu), is the same with the
original flying birds (`birds_level.tscn`) in place of the waterboatmen. Its
script, `fluid_carousel_birds.gd`, extends `fluid_carousel.gd` and only
replaces `level_paths` in `_init`; the original carousel keeps its three.

## Layers

`SharedLayers` owns what outlives the levels: the eye tank's `FluidSimulation`
and its `FluidRenderer`, seeded once, and a `Band` started once. The band is the
music layer. Its clock (the `AudioManager` loops and tempo) runs without a break
across every level, and its own `_exit_tree` stops the loops when the carousel
leaves the tree, which is the only time they stop.

`FluidCarousel` instances each level under `SharedLayers.stage`, drawn over the
tank. The tank itself never moves.

## Hosted levels

A level calls `SharedLayers.find(self)` in `_ready`: an ancestor walk, not a
group lookup, so it can never adopt a tank from a demo that is still being
freed. Null means standalone, and then the level behaves exactly as it always
has. Hosted:

- **Eye tank / eye band** use the shared tank and add no renderer or seed
  paint. The band demo keeps its own `EyeBand` only to track which eyes touch
  walls, and mirrors that into the shared band's wanted parts every frame.
- **Spout** drops the paper backdrop, uses the shared band (all parts wanted)
  and the shared tank. The fluid emitter re-applies its downward lean every
  physics frame, since each transition resets the tank's currents.
- **Waterboatmen and Birds** (the same level, `BoidsLevel`, in its two
  motions) use the shared tank, and leave the clock alone: no tempo
  change, no loop start or stop. They switch every shared band part off, so
  the flocks are the music, and follow whatever tempo the band has.

## Transitions

`advance()` instances the next level frozen, parks it one viewport width to the
right and slides both across, eased (`slide_seconds`). Outgoing and incoming
levels are both frozen while they move, because live physics at an offset would
clamp eyes against the tank walls in global coordinates. The currents are reset
at the start of each slide so one level's lean does not leak into the next. When
the slide ends the old level is freed and the new one comes alive.

Levels are `Node2D`s but their HUDs are `CanvasLayer`s, which ignore the parent
transform, so `_place` moves the layers' offsets by hand.

It advances itself every `dwell_seconds` for now. `advance()` and `retreat()`
are public so keys can be bound later; a call during a slide is ignored.

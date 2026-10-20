# Fluid carousel

Three fluid levels in turn — the eye band, a spout and a flock — looping,
over one tank and one band. `scripts/run.sh carousel`, or "Fluid
carousel" in the demo menu. This is the main way to play: the game opens
straight into it after the splash, with the demo menu behind it (Backspace,
Select or the `‹ menu` button).

Swipe along the bottom of the screen to change level: left for the next,
right for the previous. A mouse drag works the same on a desktop.

The spout and the flock hold variants (`FluidCarousel.VARIANTS`): spout A (the
fluid), B (the balls) or C (the sticky balls), a third each, and the
waterboatmen or the birds, 50:50. Each time the carousel arrives at one of
those slots it picks one of the group, each as likely (`path_for`), so swiping
round again may bring another.

`level_paths` is exported, so every other way in is just a scene that sets
it. `solo/` has a carousel of one for each level played on its own: the eye
band, spouts A, B and C, the spout shell, the birds and the waterboatmen. A
carousel of one never advances and always plays exactly its level. The demo menu's level entries and
`run.sh`'s level names open these.

## The level format

Every level has the same shape: **a foreground over a host.**

The host is `SharedLayers`. It holds the background — the game's one tank,
the `Tank` autoload (see below) — and owns the music, a `Band` started once. The band's clock (the `AudioManager` loops and tempo)
runs without a break across every level, and its own `_exit_tree` stops the
loops when the carousel leaves the tree, which is the only time they stop.

A level is everything in front: its bodies, its input, its HUD. It is
instanced under `SharedLayers.stage`, and in `_ready` it calls
`SharedLayers.host_of(self)` and takes what it needs from the host:

- **`fluid`** to stir and paint. A level never builds a tank, a renderer, a
  backdrop or seed paint of its own.
- **`band`** for its music. A level never starts a clock, sets a tempo or
  adds bus effects of its own. It chooses which parts it wants, moves the key,
  follows `key_changed` and `stepped`, and plays its own notes over the top in
  the band's key.

**A new song and every key move print the key into the tank**, whichever
level made the move: the host's `KeyPrint` follows the band's `song_started`
and `key_changed` and prints the key's name ("F# minor", in the menus'
inscription face and the root's pin colour) into the middle of the water,
the way the splash prints its logo, to drift and swirl away with it.
A level does nothing for this, unless it wants the name somewhere else: one
with a `prints_key_anywhere()` that returns true gets it at a random spot,
wholly on the screen. The eye tank does.

`host_of` is an ancestor walk, not a group lookup, so a level can never adopt
a tank from a demo still being freed. With no host it reports an error and
the level disables itself.

What each level does with the band:

- **Eye band** keeps its own `EyeBand`, never started, only to track which
  eyes touch walls, and mirrors that into the band's wanted parts every frame.
- **Spout** wants every part, scrolls its pins to the band's key, and plays
  pins on its own synth.
- **Waterboatmen and birds** (`BoidsLevel`, in its two motions) want every
  part and sing over the song: each bird's voice is a step of the band's
  pentatonic, so the flocks are in the song's key and follow its key moves.
  They add a snare, its ghosts and a scatter crash, and no kick or reverb,
  which the band already has.

The tank does not move. The fluid emitter re-applies its downward lean every
physics frame, since each transition resets the tank's currents.

## The tank

There is one tank for the whole game: the `Tank` autoload
(`autoload/Tank.gd`), a `FluidSimulation` and its `FluidRenderer` on a canvas
layer under everything else. Nothing builds it up front; the first thing to
call `Tank.acquire(holder, motion, look)` starts it, sized to the screen, and
it lives until the game quits. For a player that is the splash, which prints
the logo into it; the carousel then takes the same water over with the logo's
last swirls still in it, and the splash's black paper eases into the levels'
look over `Tank.BLEND_SECONDS`.

A holder brings its own motion (a `FluidConfig`: everything but the fields
that size the tank, `Tank.BUILD_FIELDS`) and its own look (a
`PainterlyStyle`), and lets go by leaving the tree. With nobody holding it the
tank is paused, hidden and out of the `fluid_simulation` group, its water kept:
close the carousel for the menu, open it again, and it is the same tank.
`SharedLayers` seeds it with paint only when it is the one that starts it.

## Transitions

`advance()` instances the next level frozen, parks it one viewport width to the
right and slides both across, eased (`slide_seconds`). Outgoing and incoming
levels are both frozen while they move, because live physics at an offset would
clamp eyes against the tank walls in global coordinates. The currents are reset
at the start of each slide so one level's lean does not leak into the next. When
the slide ends the old level is freed and the new one comes alive.

Levels are `Node2D`s but their HUDs are `CanvasLayer`s, which ignore the parent
transform, so `_place` moves the layers' offsets by hand.

A swipe is a press (finger or left mouse button) that starts in the bottom
`SWIPE_BAND` (a fifth) of the screen and lets go at least `SWIPE_MIN_TRAVEL`
(an eighth or so) of the screen's width to the side, more across than up.
The carousel watches it in `_input` without consuming it, so the level
underneath still sees the touch. `advance()` and `retreat()` are public so
keys can be bound too; a call during a slide is ignored.

It never advances on its own unless `dwell_seconds` is set above zero.

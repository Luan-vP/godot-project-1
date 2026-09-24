# godot-project-1

A 2D game about floaty eye thingies, in a painterly style. Godot 4.4.

## Layout

- `features/fluid/` — the fluid the eyes float in: GPU simulation, painterly
  rendering, and the coupling that lets bodies drift on it and stir it back.
  See its [README](features/fluid/README.md).
- `features/floaters/` — the eye floaters themselves: specks that drift and
  sink on the fluid. See its [README](features/floaters/README.md).
- `features/levels/secret_eyes/` — a secret level built on the fluid: a tank
  full of floaty eyes. See its [README](features/levels/secret_eyes/README.md).
- `features/levels/vitreous/` — out-of-focus eye floaters drifting in a pale,
  gel-like vitreous. See its [README](features/levels/vitreous/README.md).
- `features/levels/panorama/` — the main level's core mechanic: a camera at
  the centre of a look-around panoramic background. See its
  [README](features/levels/panorama/README.md).
- `features/ui/level_select/` — the level select: discovers `Level`
  resources from `resources/levels/` and plays whichever one is picked.
- `resources/levels/` — the `Level` resources the level select discovers.
  See its [README](resources/levels/README.md).
- `features/player/` — `PanoramaLookCamera`, the camera the panorama level
  looks around with.
- `core/motion/` — device tilt and jog behind a port, so the controls can be
  developed on a desktop and tested in CI. See its
  [README](core/motion/README.md).
- `core/look/` — camera look input (mouse, gamepad) behind a port, the same
  shape as `core/motion`. See its [README](core/look/README.md).
- `core/audio/` — the audio foundation: bus layout, `AudioManager`, and a
  manual demo scene to prove it makes a sound. See its
  [README](core/audio/README.md).
- `autoload/` — global singletons (`EventBus`, `GameState`, `AudioManager`,
  `SaveManager`, `ComfortSettings`).
- `addons/` — vendored third-party code; see [addons/README.md](addons/README.md).
- `tests/` — GUT suite.

Pressing play opens the level select: pick a level with a click, `Enter`, or
a gamepad, and press `Backspace` (or `Select` on a gamepad) from inside one to
come back. It lists whatever `Level` resources it finds under
`resources/levels/` — see [its README](resources/levels/README.md) — plus a
secret entry, reached by a gesture; see
[the secret eye level's README](features/levels/secret_eyes/README.md).

`features/ui/demo_menu/` is a separate, development-only menu that lists
every level and demo, including ones that are not `Level` resources yet — see
`scripts/run.sh menu`.

## Running a level

```sh
scripts/run.sh             # list the levels and demos, with their controls
scripts/run.sh play        # the level select every player sees
scripts/run.sh menu        # the clickable demo menu
scripts/run.sh vitreous    # floaters in the vitreous gel
scripts/run.sh eyes        # the secret eye tank
scripts/run.sh band        # the eye tank as a band: eyes off the walls play parts
scripts/run.sh panorama    # look-around camera (no panorama image yet)
scripts/run.sh refraction  # the clear medium bending a checkerboard
scripts/run.sh synth       # play the synth voices from the keyboard
scripts/run.sh groove      # synthwave loop: drums on the step grid, bass and pads
scripts/run.sh audio       # buses, loop layers, the effect fader
scripts/run.sh comfort     # distortion, look sensitivity, floater overshoot
```

It finds Godot from `$GODOT`, then `godot4`/`godot` on `PATH`, then
`/Applications/Godot.app`. On first run it imports the project, and it
recompiles the fluid's compute shaders whenever their sources are newer than
the compiled copies — Godot misses edits to the shared
`fluid_params.glslinc` on its own, and the fluid then silently stops moving.
`--fresh` forces that recompile; anything after `--` goes to Godot, e.g.
`scripts/run.sh eyes -- --resolution 1280x720`.

## Building on the Steam Deck

The Deck builds its own export: the compute shaders compile against its own
GPU, and the result is exactly what it will run. From your dev machine, over
Tailscale:

```sh
scripts/deck.sh setup   # once: Godot + templates in ~/.local, a checkout, a `deck` git remote
scripts/deck.sh build   # push HEAD to the Deck, import, export to ~/Games/godot-project-1
scripts/deck.sh run     # launch it on the Deck's screen (stop / logs / ssh too)
```

`build` sends committed work only. On the Deck itself, the build runs from
`~/dev/godot-project-1/scripts/deck-build.sh`. To play from Game Mode, add
`~/Games/godot-project-1/launch.sh` once as a non-Steam game (Desktop Mode →
Steam → *Add a Game* → *Add a Non-Steam Game*; the entry is listed as
`launch.sh` — rename it in Steam if you like). The picker only lists
`.application`, `.exe`, `.sh` and `.AppImage`, so `launch.sh` — a one-line
wrapper `deck-build.sh` writes beside the real `godot-project-1.x86_64` — is
what shows up and what to pick, not the binary itself. Launching this way
also matters beyond the file picker: Steam Input only attributes a
controller to a process Steam itself launched, so it's how the game sees
motion or gyro from a controller at all. Later builds replace it in place.

## Running the tests

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Linting

CI runs `gdformat --check` and `gdlint` over our own GDScript only —
`addons/` is vendored and not ours to reformat.

```sh
pip install "gdtoolkit==4.*"
gdformat autoload core features resources tests
gdlint autoload core features resources tests
```

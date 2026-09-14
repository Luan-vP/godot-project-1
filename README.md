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
  `SaveManager`).
- `addons/` — vendored third-party code; see [addons/README.md](addons/README.md).
- `tests/` — GUT suite.

Pressing play opens a demo menu, since there is no main level yet: click into
any level or demo, and press `Backspace` (or `Select` on a gamepad) to come
back. The secret eye level is listed there for now — see
[its README](features/levels/secret_eyes/README.md) for how it stays secret
once a main level exists.

## Running a level

```sh
scripts/run.sh             # list the levels and demos, with their controls
scripts/run.sh menu        # the clickable demo menu
scripts/run.sh vitreous    # floaters in the vitreous gel
scripts/run.sh eyes        # the secret eye tank
scripts/run.sh band        # the eye tank as a band: eyes off the walls play parts
scripts/run.sh panorama    # look-around camera (no panorama image yet)
scripts/run.sh refraction  # the clear medium bending a checkerboard
scripts/run.sh synth       # play the synth voices from the keyboard
scripts/run.sh groove      # synthwave loop: drums on the step grid, bass and pads
scripts/run.sh audio       # buses, loop layers, the effect fader
```

It finds Godot from `$GODOT`, then `godot4`/`godot` on `PATH`, then
`/Applications/Godot.app`. On first run it imports the project, and it
recompiles the fluid's compute shaders whenever their sources are newer than
the compiled copies — Godot misses edits to the shared
`fluid_params.glslinc` on its own, and the fluid then silently stops moving.
`--fresh` forces that recompile; anything after `--` goes to Godot, e.g.
`scripts/run.sh eyes -- --resolution 1280x720`.

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

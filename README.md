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
  shape as `core/motion`, including eye tracking on devices with the gaze
  plugin. See its [README](core/look/README.md) and
  [gaze README](core/look/gaze/README.md).
- `core/audio/` — the audio foundation: bus layout, `AudioManager`, and a
  manual demo scene to prove it makes a sound. See its
  [README](core/audio/README.md).
- `autoload/` — global singletons (`EventBus`, `GameState`, `AudioManager`,
  `SaveManager`).
- `addons/` — vendored third-party code; see [addons/README.md](addons/README.md).
- `tests/` — GUT suite.

Pressing play opens a demo menu, since there is no main level yet: click into
any level or demo, and press `Backspace` (or `Select` on a gamepad, or tap
`⌫ menu` in the corner) to come back. The secret eye level is listed there for now — see
[its README](features/levels/secret_eyes/README.md) for how it stays secret
once a main level exists.

## Running a level

```sh
scripts/run.sh             # list the levels and demos, with their controls
scripts/run.sh menu        # the clickable demo menu
scripts/run.sh vitreous    # floaters in the vitreous gel
scripts/run.sh eyes        # the secret eye tank
scripts/run.sh panorama    # look-around camera (no panorama image yet)
scripts/run.sh refraction  # the clear medium bending a checkerboard
scripts/run.sh gaze        # eye tracking readout (the pointer stands in on desktop)
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

## Building for iPhone

```sh
scripts/build-ios.sh                   # export, build, install and launch on the connected iPhone
scripts/build-ios.sh --device <id>     # a specific one (xcrun devicectl list devices)
scripts/build-ios.sh -- --open=eyes    # straight into a demo
scripts/build-ios.sh -- --probe        # measure every demo unattended, then quit
scripts/build-ios.sh --export-only     # just the Xcode project, in builds/ios
scripts/build-ios.sh --simulator       # layout only; see below
```

One-time setup:

- **Export templates.** Unzip the `templates/` folder of
  [Godot 4.4-stable's export templates](https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_export_templates.tpz)
  into `~/Library/Application Support/Godot/export_templates/4.4.stable/`.
- **Signing.** Signing is automatic for team `BJS3Z2X97R` (override with
  `IOS_TEAM`), so Xcode has to be signed in to an Apple ID on that team —
  Xcode > Settings > Accounts. Xcode then makes the development certificate
  and profile itself; none are committed. Without an account the build stops
  at `No Accounts`.
- **The phone.** Developer Mode on (Settings > Privacy & Security), unlocked
  and connected when you build. The first launch of a new signing identity is
  refused until you trust it: Settings > General > VPN & Device Management.

Everything generated lands in `builds/` (ignored by git, and by Godot via a
`.gdignore` the script writes).

### What changes on a phone

The `mobile` feature tag carries the phone-only settings in `project.godot`,
so the desktop window is untouched:

- **Portrait**, on a 540-unit-wide canvas that stretches (`canvas_items`,
  `expand`) to whatever height the phone has. Tanks size themselves from the
  viewport, so every tank is portrait-shaped on a phone.
- **Mobile renderer.** Forward+ does not exist on iOS. The Mobile renderer
  still has a `RenderingDevice` on Metal, which is what the fluid's compute
  solve needs.
- **Safe area.** `SafeArea` keeps the menu and demo labels clear of the
  Dynamic Island and the home indicator.
- **Touch.** Touches arrive as the left mouse button, so tapping the menu,
  dragging to stir, and dragging to look in the panorama levels need no
  code of their own. The corner `⌫ menu` is a button: it is the only way
  back without a keyboard. Tilt and jog come from the real sensors —
  `MotionInput` picks them — and the eye tank's corner readout says so.

Keyboard-only controls go missing: the eye tank's `R`/`C`/`B`, the vitreous
tank's `+`/`-`/`F`/`R`, refraction strength, and all of **Synth** and
**Groove**, which cannot be played or started at all without a keyboard.
**Audio** is all buttons and sliders and works.

### Checking a device without holding it

`--probe` opens each demo in turn, pushes a synthetic touch drag through the
same input path a finger uses, and logs the frame rate, renderer, motion
source, and the tank's peak current before and after the drag. A tank whose
compute shaders never ran reads zero there, which a screenshot of a calm tank
would not show. Results go to `user://probe/` — on the phone, the app's
Documents folder:

```sh
xcrun devicectl device copy from --device <id> --domain-type appDataContainer \
  --domain-identifier com.luanvanpletsen.godotproject1 --source Documents/probe \
  --destination builds/probe
```

### The simulator

Only for layout. Godot 4.4 runs the simulator on the OpenGL Compatibility
renderer, which has no `RenderingDevice`, so the fluid stands still there. Its
official simulator library is also x86_64 only (the script builds for Rosetta)
and links MetalFX, which the simulator SDK lacks (the script strips it).

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

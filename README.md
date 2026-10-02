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
- `features/levels/spout/` — level 3: aim a spout over a field of pins that
  play a scale, the eye band behind it. Two versions: A pours the eye tank's
  fluid, B fires balls. See its [README](features/levels/spout/README.md).
- `features/levels/boids/` — flocks of birds that sing polyrhythms, played
  with a snare. See its [README](features/levels/boids/README.md).
- `features/levels/panorama/` — the main level's core mechanic: a camera at
  the centre of a look-around panoramic background. See its
  [README](features/levels/panorama/README.md).
- `features/player/` — `PanoramaLookCamera`, the camera the panorama level
  looks around with.
- `core/motion/` — device tilt and jog behind a port, so the controls can be
  developed on a desktop and tested in CI. Reads the Steam Deck's IMU, and a
  phone's sensors, and falls back to the arrow keys. See its
  [README](core/motion/README.md).
- `core/look/` — camera look input (mouse, gamepad) behind a port, the same
  shape as `core/motion`, including eye tracking on devices with the gaze
  plugin. See its [README](core/look/README.md) and
  [gaze README](core/look/gaze/README.md).
- `core/haptics/` — short controller pulses behind a port: Steam Input on the
  Deck, plain gamepad rumble elsewhere, rate-limited. See its
  [README](core/haptics/README.md).
- `core/audio/` — the audio foundation: bus layout, `AudioManager`, and a
  manual demo scene to prove it makes a sound. See its
  [README](core/audio/README.md).
- `autoload/` — global singletons (`EventBus`, `GameState`, `AudioManager`,
  `TempoControl`, `SaveManager`, `ComfortSettings`).
- `addons/` — vendored third-party code; see [addons/README.md](addons/README.md).
- `tests/` — GUT suite.

Pressing play opens `features/ui/demo_menu/`, the list of every level and
demo (also `scripts/run.sh menu`): pick one with a click, `Enter`, or a
gamepad, and press `Backspace` (or `Select` on a gamepad) from inside one to
come back. `Backspace` or `Select` at the list itself quits, as does its Quit
button. On a touch screen with no `Backspace`, a tappable `⌫ menu` button in
the corner takes its place.

## Running a level

```sh
scripts/run.sh             # list the levels and demos, with their controls
scripts/run.sh play        # the level select every player sees
scripts/run.sh menu        # the clickable demo menu
scripts/run.sh vitreous    # floaters in the vitreous gel
scripts/run.sh eyes        # the secret eye tank
scripts/run.sh band        # the eye tank as a band: eyes off the walls play parts
scripts/run.sh spout-a     # level 3, A: pour the eye tank's fluid over the pins
scripts/run.sh spout-b     # level 3, B: RT fires billiard balls at the pins
scripts/run.sh spout       # level 3's shell: spout, pins, band (Space plucks)
scripts/run.sh birds       # flocks singing 3-against-4, played with a snare (B)
scripts/run.sh panorama    # look-around camera (no panorama image yet)
scripts/run.sh gaze        # look around to swish the floaters
scripts/run.sh refraction  # the clear medium bending a checkerboard
scripts/run.sh eye-gaze    # eye tracking readout (the pointer stands in on desktop)
scripts/run.sh synth       # play the synth voices from the keyboard
scripts/run.sh groove      # synthwave loop: drums on the step grid, bass and pads
scripts/run.sh audio       # buses, loop layers, the effect fader
scripts/run.sh motion      # tilt readout: the live source, its axes, the lean
scripts/run.sh comfort     # distortion, look sensitivity, floater overshoot
scripts/run.sh arrangement # scoring drives the layer stack (#34)
```

In every scene, the arrow keys (or d-pad) move the music's tempo: up and down
by 2 bpm, left and right by 10. Tilt, where a level has it, is on WASD.

It finds Godot from `$GODOT`, then `godot4`/`godot` on `PATH`, then
`/Applications/Godot.app`. On first run it imports the project, and it
recompiles the fluid's compute shaders whenever their sources are newer than
the compiled copies — Godot misses edits to the shared
`fluid_params.glslinc` on its own, and the fluid then silently stops moving.
`--fresh` forces that recompile; anything after `--` goes to Godot, e.g.
`scripts/run.sh eyes -- --resolution 1280x720`.

## Building on the Steam Deck

Run from Desktop Mode outside Steam, the Deck's controller reaches the game
as a keyboard and mouse (B is Escape, the triggers are clicks), not a
gamepad. [docs/steam-deck-controls.md](docs/steam-deck-controls.md) has the
layout and what each control does in the game.

The Deck builds its own export: the compute shaders compile against its own
GPU, and the result is exactly what it will run. From your dev machine, over
Tailscale:

```sh
scripts/deck.sh setup   # once: Godot + templates in ~/.local, a checkout, a `deck` git remote
scripts/deck.sh build   # push HEAD to the Deck, import, export to ~/Games/godot-project-1
scripts/deck.sh run     # launch it on the Deck's screen (stop / logs / ssh too)
```

Tilting the Deck tilts a panorama level: motion is read through Steam Input,
sensor-fused and in known units for every controller Steam supports, and the
right stick click recentres whatever pose you are holding. That needs the
Steam client running and the game launched *from* Steam — a build started
over `ssh` initialises Steam but Steam attributes no controllers to it, so
launch it as a non-Steam shortcut instead. `scripts/run.sh motion` shows what
the sensors are reporting — the first thing to look at on hardware. See
[`core/motion`](core/motion/README.md).

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

### Playing the latest main from the Desktop

`setup` also drops a **"godot-project-1 (main)"** icon on the Deck's Desktop
(Desktop Mode), for building and playing straight from `main` with no dev
machine involved: it resets the checkout to `origin/main`, builds, and
launches, in one double-click. It needs a `build` to have run at least once
first, since it launches `scripts/deck-play-main.sh` from the checkout. A
`.desktop` file needs trusting once — right-click it and choose *Trust and
Launch* the first time.

### Play-testing pull requests on the Deck

The demo menu's **Pull requests** screen lists the open PRs from GitHub. Pick
one and the Deck fetches it, checks it out in its own worktree, builds it
(skipped if that commit is already built), then closes the game and runs the
PR build in its place. Select on the PR build's demo
menu quits it and brings back the list, so you can switch between PRs with
back and pick. Select while a PR is still building stops the build.

Everything lives beside the Deck's checkout and main build:

```
~/dev/godot-project-1/               the checkout deck.sh pushes to; the one
                                     repository (gets a GitHub `origin` remote)
~/dev/godot-project-1-prs/pr-94/     PR #94's worktree, detached at its head
~/Games/godot-project-1/             the main build, with the picker
~/Games/godot-project-1-prs/pr-94/   PR #94's build
```

Each worktree keeps its own import cache, seeded from the main checkout's on
first use. Delete a PR's directories when you're done with it; the next swap
prunes the stale worktree entry.

The swap is done by `scripts/deck-demo.sh`. `deck-build.sh` copies it, along
with itself, into `tools/` beside every build, and the picker runs the copy
beside itself. So the swap always uses the scripts from the build you
launched (build `main` with `scripts/deck.sh build` and launch that one), and
PRs older than the picker still build. What a PR build can't get this way is
the Select-to-go-back: it needs this code in the PR itself (merge `main` into
the PR). Without it, leave through Steam's *Exit game* and launch again.
Picking only works in a build installed on the Deck; elsewhere,
`scripts/run.sh prs` just shows the list.

Holding `M` (or `X` on a pad) on a card for about a second and a half
squash-merges that PR, with `gh` — needs `gh auth login` run once on the
Deck itself (`repo` scope is enough). This is `scripts/deck-merge.sh`, copied
into `tools/` the same way as the swap script, so it works from any build
that has the picker regardless of whether the PR being merged does.

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

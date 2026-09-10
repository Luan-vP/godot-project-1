# godot-project-1

A 2D game about floaty eye thingies, in a painterly style. Godot 4.4.

## Layout

- `features/fluid/` — the fluid the eyes float in: GPU simulation, painterly
  rendering, and the coupling that lets bodies drift on it and stir it back.
  See its [README](features/fluid/README.md).
- `core/motion/` — device tilt and jog behind a port, so the controls can be
  developed on a desktop and tested in CI. See its
  [README](core/motion/README.md).
- `autoload/` — global singletons (`EventBus`, `GameState`, `AudioManager`,
  `SaveManager`).
- `addons/` — vendored third-party code; see [addons/README.md](addons/README.md).
- `tests/` — GUT suite.

Pressing play runs `features/fluid/demo/fluid_demo.tscn`: drag to stir and
paint, arrows to tilt, `Space` to jog, `C` to recalibrate, `R` to empty the
tank, `B` to make everyone blink. On a device with sensors the arrows and
space give way to the real accelerometer with no code change.

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

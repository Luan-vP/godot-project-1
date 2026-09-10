# godot-project-1

A 2D game about floaty eye thingies, in a painterly style. Godot 4.4.

## Layout

- `features/fluid/` — the fluid the eyes float in: GPU simulation, painterly
  rendering, and the coupling that lets bodies drift on it and stir it back.
  See its [README](features/fluid/README.md).
- `autoload/` — global singletons (`EventBus`, `GameState`, `AudioManager`,
  `SaveManager`).
- `addons/` — vendored third-party code; see [addons/README.md](addons/README.md).
- `tests/` — GUT suite.

Pressing play runs `features/fluid/demo/fluid_demo.tscn`: drag to stir and
paint, `R` to empty the tank, `Space` to make everyone blink.

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

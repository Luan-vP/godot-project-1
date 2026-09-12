# Audio

The floor everything else audible stands on: a bus layout, an `AudioManager`
that owns playback and routing, and settings that persist. No knowledge of
floaters, edges, or scoring belongs here — this is equally usable by a menu,
a level, or a test.

## Buses

`Master`, `Music` and `SFX` are committed as a resource,
[`resources/audio/default_bus_layout.tres`](../../resources/audio/default_bus_layout.tres),
and loaded through the `audio/buses/default_bus_layout` project setting.
Nothing creates buses in code — if a fourth bus is ever needed, add it to
that resource, not at runtime.

## `AudioManager`

The only script allowed to call [`AudioServer`] directly. Everything else
asks it to play something or change a volume:

```gdscript
AudioManager.play_sfx(some_stream)
AudioManager.play_music(some_stream)
AudioManager.set_bus_volume_linear(AudioManager.MUSIC_BUS, 0.7)  # 0..1, not dB
AudioManager.set_bus_mute(AudioManager.SFX_BUS, true)
```

Volume is always a **linear** fraction in `[0, 1]` at the API boundary — the
shape a UI slider produces — and gets converted to decibels internally with
`linear_to_db`. A bare linear multiplier bunches all the perceptible range
into the last stretch of a slider's travel; going through dB is what makes
the middle of the slider sound like the middle.

Mute is independent of volume, per bus, so effects can be silenced without
losing the level a player dialled in. `mute_on_focus_loss` (on by default)
mutes the Master bus while the window is unfocused and restores whatever it
was before — a player's own mute choices on other buses are left alone.

`add_bus_effect` / `get_bus_effect` / `remove_bus_effect` hand out an effect
instance already sitting on a bus, so a caller can drive one of its properties
directly without needing to talk to `AudioServer` itself:

```gdscript
var filter := AudioEffectLowPassFilter.new()
var index := AudioManager.add_bus_effect(AudioManager.SFX_BUS, filter)
# ... later, e.g. once per frame ...
AudioManager.get_bus_effect(AudioManager.SFX_BUS, index).cutoff_hz = some_value
```

## `ParameterFader`

Setting a bus volume or an effect parameter straight from a per-frame value —
the naive version — produces stepping and zipper noise, because the value
changes once per frame while the audio is mixed in much finer blocks.
[`ParameterFader`](parameter_fader.gd) smooths a float into any object's
property instead, and maps a configurable input range onto a configurable
output range so a caller passes "0.3 of the way", not a cutoff in hertz:

```gdscript
var fader := ParameterFader.new()
fader.target = AudioManager.get_bus_effect(AudioManager.SFX_BUS, index)
fader.property = &"cutoff_hz"
fader.output_min = 200.0
fader.output_max = 6000.0
fader.retention_per_second = 0.01  # fraction of the gap left after one second
# every frame:
fader.advance(delta, some_0_to_1_value)
```

Smoothing is frame-rate independent — `retention_per_second` closes the same
fraction of the gap every second regardless of `delta`, the same
`pow(rate, delta)` shape [`FluidConfig.retention_over`](../../features/fluid/fluid_config.gd)
uses for the fluid's dissipation. A fixed per-frame factor would close the gap
roughly twice as fast at 144 fps as at 30.

If the input stops arriving — pass `null` to `advance` instead of a float —
the fader holds its last value briefly, then eases towards `rest_value` after
`input_timeout` seconds, so a level ending or a pause settles somewhere
sensible instead of holding the last value forever. `ParameterFader` knows
nothing about gameplay, or even audio: `target`/`property` can be any object
with a settable property, not necessarily an `AudioEffect`.

## Persistence

Bus volumes, mutes, and the focus-mute preference are saved through
[`SaveManager`](../../autoload/SaveManager.gd) — a generic, section-keyed
`ConfigFile` wrapper that has no idea these keys are about audio. Nothing
here writes to disk directly.

## Proving it makes a sound

Open `core/audio/audio_demo.tscn` and run it directly (F6 in the editor). It
plays a procedural sine wave — [`AudioTestTone`](test_tone.gd), built at
runtime rather than shipped as a binary asset — through the SFX and Music
buses, with a slider and mute box per bus and a focus-mute toggle. Move a
slider, hear the level change; mute a bus, hear it stop; alt-tab away and
back, if focus-mute is on, to hear it recover.

The same scene also sweeps a low-pass filter on SFX and a reverb wet mix on
Music from the same value, through a `ParameterFader`. Play the looping
filtered tone and the looping music, then uncheck "Smooth" — the sweep is
identical, but now assigned directly every frame instead of through the
fader, and audibly steps and zippers where it was smooth a moment before.

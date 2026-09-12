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

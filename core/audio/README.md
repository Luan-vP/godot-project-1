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

## Loop layering

The playback machinery generated music runs on (#31): loops that stay
phase-locked with each other, layers that fade in and out on a bar boundary
instead of clicking in immediately, and a musical clock #34's composition
rules can schedule against. This is mechanism only — what the loops *are* is
#28's decision, and this works whatever that answer is; a "loop" is just
whatever `AudioStream` a [`LoopLayer`](loop_layer.gd) resource points at.

### Why `AudioStreamSynchronized`, not the other two

Godot 4 ships three stream types worth checking before hand-rolling this:

- **`AudioStreamPlaylist`** plays a list of streams one after another. It has
  no concept of simultaneous layers, so it does not fit "loops locked
  together" at all.
- **`AudioStreamInteractive`** has built-in bar/beat-aligned transitions,
  which sounds like a match for "changes land on musical boundaries" — but it
  transitions *between* clips, one active clip at a time. It has no way to
  keep several independently-toggleable layers all live in the mix at once,
  so it doesn't cover "layers that come and go" while others keep playing. It
  may be worth revisiting for section-to-section transitions once #34 needs
  those, but it doesn't solve layering.
- **`AudioStreamSynchronized`** plays up to 32 sub-streams from a single
  shared playback position and lets each one's volume
  (`set_sync_stream_volume`) be changed independently at runtime. That shared
  position is what makes "no drift over ten minutes" true by construction —
  there is one playback clock, not N separate `AudioStreamPlayer`s that could
  each round their mix buffers slightly differently. This is what
  `AudioManager`'s loop layer stack is built on.

What none of the three do is decide *when* a volume change should land.
That part — queuing a layer's on/off request and releasing it only once
playback crosses a bar boundary — is hand-rolled as
[`LoopLayerScheduler`](loop_layer_scheduler.gd), driven by a
[`MusicClock`](music_clock.gd). Both are deliberately pure (no `AudioServer`
access), so a test can "advance" them with an arbitrary seconds value instead
of waiting on real playback.

The scheduler's clock is *not* `AudioStreamPlayer.get_playback_position()`,
which was the first thing tried and is wrong here for a reason specific to
looping streams: position is measured within the stream's own buffer, so it
wraps back to the loop point every time playback loops instead of continuing
to climb. A bar longer than the loop then never arrives, since `MusicClock`
keeps being handed a position from earlier in the same loop cycle and the
scheduler sits in bar 0 forever. `AudioManager._get_loop_playback_seconds()`
instead runs its own monotonic clock, started in `play_loops()` via
`Time.get_ticks_usec()`, which has no such ceiling. The trade-off is losing
the mix-buffer-accurate correction `get_time_since_last_mix()` and
`get_output_latency()` would give a position-based clock — negligible at
musical-bar granularity, and moot since `AudioStreamSynchronized` already
guarantees the layers themselves share one playback position regardless of
what the scheduler measures against.

A second, subtler version of the same "which clock" question: changing tempo
mid-playback swaps in a new `MusicClock` with a different seconds-per-bar
scale, so the bar number a given playback position maps to changes too.
`LoopLayerScheduler.set_clock()` rebases its notion of the current bar onto
the new clock at the moment of the swap — without that, the next `update()`
compares a new-clock bar against an old-clock one, the mismatch reads as a
boundary crossing, and anything pending releases immediately instead of
waiting for a real bar to pass.

### Using it

```gdscript
AudioManager.set_tempo(96.0, 4)  # BPM, beats per bar — configurable, not baked in.

var bass := LoopLayer.new()
bass.layer_name = "bass"
bass.stream = preload("res://assets/audio/bass_loop.ogg")

var pad := LoopLayer.new()
pad.layer_name = "pad"
pad.stream = preload("res://assets/audio/pad_loop.ogg")

var layers: Array[LoopLayer] = [bass, pad]
AudioManager.configure_loop_layers(layers)  # Loops are data, not hardcoded paths.
AudioManager.set_layer_active("bass", true)  # Not playing yet: takes effect immediately.
AudioManager.play_loops()

AudioManager.set_layer_active("pad", true)  # Already playing: lands on the next bar.

AudioManager.get_current_bar()   # Readable musical clock for #34 to schedule against.
AudioManager.get_current_beat()
```

### What is left to manual verification

This issue is labelled `manual_verification`: "no drift over ten minutes" and
"no clicks" are properties of real audio hardware over real time, not
something a headless GUT run can prove. `tests/test_music_clock.gd` and
`tests/test_loop_layer_scheduler.gd` cover the bar/beat math and the
scheduling logic deterministically; `tests/test_music_layers.gd` covers the
`AudioManager` wiring with an artificially fast tempo so a bar boundary
passes within the test timeout. Actually leaving two layered loops running
for ten minutes and listening for drift or clicks — ideally through
`audio_demo.tscn` or a similar scene — is still worth doing by ear.

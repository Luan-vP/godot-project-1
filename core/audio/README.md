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

## Synth voices

The other half of #28's "hybrid" decision (#56): continuous sine, saw and
square tones generated at runtime, next to the recorded loops above.

```gdscript
var patch := SynthPatch.new()
patch.waveform = SynthWavetable.Waveform.SAW
patch.release_seconds = 0.4

var synth := Synth.new()        # a pool of voices, on the Music bus by default
synth.patch = patch
add_child(synth)

var voice := synth.note_on(220.0)
voice.set_frequency(330.0)      # glides over patch.glide_seconds
voice.note_off()                # fades over patch.release_seconds
```

Open `core/audio/synth_demo.tscn` and run it directly (F6) to play it from the
keyboard.

| Script | What it is |
| --- | --- |
| [`synth_wavetable.gd`](synth_wavetable.gd) | `SynthWavetable` — band-limited single-cycle tables, one per octave. |
| [`synth_patch.gd`](synth_patch.gd) | `SynthPatch` — waveform, envelope, level and glide, as data. |
| [`synth_voice.gd`](synth_voice.gd) | `SynthVoice` — one note: on, hold, glide, off. |
| [`synth.gd`](synth.gd) | `Synth` — a capped pool of voices, with voice stealing. |

These are their own classes, not more `AudioManager` methods. Voices play
through a bus, so bus effects and a `ParameterFader` apply to them unchanged.

### Why wavetables, not `AudioStreamGenerator`

`AudioStreamGenerator` is the obvious choice, and both of its costs were
measured rather than assumed:

- One PolyBLEP saw voice filled from GDScript costs about **7 ms of main-thread
  time per second of audio** on an M2 Max. That is fine on a desktop for a few
  voices; a phone is plausibly 5–10× slower.
- The buffer is filled from the main thread, so any long frame starves it and
  the audio drops out.

Instead each waveform is a set of one-cycle `AudioStreamWAV` loops, pitched
with `pitch_scale`. No script runs per sample, so there are no underruns and
voices cost almost nothing while they sound.

### Staying clean at high pitch

A naive saw table holds harmonics far past Nyquist once it is pitched up, and
they fold back as grit. So there are ten bands, one per octave from 20 Hz, and
each holds only the harmonics that stay under 45% of the output rate at the top
of its octave (540 harmonics in the lowest saw band, 1 in the highest). A voice
plays all of a waveform's bands phase-locked through one
`AudioStreamSynchronized` and crossfades between the two around its pitch. The
tables are built once per waveform — 41 ms for saw — when a voice is first set
up, not on the first note.

Recorded from the Music bus: a saw at 3 520 Hz puts **−50 dB** of its energy
away from its harmonics, against **−11 dB** for a single full-harmonic table
at the same pitch.

### Clicks

- **Envelope.** Attack and release are linear, and never shorter than 5 ms.
- **Starting a note.** `play()` only takes effect on the audio thread's next
  mix, so a voice holds its envelope at silence until playback has actually
  started. Without that, a 10 ms attack had already finished by the time the
  first sample was mixed and the note started at full level: measured as a
  spike 27× the steady waveform's, and 1.1× with the fix.
- **Retriggering** a sounding voice carries its envelope on rather than
  restarting from silence.

### Glide, and its limit

A held note glides in log-frequency (each octave takes the same time), eased
in and out, arriving exactly after `glide_seconds`. Eased on purpose: Godot
applies `pitch_scale` once per mix block, about 10 ms, so what is heard is the
largest step between blocks, and an exponential glide takes its biggest step
right at the start. On a two-octave glide over 0.6 s, the largest step between
cycles went from 8.7% (exponential) to 5.0% (eased).

That per-block stepping is the real limit of this approach. It is inaudible on
slow glides and noticeable as a slight staircase on fast, wide ones — roughly
`1.5 × octaves ÷ glide_seconds × 10 ms` per step. If a sound needs fast, smooth
sweeps, that voice is the case for an `AudioStreamGenerator` path.

### Voices and level

`Synth.polyphony` caps the pool (8 by default). A note past the cap steals an
idle voice, else the quietest released one, else the oldest held one. Voices
sum: eight saw voices at level 0.25 peaked at 0.97, so `SynthPatch.level`
defaults to 0.15.

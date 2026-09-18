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

## Step grid, drums and musical time

The machinery for music on a sixteenth-note grid, and a synthesised drum kit
for the floaty-synthwave direction. `core/audio/groove_demo.tscn`
(`scripts/run.sh groove`) plays all of it together at 70 bpm.

| Script | What it is |
| --- | --- |
| [`time/music_time_source.gd`](time/music_time_source.gd) | `MusicTimeSource` — port: where musical time comes from. |
| [`time/sources/wall_clock_music_time.gd`](time/sources/wall_clock_music_time.gd) | `WallClockMusicTime` — the current adapter: a session wall clock. |
| [`time/sources/scripted_music_time.gd`](time/sources/scripted_music_time.gd) | `ScriptedMusicTime` — time moved by hand, for tests. |
| [`music_clock.gd`](music_clock.gd) | `MusicClock` — now also steps: `step_at`, `seconds_per_step`, `steps_per_bar`. |
| [`step_sequencer.gd`](step_sequencer.gd) | `StepSequencer` — pure: which steps have come due, each once, in order. |
| [`step_clock.gd`](step_clock.gd) | `StepClock` — node emitting `step(index, bar, step_in_bar)` while music plays. |
| [`drum_synth.gd`](drum_synth.gd) | `DrumSynth` — kick, snare, clap, closed and open hat, synthesised. |
| [`step_pattern.gd`](step_pattern.gd) | `StepPattern` — a bar of drums as notation, rendered sample-accurately into a loop, or read hit by hit for live playback. |
| [`drum_kit.gd`](drum_kit.gd) | `DrumKit` — plays a `StepPattern`'s hits live, one-shot, off the step grid. |

### Musical time is a port

`AudioManager` asks its `MusicTimeSource` what time it is, and nothing else
does its own timekeeping: loop layers change on bars against it, and
`StepClock` fires steps against it. Replacing the timing underneath — with a
clock driven from the audio thread, say — is a new adapter and one call:

```gdscript
AudioManager.set_music_time_source(MyBetterClock.new())
```

`tests/test_music_time_sources.gd` drives both bar changes and steps from a
`ScriptedMusicTime`, which is what proves nothing is reading a clock behind the
port's back.

### Two ways onto the grid

**Rendered, where the loop stack already fits.** A `StepPattern` mixes each
hit in at its exact sample offset and renders the bar into a looping stream.
Play it as a `LoopLayer` and it runs on the loop stack's shared playback
position; switching patterns is toggling layers on a bar. `groove_demo.tscn`
and `audio_demo.tscn` play their drums this way.

```gdscript
var beat := StepPattern.parse({
	"kick":  "9.......9..5....",
	"snare": "....9.......9...",
	"hat":   "5.3.5.3.5.3.5.3.",
})
layer.stream = beat.render(70.0, 4, int(AudioServer.get_mix_rate()))
```

Digits are velocity out of 9, `x` is full, `.` is a rest. Tails wrap into the
next bar, and a closed hat chokes an open one. Kit build 41 ms, one bar 26 ms,
done before playback. The cost is that a render bakes in a tempo:
`StepPattern.render(tempo_bpm, ...)` mixes a buffer exactly
`60/bpm × beats_per_bar × rate` samples long, and re-rendering on every tempo
change is a ~26 ms-per-layer hitch that also restarts `configure_loop_layers`.
Fine for a fixed arrangement; wrong for one where the tempo, or which patterns
play, has to move while the music keeps going.

**Live, off the same `StepClock` the melodic parts already use.** `DrumKit`
reads a `StepPattern`'s notation (`StepPattern.parse` and `.velocity(hit,
step)` — `.render`/`.mix` are not involved) and plays each hit as a one-shot
from a pool of `AudioStreamPlayer`s, `Synth`'s shape: velocity becomes
`volume_db`, and past the pool size a new hit steals an idle player first,
then whichever has sounded longest. The open-hat choke moves from a fade
baked into a render to a closed hat stopping a sounding open hat's player
outright.

```gdscript
var kit := DrumKit.new()
add_child(kit)
# from StepClock.step(index, bar, step_in_bar):
var velocity := beat.velocity(DrumSynth.Hit.KICK, step_in_bar)
if velocity > 0.0:
	kit.play(DrumSynth.Hit.KICK, velocity, -6.0)  # -6.0 dB: this part's level
```

Nothing is baked in, so a tempo change or a pattern swap costs nothing —
`EyeBand` plays every one of its drum parts this way, for exactly that reason
(#75). The trade is the onset cost below, accepted deliberately and worth
listening to rather than assuming: `scripts/run.sh band`, kick against bass.

### How tight, measured

Recorded from the Music bus, onsets measured against the ideal grid:

- **Script-triggered sixteenths** at 120 bpm (`play()` when the wall clock
  crosses a step): 17.7 ms spread, every onset on a 512-sample mix-block
  boundary. With `AudioServer.get_time_to_next_mix()` as lookahead: 10.3 ms —
  one mix block, as tight as starting sound from script gets. This is
  `DrumKit`'s number too, since it triggers the same way.
- **Rendered drum loop** at 70 and 120 bpm: every kick within ±1 sample of
  the grid.
- **Live synth notes against that loop**, at 70 bpm: about 16–20 ms behind it,
  with about 10 ms of spread. Keeping synth voices playing silently between
  notes did not change that, so it was left out. This is the wonk a better
  `MusicTimeSource` would remove — and it is what `DrumKit` inherits too, at
  roughly 5–9% of a sixteenth at 70 bpm. Held in reserve if that turns out to
  be audible: a sample-accurate `MusicTimeSource` (the port most of this
  system already runs against), or running `StepPattern.mix`'s logic
  continuously into an `AudioStreamGenerator` rather than per-bar into a WAV —
  sample-accurate and live-tunable, but measured at ~7 ms of main-thread time
  per second of audio for one synth voice (see "Why wavetables, not
  `AudioStreamGenerator`" above), and by far the most code of the three
  options.

### The kit

All synthesised, so there is no sample licence to sort out. Drum-machine
shapes rather than acoustic ones: a kick swept from about 150 Hz to 45 Hz, a
snare with a 185/330 Hz body under high-passed noise, a clap of three noise
bursts and a tail, and hats built from the TR-808's six square-wave partials
through a high-pass. Every hit is normalised to the same peak and built from a
fixed noise seed, so it is identical every time — whether it ends up mixed
into a render or played live by a `DrumKit`, the buffer is the same.

## Songs: chords that branch

For music that should not audibly loop, a [`Song`](song.gd) is written as data:
named sections of chord symbols, each listing which sections may follow it and
how likely each is. [`SongWalker`](song_walker.gd) lays the path through them
bar by bar as it plays, seeded, so the progression branches but a replay with
the same seed walks the same way.

```gdscript
song.sections = {
    "A": {"bars": "Am | F | C | G", "next": {"A2": 2, "B": 1}},
    "B": {"bars": "Dm | Am | F | G,Em", "next": {"A": 1}},  # "G,Em" splits the bar
}
var walker := SongWalker.new(song, rng)
walker.chord_at(bar, step_in_bar)  # -> Chord
```

[`Chord`](chord.gd) reads symbols (`Am`, `Fmaj7`, `Dm9`, `A7sus4`, `Bbmaj7`, …)
and voices them for each part: a close voicing inside a register for pads, the
root down low for bass, the chord tones in a range for an arp or a melody.
Registers fold notes down rather than letting them climb somewhere shrill.

[`MelodyWriter`](melody_writer.gd) writes each section's melody from the song's
rhythms: chord tones on the beat, scale steps off it, always the nearest
candidate to the note before so the line moves by step, settling on the root
or third at the end. It is seeded by song and section, so a section's melody
is the same every time that section comes round — the form stays recognisable
while the order of sections varies.

`problems()` on a song lists anything written wrong (a chord that does not
parse, a section leading nowhere, a pattern of the wrong length); the eye
band's songs are checked with it in `tests/test_eye_band_songs.gd`.

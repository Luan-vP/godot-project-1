# Scoping #71 and #72: playing the music system as an instrument

Both tickets ask for the same new thing: **the player changes the music while it
is playing.** #72 moves the tempo, #71 moves the root note. Neither is possible
against the music system as it stands, for the same underlying reason — musical
state is read once, at `EyeBand.start()`, and baked into places it cannot be
taken back out of.

This is the scope of what has to change and what it costs. The four design
decisions it opened are settled and recorded in "Decisions taken" at the end;
the largest of them — drums played live rather than rendered — reverses a
decision the audio README currently argues for, so it is written up in full.

---

## What the music system does today

`EyeBand.start()` picks a `Song` from `EyeBandSongs`, and from that one object
everything downstream is fixed for the session:

| Read from the song | Where it goes | Can it change later? |
| --- | --- | --- |
| `tempo_bpm`, `beats_per_bar` | `AudioManager.set_tempo()` → `MusicClock` | Yes, but see §1 |
| `tempo_bpm` | `StepPattern.render()` → four `AudioStreamWAV` drum loops | **No — baked into the samples** |
| `tempo_bpm` | `EyeBand._on_step()`'s local `seconds_per_step` | **No — recomputed from `_song`, not the clock** |
| chord symbols (`"Am \| F \| C \| G"`) | `Chord.parse()` → absolute roots | No concept of transposition exists |
| `key_root`, `scale` | `MelodyWriter.scale_between()` | Melodies are written once and cached |

Everything sounding is driven from two places: rendered drum loops on
`AudioManager`'s shared `AudioStreamSynchronized`, and live `Synth` notes fired
per grid step from `StepClock`. Both keep time against `MusicTimeSource` →
`MusicClock`.

---

## 1. Musical position is derived from wall seconds, and must be integrated

`MusicClock.bar_at(seconds)` is `floor(seconds / seconds_per_bar())`, and
`seconds` comes from `WallClockMusicTime`, counting from `play_loops()`.
**Changing the tempo therefore reinterprets the entire history of the song at
the new tempo**, and the current position jumps.

Concretely, five minutes into a 70 bpm song:

- at 70 bpm, 300 s → seconds/bar 3.4286 → **bar 87, beat 2.0**
- nudge to 72 bpm → seconds/bar 3.3333 → **bar 90, beat 0.0**

One arrow press moves the music three bars forward and lands it on a different
beat. `LoopLayerScheduler.set_clock()` and `StepSequencer.set_clock()` already
rebase so they do not misfire — but they rebase *onto the jumped position*, so
the phase inside the bar still jumps. The error grows with elapsed time, and
#72's ±2 bpm taps are meant to be pressed repeatedly.

**The fix is to integrate musical position rather than derive it.** Musical time
must accumulate against whatever tempo was in force at the time, so a tempo
change only affects what happens next.

Two shapes:

**(a) The time source keeps reporting seconds, but musical ones.** Smallest
diff: `WallClockMusicTime` owns a tempo and scales as it accumulates;
`MusicClock` and the schedulers are untouched. But `get_seconds()` then no
longer means wall seconds, which sits badly next to `get_lookahead()` — a
genuinely wall-clock quantity — and muddles `ScriptedMusicTime` for tests.

**(b) The port reports beats.** `MusicTimeSource.get_beats()`; `MusicClock`
converts beats → bar/step; wall seconds survive only where audio really needs
them (note hold lengths, mix lookahead). **Chosen.** Position stops having a
tempo scale at all, which means `LoopLayerScheduler.set_clock()` and
`StepSequencer.set_clock()` no longer need to rebase — two subtle methods whose
doc comments are mostly an explanation of the rebase simply go away. A tempo
change becomes a non-event for everything downstream of the port.

Cost: touches `music_time_source.gd`, both adapters, `music_clock.gd`,
`step_sequencer.gd`, `loop_layer_scheduler.gd`, `AudioManager`, and their four
test files. Fully testable headless: drive `ScriptedMusicTime` across a tempo
change and assert bar/beat phase is continuous and that no step is doubled or
dropped.

## 2. Drums become live patterns — reversing the README's drum decision

The drums are the reason tempo cannot move today.
`StepPattern.render(tempo_bpm, beats_per_bar, rate)` mixes one bar into an
`AudioStreamWAV` exactly `60/bpm × beats_per_bar × rate` samples long, and all
four layers — `beat`, `ghost`, `shimmer`, `fill` — are rendered once in
`EyeBand.start()`. Change the tempo and the WAV keeps its old length: the drums
run at the old tempo and drift against the live parts, permanently.

**The decision taken is to play drum patterns live**, off `StepClock`, the way
the melodic parts already work. Tempo then costs nothing at all — there is
nothing baked to go stale — and the same machinery makes patterns swappable
mid-song later. But it reverses what `core/audio/README.md` currently argues,
and `DrumSynth`'s own class doc says the opposite in as many words:

> They are meant to be mixed at exact sample offsets by `StepPattern`, not
> played directly: triggering a hit from script lands on a mix-block boundary,
> which is audibly loose on a sixteenth-note grid.

That warning is backed by measurements already in the repo, and they are the
real cost of this change:

| | Onset accuracy |
| --- | --- |
| Rendered `StepPattern` loop | every kick within **±1 sample** of the grid |
| Script-triggered, no lookahead | **17.7 ms** spread |
| Script-triggered, mix lookahead | **10.3 ms** spread — as tight as script gets |
| Live notes against a rendered loop, 70 bpm | **16–20 ms behind**, ~10 ms spread |

At 70 bpm a sixteenth is 214 ms, so ~10 ms of spread is about **5% of a step**
and being 20 ms late is about **9%**. Whether that reads as human feel or as
sloppy is an ears question, and it is most exposed on the kick — the one hit
where people hear timing.

Three ways to get the accuracy back, if it is needed:

1. **Accept mix-block timing.** Free; ship it and listen. The style is slow and
   floaty, which is the most forgiving case for this. **Start here.**
2. **A sample-accurate time source.** The `MusicTimeSource` port exists exactly
   so this can be swapped in without touching anything above it. It tightens
   the melodic parts at the same time, which are already 16–20 ms behind today.
3. **A streaming step mixer.** `StepPattern.mix()` already places hits at exact
   sample offsets; run that logic continuously into an `AudioStreamGenerator`
   instead of per bar into a WAV. Sample-accurate *and* live-tunable. The
   README measured the generator path at ~7 ms of main-thread time per second
   of audio for one synth voice and rejected it for voices — but drums are much
   cheaper (mixing a few short cached buffers, not generating oscillators). The
   cost is underrun risk on a long frame, and it is the most code by far.

### What this changes in the code

**New: a live drum kit.** `DrumSynth` renders `PackedFloat32Array` buffers and
caches them; nothing plays one as a one-shot. Needs a `DrumKit` node in
`Synth`'s shape — wrap each cached buffer in an `AudioStreamWAV` once per hit
per sample rate, a pool of players with velocity as `volume_db`, stealing when
the pool runs out.

**`StepPattern` keeps its notation, loses its renderer.** `parse()` — the
`"9.......9..5...."` strings, velocities, hit names, the open-hat choke — is
exactly the data a live kit needs. Only `render()`/`mix()` stop being used by
the band. The choke has to move from render-time to play-time: a closed hat cuts
a sounding open hat, which is now a voice to stop rather than a fade to write
into a buffer.

**`EyeBand` gets simpler, which is the quiet win.** Today it has two kinds of
part that change at different moments, and three separate mechanisms to keep
them in step:

- `LOOP_PARTS` vs live parts, latched differently;
- `_process()` reading `AudioManager.is_layer_active()` every frame because the
  step clock fires ahead of the audio and a latch there would be a bar late;
- `_request_fill()` asking half a bar early, because a loop-layer change only
  lands on the next bar boundary.

With every part live, all three collapse into the existing `_latch_live_parts()`
and one uniform rule. Roughly 40 lines lighter, and a whole class of "the drums
changed a bar after the bass did" bug stops being possible.

**What it costs elsewhere.** Layer fades go away: `AudioManager` ramps a layer
over `_LAYER_FADE_SECONDS`, whereas a live part simply starts or stops playing
hits at the bar. If parts popping in and out is too abrupt, the kit needs its
own per-part gain ramp. `LOOP_DB` becomes per-part level on the kit.

**The loop-layer stack stays.** `groove_demo`, `audio_demo` and #34's
arrangement work (open in PR #65) all drive it; it stops being the eye band's
path, not the project's. Worth coordinating with #65 before either lands.

## 3. Tempo has three sources of truth, and two of them go stale

`EyeBand._on_step()` computes `seconds_per_step := 60.0 / _song.tempo_bpm / 4.0`
— from the **song**, not the clock. Every note hold length (pads, bass, arp,
melody) hangs off it. After a tempo change these keep the old value: at half
tempo, notes would still be released at full-tempo durations and the
arrangement would thin out; at double tempo they would overlap and pile up
voices.

All of it must read `AudioManager.get_music_clock().seconds_per_step()`.
`Song.tempo_bpm` becomes a *starting* tempo, not the tempo. `AudioManager`
already owns the live value inside `_loop_clock`, but there is no way to read or
set BPM alone — `set_tempo()` takes `beats_per_bar` too. It wants `get_tempo()`,
a BPM-only setter, and a `tempo_changed` signal for the HUD.

This is what #72's "make sure other elements depend on this value and update" is
actually asking for.

Related, minor: `EyeBand._play()` schedules note release on
`get_tree().create_timer()`, in real seconds. A note already sounding when the
tempo changes keeps its original length. Probably right — retiming a note
mid-flight is worse — but it should be a choice, not an accident.

**Safety rail.** ±2 and ±10 bpm unbounded reaches zero and goes negative, and
`MusicClock.seconds_per_beat()` is `60.0 / tempo_bpm`. Clamp the control (the
songs live at 60–74 bpm; something like 30–180 gives room to play), and guard
`MusicClock` against a non-positive tempo regardless of who calls it.

## 4. #71 is mostly cheap, because voicing already folds into registers

The pleasant surprise. `Chord` is a root pitch class plus intervals, so
`transposed(semitones)` is about four lines. And every voicing method already
keeps itself inside a register: `root_at_or_above()` walks up to the range,
`voice()` folds any tone that would pass `high` down an octave, and
`tones_between()` enumerates only within range.

So transposing the **pitch class** and letting the existing register logic place
the notes keeps bass, pads and arp in their ranges automatically, however far
round the circle the player walks — which is what makes the circle-of-fifths
reading (see Decisions) essentially free. There is no range explosion to defend
against.

**Where the offset lives.** Songs are written as absolute symbols and
`EyeBandSongs` hands out shared `Song` objects; `MelodyWriter` seeds itself from
`(title, section)`, so mutating `key_root` would also invalidate that seed. Keep
`Song` immutable and hold the offset on the band, transposing at read time:
`_walker.chords_at(bar)` → `chord.transposed(offset)`. If #35 ever wires more
than one level, that offset graduates into a shared musical state object; it
does not need to be one yet.

**The melody: transpose, do not rewrite.** `MelodyWriter.write_section()` is
cached per section in `EyeBand._melodies`. Rewriting it in the new key changes
the line's shape and breaks the documented property that a section's melody is
the same every time it comes round. Transposing the cached notes keeps the shape
— and because a scale-correct line transposed is still scale-correct, it also
satisfies #71's "any scales used should adapt to this new root note" **by
construction**, with no threading of the offset into `scale_between()` at all.

One wrinkle: `melody_range` tops out at MIDI 69 (A4, per the songs' own README
note), so a +7 shift pushes to E5. Fold the **whole line** down by a common
octave when it leaves the range, rather than note by note — per-note folding
would turn steps into leaps and change the contour, which is the thing worth
preserving.

**When the shift lands.** Everything else in this system changes on a bar line,
but a bar at 70 bpm is 3.4 s — far too laggy for a control the player is
playing. Since notes fire per step, "applies to every note triggered from the
next step" is effectively immediate (≤0.2 s).

**Pads fade across** (see Decisions), and that has a concrete cost worth
flagging before it is built: `Synth.pick_voice()` steals the **quietest released
voice first**, which is precisely the outgoing pad voicing mid-fade. Pads are
`polyphony = 8`; a `maj9` is five notes, so a fade-across wants ten voices and
would eat its own tail. Either raise pad polyphony (12–16) or reserve the
outgoing voices explicitly. A per-voice fade also wants a release override —
`SynthPatch.release_seconds` is 1.4 s for pads, which may be longer than the
crossfade should be.

## 5. Both tickets need an input layer that does not exist

`project.godot` has **no `[input]` section at all** — the project runs entirely
on Godot's built-in `ui_*` actions. Both tickets need real named actions.

**#72's arrow keys are already taken**, which is why the binding moved (see
Decisions). `KeyboardMotionSource` reads `ui_left`/`ui_right`/`ui_up`/`ui_down`
to synthesise device tilt, which is how a desktop player pushes eyes into the
walls — the level's main control, documented in `scripts/run.sh` as "arrows
tilt". Tempo goes to **WASD on keyboard and the d-pad on a controller**, leaving
tilt exactly as it is. W/S for ±2 bpm, A/D for ±10, matching the ticket's
up/down and left/right. Nothing else in the level uses WASD (`fluid_demo`
binds R, C and B).

**Gamepad specifics for #71.** L1/R1 are `JOY_BUTTON_LEFT_SHOULDER` /
`JOY_BUTTON_RIGHT_SHOULDER`, straightforward. L2/R2 on most modern pads are
**analog axes** (`JOY_AXIS_TRIGGER_LEFT` / `RIGHT`), not buttons: they bind as
`InputEventJoypadMotion` with a deadzone, and "pressed" has to come from the
action's press edge past that deadzone. They need keyboard equivalents too —
the level has no gamepad input at all today, and CI has no pad.

---

## Proposed breakdown

The two tickets share three prerequisites, and almost all of the risk is in the
first two.

**A. Musical position becomes tempo-independent** *(new, prerequisite)*
`MusicTimeSource` reports beats; `MusicClock`, `StepSequencer`,
`LoopLayerScheduler` and `AudioManager` follow; the rebasing in both schedulers
goes away. Tests drive `ScriptedMusicTime` across tempo changes and assert phase
continuity. Fully testable headless.

**B. Drums play live from patterns** *(new, prerequisite — the big one)*
A `DrumKit` one-shot player; `StepPattern.parse()` kept as notation and the
open-hat choke moved to play time; `EyeBand`'s loop/live split collapsed into one
latch. `manual_verification` — the timing change is the whole question and
cannot be heard from a diff. Coordinate with PR #65.

**C. Parts read live musical state, not the `Song`** *(new, prerequisite)*
`EyeBand` note lengths read the clock; `AudioManager` gains `get_tempo()` and
`tempo_changed`; the band gains a key offset with read-time chord transposition
and melody transposition-with-fold; pad crossfade and the polyphony it needs.
No player controls yet — driven directly, so it is testable without input.

**D. Tempo control** *(= #72)*
Input actions (WASD, d-pad), ±2 / ±10, clamp, HUD readout. Small once A–C land.

**E. Key control** *(= #71)*
Input actions (L1/R1/L2/R2 plus keyboard), ±5 / ±7 as pitch classes, HUD
readout. Small once A–C land.

The demo already draws a parts label; D and E extend it to something like
`♪ Glass Tide · A2 · 72 bpm · +5`, which is also how either gets verified by
hand.

## Decisions taken

1. **Arrow keys stay with tilt.** Tempo binds to WASD on keyboard and the d-pad
   on a controller. (§5)
2. **Drums are registered as patterns and played live during gameplay**, not
   rendered into loop layers — accepting mix-block onset timing to begin with,
   with a sample-accurate time source or a streaming mixer held in reserve if it
   sounds loose. (§2)
3. **"Up a 4th" is a pitch-class move round the circle of fifths**, every part
   staying in its own register via the existing voicing fold. Track the offset
   as an unbounded integer for display, apply it `posmod(…, 12)`. (§4)
4. **Pads fade across on a key change** — old voicing out, new one in, rather
   than a hard re-voice or a bar of bitonality. Watch the voice-stealing
   interaction. (§4)

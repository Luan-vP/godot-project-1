# Scoping #71 and #72: playing the music system as an instrument

Both tickets ask for the same new thing: **the player changes the music while it
is playing.** #72 moves the tempo, #71 moves the root note. Neither is possible
against the music system as it stands, for the same underlying reason — musical
state is read once, at `EyeBand.start()`, and baked into places it cannot be
taken back out of.

This is the scope of what has to change, what it costs, and the decisions that
want a human answer before anything is built.

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

## 1. The re-architecture: musical position is derived from wall seconds

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
`MusicClock` and both schedulers are untouched. But `get_seconds()` then no
longer means wall seconds, which sits badly next to `get_lookahead()` — a
genuinely wall-clock quantity — and muddles `ScriptedMusicTime` for tests.

**(b) The port reports beats.** `MusicTimeSource.get_beats()`; `MusicClock`
converts beats → bar/step; wall seconds survive only where audio really needs
them (note hold lengths, mix lookahead). **Recommended.** Position stops having
a tempo scale at all, which means `LoopLayerScheduler.set_clock()` and
`StepSequencer.set_clock()` no longer need to rebase — two subtle methods whose
doc comments are mostly an explanation of the rebase simply go away. A tempo
change becomes a non-event for everything downstream of the port.

Cost: touches `music_time_source.gd`, both adapters, `music_clock.gd`,
`step_sequencer.gd`, `loop_layer_scheduler.gd`, `AudioManager`, and their four
test files. This is the bulk of the work in both tickets and nearly all of the
risk.

It is also testable without ears: drive `ScriptedMusicTime` across a tempo
change and assert that bar/beat phase is continuous, and that no step fires
twice or is skipped.

## 2. Rendered drum loops have a tempo baked into the samples

`StepPattern.render(tempo_bpm, beats_per_bar, rate)` mixes one bar into an
`AudioStreamWAV` exactly `60/bpm × beats_per_bar × rate` samples long. All four
drum layers — `beat`, `ghost`, `shimmer`, `fill` — are rendered once in
`EyeBand.start()`. Change the tempo and the WAV keeps its old length: the drums
run at the old tempo and drift against the live parts, permanently.

This is the direct price of the "rendered, sample-accurate" decision the audio
README argues for, and it is the second thing that has to be answered.

**Option 1 — re-render on every change.** ~26 ms per bar per layer × 4 ≈ 100 ms
of main-thread work per arrow press, a visible hitch. Worse,
`configure_loop_layers()` calls `stop_loops()` and resets every layer's state,
so it restarts the music. Not viable as it stands.

**Option 2 — `pitch_scale` the loop player.** One line:
`_loop_player.pitch_scale = live_bpm / rendered_bpm`. Exact tempo match, no
re-render, no hitch, and because `AudioStreamSynchronized` shares one playback
position, all four layers scale together and stay locked. The cost is that the
drums are pitched with the speed: ±2 bpm on 70 is 2.9% ≈ **half a semitone**,
±10 bpm is 14% ≈ **2.3 semitones**. **Recommended** — the kit is synthesised
noise and short sine sweeps rather than melodic material, only drums live on
that player, and tape-varispeed drums are a defensible sound rather than a
defect. It should be called out as a deliberate choice, and listened to.

**Option 3 — pre-render a ladder of tempos** and crossfade on bar lines.
Memory × N and real complexity. Only worth reaching for if option 2 sounds
wrong.

## 3. Tempo has three sources of truth, and two of them go stale

`EyeBand._on_step()` computes `seconds_per_step := 60.0 / _song.tempo_bpm / 4.0`
— from the **song**, not the clock. Every note hold length (pads, bass, arp,
melody) hangs off it, as does `_loop_layer()`'s render call. After a tempo
change these keep the old value: at half tempo, notes would still be released
at full-tempo durations and the arrangement would thin out; at double tempo
they would overlap and pile up voices.

All of it must read `AudioManager.get_music_clock().seconds_per_step()`.
`Song.tempo_bpm` becomes a *starting* tempo, not the tempo. `AudioManager`
already owns the live value inside `_loop_clock`, but there is no way to read
or set BPM alone — `set_tempo()` takes `beats_per_bar` too. It wants
`get_tempo()`, a BPM-only setter, and a `tempo_changed` signal for the HUD.

This is what #72's "make sure other elements depend on this value and update"
is actually asking for.

Related, minor: `EyeBand._play()` schedules note release on
`get_tree().create_timer()`, in real seconds. A note already sounding when the
tempo changes keeps its original length. Probably correct — retiming a note
mid-flight is worse — but it is a choice, not an accident, and should be one.

## 4. #71 is mostly cheap, because voicing already folds into registers

The pleasant surprise. `Chord` is a root pitch class plus intervals, so
`transposed(semitones)` is about four lines. And every voicing method already
keeps itself inside a register: `root_at_or_above()` walks up to the range,
`voice()` folds any tone that would pass `high` down an octave, and
`tones_between()` enumerates only within range.

So transposing the **pitch class** and letting the existing register logic place
the notes keeps bass, pads and arp in their ranges automatically, however far
round the circle the player walks. There is no range explosion to defend
against. Chords cost almost nothing.

What does need design:

**Where the offset lives.** Songs are written as absolute symbols and
`EyeBandSongs` hands out shared `Song` objects; `MelodyWriter` seeds itself from
`(title, section)`, so mutating `key_root` on the song would also invalidate
that seed. Keep `Song` immutable and hold the offset on the band, transposing at
read time: `_walker.chords_at(bar)` → `chord.transposed(offset)`. If #35 ever
wires more than one level, that offset graduates into a small shared musical
state object; it does not need to be one yet.

**The melody.** `MelodyWriter.write_section()` is cached per section in
`EyeBand._melodies`. Two ways:

- *Rewrite the section in the new key.* The melody changes shape, and the
  documented property that "a section's melody is the same every time that
  section comes round" breaks across a key change.
- *Transpose the cached notes.* The line keeps its shape, and — because a
  scale-correct line transposed is still scale-correct — this also satisfies
  #71's "any scales used should adapt to this new root note" **by construction**,
  with no threading of the offset into `scale_between()` at all.

**Recommended: transpose.** One wrinkle: `melody_range` tops out at MIDI 69
(A4, per the songs' own README note), so a +7 shift pushes to E5. Fold the
**whole line** down by a common octave when it leaves the range, rather than
folding note by note — per-note folding would turn steps into leaps and change
the contour, which is the thing worth preserving.

**When the shift lands.** Everything else in this system changes on a bar line,
but a bar at 70 bpm is 3.4 s — far too laggy for a control the player is
playing. Since notes fire per step, "applies to every note triggered from the
next step" is effectively immediate (≤0.2 s). The exception is pads, held for a
whole chord span: a pad voiced before the shift keeps sounding the old chord
against the new one for up to a bar. Either release and re-voice the pads on the
shift (a small audible bump) or let them ride (up to a bar of bitonality).
**Suggest re-voicing** — but this is an ears decision.

**What "up a 4th" means when you press it twice.** Up a fourth is +5 semitones,
up a fifth is +7, and applied to a pitch class these are the same circle walked
in opposite directions (+5 ≡ −7 mod 12). Taking the pitch-class reading — track
the offset as an unbounded integer for display, apply it `posmod(…, 12)` — is
the only reading that survives repeated presses; a literal pitch shift climbs
until everything is shrill and the registers stop being able to save it. Worth
confirming that matches what the ticket means by "move the root note up a 4th".

## 5. Both tickets need an input layer that does not exist

`project.godot` has **no `[input]` section at all** — the project runs entirely
on Godot's built-in `ui_*` actions. Both tickets need real named actions.

**And #72 has a direct conflict with the level it targets.** `KeyboardMotionSource`
already reads `ui_left`/`ui_right`/`ui_up`/`ui_down` to synthesise device tilt,
which is how a desktop player pushes eyes into the walls — it is the level's
main control, and `scripts/run.sh` documents it as "arrows tilt". #72 asks for
those same four keys.

They cannot both have the arrows. Options: move keyboard tilt to WASD; put
tempo behind a modifier (Shift+arrows); or split them some other way.
**Suggest moving tilt to WASD**: on a phone, tilt comes from the real
accelerometer and `KeyboardMotionSource` is explicitly a desktop development
stand-in, whereas tempo is a real player control that has to work on a desktop.
Moving the stand-in costs nothing. **This one needs a human answer**, because
the conflict is not visible from the ticket text.

**Gamepad specifics for #71.** L1/R1 are `JOY_BUTTON_LEFT_SHOULDER` /
`JOY_BUTTON_RIGHT_SHOULDER`, straightforward. L2/R2 on most modern pads are
**analog axes** (`JOY_AXIS_TRIGGER_LEFT` / `RIGHT`), not buttons: they bind as
`InputEventJoypadMotion` with a deadzone, and "pressed" has to come from the
action's press edge past that deadzone. They also need keyboard equivalents —
the level has no gamepad input today at all, and CI has no pad.

**Safety rail for #72.** ±2 and ±10 bpm unbounded reaches zero and goes negative,
and `MusicClock.seconds_per_beat()` is `60.0 / tempo_bpm`. Clamp the control
(the songs live at 60–74 bpm; something like 30–180 gives room to play), and
guard `MusicClock` against a non-positive tempo regardless of who calls it.

---

## Proposed breakdown

The two tickets share a prerequisite, and almost all of the risk is in it.

**A. Musical position becomes tempo-independent** *(new, prerequisite)*
`MusicTimeSource` reports beats; `MusicClock`, `StepSequencer`,
`LoopLayerScheduler` and `AudioManager` follow; the rebasing in both schedulers
goes away. Tests drive `ScriptedMusicTime` across tempo changes and assert
phase continuity and that no step is doubled or dropped. Largest piece; fully
testable headless.

**B. Parts read live musical state, not the `Song`** *(new, prerequisite)*
`EyeBand` note lengths read the clock; `AudioManager` gains `get_tempo()` and
`tempo_changed`; the loop player gets its `pitch_scale` follow; the band gains a
key offset with read-time chord transposition and melody transposition-with-fold.
No player controls yet — driven directly, so it is testable without input.

**C. Tempo control** *(= #72)*
Input actions, ±2 / ±10, clamp, HUD readout. Small once A and B land.

**D. Key control** *(= #71)*
Input actions, ±5 / ±7, pad re-voicing policy, HUD readout. Small once A and B
land.

The demo already draws a parts label; C and D extend it to something like
`♪ Glass Tide · A2 · 72 bpm · +5`, which is also how either gets verified by
hand.

## Decisions wanted before building

1. **The arrow keys.** Tempo takes them and keyboard tilt moves to WASD, or
   something else? (§5)
2. **Pitched drums.** Is `pitch_scale` on the drum loops an acceptable sound at
   ±10 bpm (≈2.3 semitones), or is this worth the tempo ladder? (§2)
3. **"Up a 4th"** — a pitch-class move round the circle, keeping every part in
   its register, or a literal upward pitch shift? (§4)
4. **Pads on a key change** — re-voice immediately with a small bump, or let the
   held chord ride out against the new key? (§4)

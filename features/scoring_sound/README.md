# Scoring sound

Turns a scoring contact into sound (`#33`), shaped by where the floater sits
along its edge — the one continuous, per-floater, musically meaningful
quantity the game produces (`#30`). This is the first consumer of
[`EventBus.scoring_updated`](../../autoload/EventBus.gd); the scorer that
publishes it (`#26`) is separate and this feature does not depend on it being
built yet — see [`ScoringSnapshot`](../../core/scoring/scoring_snapshot.gd)
and [`tests/test_event_bus_scoring.gd`](../../tests/test_event_bus_scoring.gd)
for the contract this reacts to.

## Pieces

| Script | What it is |
| --- | --- |
| [`contact_sound.gd`](contact_sound.gd) | `ContactSound` — the whole feature: listens for scoring updates, starts/holds/releases a voice per contact. |
| [`contact_pitch.gd`](contact_pitch.gd) | `ContactPitch` — pure position-to-hertz mapping, checkable with no scene tree. |
| [`contact_sound_demo.gd`](contact_sound_demo.gd), `.tscn` | Manual proof: simulated floaters, played from the keyboard. |

```gdscript
var contact_sound := ContactSound.new()
add_child(contact_sound)
# From here on, EventBus.scoring_updated drives it. Nothing else to wire up.
```

`voice_cap`, `root_hz`, `span_semitones`, `pitch_retention_per_second` and
`patch` are all exported, so a level or a composition rule (`#34`) can retune
the instrument without touching this script.

## Continuous pitch, not a quantised scale

The issue asks this to be decided and written down, since neither answer is
obviously right:

- **Continuous** (chosen). Position maps straight to hertz
  ([`ContactPitch.hz_for_position`](contact_pitch.gd)), linear in semitones so
  it reads as even pitch motion rather than crowding into one end of the
  range. A held contact glissandos as its floater drifts.
- **Quantised to a scale** (not chosen). Position would snap to the nearest
  step. Rejected for two reasons:
  1. **It fights the medium.** `ScoringSnapshot`'s own docs are explicit that
     position drift is "musically meaningful" and publishing it every tick
     rather than throttling it is deliberate, so a consumer does not turn
     continuous drift into a staircase. Quantising the *pitch* mapping would
     reintroduce exactly the staircase the snapshot's publish cadence was
     designed to avoid — just one step later in the pipeline.
  2. **Chattering near a step boundary.** The issue names this directly: a
     floater sitting near a scale step, with the medium always drifting,
     would flicker between two adjacent notes. A [`ParameterFader`](../../core/audio/parameter_fader.gd)
     smooths that motion but cannot remove a boundary crossing — quantising
     after smoothing still snaps, and quantising before smoothing still
     chatters into the fader.
  3. **It matches what's already built.** `#28`'s hybrid decision pairs
     continuous synth tones (`SynthVoice`, built around glide, not steps) with
     metric loops. A contact is the continuous half of that pair: one floater,
     one drifting number, not a note-by-note performance on a grid. Sitting
     this feature on the continuous side means the pitch and the machinery
     playing it agree with each other; nothing here fights `SynthVoice`'s own
     glide semantics or needs a scale-quantiser class that does not otherwise
     exist in the codebase.

The trade-off is real and worth naming: continuous pitch can read as
"unfinished" or "out of tune" next to a metric palette, since it never lands
on a stable scale step the way the loops and drum grid (`core/audio`'s step
grid) do. That is accepted here because a contact is reporting a continuously
drifting quantity, not performing a note — see the acceptance criteria's own
framing of position as "the one continuous, per-floater, musically meaningful
quantity the game produces". If a later pass (`#34`) wants contacts to feel
more integrated with a metric section, quantising is a small, local change:
[`ContactPitch.hz_for_position`](contact_pitch.gd) is the only place pitch
gets computed from position, and it is pure and independently tested.

## New versus continuing, and the voice cap

A contact's identity is [`ScoringContact.key`](../../core/scoring/scoring_contact.gd) —
the same floater staying on the same edge. `ContactSound` diffs each
snapshot against the previous one
([`new_contacts`](../../core/scoring/scoring_snapshot.gd) /
`ended_keys`) rather than reacting to every publish: a new key starts a
voice, a persisting key only has its pitch nudged, an absent key releases.
Nothing here retriggers a held contact — see `ContactSound`'s class doc for
why keying off anything else (position, arrival order) would.

Voices are capped at `voice_cap` (default 4). Past it, a new contact stays
silent until a slot frees, rather than stealing one already sounding — the
opposite of `Synth`'s own note-stealing, which exists for interactive,
one-note-at-a-time playing and would otherwise cut a contact that is already
mid-scoring to make room for one that just arrived. `ContactSound` enforces
the cap itself before ever asking `Synth` for a voice, so `Synth`'s stealing
logic is never exercised here at all.

## Parameter changes go through the fader

A contact's position changes on (at least) every scoring tick. Each held
contact gets its own [`ParameterFader`](../../core/audio/parameter_fader.gd),
and only the fader's smoothed output ever reaches
[`SynthVoice.set_frequency`](../../core/audio/synth_voice.gd) — this is the
same problem, and the same fix, `#32` exists for: a per-frame value assigned
straight to a synthesis parameter zippers, because the value changes once a
tick while audio mixes in much finer blocks. The contact's patch
(`ContactSound._default_patch`) deliberately sets `glide_seconds` to zero, so
there is exactly one place smoothing happens; layering `SynthVoice`'s own
glide on top of an already-smoothed value would just blur it further for no
benefit.

## Loudness

Voices sum on the bus, the same as any `Synth` pool — see its docs. Nothing
here scales a voice's level by how many contacts are active: loudness is
bounded by keeping `voice_cap` low and each voice's `SynthPatch.level` quiet
(0.12, four voices), not by attenuating per-voice level as a side effect of
activity, which would still let enough simultaneous contacts clip and would
make level depend on something unrelated to the player's volume setting.

## Manual verification

Labelled `manual_verification`: a diff cannot review a sound design decision.
`scripts/run.sh contacts` opens [`contact_sound_demo.tscn`](contact_sound_demo.tscn) —
hold keys 1-6 to hear pitch follow a drifting position, hold a held key
through several seconds of drift to confirm it glissandos rather than
retriggering, hold a 5th and 6th to hear the cap, and press Space for a burst
that flickers every simulated floater to confirm busy moments stay quiet and
uncluttered rather than turning into a machine gun.

This environment has no audio device and cannot run the Godot editor, so no
recording is included in this change — that step is still owed, by a human,
against the acceptance criteria above.

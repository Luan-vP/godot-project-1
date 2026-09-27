# Scoping #90: the boids level's rhythm interaction

Ticket #90 asks for birds with modelled flocking behaviour that "play with 3 and
4 counter rhythms", where "when a bird snaps to a group it matches the group
rhythm. Its voice stays the same."

This document records the decisions from a design interview about the rhythm
interaction specifically: what the player does, how their input is read, and how
it acts on the flocks. It does not cover the boids simulation itself beyond the
hooks the rhythm needs.

---

## Summary

- **A sandbox instrument.** No win state. The player is a percussionist playing
  against a sky of flocks.
- **Flocks play polyrhythms.** Every flock plays N even pulses over a shared bar.
  N comes from a table (3, 4, 6 now; 5, 7 later).
- **Loners are silent.** A bird sounds only while it belongs to a flock; it takes
  the flock's rhythm and keeps its own voice.
- **The player's only input is a snare.** Each tap is read as a fit against every
  rhythm. The fit continuously shifts which flocks are attractive; sustained,
  unambiguous playing of one rhythm eventually scatters every other flock.
- **Full scatters are rare events** — the climax, not the everyday effect.

---

## 1. Rhythms are polyrhythms on a shared bar

A rhythm of order N places N evenly spaced pulses in one bar. Every flock shares
the same bar and downbeat, so a 3-flock and a 4-flock line up on the 1 and play
3-against-4 inside it:

```
12-step bar:  0 1 2 3 4 5 6 7 8 9 10 11
N = 3:        X . . . X . . . X . .  .
N = 4:        X . . X . . X . . X .  .
N = 6:        X . X . X . X . X . X  .
```

This is a polyrhythm (same cycle, different pulse rate), not a polymeter (same
pulse, different cycle length). Flocks do not need motifs; a pulse is enough.

### Rhythms are data, not code

The set of supported rhythms is a table, so adding 5 or 7 is a table entry:

| Field | Meaning |
| --- | --- |
| `pulses` | N, the number of even pulses per bar |
| `spawn_weight` | Base weight when a new flock rolls its rhythm (§4) |
| (visual/audio tuning) | Colour tint, pulse envelope, etc. |

Nothing in the level may special-case 3 or 4.

### The bar is an LCM grid

The bar is divided into `LCM(all pulses in the table)` steps, and pulse `k` of
rhythm N falls on step `k * grid / N`. The grid size is derived from the table,
never written by hand:

| Rhythms in the table | Steps per bar |
| --- | --- |
| 3, 4, 6 | 12 |
| + 5 | 60 |
| + 7 | 420 |

Taps are quantised to this grid for scoring and for the ghost echo (§3).

**Against the music system.** `MusicClock.steps_per_bar()` is
`beats_per_bar * steps_per_beat`, so a 12-step bar in 4/4 is
`steps_per_beat = 3`, and 60 is `15`. At 420 steps per bar, `StepClock` would
emit a signal per step (≈210/s at 120 bpm); the level should instead ask for
"next pulse of rhythm N" as a step index and schedule against that, rather than
listening to every step. Worth deciding when 7 is actually added, not before.

---

## 2. Birds, flocks and sound

- **Loners are silent.**
- **Snapping to a flock** sets the bird's rhythm to the flock's. The bird's
  voice (timbre/pitch) is its own and never changes.
- **Flocking forces pulse.** Cohesion and alignment surge on each of the flock's
  pulses, so a 3-flock visibly breathes three times a bar and a 4-flock four.
  Movement is the visual expression of rhythm; there is no separate wingbeat
  animation requirement.

---

## 3. The snare

The snare is the player's only input.

**Sound: instant plus ghost.** The snare plays the moment the button is pressed,
so there is no felt latency and timing errors are audible. A quieter ghost
echo then lands on the grid step the tap was read as, telling the player how the
game heard them.

### Reading taps: two-way least squares over the last bar

After every tap, the taps in the trailing one-bar window are scored against each
rhythm in the table. Positions are bar phases, compared on the circle (distance
wraps around the bar line).

For a rhythm with pulse set `P` and taps `T`:

```
tap_to_pulse  = mean over t in T of  min over p in P of  d(t, p)^2
pulse_to_tap  = mean over p in P of  min over t in T of  d(p, t)^2
error(N)      = tap_to_pulse + pulse_to_tap
fit(N)        = a decreasing function of error(N), e.g. 1 / (1 + k * error)
```

It is two-way because of nesting. Rhythm 3's pulses are a subset of 6's, and
the downbeat is in every rhythm. With a one-way (tap → pulse) error, tapping a
clean 3 fits 6 perfectly too. The pulse → tap term penalises the pulses of 6
that were never tapped, so a 3 reads as 3 and a 6 only reads as 6 when all six
are played.

The rolling window re-scores on every tap, so the reading responds immediately.
The guards in §5 keep that responsiveness from turning into premature scatters.

---

## 4. Everyday effect: attraction shifts

Below the scatter threshold, the fit scores continuously weight the flocking
forces per rhythm:

- Flocks whose rhythm fits the player's recent playing **tighten** (cohesion ↑)
  and **pull nearby loners in**.
- Flocks whose rhythm fits poorly **loosen** and drift, making them likelier to
  lose birds naturally through the boids simulation.

This is how the player plays the sky most of the time: steering which rhythms
are gathering and which are fraying, without anything bursting.

When no taps are in the window, weights relax back to neutral.

### New flocks roll a random rhythm

When silent loners clump into a new flock, it rolls its rhythm from the table's
`spawn_weight`s. **Recent tapping biases the roll toward rhythms not currently on
screen.** If the player has been tapping a 6 and no 6-flock exists, 6 becomes
likelier to be born. A rhythm already present gets no boost, so tapping becomes a
way to summon new rhythms, not just reinforce existing ones.

---

## 5. Rare effect: the full scatter

A full scatter makes **every flock whose rhythm is not the winner** burst apart.
Its birds go silent and become loners, which will later re-clump into new
flocks with freshly rolled rhythms.

Because it clears the sky down to one rhythm, it must be rare and deliberate.
Two mechanisms gate it together:

### Charge

A charge meter fills while the player keeps playing one rhythm unambiguously,
and drains otherwise. On each re-score:

- The **winner** is the rhythm with the best fit.
- It counts as unambiguous only if:
  - the window holds at least `min(pulses)` taps, so one or two taps can't
    decide anything and small N doesn't win by default; and
  - the winner's fit clears an absolute threshold; and
  - it beats the second-best fit by a margin.
- Unambiguous and the same winner as last time → charge rises.
- Ambiguous, or a different winner → charge drains (a change of winner may
  reset it outright; to tune).

The scatter fires when the charge is full. The fill rate should be tuned so it
takes several bars (starting point: about 4) of consistent playing.

### Cooldown

After a scatter, the charge is locked for a cooldown (starting point: about 8
bars), so scatters cannot chain. Attraction shifts (§4) keep working during the
cooldown, so the snare never goes dead.

### Feedback

The charge must be perceivable before the scatter fires, or the scatter reads
as random. Exactly how is open (see below), but it should be tied to the
winning rhythm's flocks, e.g. their force pulses growing more pronounced as the
charge builds.

---

## Tuning knobs

| Knob | Starting point |
| --- | --- |
| Scoring window | 1 bar |
| `fit` curve constant `k` | tune by ear |
| Absolute fit threshold | tune |
| Winner margin over second best | tune |
| Minimum taps in window | `min(pulses)` |
| Charge fill time | ~4 bars of consistent playing |
| Charge drain rate / reset-on-change | tune |
| Cooldown after scatter | ~8 bars |
| Attraction weight range | tune |
| Unseen-rhythm spawn bias | tune |

---

## Testable without ears

The rhythm model is pure data and arithmetic and should be tested headless,
without the boids simulation:

- The LCM grid size is derived from the table (12, 60, 420).
- Pulse steps for each N are correct on the grid.
- Two-way fit: a clean 3 scores 3 above 6; a clean 6 scores 6 above 3. A lone
  downbeat slightly favours the smallest N (fewer unmatched pulses), so it
  must be the minimum-taps guard that stops it counting, not the fit.
- Circular distance wraps across the bar line.
- Charge rises only on consecutive unambiguous wins, drains otherwise, fires
  once when full, and is locked for the cooldown.
- The spawn roll boosts off-screen rhythms and not on-screen ones (seeded RNG).

`ScriptedMusicTime` can drive tap timestamps deterministically.

---

## First-try answers to what was left open

The level is built (`features/levels/boids/`, see its README); these were
decided for it, to be revisited by ear:

- **Snare button:** `B`, on the keyboard and the gamepad (the Deck's B).
- **Tempo:** the #72 control is global, in every scene (`TempoControl`
  autoload): ↑/↓ ±2 bpm, ←/→ ±10, d-pad too, clamped to 30-180. Keyboard
  tilt in the tank levels moved from the arrows to WASD to make room.
  Rendered drum loops (the eye band's) follow a tempo change by playing
  faster or slower, pitch and all.
- **Clumping:** four or more loners within 60 px of each other for 1.5 s
  form a flock. Every flock sounds, whatever its size; one down to a single
  bird dissolves.
- **Flock caps:** at most five flocks, of at most fourteen birds. Same-rhythm
  flocks that meet merge.
- **Charge feedback:** an arc round the rhythm dial, in the winning rhythm's
  colour; flocks that would be scattered tremble as it builds, and flocks
  that would survive glow.
- **Voices:** a note from D major pentatonic over two octaves and a timbre
  (sine, square or saw) per bird, for life. A few members sing on each
  pulse, in turn.
- **Everyday weights:** fit maps to a weight from 0.7 (out of favour) to 1.6
  (in favour), easing rather than jumping. It is scaled back towards neutral
  until the window holds enough taps. The first try used 0.45 at the low
  end; a headless balance run showed that alone turned the whole sky into
  the favoured rhythm within half a minute, which made the scatter pointless.
- **Latency:** no calibration step yet; `tap_offset_seconds` on the level is
  the hook for one.

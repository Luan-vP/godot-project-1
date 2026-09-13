class_name SynthPatch
extends Resource
## What a [SynthVoice] sounds like: its waveform, envelope, level and glide.
## Data, so a level or a composition rule picks a patch rather than a script
## hardcoding one.

@export var waveform: SynthWavetable.Waveform = SynthWavetable.Waveform.SINE

## Seconds from silence to full level on note on. Clamped to at least
## [constant SynthVoice.MIN_ENVELOPE_SECONDS], since an instant start clicks.
@export_range(0.0, 10.0, 0.001, "or_greater") var attack_seconds: float = 0.01

## Seconds from full level to silence on note off. Clamped the same way.
@export_range(0.0, 10.0, 0.001, "or_greater") var release_seconds: float = 0.3

## Linear output level at full envelope, 0..1. Keep it well below 1: voices
## sum. Eight saw voices at 0.25 (and velocity 0.8) peaked at 0.97 on the bus,
## a hair under clipping, so the default leaves room for a full pool.
@export_range(0.0, 1.0, 0.01) var level: float = 0.15

## Seconds a held note takes to glide to a new pitch. Zero jumps straight there.
@export_range(0.0, 5.0, 0.001, "or_greater") var glide_seconds: float = 0.08

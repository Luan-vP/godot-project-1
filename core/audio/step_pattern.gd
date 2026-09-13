class_name StepPattern
extends Resource
## One bar of drums on a step grid, rendered into a looping stream with every
## hit at its exact sample position.
##
## This is how drums stay tight. Triggering hits from script lands each one
## on an audio mix-block boundary: 16ths at 120 bpm measured 17.7 ms of
## spread from frame triggers and 10.3 ms at best. Rendered here, the spread is
## zero by construction. Play the result as a [LoopLayer] and it runs on the
## same shared playback clock as every other loop, and swapping patterns is
## toggling layers on a bar boundary.
##
## [codeblock]
## var pattern := StepPattern.parse({
##     "kick":  "9.......9.......",
##     "snare": "....9.......9...",
##     "hat":   "5.3.5.3.5.3.5.3.",
## })
## var layer := LoopLayer.new()
## layer.layer_name = "drums"
## layer.stream = pattern.render(96.0, 4, 48000)
## [/codeblock]

## Fade applied where a closed hat cuts an open hat off, so the choke does not
## click.
const CHOKE_FADE_SECONDS := 0.005

## Grid steps in the bar. 16 is sixteenth notes in 4/4.
@export var steps: int = 16

## [enum DrumSynth.Hit] -> velocity per step, 0 for a rest.
@export var tracks: Dictionary = {}


## Build a pattern from text, one string per hit: [code].[/code] or
## [code]-[/code] is a rest, [code]1[/code]-[code]9[/code] a hit at that
## velocity out of 9, [code]x[/code] full velocity. Hit names are those
## [method DrumSynth.hit_from_name] accepts. The longest string sets the step
## count.
static func parse(lines: Dictionary) -> StepPattern:
	var pattern := StepPattern.new()
	var longest := 0
	for hit_name in lines:
		longest = maxi(longest, String(lines[hit_name]).length())
	pattern.steps = maxi(longest, 1)
	for hit_name in lines:
		var hit := DrumSynth.hit_from_name(hit_name)
		if hit < 0:
			push_warning("StepPattern: unknown hit '%s'" % hit_name)
			continue
		var text := String(lines[hit_name])
		var velocities := PackedFloat32Array()
		velocities.resize(pattern.steps)
		for i in text.length():
			velocities[i] = velocity_from_char(text[i])
		pattern.tracks[hit] = velocities
	return pattern


static func velocity_from_char(character: String) -> float:
	if character == "x" or character == "X":
		return 1.0
	if character.is_valid_int() and character != "0":
		return character.to_int() / 9.0
	return 0.0


## Velocity of [param hit] at [param step], 0 when it does not play there.
func velocity(hit: int, step: int) -> float:
	var track: PackedFloat32Array = tracks.get(hit, PackedFloat32Array())
	return track[step] if step >= 0 and step < track.size() else 0.0


## Sample offset where [param step] starts in a bar [param bar_samples] long.
## Rounded per step from the bar start, not accumulated, so rounding never
## builds up across the bar.
static func step_offset(step: int, step_count: int, bar_samples: int) -> int:
	return int(round(float(step) * bar_samples / step_count))


## Length of one bar in whole samples.
static func bar_length(tempo_bpm: float, beats_per_bar: int, sample_rate: int) -> int:
	return int(round(60.0 / tempo_bpm * beats_per_bar * sample_rate))


## Mix the bar into a buffer exactly one bar long. A tail that runs past the
## end wraps to the start, so an open hat on the last step rings into the
## downbeat when the bar loops, just as it would live. An open hat stops at the
## next closed hat, the way a drum machine chokes it.
func mix(tempo_bpm: float, beats_per_bar: int, sample_rate: int) -> PackedFloat32Array:
	var bar_samples := bar_length(tempo_bpm, beats_per_bar, sample_rate)
	var out := PackedFloat32Array()
	out.resize(bar_samples)
	var fade := maxi(int(CHOKE_FADE_SECONDS * sample_rate), 1)
	for hit in tracks:
		var sound := DrumSynth.render(hit, sample_rate)
		for step in steps:
			var level := velocity(hit, step)
			if level <= 0.0:
				continue
			var start := step_offset(step, steps, bar_samples)
			var length := sound.size()
			if hit == DrumSynth.Hit.OPEN_HAT:
				length = mini(length, _samples_until_choke(step, bar_samples))
			for i in length:
				var gain := level
				if length < sound.size() and i >= length - fade:
					gain *= float(length - i) / fade
				out[(start + i) % bar_samples] += sound[i] * gain
	for i in out.size():
		out[i] = soft_clip(out[i])
	return out


## [method mix], as a mono 16-bit stream that loops exactly one bar.
func render(tempo_bpm: float, beats_per_bar: int, sample_rate: int) -> AudioStreamWAV:
	var samples := mix(tempo_bpm, beats_per_bar, sample_rate)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream


## Leaves anything within ±0.8 untouched and eases louder peaks towards 1, so
## hits that stack up round off instead of wrapping around.
static func soft_clip(x: float) -> float:
	var magnitude := absf(x)
	if magnitude <= 0.8:
		return x
	return signf(x) * (0.8 + 0.2 * tanh((magnitude - 0.8) / 0.2))


func _samples_until_choke(step: int, bar_samples: int) -> int:
	var start := step_offset(step, steps, bar_samples)
	for ahead in range(1, steps + 1):
		var next := (step + ahead) % steps
		if velocity(DrumSynth.Hit.CLOSED_HAT, next) > 0.0:
			var offset := step_offset(next, steps, bar_samples)
			return posmod(offset - start, bar_samples) if next != step else bar_samples
	return bar_samples

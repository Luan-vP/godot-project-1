class_name SynthWavetable
extends RefCounted
## Band-limited single-cycle wavetables for [SynthVoice].
##
## A naive saw or square has harmonics all the way up, and any above the
## output's Nyquist frequency fold back down as inharmonic grit — which gets
## worse the higher the note. So each waveform is built as a set of bands, one
## per octave of played pitch, and each band holds only the harmonics that stay
## below Nyquist at the *top* of its octave. A voice crossfades between the two
## bands around its current pitch.
##
## Every band is one cycle of the same length, so they play phase-locked
## through one [AudioStreamSynchronized] and a crossfade between them is
## seamless. Pitch comes from the player's pitch scale; no per-sample script
## work happens while a note sounds.

enum Waveform { SINE, SAW, SQUARE }

## Samples in one cycle. Enough to hold every harmonic the lowest band needs.
const CYCLE_SAMPLES := 2048

## Rate the cycle is authored at, so one cycle plays at [method base_frequency].
const TABLE_RATE := 48000

## Bottom of the lowest band, in hertz.
const LOWEST_BAND_HZ := 20.0

## Ten octaves: 20 Hz to 20 kHz.
const BAND_COUNT := 10

## Harmonics are kept below this fraction of the output rate, not right up to
## Nyquist, leaving room for the interpolation the resampler does.
const SAFE_NYQUIST_FRACTION := 0.45

## Where in its octave a band starts handing over to the next one up.
const CROSSFADE_START := 0.75

## Fixed output scale, so bands with different harmonic counts sit at the same
## loudness and a crossfade does not pump. Leaves headroom for the Gibbs
## overshoot a band-limited saw or square has.
const TABLE_GAIN := 0.8

static var _cache := {}


## Frequency one cycle plays at with a pitch scale of 1.
static func base_frequency() -> float:
	return float(TABLE_RATE) / float(CYCLE_SAMPLES)


## Highest pitch band [param band] is safe for, in hertz.
static func band_top(band: int) -> float:
	return LOWEST_BAND_HZ * pow(2.0, band + 1)


## How many harmonics band [param band] of [param waveform] may hold at
## [param mix_rate] without any of them passing Nyquist at the band's top.
static func harmonic_limit(waveform: Waveform, band: int, mix_rate: float) -> int:
	if waveform == Waveform.SINE:
		return 1
	var limit := int(floor(SAFE_NYQUIST_FRACTION * mix_rate / band_top(band)))
	return clampi(limit, 1, CYCLE_SAMPLES / 2 - 1)


## Linear weight of each band for a note at [param frequency]. At most two are
## non-zero and they always sum to 1. Within an octave the band is used alone
## until [constant CROSSFADE_START], then eased into the next band up, which
## has fewer harmonics and so is also safe lower down.
static func band_weights(frequency: float, band_count: int = BAND_COUNT) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	weights.resize(band_count)
	var position := log(maxf(frequency, 1.0) / LOWEST_BAND_HZ) / log(2.0)
	position = clampf(position, 0.0, float(band_count - 1))
	var band := mini(int(floor(position)), band_count - 1)
	var handover := smoothstep(CROSSFADE_START, 1.0, position - band)
	if band + 1 >= band_count:
		handover = 0.0
	weights[band] = 1.0 - handover
	if handover > 0.0:
		weights[band + 1] = handover
	return weights


## One cycle of [param waveform] holding its first [param harmonics]
## harmonics, scaled by [constant TABLE_GAIN]. Values in -1..1.
static func build_cycle(waveform: Waveform, harmonics: int) -> PackedFloat32Array:
	return _build_cycles(waveform, [harmonics])[0]


## A looping one-cycle stream per band for [param waveform] at [param
## mix_rate], built once and cached. A sine has one band, since it has no
## harmonics to alias.
static func bands(waveform: Waveform, mix_rate: float) -> Array[AudioStreamWAV]:
	var key := "%d@%d" % [waveform, int(mix_rate)]
	if _cache.has(key):
		return _cache[key]
	var count := 1 if waveform == Waveform.SINE else BAND_COUNT
	var limits: Array[int] = []
	for band in count:
		limits.append(harmonic_limit(waveform, band, mix_rate))
	var streams: Array[AudioStreamWAV] = []
	for cycle in _build_cycles(waveform, limits):
		streams.append(_to_stream(cycle))
	_cache[key] = streams
	return streams


## Builds one cycle per entry of [param limits] in a single additive pass.
## Harmonics are summed from the fundamental upward and the running sum is
## copied out as it reaches each requested limit, so the cost is set by the
## largest limit alone rather than the total across bands.
static func _build_cycles(waveform: Waveform, limits: Array) -> Array[PackedFloat32Array]:
	var sines := PackedFloat32Array()
	sines.resize(CYCLE_SAMPLES)
	for i in CYCLE_SAMPLES:
		sines[i] = sin(TAU * float(i) / float(CYCLE_SAMPLES))

	var highest := 0
	for limit in limits:
		highest = maxi(highest, limit)

	var running := PackedFloat32Array()
	running.resize(CYCLE_SAMPLES)
	var snapshots := {}
	for n in range(1, highest + 1):
		var amplitude := _harmonic_amplitude(waveform, n)
		if amplitude != 0.0:
			for i in CYCLE_SAMPLES:
				running[i] += sines[(n * i) % CYCLE_SAMPLES] * amplitude
		if limits.has(n):
			snapshots[n] = running.duplicate()

	var cycles: Array[PackedFloat32Array] = []
	for limit in limits:
		cycles.append(snapshots[limit])
	return cycles


static func _harmonic_amplitude(waveform: Waveform, n: int) -> float:
	match waveform:
		Waveform.SAW:
			return TABLE_GAIN * 2.0 / (PI * n)
		Waveform.SQUARE:
			return TABLE_GAIN * 4.0 / (PI * n) if n % 2 == 1 else 0.0
		_:
			return TABLE_GAIN if n == 1 else 0.0


static func _to_stream(cycle: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(cycle.size() * 2)
	for i in cycle.size():
		data.encode_s16(i * 2, int(round(clampf(cycle[i], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TABLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = cycle.size()
	return stream

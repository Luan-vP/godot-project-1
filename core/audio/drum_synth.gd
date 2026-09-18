class_name DrumSynth
extends RefCounted
## Synthesised drum hits in the drum-machine style synthwave leans on, rendered
## once per sample rate and cached. No recorded samples, so there is nothing
## to license.
##
## Each hit is a short mono buffer peaking at [constant HIT_PEAK]. Two things
## play them: [StepPattern] mixes them in at exact sample offsets, which is
## tight but bakes a tempo into the render; [DrumKit] plays them live as
## one-shots instead, for a part whose tempo has to be free to move, at the
## cost of landing on a mix-block boundary rather than the sample — see the
## drums section of core/audio/README.md for the measured cost and why the
## eye band accepts it.
##
## Noise comes from a fixed seed per hit, so a hit is identical every time it
## is built.

enum Hit { KICK, SNARE, CLAP, CLOSED_HAT, OPEN_HAT }

## Every hit is normalised to this peak before velocity, leaving headroom for
## hits that land together.
const HIT_PEAK := 0.7

## The six square-wave partials of the Roland TR-808 cymbal circuit, the metal
## a synthwave hat is made of.
const HAT_PARTIALS_HZ: Array[float] = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]

static var _cache := {}


## Hit names as used in [method StepPattern.parse].
static func hit_from_name(hit_name: String) -> int:
	match hit_name.to_lower():
		"kick":
			return Hit.KICK
		"snare":
			return Hit.SNARE
		"clap":
			return Hit.CLAP
		"hat", "closed_hat":
			return Hit.CLOSED_HAT
		"open_hat", "open":
			return Hit.OPEN_HAT
	return -1


## The rendered buffer for [param hit] at [param sample_rate], built once.
static func render(hit: Hit, sample_rate: int) -> PackedFloat32Array:
	var key := "%d@%d" % [hit, sample_rate]
	if not _cache.has(key):
		_cache[key] = _normalised(_build(hit, float(sample_rate)))
	return _cache[key]


static func _build(hit: Hit, rate: float) -> PackedFloat32Array:
	match hit:
		Hit.KICK:
			return _kick(rate)
		Hit.SNARE:
			return _snare(rate)
		Hit.CLAP:
			return _clap(rate)
		Hit.CLOSED_HAT:
			return _hat(rate, 0.08, 0.018)
		_:
			return _hat(rate, 0.5, 0.14)


## A sine swept from about 150 Hz down to 45 Hz in the first tens of
## milliseconds, with a long body and a tiny noise click on the front.
static func _kick(rate: float) -> PackedFloat32Array:
	var out := _silence(rate, 0.45)
	var rng := _rng(Hit.KICK)
	var phase := 0.0
	for i in out.size():
		var t := i / rate
		var frequency := 45.0 + 105.0 * exp(-t / 0.035)
		phase += TAU * frequency / rate
		var body := sin(phase) * exp(-t / 0.16)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t / 0.002) * 0.25
		out[i] = body + click
	return out


## A tuned body at 185 and 330 Hz under a burst of high-passed noise.
static func _snare(rate: float) -> PackedFloat32Array:
	var out := _silence(rate, 0.3)
	var rng := _rng(Hit.SNARE)
	var high_pass := _one_pole_high_pass(rate, 1200.0)
	var state := [0.0, 0.0]
	for i in out.size():
		var t := i / rate
		var tone := sin(TAU * 185.0 * t) * exp(-t / 0.05) * 0.5
		tone += sin(TAU * 330.0 * t) * exp(-t / 0.03) * 0.2
		var noise := _high_pass_step(rng.randf_range(-1.0, 1.0), high_pass, state)
		out[i] = tone + noise * exp(-t / 0.09) * 0.8
	return out


## Three quick noise bursts ten milliseconds apart and a short tail, band-passed
## around 1.2 kHz — the smeared attack of several hands.
static func _clap(rate: float) -> PackedFloat32Array:
	var out := _silence(rate, 0.35)
	var rng := _rng(Hit.CLAP)
	var band := _band_pass(rate, 1200.0, 1.2)
	var state := [0.0, 0.0, 0.0, 0.0]
	for i in out.size():
		var t := i / rate
		var envelope := 0.0
		for burst in 3:
			var start := burst * 0.01
			if t >= start:
				envelope += exp(-(t - start) / 0.006)
		if t >= 0.03:
			envelope += exp(-(t - 0.03) / 0.12) * 0.6
		out[i] = _biquad_step(rng.randf_range(-1.0, 1.0), band, state) * envelope
	return out


## The 808 cymbal partials, high-passed twice so only the sizzle is left.
static func _hat(rate: float, seconds: float, decay: float) -> PackedFloat32Array:
	var out := _silence(rate, seconds)
	var high_pass := _one_pole_high_pass(rate, 6000.0)
	var first := [0.0, 0.0]
	var second := [0.0, 0.0]
	for i in out.size():
		var t := i / rate
		var metal := 0.0
		for partial in HAT_PARTIALS_HZ:
			metal += 1.0 if fmod(t * partial, 1.0) < 0.5 else -1.0
		var filtered := _high_pass_step(metal / HAT_PARTIALS_HZ.size(), high_pass, first)
		filtered = _high_pass_step(filtered, high_pass, second)
		out[i] = filtered * exp(-t / decay)
	return out


static func _silence(rate: float, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(rate * seconds))
	return out


static func _rng(hit: Hit) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED + hit
	return rng


static func _normalised(buffer: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0
	for sample in buffer:
		peak = maxf(peak, absf(sample))
	if peak > 0.0:
		var scale := HIT_PEAK / peak
		for i in buffer.size():
			buffer[i] *= scale
	return buffer


static func _one_pole_high_pass(rate: float, cutoff: float) -> float:
	var rc := 1.0 / (TAU * cutoff)
	return rc / (rc + 1.0 / rate)


## One high-pass step; [param state] is [previous input, previous output].
static func _high_pass_step(x: float, coefficient: float, state: Array) -> float:
	var y: float = coefficient * (state[1] + x - state[0])
	state[0] = x
	state[1] = y
	return y


## RBJ band-pass (constant peak gain) coefficients: [b0, b1, b2, a1, a2].
static func _band_pass(rate: float, centre: float, q: float) -> Array[float]:
	var w := TAU * centre / rate
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return [alpha / a0, 0.0, -alpha / a0, -2.0 * cos(w) / a0, (1.0 - alpha) / a0]


## One biquad step; [param state] is [x1, x2, y1, y2].
static func _biquad_step(x: float, c: Array[float], state: Array) -> float:
	var y: float = c[0] * x + c[1] * state[0] + c[2] * state[1] - c[3] * state[2] - c[4] * state[3]
	state[1] = state[0]
	state[0] = x
	state[3] = state[2]
	state[2] = y
	return y

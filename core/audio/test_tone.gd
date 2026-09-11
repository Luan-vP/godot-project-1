class_name AudioTestTone
extends RefCounted
## A short procedural sine wave, built at runtime rather than shipped as a
## binary asset.
##
## Its only job is to give the audio foundation something audible to play
## through [AudioManager]: hearing it prove that buses, volume conversion and
## playback are actually wired up, not just declared.


const _MIX_RATE := 44100

## Length of the fade in and out, in seconds. Without one, a tone that starts
## or ends mid-cycle clicks instead of beeping.
const _FADE_SECONDS := 0.02


## Builds a mono 16-bit [AudioStreamWAV] sine wave at [param frequency] Hz,
## [param duration] seconds long, peaking at [param amplitude] (0 to 1).
static func generate(
	frequency: float = 440.0, duration: float = 0.4, amplitude: float = 0.5
) -> AudioStreamWAV:
	var sample_count := maxi(int(_MIX_RATE * duration), 1)
	var fade_samples := maxi(int(_MIX_RATE * _FADE_SECONDS), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var envelope := 1.0
		if i < fade_samples:
			envelope = float(i) / fade_samples
		elif i > sample_count - fade_samples:
			envelope = float(sample_count - i) / fade_samples
		var t := float(i) / _MIX_RATE
		var value := sin(TAU * frequency * t) * amplitude * envelope
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

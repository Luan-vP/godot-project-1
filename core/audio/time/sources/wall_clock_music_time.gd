class_name WallClockMusicTime
extends MusicTimeSource
## Adapter: musical time from a monotonic wall clock started with the music.
##
## Simple and good enough for now, with known wonk. Sound started from script
## only begins at the next audio mix block (about 10 ms), so events triggered
## on this clock land within roughly a block of where they should — that part
## is [member use_mix_lookahead]. What is left after that is the driver's
## fixed output latency between a mix and the sample actually reaching the
## speaker, which read as a steady 16-20 ms lag rather than jitter (#75, #78):
## [member use_output_latency_compensation] folds that into the lookahead too,
## so a step fires that much earlier and lands on the grid instead of behind
## it. Anything that must be sample-accurate regardless of driver, like a
## rendered loop, still belongs in a rendered [StepPattern] instead.
##
## Why not [method AudioStreamPlayer.get_playback_position]: for a looping
## stream it wraps back every loop instead of climbing, so a bar longer than
## the loop would never arrive.

## Report the time to the next audio mix as lookahead, so a step due before
## that block fires this frame instead of the first frame after it. Measured at
## 120 fps, that took sixteenths from 17.7 ms of spread to 10.3 ms.
var use_mix_lookahead := true

## Also report [method AudioServer.get_output_latency] as lookahead, to
## compensate for the driver's fixed mix-to-speaker delay rather than just the
## next-mix-block quantization above. On by default so live parts — drums
## above all — land on the grid rather than a steady step behind it.
var use_output_latency_compensation := true

var _start_usec: int = 0
var _running := false


func start() -> void:
	_start_usec = Time.get_ticks_usec()
	_running = true


func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


func get_seconds() -> float:
	if not _running:
		return 0.0
	return (Time.get_ticks_usec() - _start_usec) / 1_000_000.0


func get_lookahead() -> float:
	if not _running:
		return 0.0
	var lookahead := 0.0
	if use_mix_lookahead:
		lookahead += AudioServer.get_time_to_next_mix()
	if use_output_latency_compensation:
		lookahead += AudioServer.get_output_latency()
	return lookahead


func describe() -> String:
	return "wall clock"

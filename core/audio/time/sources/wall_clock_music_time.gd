class_name WallClockMusicTime
extends MusicTimeSource
## Adapter: musical time from a monotonic wall clock started with the music.
##
## Simple and good enough for now, with known wonk. Sound started from script
## only begins at the next audio mix block (about 10 ms), so events triggered
## on this clock land within roughly a block of where they should, and not
## exactly in phase with a loop playing on the audio thread: measured, live
## notes on sixteenths sat 16-20 ms behind a sample-accurate drum loop, give
## or take 10 ms. Anything that must be tight, like drums, belongs in a
## rendered [StepPattern] instead.
##
## Why not [method AudioStreamPlayer.get_playback_position]: for a looping
## stream it wraps back every loop instead of climbing, so a bar longer than
## the loop would never arrive.

## Report the time to the next audio mix as lookahead, so a step due before
## that block fires this frame instead of the first frame after it. Measured at
## 120 fps, that took sixteenths from 17.7 ms of spread to 10.3 ms.
var use_mix_lookahead := true

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
	return AudioServer.get_time_to_next_mix() if use_mix_lookahead and _running else 0.0


func describe() -> String:
	return "wall clock"

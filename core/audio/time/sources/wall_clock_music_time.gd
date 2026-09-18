class_name WallClockMusicTime
extends MusicTimeSource
## Adapter: musical time from a monotonic wall clock started with the music.
##
## Simple and good enough for now, with known wonk. Sound started from script
## only begins at the next audio mix block (about 10 ms), so events triggered
## on this clock land within roughly a block of where they should, and not
## exactly in phase with a loop playing on the audio thread: measured, live
## notes on sixteenths sat 16-20 ms behind a sample-accurate drum loop, give
## or take 10 ms.
##
## Beats are accumulated as they elapse rather than computed from a running
## seconds total, so a tempo change only affects what comes after it. Scaling a
## total by the current tempo would reinterpret everything already played and
## the music would jump — see [MusicClock] for the measured example.
##
## Why not [method AudioStreamPlayer.get_playback_position]: for a looping
## stream it wraps back every loop instead of climbing, so a bar longer than
## the loop would never arrive.

## Report the time to the next audio mix as lookahead, so a step due before
## that block fires this frame instead of the first frame after it. Measured at
## 120 fps, that took sixteenths from 17.7 ms of spread to 10.3 ms.
var use_mix_lookahead := true

var _beats: float = 0.0
var _tempo_bpm: float = 120.0
var _last_usec: int = 0
var _running := false


func start() -> void:
	_beats = 0.0
	_last_usec = Time.get_ticks_usec()
	_running = true


func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


## Banks what has elapsed at the old tempo before adopting the new one, so the
## beats already played keep the tempo they were played at.
func set_tempo(tempo_bpm: float) -> void:
	_accumulate()
	_tempo_bpm = maxf(tempo_bpm, MusicClock.MIN_TEMPO_BPM)


func get_beats() -> float:
	if not _running:
		return 0.0
	_accumulate()
	return _beats


func get_lookahead() -> float:
	return AudioServer.get_time_to_next_mix() if use_mix_lookahead and _running else 0.0


func describe() -> String:
	return "wall clock"


## Bank the beats elapsed since this was last called, at the tempo in force
## over that stretch. Safe to call as often as anyone likes: it measures the
## real time that has passed, so a second call in the same frame adds nothing.
func _accumulate() -> void:
	if not _running:
		return
	var now := Time.get_ticks_usec()
	var elapsed := (now - _last_usec) / 1_000_000.0
	_last_usec = now
	_beats += elapsed * _tempo_bpm / 60.0

class_name ScriptedMusicTime
extends MusicTimeSource
## Adapter: musical time moved by hand, for tests and replays.
##
## Nothing that reads a real clock is deterministic, so this is what lets bar
## changes and step events be checked exactly, the same role
## [ScriptedLookSource] plays for the camera.

var lookahead: float = 0.0

var _seconds: float = 0.0
var _running := false


func start() -> void:
	_seconds = 0.0
	_running = true


func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


func get_seconds() -> float:
	return _seconds if _running else 0.0


func get_lookahead() -> float:
	return lookahead


func describe() -> String:
	return "scripted"


## Move musical time forward by [param seconds].
func advance(seconds: float) -> void:
	_seconds += seconds


## Jump musical time to [param seconds].
func set_seconds(seconds: float) -> void:
	_seconds = seconds

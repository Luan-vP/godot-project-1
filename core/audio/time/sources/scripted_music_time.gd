class_name ScriptedMusicTime
extends MusicTimeSource
## Adapter: musical time moved by hand, in beats, for tests and replays.
##
## Nothing that reads a real clock is deterministic, so this is what lets bar
## changes and step events be checked exactly, the same role
## [ScriptedLookSource] plays for the camera. A test drives beats directly
## with [method advance] or [method set_beats] — standing in for
## [WallClockMusicTime] integrating wall time against whatever tempo is in
## force, without needing a real clock or a real tempo to do it.

var lookahead: float = 0.0

var _beats: float = 0.0
var _running := false


func start() -> void:
	_beats = 0.0
	_running = true


func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


func get_beats() -> float:
	return _beats if _running else 0.0


func get_lookahead() -> float:
	return lookahead


func describe() -> String:
	return "scripted"


## Move musical time forward by [param beats].
func advance(beats: float) -> void:
	_beats += beats


## Jump musical time to [param beats].
func set_beats(beats: float) -> void:
	_beats = beats

class_name ScriptedMusicTime
extends MusicTimeSource
## Adapter: musical time moved by hand, for tests and replays.
##
## Nothing that reads a real clock is deterministic, so this is what lets bar
## changes and step events be checked exactly, the same role
## [ScriptedLookSource] plays for the camera.
##
## It is driven in beats, which is what the port reports, so a test says
## [code]advance(4.0)[/code] for a bar of 4/4 rather than converting a tempo
## into seconds. Tempo is therefore irrelevant here: a test that wants to check
## a tempo change moves the same beats and asserts nothing moved.

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

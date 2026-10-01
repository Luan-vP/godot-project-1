class_name NativeEyeGazeBackend
extends EyeGazeBackend
## Adapter: the eye-tracking plugin compiled into this build, if there is one.
##
## Every platform's plugin registers the same engine singleton with the same
## four methods — [code]start()[/code], [code]stop()[/code],
## [code]get_sample() -> Dictionary[/code], [code]get_api_version() -> int[/code]
## — so this adapter looks for that singleton by name and never asks which OS
## it is on. A build without the plugin (every desktop build) simply finds
## nothing and reports [constant EyeGazeSample.State.UNAVAILABLE].
##
## Several consumers may want gaze at once — a look camera and a debug overlay,
## say — but there is only one camera. Starts are counted across every
## instance so one consumer stopping does not switch the camera off under
## another.

## The engine singleton every native backend registers.
const SINGLETON_NAME := "EyeGaze"

static var _active_users: int = 0

var _plugin: Object
var _started: bool = false


## Whether this build carries a gaze plugin at all. Not whether it works: the
## plugin answers that itself, through the state it reports.
static func is_present() -> bool:
	return Engine.has_singleton(SINGLETON_NAME)


func _init() -> void:
	if is_present():
		_plugin = Engine.get_singleton(SINGLETON_NAME)


func _notification(what: int) -> void:
	# A consumer that forgets to stop must not leave the camera running. Not
	# via stop(): a script's own methods cannot be called during predelete.
	if what == NOTIFICATION_PREDELETE and _plugin != null and _started:
		_started = false
		_active_users = maxi(_active_users - 1, 0)
		if _active_users == 0:
			_plugin.call("stop")


func start() -> void:
	if _plugin == null or _started:
		return
	_started = true
	_active_users += 1
	if _active_users == 1:
		_plugin.call("start")


func stop() -> void:
	if _plugin == null or not _started:
		return
	_started = false
	_active_users = maxi(_active_users - 1, 0)
	if _active_users == 0:
		_plugin.call("stop")


func poll() -> EyeGazeSample:
	if _plugin == null:
		var missing := EyeGazeSample.new()
		missing.message = "no %s plugin in this build" % SINGLETON_NAME
		return missing
	return EyeGazeSample.from_dictionary(_plugin.call("get_sample"))


func describe() -> String:
	return "device" if _plugin != null else "no plugin"

class_name PrPicker
extends Control
## Lists the repository's open pull requests, and swaps this build for one.
##
## Reached from the demo menu, or opened straight away when the game starts
## with [code]--prs[/code]. Picking a PR runs [code]tools/deck-demo.sh[/code]
## from beside the executable (copied there by scripts/deck-build.sh), which
## fetches and builds that PR on the Deck while this screen shows its progress,
## then ends this process and runs the PR build in its place. When the PR build
## quits, the script starts this build again with [code]--prs[/code], so it
## lands back here.
##
## The script runs in its own process group so Select during a build can stop
## it along with the import and export under it. Leaving the screen any other
## way does not: once the script has started handing over, it is the one
## ending this process, and a cleanup here would take it down too.

const REPO := "Luan-vP/godot-project-1"
const PULLS_URL := "https://api.github.com/repos/" + REPO + "/pulls?state=open&per_page=50"
const LOG_PATH := "user://pr_build.log"
const LOG_LINES := 14

var _http: HTTPRequest
var _status: Label
var _list: VBoxContainer
var _log_view: Label
var _poll: Timer
var _build_pid := -1
var _building := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_pulls_received)
	add_child(_http)
	_poll = Timer.new()
	_poll.wait_time = 0.5
	_poll.timeout.connect(_poll_build)
	add_child(_poll)
	refresh()


## Ask GitHub for the open pull requests again.
func refresh() -> void:
	_http.cancel_request()
	_set_status("Fetching open pull requests...")
	var headers := ["Accept: application/vnd.github+json", "User-Agent: godot-project-1"]
	var error := _http.request(PULLS_URL, headers)
	if error != OK:
		_set_status("Could not start the request (%s)." % error_string(error))


## Whether a PR is being fetched and built behind this screen.
func is_building() -> bool:
	return _building > 0


## Build PR [param number] and hand the screen to it.
func start_build(number: int) -> void:
	if is_building():
		return
	var demo_script := demo_script_path()
	if OS.has_feature("editor") or not FileAccess.file_exists(demo_script):
		_set_status(
			(
				"Swapping builds only works from a build installed on the Deck by "
				+ "scripts/deck-build.sh (no %s)." % demo_script
			)
		)
		return
	var log_path := ProjectSettings.globalize_path(LOG_PATH)
	var pid := OS.create_process(
		"bash", demo_args(demo_script, number, OS.get_process_id(), log_path)
	)
	if pid <= 0:
		_set_status("Could not start %s." % demo_script)
		return
	_build_pid = pid
	_building = number
	_list.hide()
	_log_view.text = ""
	_log_view.show()
	_set_status(
		"Building PR #%d. It takes over the screen when it is ready; Select stops it." % number
	)
	_poll.start()


## Stop the running build, and everything it started, and show the list again.
func cancel_build() -> void:
	if not is_building():
		return
	# Godot starts a child as the leader of a new session, so its pid is also
	# its process group. OS.execute goes through sh, whose kill builtin takes
	# a negative pid for a group but not a "--" before it.
	OS.execute("kill", ["-TERM", "-%d" % _build_pid])
	_end_build("Stopped building PR #%d." % _building)


## The swap script installed beside the running executable.
static func demo_script_path() -> String:
	return OS.get_executable_path().get_base_dir().path_join("tools/deck-demo.sh")


## Arguments for [code]bash[/code] that run the swap script for [param number].
static func demo_args(
	demo_script: String, number: int, pid: int, log_path: String
) -> PackedStringArray:
	return PackedStringArray(
		[demo_script, str(number), "--launcher-pid", str(pid), "--log", log_path]
	)


## The fields the list shows, from GitHub's pulls response.
static func entries_from_json(pulls: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not pulls is Array:
		return entries
	for pull: Variant in pulls:
		if not pull is Dictionary or not pull.has("number"):
			continue
		var head: Dictionary = pull.get("head", {}) if pull.get("head") is Dictionary else {}
		(
			entries
			. append(
				{
					"number": int(pull["number"]),
					"title": str(pull.get("title", "")),
					"branch": str(head.get("ref", "")),
					"draft": bool(pull.get("draft", false)),
					"updated_at": str(pull.get("updated_at", "")),
				}
			)
		)
	return entries


## The line under a PR's title: branch, how long since it changed, and draft.
static func describe(entry: Dictionary, now_unix: int) -> String:
	var parts: Array[String] = [entry["branch"]]
	var updated := str(entry["updated_at"]).trim_suffix("Z")
	if not updated.is_empty():
		var seconds := now_unix - Time.get_unix_time_from_datetime_string(updated)
		parts.append("updated %s" % ago(seconds))
	if entry["draft"]:
		parts.append("draft")
	return " · ".join(parts)


## [param seconds] as a short "3h ago".
static func ago(seconds: int) -> String:
	if seconds < 60:
		return "just now"
	if seconds < 3600:
		return "%dm ago" % (seconds / 60)
	if seconds < 86400:
		return "%dh ago" % (seconds / 3600)
	return "%dd ago" % (seconds / 86400)


## The last [param count] lines of [param text], without trailing blank ones.
static func tail(text: String, count: int) -> String:
	var lines := text.strip_edges(false, true).split("\n")
	return "\n".join(lines.slice(maxi(lines.size() - count, 0)))


## Ahead of the demo menu, which would otherwise take Select to mean "leave".
func _input(event: InputEvent) -> void:
	if is_building() and DemoMenu._is_back(event):
		get_viewport().set_input_as_handled()
		cancel_build()


func _unhandled_input(event: InputEvent) -> void:
	if is_building():
		return
	var key := event as InputEventKey
	var button := event as InputEventJoypadButton
	var wants_refresh := (
		(key != null and key.pressed and not key.echo and key.keycode == KEY_R)
		or (button != null and button.pressed and button.button_index == JOY_BUTTON_Y)
	)
	if wants_refresh:
		get_viewport().set_input_as_handled()
		refresh()


func _on_pulls_received(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("Could not reach GitHub (result %d). R or Y tries again." % result)
		return
	if code != 200:
		_set_status("GitHub answered %d. R or Y tries again." % code)
		return
	var entries := entries_from_json(JSON.parse_string(body.get_string_from_utf8()))
	# Out of the list now, not at the end of the frame, so the first card
	# focused below is a new one.
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var now := int(Time.get_unix_time_from_system())
	for entry in entries:
		_list.add_child(_card(entry, now))
	if entries.is_empty():
		_set_status("No open pull requests.")
		return
	_set_status("%d open. Pick one to build and play it; R or Y refreshes." % entries.size())
	(_list.get_child(0) as Control).grab_focus.call_deferred()


func _poll_build() -> void:
	_log_view.text = tail(FileAccess.get_file_as_string(LOG_PATH), LOG_LINES)
	# Still here after the script ended means it never handed over.
	if not OS.is_process_running(_build_pid):
		_end_build("Building PR #%d failed; the log is above. Pick one to try again." % _building)
		_log_view.show()


func _end_build(message: String) -> void:
	_poll.stop()
	_build_pid = -1
	_building = 0
	_log_view.hide()
	_list.show()
	_set_status(message)
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Control).grab_focus.call_deferred()


func _set_status(text: String) -> void:
	_status.text = text


func _build() -> void:
	var background := ColorRect.new()
	background.color = DemoMenu.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	column.add_child(DemoMenu._label("Pull requests", 40, DemoMenu.TEXT))
	column.add_child(DemoMenu._label(_running_build(), 14, DemoMenu.MUTED))
	_status = DemoMenu._label("", 16, DemoMenu.TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	content.add_child(_list)

	_log_view = DemoMenu._label("", 13, DemoMenu.MUTED)
	_log_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_view.hide()
	content.add_child(_log_view)


func _card(entry: Dictionary, now_unix: int) -> Button:
	var button := Button.new()
	button.name = "PR%d" % entry["number"]
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(start_build.bind(entry["number"]))

	var text := VBoxContainer.new()
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 16.0
	text.offset_right = -16.0
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := DemoMenu._label("#%d  %s" % [entry["number"], entry["title"]], 20, DemoMenu.TEXT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	text.add_child(DemoMenu._label(describe(entry, now_unix), 14, DemoMenu.MUTED))
	button.add_child(text)
	return button


## Which install this is, from the BUILD file deck-build.sh writes beside it.
static func _running_build() -> String:
	var dir := OS.get_executable_path().get_base_dir()
	var build := FileAccess.get_file_as_string(dir.path_join("BUILD")).strip_edges()
	if build.is_empty():
		return "Running from %s" % dir
	return "Running %s: %s" % [dir.get_file(), build]

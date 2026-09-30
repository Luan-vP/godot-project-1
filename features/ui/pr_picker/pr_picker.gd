class_name PrPicker
extends Control
## Lists the repository's open pull requests, and swaps this build for one,
## or merges one in place.
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
##
## Holding [constant MERGE_KEY] ([kbd]M[/kbd]) or [constant MERGE_BUTTON]
## ([kbd]X[/kbd]) on a focused card for [constant MERGE_HOLD_SECONDS] runs
## [code]tools/deck-merge.sh[/code], which squash-merges it with `gh` — see
## that script for what it needs on the Deck. Held on the wrong card, or let
## go early, the hold resets rather than merging early or merging the wrong
## one.

const REPO := "Luan-vP/godot-project-1"
const PULLS_URL := "https://api.github.com/repos/" + REPO + "/pulls?state=open&per_page=50"
const LOG_PATH := "user://pr_build.log"
const LOG_LINES := 14

const MERGE_LOG_PATH := "user://pr_merge.log"
const MERGE_HOLD_SECONDS := 1.5
const MERGE_KEY := KEY_M
const MERGE_BUTTON := JOY_BUTTON_X

var _http: HTTPRequest
var _status: Label
var _list: VBoxContainer
var _log_view: Label
var _poll: Timer
var _build_pid := -1
var _building := 0

var _merge_poll: Timer
var _merge_pid := -1
var _merging := 0
var _merge_bars := {}
var _merge_hold_number := -1
var _merge_hold_elapsed := 0.0


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
	_merge_poll = Timer.new()
	_merge_poll.wait_time = 0.5
	_merge_poll.timeout.connect(_poll_merge)
	add_child(_merge_poll)
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


## Whether a PR is being merged.
func is_merging() -> bool:
	return _merging > 0


## Build PR [param number] and hand the screen to it.
func start_build(number: int) -> void:
	if is_building() or is_merging():
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


## Squash-merge PR [param number], holding the list up until it is done.
func start_merge(number: int) -> void:
	if is_building() or is_merging():
		return
	var merge_script := merge_script_path()
	if OS.has_feature("editor") or not FileAccess.file_exists(merge_script):
		_set_status("Merging only works from a build installed on the Deck (no %s)." % merge_script)
		return
	var log_path := ProjectSettings.globalize_path(MERGE_LOG_PATH)
	var pid := OS.create_process("bash", merge_args(merge_script, number, log_path))
	if pid <= 0:
		_set_status("Could not start %s." % merge_script)
		return
	_merge_pid = pid
	_merging = number
	_set_status("Merging PR #%d..." % number)
	_merge_poll.start()


## The merge script installed beside the running executable.
static func merge_script_path() -> String:
	return OS.get_executable_path().get_base_dir().path_join("tools/deck-merge.sh")


## Arguments for [code]bash[/code] that run the merge script for [param number].
static func merge_args(merge_script: String, number: int, log_path: String) -> PackedStringArray:
	return PackedStringArray([merge_script, str(number), "--log", log_path])


## Whether [param log_text] ends with the marker [code]deck-merge.sh[/code]
## writes after a successful merge — the only way to tell a spawned process's
## outcome apart from a failure, since its exit code isn't otherwise visible.
static func merge_succeeded(log_text: String) -> bool:
	return log_text.strip_edges(false, true).ends_with("MERGED")


## [param control]'s pull request number, from a card's own name (see
## [method _card]), or -1 for anything else — including no focus at all.
static func pr_number_from_name(control_name: String) -> int:
	if not control_name.begins_with("PR"):
		return -1
	var digits := control_name.substr(2)
	return int(digits) if digits.is_valid_int() else -1


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
	if is_building() or is_merging():
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


## Tracks the merge hold each frame, since [Button] has no "held" signal:
## whether [constant MERGE_KEY] or [constant MERGE_BUTTON] is down, and
## whether it has been down on the same card the whole time, are both only
## answerable by polling. Switching cards, or letting go, forgets the hold
## rather than carrying it over or merging the one that lost focus.
func _process(delta: float) -> void:
	if is_building() or is_merging():
		_reset_merge_hold()
		return
	var number := pr_number_from_name(_focused_card_name())
	if number < 0 or not _merge_held():
		_reset_merge_hold()
		return
	if number != _merge_hold_number:
		_reset_merge_hold()
		_merge_hold_number = number
	_merge_hold_elapsed += delta
	var bar: ProgressBar = _merge_bars.get(number)
	if bar != null:
		bar.show()
		bar.value = _merge_hold_elapsed / MERGE_HOLD_SECONDS
	if _merge_hold_elapsed >= MERGE_HOLD_SECONDS:
		_reset_merge_hold()
		start_merge(number)


## The name of whichever card has focus, or "" for none. [member Node.name]
## is a [StringName]; [method pr_number_from_name] wants a plain [String].
func _focused_card_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return String(focused.name) if focused != null else ""


## Whether [constant MERGE_KEY] or [constant MERGE_BUTTON] is down right now,
## on the keyboard or the first connected pad.
static func _merge_held() -> bool:
	if Input.is_key_pressed(MERGE_KEY):
		return true
	var pads := Input.get_connected_joypads()
	var device := pads[0] if not pads.is_empty() else 0
	return Input.is_joy_button_pressed(device, MERGE_BUTTON)


## Forgets the hold in progress, if any, and un-fills its card's bar.
func _reset_merge_hold() -> void:
	if _merge_hold_number >= 0:
		var bar: ProgressBar = _merge_bars.get(_merge_hold_number)
		if bar != null:
			bar.value = 0.0
			bar.hide()
	_merge_hold_number = -1
	_merge_hold_elapsed = 0.0


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
	_merge_bars.clear()
	_reset_merge_hold()
	var now := int(Time.get_unix_time_from_system())
	for entry in entries:
		_list.add_child(_card(entry, now))
	if entries.is_empty():
		_set_status("No open pull requests.")
		return
	_set_status(
		(
			"%d open. Pick one to build and play it; hold M or X to merge it; R or Y refreshes."
			% entries.size()
		)
	)
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


func _poll_merge() -> void:
	if OS.is_process_running(_merge_pid):
		return
	_merge_poll.stop()
	var log_text := FileAccess.get_file_as_string(MERGE_LOG_PATH)
	var number := _merging
	_merge_pid = -1
	_merging = 0
	if merge_succeeded(log_text):
		_set_status("Merged PR #%d." % number)
		refresh()
	else:
		_set_status("Could not merge PR #%d:\n%s" % [number, tail(log_text, LOG_LINES)])


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

	# A thin sliver along the bottom edge, hidden until held; see _process.
	var bar := ProgressBar.new()
	bar.name = "MergeHold"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0.0, 4.0)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.hide()
	button.add_child(bar)
	_merge_bars[entry["number"]] = bar

	return button


## Which install this is, from the BUILD file deck-build.sh writes beside it.
static func _running_build() -> String:
	var dir := OS.get_executable_path().get_base_dir()
	var build := FileAccess.get_file_as_string(dir.path_join("BUILD")).strip_edges()
	if build.is_empty():
		return "Running from %s" % dir
	return "Running %s: %s" % [dir.get_file(), build]

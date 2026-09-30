extends GutTest
## Covers [PrPicker]'s pure parts: reading GitHub's pulls response, the line
## under each title, the commands that hand over to the swap and merge
## scripts, and reading a card's own name back into a PR number. The
## request, the swap and the merge itself need the network and a Deck
## install, so they are left to playing it.

const NOW := 1790000000


func test_entries_keep_the_fields_the_list_shows() -> void:
	var pulls := [
		{
			"number": 94,
			"title": "Shift the eye band's key",
			"head": {"ref": "claude/magical-franklin"},
			"draft": false,
			"updated_at": "2026-09-27T11:27:55Z",
			"body": "ignored",
		}
	]
	var entries := PrPicker.entries_from_json(pulls)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["number"], 94)
	assert_eq(entries[0]["title"], "Shift the eye band's key")
	assert_eq(entries[0]["branch"], "claude/magical-franklin")
	assert_false(entries[0]["draft"])
	assert_eq(entries[0]["updated_at"], "2026-09-27T11:27:55Z")


func test_entries_skip_what_is_not_a_pull_request() -> void:
	assert_eq(PrPicker.entries_from_json(null).size(), 0, "Unparseable body")
	assert_eq(PrPicker.entries_from_json({"message": "rate limited"}).size(), 0, "Error object")
	assert_eq(PrPicker.entries_from_json([{"title": "no number"}, 3]).size(), 0, "Junk items")


func test_entries_tolerate_a_missing_head() -> void:
	var entries := PrPicker.entries_from_json([{"number": 7, "head": null}])
	assert_eq(entries[0]["branch"], "")


func test_describe_shows_branch_age_and_draft() -> void:
	var updated := Time.get_datetime_string_from_unix_time(NOW - 2 * 3600) + "Z"
	var entry := {"branch": "feature/x", "updated_at": updated, "draft": true}
	assert_eq(PrPicker.describe(entry, NOW), "feature/x · updated 2h ago · draft")


func test_describe_without_a_date() -> void:
	var entry := {"branch": "feature/x", "updated_at": "", "draft": false}
	assert_eq(PrPicker.describe(entry, NOW), "feature/x")


func test_ago_picks_the_largest_whole_unit() -> void:
	assert_eq(PrPicker.ago(5), "just now")
	assert_eq(PrPicker.ago(90), "1m ago")
	assert_eq(PrPicker.ago(3 * 3600 + 59), "3h ago")
	assert_eq(PrPicker.ago(2 * 86400), "2d ago")


func test_demo_args_run_the_script_with_the_pr_pid_and_log() -> void:
	var args := PrPicker.demo_args("/g/tools/deck-demo.sh", 94, 1234, "/u/pr_build.log")
	assert_eq(
		Array(args),
		["/g/tools/deck-demo.sh", "94", "--launcher-pid", "1234", "--log", "/u/pr_build.log"]
	)


func test_tail_keeps_the_last_lines() -> void:
	assert_eq(PrPicker.tail("a\nb\nc\nd\n\n", 2), "c\nd")
	assert_eq(PrPicker.tail("only", 5), "only")


func test_the_demo_script_sits_in_tools_beside_the_executable() -> void:
	var expected := OS.get_executable_path().get_base_dir().path_join("tools/deck-demo.sh")
	assert_eq(PrPicker.demo_script_path(), expected)


func test_the_demo_menu_lists_the_picker() -> void:
	var paths := DemoMenu.DEMOS.map(func(demo: Dictionary) -> String: return demo["path"])
	assert_has(paths, DemoMenu.PR_PICKER_PATH)


func test_merge_args_run_the_script_with_the_pr_and_log() -> void:
	var args := PrPicker.merge_args("/g/tools/deck-merge.sh", 94, "/u/pr_merge.log")
	assert_eq(Array(args), ["/g/tools/deck-merge.sh", "94", "--log", "/u/pr_merge.log"])


func test_the_merge_script_sits_in_tools_beside_the_executable() -> void:
	var expected := OS.get_executable_path().get_base_dir().path_join("tools/deck-merge.sh")
	assert_eq(PrPicker.merge_script_path(), expected)


func test_merge_succeeded_reads_the_marker_deck_merge_writes() -> void:
	assert_true(PrPicker.merge_succeeded("gh output...\nMERGED\n"))
	assert_false(PrPicker.merge_succeeded("gh output...\nFAILED (exit 1)\n"))
	assert_false(PrPicker.merge_succeeded(""))


func test_pr_number_from_name_reads_a_cards_own_name() -> void:
	assert_eq(PrPicker.pr_number_from_name("PR94"), 94)
	assert_eq(PrPicker.pr_number_from_name(""), -1, "No focus")
	assert_eq(PrPicker.pr_number_from_name("Refresh"), -1, "Not a card")
	assert_eq(PrPicker.pr_number_from_name("PR"), -1, "No digits")

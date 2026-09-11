extends GutTest
## Covers composition: every configured source contributes, not just one.
##
## Unlike MotionInput, which is exercised through a single scripted source,
## the interesting behaviour here is what happens with more than one.

const STEP := 1.0 / 60.0

var _input: LookInput


func before_each() -> void:
	_input = LookInput.new()
	add_child_autofree(_input)
	# _ready installs the desktop defaults; start from a known, empty mix.
	_input.clear_sources()


func test_no_sources_produce_nothing() -> void:
	assert_eq(_input.poll(STEP), Vector2.ZERO, "No sources, no rotation")


func test_one_source_passes_through() -> void:
	var source := ScriptedLookSource.new()
	source.push(Vector2(0.1, -0.05))
	_input.add_source(source)
	assert_eq(_input.poll(STEP), Vector2(0.1, -0.05), "Should pass the source's delta through")


func test_sources_are_summed_not_switched() -> void:
	var mouse := ScriptedLookSource.new()
	var stick := ScriptedLookSource.new()
	mouse.push(Vector2(0.1, 0.0))
	stick.push(Vector2(0.0, 0.2))
	_input.add_source(mouse)
	_input.add_source(stick)
	assert_eq(_input.poll(STEP), Vector2(0.1, 0.2), "Both sources should contribute")


func test_looked_emits_only_on_nonzero_rotation() -> void:
	var source := ScriptedLookSource.new()
	_input.add_source(source)
	watch_signals(_input)

	_input.poll(STEP)
	assert_signal_not_emitted(_input, "looked", "Zero rotation should not be announced")

	source.push(Vector2(0.2, 0.0))
	_input.poll(STEP)
	assert_signal_emitted_with_parameters(_input, "looked", [Vector2(0.2, 0.0)])


func test_clear_sources_empties_the_desktop_defaults() -> void:
	var fresh := LookInput.new()
	add_child_autofree(fresh)
	fresh.clear_sources()
	assert_eq(fresh.poll(STEP), Vector2.ZERO, "Cleared input should produce nothing")


func test_describe_sources_lists_every_source() -> void:
	_input.add_source(ScriptedLookSource.new())
	_input.add_source(ScriptedLookSource.new())
	assert_eq(_input.describe_sources(), "scripted, scripted", "Should list each source's name")

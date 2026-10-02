extends GutTest
## Covers #113: [PinField]'s layout, its pins' order and notes, hits and
## their cooldown, and finding a pin by position.

var _field: PinField
var _scale: PegScale


func before_each() -> void:
	_field = PinField.new()
	_field.area = Rect2(0, 0, 600, 250)
	_field.rows = 4
	_field.pins_per_row = 4
	add_child_autofree(_field)
	_scale = PegScale.new()
	_field.bind_scale(_scale)
	_scale.set_key(0, false)
	_scale.snap()


func test_pins_are_indexed_left_to_right_by_x() -> void:
	var last_x := -INF
	for pin in _field.pin_count():
		var x := _field.pin_position(pin).x
		assert_gte(x, last_x, "Pin %d no further left than the one before" % pin)
		last_x = x


func test_staggered_rows_make_distinct_columns() -> void:
	# 4 + 3 + 4 + 3 pins; 4 full columns and 3 set in between them.
	assert_eq(_field.pin_count(), 14)
	assert_eq(_field.column_count(), 7)
	assert_eq(_scale.pin_count(), 7, "The scale is configured per column")


func test_pitch_rises_left_to_right() -> void:
	var last := -1
	for pin in _field.pin_count():
		var note := _field.note_for(pin)
		assert_gte(note, last, "Pin %d" % pin)
		last = note
	assert_eq(_field.note_for(0), 48, "Leftmost is the lowest note at or above C3")


func test_pins_in_a_column_share_a_note() -> void:
	for pin in _field.pin_count():
		var column := _field.column_of(pin)
		assert_eq(_field.note_for(pin), _scale.note_for(column))


func test_hit_sounds_and_respects_the_cooldown() -> void:
	watch_signals(_field)
	assert_true(_field.hit(0, 0.8, 1_000_000), "First hit sounds")
	assert_false(_field.hit(0, 0.8, 1_020_000), "20 ms later: inside the cooldown")
	assert_true(_field.hit(1, 0.8, 1_020_000), "Another pin is free")
	assert_true(_field.hit(0, 0.8, 1_100_000), "100 ms later: again")
	assert_signal_emit_count(_field, "pin_hit", 3)


func test_hit_plays_the_note_the_scale_gives_now_mid_scroll() -> void:
	watch_signals(_field)
	_scale.set_scale_named("blues")
	_scale.advance()
	_scale.advance()
	var last := _field.pin_count() - 1
	_field.hit(last, 0.5, 5_000_000)
	var expected := _scale.note_for(_field.column_of(last))
	assert_signal_emitted_with_parameters(_field, "pin_hit", [last, expected, 0.5])
	assert_true(_scale.pending_for(_field.column_of(last)) >= 0, "That pin has not flipped yet")


func test_pin_at_finds_the_pin_under_a_point() -> void:
	var where := _field.to_global(_field.pin_position(5))
	assert_eq(_field.pin_at(where + Vector2(3, 0), 2.0), 5)
	assert_eq(_field.pin_at(where + Vector2(80, 80), 2.0), -1, "Nothing there")


func test_bodies_map_back_to_pins() -> void:
	for child in _field.get_children():
		if child is StaticBody2D:
			var pin := _field.pin_for_body(child)
			assert_almost_eq(child.position, _field.pin_position(pin), Vector2(0.01, 0.01))


func test_note_names() -> void:
	assert_eq(PinField.note_name(60), "C4")
	assert_eq(PinField.note_name(57), "A3")

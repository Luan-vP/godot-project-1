extends GutTest
## Covers the fretboard layout: the stored guitar scale diagrams
## ([GuitarDiagrams]), the scale that reads them ([FretboardScale]), and a
## [PinField] laid out as a fretboard — pins only where the scale is, moving
## along the neck fret by fret when the key changes.

var _field: PinField
var _scale: FretboardScale


func before_each() -> void:
	_field = PinField.new()
	_field.layout = PinField.Layout.FRETBOARD
	_field.area = Rect2(0, 0, 600, 100)
	add_child_autofree(_field)
	_scale = _field.new_scale()
	_field.bind_scale(_scale)
	_scale.set_key(9, true)  # A minor: the minor pentatonic.
	_scale.snap()


func test_every_scale_has_a_full_six_string_diagram() -> void:
	for scale_name in PegScale.SCALES:
		assert_true(GuitarDiagrams.has(scale_name), scale_name)
		var lines: Array = GuitarDiagrams.DIAGRAMS[scale_name]
		assert_eq(lines.size(), 6, "%s: six strings" % scale_name)
		for row in lines.size():
			var line: String = lines[row]
			assert_true(line.begins_with(GuitarDiagrams.STRING_NAMES[row] + " "), line)
			assert_eq(line.length(), 2 + GuitarDiagrams.LAST_FRET + 1, "Frets 0-24: %s" % line)


func test_the_diagrams_match_the_scales_intervals() -> void:
	for scale_name in PegScale.SCALES:
		var intervals: Array = PegScale.SCALES[scale_name]
		for row in 6:
			var open := GuitarDiagrams.STANDARD_TUNING[row]
			for fret in GuitarDiagrams.LAST_FRET + 1:
				var degree := posmod(open + fret - GuitarDiagrams.DIAGRAM_ROOT, 12)
				var mark := GuitarDiagrams.mark(scale_name, row, fret)
				var expected := "R" if degree == 0 else ("o" if intervals.has(degree) else "-")
				assert_eq(mark, expected, "%s, string %d, fret %d" % [scale_name, row, fret])


func test_another_key_is_the_diagram_slid_along_the_neck() -> void:
	for scale_name in PegScale.SCALES:
		var intervals: Array = PegScale.SCALES[scale_name]
		for root in 12:
			for row in 6:
				for fret in 30:
					var note := GuitarDiagrams.STANDARD_TUNING[row] + fret
					assert_eq(
						GuitarDiagrams.in_scale(scale_name, row, fret, root),
						intervals.has(posmod(note - root, 12)),
						"%s in %d, string %d, fret %d" % [scale_name, root, row, fret]
					)


func test_a_minor_pentatonic_box_at_the_fifth_fret() -> void:
	# The classic box: A on the high e at 5, C at 8.
	assert_true(GuitarDiagrams.in_scale("minor pentatonic", 0, 5, 9))
	assert_true(GuitarDiagrams.in_scale("minor pentatonic", 0, 8, 9))
	assert_false(GuitarDiagrams.in_scale("minor pentatonic", 0, 6, 9))


func test_six_strings_from_the_ninth_fret_twelve_frets_wide() -> void:
	assert_eq(_scale.string_count(), 6)
	assert_eq(_scale.fret_count(), 12)
	assert_eq(_scale.pin_count(), 72)
	assert_eq(_scale.site_note(_scale.site(0, 0)), 64 + 9, "High e, fret 9: C#5")
	assert_eq(_scale.site_note(_scale.site(0, 2)), 55 + 9, "G string, fret 9: E4")
	assert_eq(_scale.site_note(_scale.site(11, 0)), 64 + 20, "High e, fret 20")
	assert_eq(_scale.site_note(_scale.site(0, 5)), 40 + 9, "Low E, fret 9: C#3")


func test_pins_sit_only_where_the_scale_is() -> void:
	var live := _field.live_pins()
	assert_gt(live.size(), 0)
	for pin in _field.pin_count():
		var note := _scale.site_note(pin)
		var in_scale := PegScale.MINOR_PENTATONIC.has(posmod(note - 9, 12))
		assert_eq(_field.is_live(pin), in_scale, "Site %d" % pin)
		assert_eq(_field.note_for(pin), note if in_scale else -1)


func test_rows_are_strings_high_e_on_top_and_columns_are_frets() -> void:
	var top := _field.pin_position(_scale.site(4, 0))
	var bottom := _field.pin_position(_scale.site(4, 2))
	assert_lt(top.y, bottom.y, "High e above the G")
	assert_lt(_field.pin_position(_scale.site(3, 1)).x, _field.pin_position(_scale.site(4, 1)).x)
	assert_eq(_field.column_of(_scale.site(4, 1)), 4)


func test_a_key_change_moves_pins_fret_by_fret() -> void:
	_scale.set_key(2, true)  # D minor.
	assert_true(_scale.is_scrolling())
	_scale.advance()
	for row in 3:
		var first := _scale.site(0, row)
		var note := _scale.site_note(first)
		var in_d := PegScale.MINOR_PENTATONIC.has(posmod(note - 2, 12))
		assert_eq(_field.is_live(first), in_d, "The first fret has moved")
	for i in _scale.fret_count() - 1:
		_scale.advance()
	assert_false(_scale.is_scrolling())
	for pin in _field.pin_count():
		var note := _scale.site_note(pin)
		assert_eq(_field.is_live(pin), PegScale.MINOR_PENTATONIC.has(posmod(note - 2, 12)))


func test_an_empty_site_cannot_be_hit_or_found() -> void:
	var empty := -1
	for pin in _field.pin_count():
		if not _field.is_live(pin):
			empty = pin
			break
	assert_false(_field.hit(empty, 1.0, 1_000_000), "No pin to hit")
	var where := _field.to_global(_field.pin_position(empty))
	assert_ne(_field.pin_at(where), empty)


func test_an_empty_site_does_not_collide() -> void:
	await wait_physics_frames(1)
	for pin in _field.pin_count():
		var body := _field.get_node("Pin%d" % pin) as StaticBody2D
		var shape := body.get_child(0) as CollisionShape2D
		assert_eq(shape.disabled, not _field.is_live(pin), "Site %d" % pin)


func test_a_scale_with_no_diagram_is_worked_out_from_its_intervals() -> void:
	var whole_tone: Array[int] = [0, 2, 4, 6, 8, 10]
	_scale.set_scale(whole_tone, "")
	_scale.snap()
	for pin in _field.pin_count():
		var note := _scale.site_note(pin)
		assert_eq(_field.is_live(pin), whole_tone.has(posmod(note - 9, 12)))


func test_the_layout_takes_fewer_strings() -> void:
	var three := FretboardScale.new()
	three.configure_fretboard(3, 0, 13)
	assert_eq(three.string_count(), 3)
	assert_eq(three.site_note(three.site(0, 2)), 55, "Open G, the third string down")

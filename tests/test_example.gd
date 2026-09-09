extends GutTest


func test_arithmetic_sanity_check() -> void:
	assert_eq(2 + 2, 4, "2 + 2 should equal 4")


func test_string_concatenation() -> void:
	assert_eq("foo" + "bar", "foobar", "Strings should concatenate")

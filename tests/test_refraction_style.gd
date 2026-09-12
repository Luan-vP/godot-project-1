extends GutTest
## Covers [RefractionStyle], the tunable half of the clear-medium renderer.

var _style: RefractionStyle
var _material: ShaderMaterial


func before_each() -> void:
	_style = RefractionStyle.new()
	_material = ShaderMaterial.new()


func test_default_strength_is_subtle_but_nonzero() -> void:
	# Non-zero, so the medium is not silently invisible out of the box; small,
	# so a screenshot at rest still reads as unchanged per the issue's bar.
	assert_gt(_style.strength, 0.0, "A zero default would ship the bend invisible")
	assert_lt(_style.strength, 0.05, "Default strength should read as barely-there")


func test_strength_is_tunable_to_zero() -> void:
	_style.strength = 0.0
	_style.apply_to(_material)
	assert_eq(_material.get_shader_parameter("strength"), 0.0, "Zero must turn the bend off")


func test_apply_to_pushes_every_parameter() -> void:
	_style.strength = 0.03
	_style.speed_reference = 80.0
	_style.apply_to(_material)
	assert_eq(_material.get_shader_parameter("strength"), 0.03)
	assert_eq(_material.get_shader_parameter("speed_reference"), 80.0)


func test_apply_to_ignores_a_null_material() -> void:
	_style.apply_to(null)
	pass_test("A null material should be a no-op rather than an error")

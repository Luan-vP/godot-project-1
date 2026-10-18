extends GutTest
## Covers how the painterly pass reaches the screen: offscreen, then stretched.


func test_the_painterly_pass_draws_offscreen_and_is_shown_stretched() -> void:
	var renderer: FluidRenderer = add_child_autofree(FluidRenderer.new())
	var buffer := renderer.get_buffer()
	assert_eq(buffer.get_parent(), renderer, "The buffer belongs to the renderer")
	assert_eq(renderer.texture, buffer.get_texture(), "It shows what the buffer drew")
	assert_eq(renderer.stretch_mode, TextureRect.STRETCH_SCALE, "Stretched over the tank")
	assert_eq(
		renderer.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Upscaled smooth, not blocky"
	)
	var paint: ColorRect = buffer.find_children("*", "ColorRect", false, false)[0]
	var material: ShaderMaterial = paint.material
	assert_eq(material.shader, FluidRenderer.PAINTERLY_SHADER, "The shader runs in the buffer")


func test_a_sleeping_tank_draws_nothing_offscreen() -> void:
	var renderer: FluidRenderer = add_child_autofree(FluidRenderer.new())
	assert_eq(
		renderer.get_buffer().render_target_update_mode,
		SubViewport.UPDATE_WHEN_VISIBLE,
		"Only while shown: WHEN_PARENT_VISIBLE follows the root viewport, which never hides"
	)

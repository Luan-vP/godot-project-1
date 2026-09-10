class_name FluidPass
extends RefCounted
## One full-screen shader step of the fluid solve, rendered into its own
## [SubViewport].
##
## Passes are chained by [i]nesting[/i] their viewports: Godot renders a child
## viewport before its parent, so making each step the child of the next one
## guarantees the whole solve completes in a single frame, in order. See
## [FluidSimulation] for the assembled chain.

## The render target. Nest this under the next pass's viewport.
var viewport: SubViewport

## Material driving this step. Set uniforms through [method set_param].
var material: ShaderMaterial


func _init(pass_name: String, shader: Shader, resolution: Vector2i) -> void:
	material = ShaderMaterial.new()
	material.shader = shader

	var canvas := ColorRect.new()
	canvas.name = "Canvas"
	canvas.material = material
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.size = Vector2(resolution)

	viewport = SubViewport.new()
	viewport.name = pass_name
	viewport.size = resolution
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.transparent_bg = true
	# Velocity is signed and pigment density runs past 1.0, so an 8-bit target
	# would clamp the simulation into uselessness. This is not optional.
	viewport.use_hdr_2d = true
	# The canvas covers every pixel and blending is off, so there is nothing
	# to clear.
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(canvas)


## This pass's output. Only valid once the viewport is inside the tree.
func texture() -> ViewportTexture:
	return viewport.get_texture()


func set_param(param_name: String, value: Variant) -> void:
	material.set_shader_parameter(param_name, value)


## Blank the render target on the next frame, dropping accumulated state.
func clear_target() -> void:
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE

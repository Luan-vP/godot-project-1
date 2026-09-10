shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Straight resample. Used to downsample the projected velocity for CPU
// readback, and to hold the previous frame's dye (a viewport cannot sample
// its own texture, so the dye field lives in two passes).

uniform sampler2D source_tex : filter_linear, repeat_disable, hint_default_black;

// Held true for one frame to empty the tank. Clearing the render targets
// cannot do this: every pass repaints from its source in the same frame,
// and sources are cleared later in the nested chain, so the old field
// survives. Writing zeros here also makes the first frame well-defined
// without trusting whatever the driver left in the target.
uniform bool blank = false;

void fragment() {
	COLOR = texture(source_tex, UV);

	if (blank) {
		COLOR = vec4(0.0);
	}
}

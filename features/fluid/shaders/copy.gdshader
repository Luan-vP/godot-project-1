shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Straight resample. Used to downsample the projected velocity for CPU
// readback, and to hold the previous frame's dye (a viewport cannot sample
// its own texture, so the dye field lives in two passes).

uniform sampler2D source_tex : filter_linear, repeat_disable, hint_default_black;

void fragment() {
	COLOR = texture(source_tex, UV);
}

shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The medium is clear: nothing is painted, only the background behind it
// bends. It has to stay subtle enough that a still tank is nearly invisible —
// this is vitreous humour, not a heat haze.
//
// Offsetting the sample UV by the velocity field directly reads as a smear
// dragged across the screen, because a uniform current then shifts every
// pixel by the same amount. What actually reads as refraction is the
// *gradient* of local speed: flat (so no offset) wherever the flow is
// uniform, including a tank entirely at rest, and only curved at the rim of
// a swish, where speed changes fastest across the screen. That gradient is
// used the way a height field feeds a normal map, to bend the background
// sample rather than drag it.

uniform sampler2D velocity_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 texel_size = vec2(0.00390625);  // 1/256, replaced by the real size each frame.

// How far the background sample shifts, in UV. Tunable down to zero.
uniform float strength : hint_range(0.0, 0.1) = 0.012;
// Speed, in cells/second, at which the gradient reaches full strength.
uniform float speed_reference : hint_range(1.0, 400.0) = 50.0;

float speed_at(vec2 uv) {
	return length(texture(velocity_tex, uv).xy);
}

void fragment() {
	float right = speed_at(UV + vec2(texel_size.x, 0.0));
	float left = speed_at(UV - vec2(texel_size.x, 0.0));
	float up = speed_at(UV + vec2(0.0, texel_size.y));
	float down = speed_at(UV - vec2(0.0, texel_size.y));

	vec2 gradient = vec2(
		(right - left) / (2.0 * max(texel_size.x, 1e-6)),
		(up - down) / (2.0 * max(texel_size.y, 1e-6))
	);
	gradient /= max(speed_reference, 1e-5);
	// A splat's leading edge can spike the gradient far past a "normal" swish.
	// Clamping keeps that spike from ever reading as more than the configured
	// strength, however hard the tank is shoved.
	gradient = clamp(gradient, vec2(-1.0), vec2(1.0));

	// Clamped rather than wrapped or mirrored, so a sample pushed past the
	// edge of the screen holds the edge pixel instead of tiling or seaming.
	vec2 sample_uv = clamp(SCREEN_UV + gradient * strength, vec2(0.0), vec2(1.0));
	COLOR = vec4(texture(screen_texture, sample_uv).rgb, 1.0);
}

shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Pass 2: how much the advected field is compressing or expanding at each cell.
// Walls are free-slip — the normal component is mirrored at the border so the
// fluid slides along the edge of the tank instead of leaking through it.

uniform sampler2D velocity_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 texel_size = vec2(1.0 / 256.0);

// Held true for one frame to empty the tank. Clearing the render targets
// cannot do this: every pass repaints from its source in the same frame,
// and sources are cleared later in the nested chain, so the old field
// survives. Writing zeros here also makes the first frame well-defined
// without trusting whatever the driver left in the target.
uniform bool blank = false;

void fragment() {
	vec2 centre = texture(velocity_tex, UV).xy;
	float right = texture(velocity_tex, UV + vec2(texel_size.x, 0.0)).x;
	float left = texture(velocity_tex, UV - vec2(texel_size.x, 0.0)).x;
	float top = texture(velocity_tex, UV + vec2(0.0, texel_size.y)).y;
	float bottom = texture(velocity_tex, UV - vec2(0.0, texel_size.y)).y;

	if (UV.x + texel_size.x > 1.0) {
		right = -centre.x;
	}
	if (UV.x - texel_size.x < 0.0) {
		left = -centre.x;
	}
	if (UV.y + texel_size.y > 1.0) {
		top = -centre.y;
	}
	if (UV.y - texel_size.y < 0.0) {
		bottom = -centre.y;
	}

	COLOR = vec4(0.5 * ((right - left) + (top - bottom)), 0.0, 0.0, 1.0);

	if (blank) {
		COLOR = vec4(0.0);
	}
}

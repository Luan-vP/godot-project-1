shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Pass 4: subtract the pressure gradient. What comes out is (approximately)
// divergence free — the field the eyes actually read and the dye rides on.

uniform sampler2D velocity_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D pressure_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 texel_size = vec2(1.0 / 256.0);

// Held true for one frame to empty the tank. Clearing the render targets
// cannot do this: every pass repaints from its source in the same frame,
// and sources are cleared later in the nested chain, so the old field
// survives. Writing zeros here also makes the first frame well-defined
// without trusting whatever the driver left in the target.
uniform bool blank = false;

void fragment() {
	float right = texture(pressure_tex, UV + vec2(texel_size.x, 0.0)).x;
	float left = texture(pressure_tex, UV - vec2(texel_size.x, 0.0)).x;
	float top = texture(pressure_tex, UV + vec2(0.0, texel_size.y)).x;
	float bottom = texture(pressure_tex, UV - vec2(0.0, texel_size.y)).x;

	vec2 velocity = texture(velocity_tex, UV).xy;
	velocity -= 0.5 * vec2(right - left, top - bottom);

	// Hard stop in the outermost ring of cells, so nothing streams off-tank.
	vec2 inside = step(texel_size, UV) * step(texel_size, vec2(1.0) - UV);
	velocity *= min(inside.x, inside.y);

	COLOR = vec4(velocity, 0.0, 1.0);

	if (blank) {
		COLOR = vec4(0.0);
	}
}

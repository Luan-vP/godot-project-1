shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Pass 3, run once per iteration: one Jacobi relaxation of the Poisson
// equation grad^2(p) = divergence. Each pass reads the previous pass's result,
// and the first pass reads the last one — so pressure keeps relaxing across
// frames instead of restarting from zero every step.

uniform sampler2D pressure_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D divergence_tex : filter_linear, repeat_disable, hint_default_black;
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
	float divergence = texture(divergence_tex, UV).x;

	COLOR = vec4((left + right + bottom + top - divergence) * 0.25, 0.0, 0.0, 1.0);

	if (blank) {
		COLOR = vec4(0.0);
	}
}

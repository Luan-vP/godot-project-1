shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The look. Four things stacked, in the order a painter would do them:
//
//   1. pigment    — dye density read subtractively, the way a wash sits on
//                   paper, instead of as additive light
//   2. brushwork  — a Kuwahara filter whose kernel is stretched *along the
//                   flow*, so the strokes follow the current instead of
//                   sitting on a fixed grid
//   3. edges      — pigment piles up where a wash stops, so wash boundaries
//                   get a darker rim
//   4. paper      — grain, fibre, and a little hand-drawn wobble

uniform sampler2D dye_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D velocity_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 texel_size = vec2(0.00390625);  // 1/256, replaced by the real size each frame.

group_uniforms pigment;
uniform vec3 paper_color : source_color = vec3(0.129, 0.156, 0.219);
uniform vec3 deep_color : source_color = vec3(0.043, 0.055, 0.098);
uniform vec3 absorption = vec3(1.15, 1.45, 1.75);
uniform float ambient_density : hint_range(0.0, 2.0) = 0.28;
uniform float pigment_gain : hint_range(0.1, 4.0) = 1.5;

group_uniforms brushwork;
uniform float stroke_size : hint_range(0.0, 12.0) = 2.4;
uniform float stroke_stretch : hint_range(1.0, 8.0) = 3.2;
uniform float stroke_speed_reference : hint_range(1.0, 400.0) = 45.0;

group_uniforms edges;
uniform float edge_darkening : hint_range(0.0, 2.0) = 0.7;
uniform float edge_width : hint_range(0.5, 6.0) = 1.8;

group_uniforms paper;
uniform float canvas_grain : hint_range(0.0, 1.0) = 0.16;
uniform float canvas_scale : hint_range(16.0, 2048.0) = 420.0;
uniform float wobble : hint_range(0.0, 8.0) = 1.1;

// Half-width of the brush kernel, in samples. Cost is 4 * (N+1)^2 taps.
const int STROKE_RADIUS = 2;

float hash21(vec2 p) {
	vec2 h = fract(p * vec2(123.34, 456.21));
	h += dot(h, h + 45.32);
	return fract(h.x * h.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 frac = fract(p);
	vec2 weight = frac * frac * (3.0 - 2.0 * frac);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
}

// A wash of pigment sitting on the paper, read the way transmitted light
// actually behaves: thicker pigment absorbs more, per channel.
vec3 paint_at(vec2 uv) {
	vec4 dye = texture(dye_tex, uv);
	float density = dye.a + ambient_density;
	vec3 pigment = deep_color;
	if (dye.a > 1e-4) {
		pigment = mix(deep_color, dye.rgb / dye.a, clamp(dye.a * pigment_gain, 0.0, 1.0));
	}
	vec3 transmitted = exp(-absorption * density);
	return paper_color * transmitted + pigment * (1.0 - transmitted);
}

void fragment() {
	// The brush follows the current: long axis along the flow, short axis
	// across it, and it only elongates once the water is actually moving.
	vec2 flow = texture(velocity_tex, UV).xy;
	float speed = length(flow);
	vec2 direction = speed > 1e-4 ? flow / speed : vec2(1.0, 0.0);
	float stretch = mix(1.0, stroke_stretch, clamp(speed / stroke_speed_reference, 0.0, 1.0));
	vec2 long_axis = direction * stroke_size * stretch;
	vec2 short_axis = vec2(-direction.y, direction.x) * stroke_size;

	// Nudge the sample point so wash edges read as drawn rather than computed.
	vec2 jitter = vec2(
		value_noise(UV * canvas_scale * 0.37),
		value_noise(UV * canvas_scale * 0.37 + 31.7)
	) - 0.5;
	vec2 uv = UV + jitter * wobble * texel_size;

	// Kuwahara: of the four quadrants of the brush, keep the flattest one.
	// Flat quadrants win, so colour spreads within a stroke but stops dead at
	// its edge — which is what makes it read as paint and not as blur.
	vec3 best_mean = paint_at(uv);
	float best_score = 1e9;
	for (int s = 0; s < 4; s++) {
		float sign_x = (s == 0 || s == 2) ? 1.0 : -1.0;
		float sign_y = (s < 2) ? 1.0 : -1.0;
		vec3 sum = vec3(0.0);
		vec3 sum_squared = vec3(0.0);
		float count = 0.0;
		for (int i = 0; i <= STROKE_RADIUS; i++) {
			for (int j = 0; j <= STROKE_RADIUS; j++) {
				float along = float(i) / float(STROKE_RADIUS) * sign_x;
				float across = float(j) / float(STROKE_RADIUS) * sign_y;
				vec2 offset = (long_axis * along + short_axis * across) * texel_size;
				vec3 sampled = paint_at(uv + offset);
				sum += sampled;
				sum_squared += sampled * sampled;
				count += 1.0;
			}
		}
		vec3 mean = sum / count;
		vec3 variance = max(sum_squared / count - mean * mean, vec3(0.0));
		float score = variance.r + variance.g + variance.b;
		if (score < best_score) {
			best_score = score;
			best_mean = mean;
		}
	}

	// Pigment strands towards the rim of a drying wash.
	vec2 edge_step = texel_size * edge_width;
	float density_right = texture(dye_tex, uv + vec2(edge_step.x, 0.0)).a;
	float density_left = texture(dye_tex, uv - vec2(edge_step.x, 0.0)).a;
	float density_top = texture(dye_tex, uv + vec2(0.0, edge_step.y)).a;
	float density_bottom = texture(dye_tex, uv - vec2(0.0, edge_step.y)).a;
	float rim = length(vec2(density_right - density_left, density_top - density_bottom));
	vec3 colour = best_mean * (1.0 - clamp(rim * edge_darkening, 0.0, 0.8));

	// Cold-press grain plus a stretched fibre direction.
	float grain = value_noise(uv * canvas_scale);
	float fibre = value_noise(uv * vec2(canvas_scale * 2.3, canvas_scale * 0.22));
	float tooth = clamp(grain * 0.65 + fibre * 0.35, 0.0, 1.0);
	colour *= mix(1.0 - canvas_grain, 1.0 + canvas_grain, tooth);

	COLOR = vec4(colour, 1.0);
}

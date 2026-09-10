shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Pass 1 of the fluid step: move the velocity field along itself, keep the
// small eddies alive, and fold in this frame's impulses.
//
// Velocities are expressed in *simulation cells per second*, so multiplying by
// TEXEL_SIZE converts them into UV space. The result is still divergent — the
// pressure passes clean that up.

const int MAX_SPLATS = 16;

uniform sampler2D velocity_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 texel_size = vec2(1.0 / 256.0);
uniform float time_step = 0.0166;
uniform float dissipation = 0.997;
uniform float vorticity_strength = 24.0;

// A slow, large-scale swell so the medium never settles into dead water.
uniform float ambient_strength = 12.0;
uniform float ambient_scale = 1.7;
uniform float elapsed = 0.0;

// Splat radii are in units of tank height; this squares up the UV
// offset so a blob stays round in a non-square tank.
uniform vec2 splat_aspect = vec2(1.0, 1.0);

// xy = centre in UV space, zw = impulse in cells/second^2.
uniform vec4 splats[16];
// x = radius in tank heights, y = 1.0 while the slot is in use.
uniform vec4 splat_shape[16];

float curl_at(vec2 uv) {
	float right = texture(velocity_tex, uv + vec2(texel_size.x, 0.0)).y;
	float left = texture(velocity_tex, uv - vec2(texel_size.x, 0.0)).y;
	float top = texture(velocity_tex, uv + vec2(0.0, texel_size.y)).x;
	float bottom = texture(velocity_tex, uv - vec2(0.0, texel_size.y)).x;
	return 0.5 * ((right - left) - (top - bottom));
}

void fragment() {
	vec2 half_texel = texel_size * 0.5;

	// Semi-Lagrangian advection: look backwards along the flow and resample.
	vec2 here = texture(velocity_tex, UV).xy;
	vec2 source_uv = clamp(UV - here * time_step * texel_size, half_texel, vec2(1.0) - half_texel);
	vec2 velocity = texture(velocity_tex, source_uv).xy * dissipation;

	// Vorticity confinement. Numerical diffusion eats small vortices every
	// step; this pushes energy back into whatever swirl is still there.
	float curl = curl_at(UV);
	vec2 gradient = vec2(
		abs(curl_at(UV + vec2(texel_size.x, 0.0))) - abs(curl_at(UV - vec2(texel_size.x, 0.0))),
		abs(curl_at(UV + vec2(0.0, texel_size.y))) - abs(curl_at(UV - vec2(0.0, texel_size.y)))
	) * 0.5;
	float magnitude = length(gradient);
	if (magnitude > 1e-5) {
		vec2 normal = gradient / magnitude;
		velocity += vec2(normal.y, -normal.x) * curl * vorticity_strength * time_step;
	}

	vec2 ambient = vec2(
		sin(UV.y * ambient_scale * TAU + elapsed * 0.11),
		cos(UV.x * ambient_scale * TAU - elapsed * 0.083)
	);
	velocity += ambient * ambient_strength * time_step;

	for (int i = 0; i < MAX_SPLATS; i++) {
		if (splat_shape[i].y < 0.5) {
			continue;
		}
		vec2 offset = (UV - splats[i].xy) * splat_aspect;
		float radius = max(splat_shape[i].x, 1e-4);
		float falloff = exp(-dot(offset, offset) / (radius * radius));
		velocity += splats[i].zw * falloff * time_step;
	}

	COLOR = vec4(velocity, 0.0, 1.0);
}

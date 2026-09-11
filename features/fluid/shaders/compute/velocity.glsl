#[compute]
#version 450

// Pass 1 of the fluid step: move the velocity field along itself, keep the
// small eddies alive, and fold in this frame's impulses.
//
// Velocities are expressed in *simulation cells per second*, so multiplying by
// texel_size converts them into UV space. The result is still divergent -- the
// pressure passes clean that up.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D velocity_tex;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2D out_velocity;
layout(set = 0, binding = 2, std430) restrict readonly buffer Splats {
	Splat splats[];
} splat_buffer;

float curl_at(vec2 uv) {
	float right = texture(velocity_tex, uv + vec2(params.texel_size.x, 0.0)).y;
	float left = texture(velocity_tex, uv - vec2(params.texel_size.x, 0.0)).y;
	float top = texture(velocity_tex, uv + vec2(0.0, params.texel_size.y)).x;
	float bottom = texture(velocity_tex, uv - vec2(0.0, params.texel_size.y)).x;
	return 0.5 * ((right - left) - (top - bottom));
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (out_of_bounds(coord)) {
		return;
	}
	vec2 uv = cell_uv(coord);
	vec2 half_texel = params.texel_size * 0.5;

	// Semi-Lagrangian advection: look backwards along the flow and resample.
	vec2 here = texture(velocity_tex, uv).xy;
	vec2 source_uv = clamp(
		uv - here * params.time_step * params.texel_size, half_texel, vec2(1.0) - half_texel
	);
	vec2 velocity = texture(velocity_tex, source_uv).xy * params.dissipation;

	// Vorticity confinement. Numerical diffusion eats small vortices every
	// step; this pushes energy back into whatever swirl is still there.
	float curl = curl_at(uv);
	vec2 gradient = vec2(
		abs(curl_at(uv + vec2(params.texel_size.x, 0.0)))
			- abs(curl_at(uv - vec2(params.texel_size.x, 0.0))),
		abs(curl_at(uv + vec2(0.0, params.texel_size.y)))
			- abs(curl_at(uv - vec2(0.0, params.texel_size.y)))
	) * 0.5;
	float magnitude = length(gradient);
	if (magnitude > 1e-5) {
		vec2 normal = gradient / magnitude;
		velocity += vec2(normal.y, -normal.x) * curl * params.vorticity_strength * params.time_step;
	}

	vec2 ambient = vec2(
		sin(uv.y * params.ambient_scale * TAU + params.elapsed * 0.11),
		cos(uv.x * params.ambient_scale * TAU - params.elapsed * 0.083)
	);
	velocity += (ambient * params.ambient_strength + params.ambient_drift) * params.time_step;

	// A uniform field is already divergence free, so the projection step leaves
	// it alone except at the walls -- which is where the sloshing comes from.
	velocity += params.uniform_impulse;

	for (int i = 0; i < params.splat_count; i++) {
		vec2 offset = (uv - splat_buffer.splats[i].slot.xy) * params.splat_aspect;
		float radius = max(splat_buffer.splats[i].shape.x, 1e-4);
		float falloff = exp(-dot(offset, offset) / (radius * radius));
		velocity += splat_buffer.splats[i].slot.zw * falloff;
	}

	imageStore(out_velocity, coord, vec4(velocity, 0.0, 1.0));
}

#[compute]
#version 450

// Pass 3, run once per iteration: one Jacobi relaxation of the Poisson
// equation grad^2(p) = divergence. The two pressure targets ping-pong, and
// neither is cleared between frames -- so pressure keeps relaxing across frames
// instead of restarting from zero every step.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D pressure_tex;
layout(set = 0, binding = 1, r16f) uniform restrict writeonly image2D out_pressure;
layout(set = 0, binding = 2) uniform sampler2D divergence_tex;

float pressure_at(ivec2 coord) {
	return texelFetch(pressure_tex, clamp(coord, ivec2(0), params.size - 1), 0).x;
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (out_of_bounds(coord)) {
		return;
	}
	float right = pressure_at(coord + ivec2(1, 0));
	float left = pressure_at(coord - ivec2(1, 0));
	float top = pressure_at(coord + ivec2(0, 1));
	float bottom = pressure_at(coord - ivec2(0, 1));
	float divergence = texelFetch(divergence_tex, coord, 0).x;

	imageStore(
		out_pressure, coord, vec4((left + right + bottom + top - divergence) * 0.25, 0.0, 0.0, 1.0)
	);
}

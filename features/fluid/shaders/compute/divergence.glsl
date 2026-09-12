#[compute]
#version 450

// Pass 2: how much the advected field is compressing or expanding at each cell.
// A masked neighbour -- a wall or, eventually, a body -- is free-slip: the
// normal component is mirrored against it so the fluid slides along instead
// of leaking through.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D velocity_tex;
layout(set = 0, binding = 1, r16f) uniform restrict writeonly image2D out_divergence;
layout(set = 0, binding = 2) uniform sampler2D obstacle_tex;

vec2 velocity_at(ivec2 coord) {
	return texelFetch(velocity_tex, clamp(coord, ivec2(0), params.size - 1), 0).xy;
}

bool is_obstacle(ivec2 coord) {
	return texelFetch(obstacle_tex, clamp(coord, ivec2(0), params.size - 1), 0).x > 0.5;
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (out_of_bounds(coord)) {
		return;
	}
	vec2 centre = velocity_at(coord);
	float right = velocity_at(coord + ivec2(1, 0)).x;
	float left = velocity_at(coord - ivec2(1, 0)).x;
	float top = velocity_at(coord + ivec2(0, 1)).y;
	float bottom = velocity_at(coord - ivec2(0, 1)).y;

	if (is_obstacle(coord + ivec2(1, 0))) {
		right = -centre.x;
	}
	if (is_obstacle(coord - ivec2(1, 0))) {
		left = -centre.x;
	}
	if (is_obstacle(coord + ivec2(0, 1))) {
		top = -centre.y;
	}
	if (is_obstacle(coord - ivec2(0, 1))) {
		bottom = -centre.y;
	}

	imageStore(out_divergence, coord, vec4(0.5 * ((right - left) + (top - bottom)), 0.0, 0.0, 1.0));
}

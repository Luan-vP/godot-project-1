#[compute]
#version 450

// Pass 2: how much the advected field is compressing or expanding at each cell.
// Walls are free-slip -- the normal component is mirrored at the border so the
// fluid slides along the edge of the tank instead of leaking through it.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D velocity_tex;
layout(set = 0, binding = 1, r16f) uniform restrict writeonly image2D out_divergence;

vec2 velocity_at(ivec2 coord) {
	return texelFetch(velocity_tex, clamp(coord, ivec2(0), params.size - 1), 0).xy;
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

	if (coord.x + 1 >= params.size.x) {
		right = -centre.x;
	}
	if (coord.x - 1 < 0) {
		left = -centre.x;
	}
	if (coord.y + 1 >= params.size.y) {
		top = -centre.y;
	}
	if (coord.y - 1 < 0) {
		bottom = -centre.y;
	}

	imageStore(out_divergence, coord, vec4(0.5 * ((right - left) + (top - bottom)), 0.0, 0.0, 1.0));
}

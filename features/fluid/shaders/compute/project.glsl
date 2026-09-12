#[compute]
#version 450

// Pass 4: subtract the pressure gradient. What comes out is (approximately)
// divergence free -- the field the eyes actually read and the dye rides on.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D velocity_tex;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2D out_velocity;
layout(set = 0, binding = 2) uniform sampler2D pressure_tex;
layout(set = 0, binding = 3) uniform sampler2D obstacle_tex;

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

	vec2 velocity = texelFetch(velocity_tex, coord, 0).xy;
	velocity -= 0.5 * vec2(right - left, top - bottom);

	// Hard stop inside a masked cell, so nothing streams into a wall -- or,
	// eventually, a body.
	if (texelFetch(obstacle_tex, coord, 0).x > 0.5) {
		velocity = vec2(0.0);
	}

	imageStore(out_velocity, coord, vec4(velocity, 0.0, 1.0));
}

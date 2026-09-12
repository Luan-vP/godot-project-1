#[compute]
#version 450

// Pass 1b, run once per iteration: one Jacobi relaxation of implicit viscous
// diffusion, (I - nu * dt * laplacian) u = u_advected.
//
// Implicit so that no viscosity is ever too thick to be stable; an explicit
// step blows up as soon as nu * dt outgrows a cell. The coefficient is split
// per axis because cells are not square in world space -- a 16:9 tank on a
// square grid has wider cells than tall ones, and the fluid should thicken the
// same in every direction on screen, not in every direction on the grid.
//
// A masked neighbour is no-slip: it holds zero velocity, so fluid drags along
// a wall instead of sliding past it. That drag is what viscosity *is* at a
// boundary.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// The current guess, the advected field it is solving against, and the mask.
layout(set = 0, binding = 0) uniform sampler2D guess_tex;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2D out_velocity;
layout(set = 0, binding = 2) uniform sampler2D advected_tex;
layout(set = 0, binding = 3) uniform sampler2D obstacle_tex;

bool is_obstacle(ivec2 coord) {
	return texelFetch(obstacle_tex, clamp(coord, ivec2(0), params.size - 1), 0).x > 0.5;
}

vec2 guess_at(ivec2 coord) {
	if (is_obstacle(coord)) {
		return vec2(0.0);
	}
	return texelFetch(guess_tex, clamp(coord, ivec2(0), params.size - 1), 0).xy;
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (out_of_bounds(coord)) {
		return;
	}
	if (is_obstacle(coord)) {
		imageStore(out_velocity, coord, vec4(0.0, 0.0, 0.0, 1.0));
		return;
	}

	vec2 alpha = params.viscous_alpha;
	vec2 horizontal = guess_at(coord + ivec2(1, 0)) + guess_at(coord - ivec2(1, 0));
	vec2 vertical = guess_at(coord + ivec2(0, 1)) + guess_at(coord - ivec2(0, 1));
	vec2 advected = texelFetch(advected_tex, coord, 0).xy;

	vec2 velocity =
		(advected + alpha.x * horizontal + alpha.y * vertical) / (1.0 + 2.0 * alpha.x + 2.0 * alpha.y);

	imageStore(out_velocity, coord, vec4(velocity, 0.0, 1.0));
}

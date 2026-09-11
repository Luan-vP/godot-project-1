#[compute]
#version 450

// The seam between the GPU solve and gameplay: resample the projected velocity
// onto the small grid the CPU mirror reads. Kept as its own pass so the stall
// on [method RenderingDevice.texture_get_data] is over a 64x64 target rather
// than the full simulation.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D velocity_tex;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2D out_velocity;

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (out_of_bounds(coord)) {
		return;
	}
	// params.size is the readback grid here, so this samples the simulation
	// through the bilinear filter rather than picking one cell in every four.
	imageStore(out_velocity, coord, texture(velocity_tex, cell_uv(coord)));
}

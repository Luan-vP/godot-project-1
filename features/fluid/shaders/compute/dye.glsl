#[compute]
#version 450

// Pass 5: carry the pigment on the projected field and add this frame's dabs.
// Density is premultiplied -- rgb is pigment * density and a is density -- so
// the painterly pass can divide it back out to get the hue.

#include "fluid_params.glslinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D dye_tex;
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image2D out_dye;
layout(set = 0, binding = 2) uniform sampler2D velocity_tex;
layout(set = 0, binding = 3, std430) restrict readonly buffer Splats {
	Splat splats[];
} splat_buffer;

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (out_of_bounds(coord)) {
		return;
	}
	vec2 uv = cell_uv(coord);
	vec2 half_texel = params.texel_size * 0.5;

	vec2 velocity = texture(velocity_tex, uv).xy;
	vec2 source_uv = clamp(
		uv - velocity * params.time_step * params.texel_size, half_texel, vec2(1.0) - half_texel
	);
	vec4 dye = texture(dye_tex, source_uv) * params.dissipation;

	for (int i = 0; i < params.splat_count; i++) {
		vec2 offset = (uv - splat_buffer.splats[i].slot.xy) * params.splat_aspect;
		float radius = max(splat_buffer.splats[i].slot.z, 1e-4);
		float falloff = exp(-dot(offset, offset) / (radius * radius));
		float deposited = splat_buffer.splats[i].shape.a * falloff;
		dye += vec4(splat_buffer.splats[i].shape.rgb * deposited, deposited);
	}

	imageStore(out_dye, coord, clamp(dye, vec4(0.0), vec4(params.max_density)));
}

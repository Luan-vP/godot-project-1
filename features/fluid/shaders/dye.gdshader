shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Pass 5: the pigment carried by the fluid. This is the layer you actually
// see; the velocity field only exists to smear it around convincingly.
//
// Storage is premultiplied: .rgb is pigment * density and .a is density, so
// two washes meeting mix by weight rather than by whoever drew last.

const int MAX_SPLATS = 16;

uniform sampler2D velocity_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D dye_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 texel_size = vec2(1.0 / 256.0);
uniform float time_step = 0.0166;
uniform float dissipation = 0.994;
uniform float max_density = 6.0;

// Splat radii are in units of tank height; this squares up the UV
// offset so a blob stays round in a non-square tank.
uniform vec2 splat_aspect = vec2(1.0, 1.0);

// xy = centre in UV space, z = radius in tank heights, w = 1.0 while in use.
uniform vec4 splats[16];
// rgb = pigment, a = deposition rate in density/second.
uniform vec4 splat_paint[16];

void fragment() {
	vec2 half_texel = texel_size * 0.5;
	vec2 velocity = texture(velocity_tex, UV).xy;
	vec2 source_uv = clamp(UV - velocity * time_step * texel_size, half_texel, vec2(1.0) - half_texel);
	vec4 dye = texture(dye_tex, source_uv) * dissipation;

	for (int i = 0; i < MAX_SPLATS; i++) {
		if (splats[i].w < 0.5) {
			continue;
		}
		vec2 offset = (UV - splats[i].xy) * splat_aspect;
		float radius = max(splats[i].z, 1e-4);
		float falloff = exp(-dot(offset, offset) / (radius * radius));
		float deposited = splat_paint[i].a * falloff * time_step;
		dye += vec4(splat_paint[i].rgb * deposited, deposited);
	}

	COLOR = clamp(dye, vec4(0.0), vec4(max_density));
}

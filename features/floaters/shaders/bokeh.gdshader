shader_type canvas_item;
// Out-of-focus composite for one FloaterDepth band.
//
// A disc blur, not a Gaussian: taps fill a circle on a golden-angle spiral,
// which is what turns a defocused speck into a soft-edged coin instead of a
// smudge. Outer taps are weighted up a little for the rim real bokeh has. The
// spiral is rotated per pixel so sparse taps read as grain, not banding.
//
// Only coverage is blurred. Colour comes from `tint`: every floater in a band
// is one colour, and it sidesteps premultiplied-alpha fringes at the edges.

uniform float radius_px = 0.0;
uniform float gain = 1.0;
uniform float rim = 0.6;
uniform vec4 tint : source_color = vec4(0.13, 0.14, 0.17, 0.5);

const int TAPS = 64;
const float GOLDEN_ANGLE = 2.39996323;

float hash(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	if (radius_px < 0.75) {
		COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
	} else {
		float spin = hash(FRAGCOORD.xy) * 6.2831853;
		float total = 0.0;
		float weight_sum = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float r = sqrt((float(i) + 0.5) / float(TAPS));
			float a = float(i) * GOLDEN_ANGLE + spin;
			vec2 offset = vec2(cos(a), sin(a)) * r * radius_px * TEXTURE_PIXEL_SIZE;
			float w = 1.0 + rim * r * r;
			total += texture(TEXTURE, UV + offset).a * w;
			weight_sum += w;
		}
		float coverage = clamp(total / weight_sum * gain, 0.0, 1.0);
		COLOR = vec4(tint.rgb, coverage * tint.a);
	}
}

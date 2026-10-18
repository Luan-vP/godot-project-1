shader_type canvas_item;
render_mode blend_disabled;
// Out-of-focus blur for one FloaterDepth band, drawn offscreen.
//
// A disc blur, not a Gaussian: taps fill a circle on a golden-angle spiral,
// which is what turns a defocused speck into a soft-edged coin instead of a
// smudge. Outer taps are weighted up a little for the rim real bokeh has. The
// spiral is rotated per pixel so sparse taps read as grain, not banding.
//
// Only coverage is blurred. Colour comes later, from bokeh_glass.gdshader:
// every floater in a band is one colour, and it sidesteps premultiplied-alpha
// fringes at the edges.
//
// This is the expensive half of a band, so it runs at the band's buffer
// resolution — on a phone, a fraction of the screen's (see RenderScale) — and
// hands on what the glass needs per pixel, cheap to stretch back up:
//   r, g — the lean: coverage-weighted mean tap direction, in units of the
//          disc radius, clamped to the unit disc and mapped to 0..1
//   b    — the blurred coverage

uniform float radius_px = 0.0;
uniform float gain = 1.0;
uniform float rim = 0.6;

const int TAPS = 64;
const float GOLDEN_ANGLE = 2.39996323;

float hash(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	float coverage = 0.0;
	vec2 lean = vec2(0.0);
	if (radius_px < 0.75) {
		coverage = texture(TEXTURE, UV).a;
	} else {
		float spin = hash(FRAGCOORD.xy) * 6.2831853;
		float total = 0.0;
		float weight_sum = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float r = sqrt((float(i) + 0.5) / float(TAPS));
			float a = float(i) * GOLDEN_ANGLE + spin;
			vec2 direction = vec2(cos(a), sin(a)) * r;
			float w = 1.0 + rim * r * r;
			float sample_coverage = texture(TEXTURE, UV + direction * radius_px * TEXTURE_PIXEL_SIZE).a;
			total += sample_coverage * w;
			lean += direction * sample_coverage * w;
			weight_sum += w;
		}
		coverage = clamp(total / weight_sum * gain, 0.0, 1.0);
		lean *= gain / weight_sum;
	}
	// The glass bends fully from a lean of 0.4 on, so clamping to the unit
	// disc loses nothing it uses.
	float lean_length = length(lean);
	if (lean_length > 1.0) {
		lean /= lean_length;
	}
	COLOR = vec4(lean * 0.5 + 0.5, coverage, 1.0);
}

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
//
// A floater is glass, not paint, so the band is composited over what is behind
// it rather than blended on top:
// - The background is multiplied by the tint instead of mixed towards it, so
//   the dimming scales with how bright the background already is: obvious
//   over a bright sky, all but gone over a dark one, with no per-level tuning.
//   Mixing towards a dark tint does the opposite over black — it lightens.
// - The background is read slightly displaced. The taps already measure where
//   the blurred coverage sits within the disc; that lean points up the slope
//   of the coverage, and bending the read along it makes each floater a faint
//   lens, strongest at its soft edge and nothing at its flat core.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float radius_px = 0.0;
uniform float gain = 1.0;
uniform float rim = 0.6;
uniform vec4 tint : source_color = vec4(0.13, 0.14, 0.17, 0.5);
// Most the background behind a floater is bent, in screen pixels.
uniform float refraction_px = 0.0;

const int TAPS = 64;
const float GOLDEN_ANGLE = 2.39996323;
// Coverage at which the composite fully owns the pixel. Below it the glass is
// faded in, which is seamless: at low coverage it is the background, barely
// dimmed and barely bent.
const float OWNED_COVERAGE = 0.05;

float hash(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	float coverage = 0.0;
	// Coverage-weighted mean tap direction, in units of the disc radius.
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
	if (coverage <= 0.0) {
		discard;
	}

	// A half-covered disc leans about 0.4 of its radius; scale so that is the
	// full bend, and never past it however dense the band.
	vec2 bend = lean * 2.5 * refraction_px;
	float bend_length = length(bend);
	if (bend_length > refraction_px) {
		bend *= refraction_px / bend_length;
	}
	vec3 behind = texture(screen_texture, SCREEN_UV + bend * SCREEN_PIXEL_SIZE).rgb;

	vec3 glass = behind * mix(vec3(1.0), tint.rgb, coverage * tint.a);
	COLOR = vec4(glass, clamp(coverage / OWNED_COVERAGE, 0.0, 1.0));
}

shader_type canvas_item;
// Composites one FloaterDepth band's blur (bokeh.gdshader) over the screen,
// at the screen's own resolution. The blur arrives as lean and coverage; see
// there for the packing.
//
// A floater is glass, not paint, so the band is composited over what is behind
// it rather than blended on top:
// - The background is multiplied by the tint instead of mixed towards it, so
//   the dimming scales with how bright the background already is: obvious
//   over a bright sky, all but gone over a dark one, with no per-level tuning.
//   Mixing towards a dark tint does the opposite over black — it lightens.
// - The background is read slightly displaced. The blur measured where the
//   coverage sits within each disc; that lean points up the slope of the
//   coverage, and bending the read along it makes each floater a faint lens,
//   strongest at its soft edge and nothing at its flat core.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec4 tint : source_color = vec4(0.13, 0.14, 0.17, 0.5);
// Most the background behind a floater is bent, in screen pixels.
uniform float refraction_px = 0.0;

// Coverage at which the composite fully owns the pixel. Below it the glass is
// faded in, which is seamless: at low coverage it is the background, barely
// dimmed and barely bent.
const float OWNED_COVERAGE = 0.05;

void fragment() {
	vec4 blurred = texture(TEXTURE, UV);
	float coverage = blurred.b;
	if (coverage <= 0.0) {
		discard;
	}
	vec2 lean = blurred.rg * 2.0 - 1.0;

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

shader_type canvas_item;
render_mode blend_mix, unshaded;

// A floater is glass debris, not a sprite: it barely touches the light passing
// through it rather than replacing it. Every floater shares this one shader —
// only the baked alpha mask (TEXTURE, soft-edged per shape by
// FloaterShape.rasterize) and these instance uniforms differ per node, so N
// floaters cost one shared material plus a small per-instance quad each.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Colour and overall translucency. Alpha is how much of the background this
// floater's "glass" replaces at its most opaque point (its own mask peak),
// not a flat fill amount — see the mix below.
instance uniform vec4 tint : source_color = vec4(0.13, 0.14, 0.17, 0.55);

// Screen pixels the background is displaced by, at the mask's own edge — a
// cheap stand-in for a lens bending light more where the "glass" is thinnest.
instance uniform float refraction_px : hint_range(0.0, 6.0) = 1.6;

// Screen pixels the background is blurred over. Driven by Floater.radius, so
// bigger floaters — sitting closer to the lens and further from the retina —
// read as more out of focus, never sharp.
instance uniform float blur_px : hint_range(0.0, 16.0) = 0.0;

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	if (mask <= 0.003) {
		discard;
	}

	// Radial offset from the shape's own centre, scaled by the mask so the
	// bend fades out with the same softness as the edge itself.
	vec2 offset = (UV - vec2(0.5)) * refraction_px * mask * SCREEN_PIXEL_SIZE;
	vec2 sample_uv = SCREEN_UV + offset;

	vec3 background = texture(screen_texture, sample_uv).rgb;
	if (blur_px > 0.01) {
		vec2 tap_step = SCREEN_PIXEL_SIZE * blur_px;
		background += texture(screen_texture, sample_uv + vec2(tap_step.x, 0.0)).rgb;
		background += texture(screen_texture, sample_uv - vec2(tap_step.x, 0.0)).rgb;
		background += texture(screen_texture, sample_uv + vec2(0.0, tap_step.y)).rgb;
		background += texture(screen_texture, sample_uv - vec2(0.0, tap_step.y)).rgb;
		background *= 0.2;
	}

	// Multiplying the sampled background by the tint — rather than blending in
	// a flat colour — is what makes the dimming scale with how bright the
	// background already is: negligible over a near-black panorama, obvious
	// over a bright one, with no per-level tuning of either.
	COLOR = vec4(background * tint.rgb, mask * tint.a);
}

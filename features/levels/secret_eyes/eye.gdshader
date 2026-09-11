shader_type canvas_item;
render_mode blend_mix, unshaded;

// A floaty eye, drawn procedurally so the fluid can wobble it. UV (0,0)-(1,1)
// spans the whole creature; everything is measured from the centre outwards.

uniform vec4 sclera_color : source_color = vec4(0.937, 0.918, 0.859, 1.0);
uniform vec4 iris_color : source_color = vec4(0.396, 0.643, 0.639, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.078, 0.086, 0.129, 1.0);
uniform vec4 rim_color : source_color = vec4(0.235, 0.243, 0.353, 1.0);

uniform vec2 gaze = vec2(0.0, 0.0);
uniform float iris_radius : hint_range(0.05, 0.5) = 0.24;
uniform float pupil_radius : hint_range(0.02, 0.4) = 0.11;
uniform float lid : hint_range(0.0, 1.0) = 0.0;
uniform float squash : hint_range(0.2, 2.0) = 1.0;
uniform float wobble_amount : hint_range(0.0, 0.2) = 0.035;
uniform float wobble_speed : hint_range(0.0, 8.0) = 1.3;
uniform float seed = 0.0;
uniform float edge_softness : hint_range(0.001, 0.2) = 0.02;

float hash21(vec2 p) {
	vec2 h = fract(p * vec2(123.34, 456.21));
	h += dot(h, h + 45.32);
	return fract(h.x * h.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 frac = fract(p);
	vec2 weight = frac * frac * (3.0 - 2.0 * frac);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
}

void fragment() {
	vec2 centred = (UV - 0.5) * vec2(1.0, squash);
	float angle = atan(centred.y, centred.x);
	float distance_out = length(centred);

	// Breathing outline — the body is jelly, not a circle.
	float breathe = value_noise(vec2(angle * 1.6, TIME * wobble_speed + seed) * 1.7) - 0.5;
	float body_radius = 0.42 + breathe * wobble_amount;

	float body = smoothstep(body_radius, body_radius - edge_softness, distance_out);
	if (body <= 0.001) {
		discard;
	}

	vec2 iris_centre = clamp(gaze, vec2(-1.0), vec2(1.0)) * (body_radius - iris_radius) * 0.85;
	float iris_distance = length(centred - iris_centre);
	float iris = smoothstep(iris_radius, iris_radius - edge_softness, iris_distance);
	float pupil = smoothstep(pupil_radius, pupil_radius - edge_softness, iris_distance);

	// Fibres running out from the pupil keep the iris from looking flat.
	float fibres = value_noise(vec2(atan(
		centred.y - iris_centre.y,
		centred.x - iris_centre.x
	) * 9.0, iris_distance * 24.0));
	vec3 iris_shaded = iris_color.rgb * mix(0.78, 1.18, fibres);

	vec3 colour = mix(sclera_color.rgb, iris_shaded, iris);
	colour = mix(colour, pupil_color.rgb, pupil);

	// Wet rim and a single specular dot, offset against the gaze.
	float rim = smoothstep(body_radius - 0.075, body_radius, distance_out);
	colour = mix(colour, rim_color.rgb, rim * 0.65);
	float glint = smoothstep(0.075, 0.0, length(centred - iris_centre + vec2(0.085, 0.085)));
	colour = mix(colour, vec3(1.0), glint * 0.72);

	// Lids close from both sides, as a fraction of the body height.
	float lid_edge = (1.0 - lid) * body_radius;
	float lidded = smoothstep(lid_edge, lid_edge - edge_softness, abs(centred.y));
	float alpha = body * mix(1.0, lidded, step(0.001, lid));

	COLOR = vec4(colour, alpha * sclera_color.a);
}

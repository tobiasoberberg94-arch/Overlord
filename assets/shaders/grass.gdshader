// Prozedurales Gras und Wildblumen (scripts/world3d/grass.gd): Farbe aus Höhe am Halm,
// fleckige Wiesenfarbe je Ort, Wind, Licht scheint durch die Halme.
// Farbattribut: r = Höhe am Halm (0…1), g = Zufall je Halm, b = 1 bei Blütenblatt, a = Blütenfarbe.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_col : source_color = vec3(0.10, 0.17, 0.04);
uniform vec3 tip_col : source_color = vec3(0.42, 0.55, 0.16);
uniform vec3 dry_col : source_color = vec3(0.62, 0.56, 0.28);
uniform float wind = 0.18;

varying vec3 v_col;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float h = COLOR.r;
	float rnd = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float t = TIME * 1.8 + wp.x * 0.3 + wp.z * 0.23;
	float gust = 0.6 + 0.4 * sin(TIME * 0.35 + wp.x * 0.05);
	vec2 bend = vec2(sin(t) + 0.35 * sin(t * 2.7 + COLOR.g * 6.0), cos(t * 0.7) * 0.5) * wind * gust * h * h;
	VERTEX.xz += bend;
	VERTEX.y -= dot(bend, bend) * 0.5;
	float patch = sin(wp.x * 0.09 + 1.3) * cos(wp.z * 0.11) * 0.5 + 0.5;
	vec3 tip = mix(tip_col, dry_col, smoothstep(0.45, 0.95, patch) * 0.7);
	v_col = mix(base_col, tip, h) * (0.82 + 0.36 * rnd) * (0.9 + 0.2 * COLOR.g);
	if (COLOR.b > 0.5) {
		int k = int(COLOR.a * 4.99);
		vec3 pal[5] = vec3[](vec3(0.95, 0.93, 0.85), vec3(0.98, 0.82, 0.15), vec3(0.85, 0.12, 0.08),
				vec3(0.55, 0.35, 0.85), vec3(0.95, 0.55, 0.7));
		v_col = pal[k];
	}
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = v_col * 0.45;
}

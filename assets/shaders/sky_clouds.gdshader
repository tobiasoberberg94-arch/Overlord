// Himmel für alle Außenorte: Farbverlauf, Sonnenscheibe mit Halo, ziehende Wolkendecke (zwei fbm-Schichten,
// von der Sonne hinterleuchtet, unten dunkler), Dunst zum Horizont und Sterne bei Nacht.
shader_type sky;

uniform vec3 top_col : source_color = vec3(0.2, 0.42, 0.78);
uniform vec3 horizon_col : source_color = vec3(0.72, 0.78, 0.86);
uniform vec3 ground_col : source_color = vec3(0.25, 0.25, 0.27);
uniform vec3 cloud_col : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.45, 0.48, 0.56);
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed = 0.004;
uniform float energy = 1.0;
uniform float stars = 0.0;

// sinusfreier Hash (stabil auch bei großen Koordinaten – keine Rechteck-Artefakte)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 6; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_col, top_col, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) col = mix(horizon_col, ground_col, clamp(-h * 4.0, 0.0, 1.0));
	vec3 sdir = LIGHT0_DIRECTION;
	float sd = max(dot(d, sdir), 0.0);
	vec3 scol = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(0.0);
	// Halo + Scheibe
	col += scol * (pow(sd, 8.0) * 0.18 + pow(sd, 64.0) * 0.5);
	if (LIGHT0_ENABLED) col += scol * smoothstep(0.9994, 0.9998, sd) * 6.0;
	// Wolken: Projektion auf eine Wolkendecke
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18) * 1.4;
		vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(uv * 0.9 + wind) * 0.65 + fbm(uv * 2.6 - wind * 2.0) * 0.35;
		float c = smoothstep(1.0 - coverage - 0.12, 1.0 - coverage + 0.25, n);
		float dens = smoothstep(1.0 - coverage, 1.05, n);
		vec3 ccol = mix(cloud_col, cloud_shade, dens * 0.85);
		ccol += scol * pow(sd, 6.0) * (1.0 - dens) * 0.6;            // hinterleuchtete Ränder
		float fade = smoothstep(0.0, 0.18, h);                          // zum Horizont im Dunst
		col = mix(col, ccol * mix(0.6, 1.0, energy), c * fade);
	}
	// Dunst am Horizont
	col = mix(col, horizon_col, exp(-abs(h) * 9.0) * 0.55);
	// Sterne
	if (stars > 0.0 && h > 0.0) {
		vec2 sp = d.xz / (h + 0.3) * 160.0;
		float s = step(0.997, hash(floor(sp))) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(floor(sp)) * 30.0));
		col += vec3(s) * stars * smoothstep(0.05, 0.4, h);
	}
	COLOR = col * energy;
}

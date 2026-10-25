// Fließende Lava: erkaltete Krustenschollen (Voronoi-Zellen) treiben langsam auf der Glut, dazwischen glühende Fugen;
// in großen Feldern ist die Kruste aufgebrochen (offene Lava, gelber Kern nur in den heißesten Adern). Die Glut pulsiert
// leicht, die Kruste glänzt matt. Vorher: gleichmäßig grell leuchtende Fläche ohne Struktur (überstrahlte weiß).
shader_type spatial;
render_mode cull_disabled, specular_disabled;   // keine Himmelsspiegelung: bei flachem Blick färbte sie die Kruste hell

uniform vec3 hot : source_color = vec3(1.0, 0.3, 0.04);
uniform vec3 core : source_color = vec3(1.0, 0.78, 0.3);
uniform float glow = 1.1;
uniform float speed = 0.035;
uniform float scale = 0.16;      // Maßstab der Schollen (Kohlen in Feuerschalen: viel kleiner)
uniform float wobble = 0.03;     // Wabern der Oberfläche in Metern

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}
// Abstand zur nächsten Zellgrenze (F2 - F1): 0 an den Fugen zwischen den Schollen
float vor_edge(vec2 x) {
	vec2 n = floor(x), f = fract(x);
	float f1 = 8.0, f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float d = dot(r, r);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return sqrt(f2) - sqrt(f1);
}

varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 0.7 + wp.x * 0.3 + wp.z * 0.2) * wobble;
}
// Glutfarbe nach Hitze: dunkelrot → orange → gelb
vec3 ramp(float h) {
	vec3 c = mix(vec3(0.45, 0.05, 0.01), hot, smoothstep(0.25, 0.65, h));
	return mix(c, core, smoothstep(0.75, 1.0, h));
}

void fragment() {
	vec2 p = wp.xz * scale;
	vec2 flow = vec2(TIME * speed, TIME * speed * 0.6);
	float warp = fbm(p * 0.7 + flow) - 0.5;
	float e = vor_edge(p * 1.35 + flow * 1.3 + warp * 0.7);
	float n = fbm(p * 2.2 + flow * 2.0);
	// scharfe Risse zwischen den Schollen, daneben aufgeheizter Rand (dunkelrot)
	float seam = 1.0 - smoothstep(0.012, 0.07 + 0.03 * n, e);
	float rim = 1.0 - smoothstep(0.06, 0.24, e);
	// Die Risse liegen vertieft: bei flachem Blick verdecken die Schollen sie (sonst verschmilzt das Netz in der Ferne
	// zu einer gleichmäßig orangen Fläche)
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float occl = mix(0.2, 1.0, smoothstep(0.06, 0.6, ndv));
	// selten aufgebrochene Felder: offene Lava, in der dunkle Krustenfetzen treiben und helle Adern fließen
	float open_l = smoothstep(0.64, 0.8, fbm(p * 0.33 - flow * 0.6));
	vec2 q = vec2(p.x * 4.2, p.y * 1.6) + vec2(warp * 3.0, fbm(p * 1.1 - flow) * 2.0) - flow * 4.0;
	float veins = smoothstep(0.42, 0.68, fbm(q));
	float scraps = smoothstep(0.55, 0.62, fbm(p * 3.1 + flow * 2.5 + 7.0));          // treibende Krustenfetzen
	float open_heat = open_l * mix(0.22, 1.0, veins) * (1.0 - scraps * 0.85);
	float heat = max(max(seam * (0.75 + 0.3 * n) * occl, rim * 0.28 * occl), open_heat);
	heat = clamp(heat, 0.0, 1.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.3 + n * 6.0 + wp.x * 0.05);
	// Kruste fast schwarz (erstarrter Basalt, lineare Werte): unter den starken Lichtern am Lavastrom wurde sie sonst
	// zu einer gleichmäßig roten Fläche
	vec3 crust_col = vec3(0.016, 0.008, 0.006) * (0.7 + 0.6 * n);
	ALBEDO = mix(crust_col, vec3(0.05, 0.012, 0.004), heat);
	EMISSION = ramp(heat) * glow * heat * pulse + vec3(0.012, 0.003, 0.0) * (1.0 - heat);
	ROUGHNESS = mix(0.9, 0.5, heat);
}

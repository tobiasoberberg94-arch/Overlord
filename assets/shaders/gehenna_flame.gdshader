// Gehenna-Flamme: eine haushohe Wand aus Höllenfeuer (Story »Gehenna«). Vorhang aus mehreren Segmenten (QuadMesh,
// u0/u_len je Segment für durchgehende Flammen), Rauschen steigt nach oben: heißer, fast weißer Saum am Boden,
// Orange und Blutrot in der Mitte, oben zerfasert die Wand in schwarzen Rauch. `grow` hebt und senkt die Wand.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.82, 0.45);
uniform vec3 mid : source_color = vec3(1.0, 0.32, 0.05);
uniform vec3 deep : source_color = vec3(0.45, 0.03, 0.02);
uniform vec3 smoke : source_color = vec3(0.04, 0.01, 0.015);
uniform float intensity = 2.2;
uniform float speed = 0.55;
uniform float height_m = 24.0;
uniform float grow = 1.0;
instance uniform float u0 = 0.0;      // Anfang des Segments entlang der Wand (m)
instance uniform float u_len = 10.0;  // Länge des Segments (m)
instance uniform float layer = 0.0;   // zweite, versetzte Lage für Tiefe

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	float x = u0 + UV.x * u_len;                 // Meter entlang der Wand
	float y = (1.0 - UV.y) * height_m;            // Meter über dem Boden
	float t = TIME * speed + layer * 13.7;
	vec2 q = vec2(x * 0.16, y * 0.09);
	// Zungen: grobes Rauschen gegen die Höhe, darin feine, schneller steigende Fetzen
	float tongues = fbm(q * vec2(1.0, 0.55) + vec2(layer * 3.1, -t * 1.5));
	float detail = fbm(q * 2.6 + vec2(5.2, -t * 3.2));
	float g = max(grow, 0.001);
	float h = y / (height_m * g);                 // 0 unten … 1 oben (aktuelle Wandhöhe)
	float body = tongues * 0.72 + detail * 0.38 - h * 0.95 + 0.42 - layer * 0.08;
	float a = smoothstep(0.0, 0.18, body);
	a *= smoothstep(0.0, 0.6, y);                 // weicher Fuß im Boden
	a *= smoothstep(1.08, 0.75, h);               // oben ausfransen
	float heat = clamp(body * 1.9 + (1.0 - h) * 0.35 - 0.25, 0.0, 1.0);
	vec3 col = mix(smoke, deep, smoothstep(0.05, 0.32, heat));
	col = mix(col, mid, smoothstep(0.3, 0.65, heat));
	col = mix(col, core, smoothstep(0.7, 1.0, heat));
	float glow = mix(0.6, intensity, smoothstep(0.25, 1.0, heat));
	ALBEDO = col * glow;
	ALPHA = clamp(a * mix(0.75, 1.0, heat), 0.0, 1.0);
}

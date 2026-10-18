// Fernkulisse (scripts/world3d/horizon.gd): dichtes Kronendach aus „Baumkronen-Buckeln“, an steilen und
// hohen Stellen Fels, darüber Schnee (Bergketten). Nebel und Luftperspektive kommen vom Environment.
shader_type spatial;

uniform vec3 canopy : source_color = vec3(0.16, 0.24, 0.1);
uniform vec3 rock : source_color = vec3(0.38, 0.37, 0.36);
uniform vec3 snow : source_color = vec3(0.9, 0.92, 0.96);
uniform float mountain = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// Zellrauschen: runde Kronen
float crowns(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
		d = min(d, length(g + o - f));
	}
	return d;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float cr = crowns(p * 0.12);
	float big = vnoise(p * 0.01);
	vec3 col = canopy * mix(0.55, 1.25, 1.0 - cr) * mix(0.75, 1.2, big);
	col = mix(col, col * vec3(1.25, 1.05, 0.7), smoothstep(0.6, 0.9, vnoise(p * 0.004)) * 0.6);   // Herbstflecken
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float rk = clamp(smoothstep(0.35, 0.6, slope) + smoothstep(120.0, 220.0, wpos.y) * mountain, 0.0, 1.0);
	col = mix(col, rock * mix(0.7, 1.1, vnoise(p * 0.05)), rk);
	float sn = smoothstep(230.0, 300.0, wpos.y + vnoise(p * 0.02) * 40.0) * mountain * (1.0 - smoothstep(0.55, 0.8, slope));
	col = mix(col, snow, sn);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	// Kronen-Relief über die Normale
	vec2 e = vec2(0.6, 0.0);
	float hx = crowns((p + e.xy) * 0.12) - crowns((p - e.xy) * 0.12);
	float hz = crowns((p + e.yx) * 0.12) - crowns((p - e.yx) * 0.12);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(hx, 0.0, hz, 0.0)).xyz * 1.5 * (1.0 - rk));
}

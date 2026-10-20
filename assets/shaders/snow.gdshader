// Schnee aus Fotoscans (Poly Haven snow_02) in Weltkoordinaten: zweifach mit unterschiedlicher Größe/Drehung
// gelesen und per Rauschen gemischt (keine sichtbare Kachelung), großflächige Windgangeln und bläuliche Mulden,
// Glitzern einzelner Eiskristalle – blickabhängig, funkelt beim Bewegen, nur in der Nähe.
shader_type spatial;

uniform sampler2D snow_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tex = false;
uniform float size = 2.6;
uniform vec3 snow : source_color = vec3(0.93, 0.96, 1.0);
uniform vec3 shade : source_color = vec3(0.68, 0.78, 0.93);
uniform float sparkle = 1.0;

varying vec3 wp;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vn(p); p = p * 2.03 + 7.1; a *= 0.5; }
	return v;
}
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float macro = fbm(p * 0.035);
	float m_tile = smoothstep(0.3, 0.7, fbm(p * 0.06 + 3.0));
	vec3 col;
	vec3 nm = vec3(0.5, 0.5, 1.0);
	float rg = 0.8;
	if (has_tex) {
		vec2 ua = p / size;
		vec2 ub = (rot(1.3) * p) / (size * 1.9) + 0.37;
		col = mix(texture(snow_diff, ua).rgb, texture(snow_diff, ub).rgb, m_tile);
		col = col / max(dot(col, vec3(0.2126, 0.7152, 0.0722)), 0.05) * 0.78;      // auf Schneehelligkeit normieren
		nm = mix(texture(snow_nor, ua).rgb, texture(snow_nor, ub).rgb, m_tile);
		rg = mix(texture(snow_rough, ua).r, texture(snow_rough, ub).r, m_tile);
	} else {
		float n = vn(p * 0.7) * 0.6 + vn(p * 3.0) * 0.4;
		col = vec3(0.8 + n * 0.1);
		nm = normalize(vec3((vn(p * 6.0) - 0.5) * 0.4 + 0.5, (vn(p.yx * 6.0) - 0.5) * 0.4 + 0.5, 1.0));
	}
	// Windgangeln (lang gezogene Rippen) und bläuliche Mulden
	float ripple = sin(dot(p, vec2(0.83, 0.55)) * 2.4 + fbm(p * 0.25) * 6.0) * 0.5 + 0.5;
	col *= mix(1.0, 0.94, ripple * 0.5);
	col *= mix(shade, snow, smoothstep(0.28, 0.72, macro));
	ALBEDO = clamp(col, vec3(0.0), vec3(0.92));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = clamp(rg * 0.85 + 0.1, 0.35, 0.95);
	SPECULAR = 0.45;
	// Glitzern: Zellen von 2–3 cm, je nach Blickrichtung an/aus
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec3 cell = floor(wp * 38.0);
	float h = hash3(cell);
	float tw = fract(h * 91.7 + dot(vw, vec3(3.7, 2.9, 4.3)) * 1.5);
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float g = step(0.9975, h) * smoothstep(0.82, 0.98, tw) * (1.0 - smoothstep(6.0, 22.0, dist));
	EMISSION = vec3(0.85, 0.92, 1.0) * g * 1.6 * sparkle;
}

// Dunkles Junges (Story »Katze-Ebene«): nasse, fast schwarze Haut mit grünviolettem Schimmer, Poren und Beulen.
// mode 0 = Körper (Beulen wabern langsam), 1 = Tentakel (winden sich, Ausschlag wächst zur Spitze), 2 = Beine.
shader_type spatial;

uniform int mode = 0;
uniform vec3 base_col : source_color = vec3(0.03, 0.022, 0.03);
uniform vec3 sheen_col : source_color = vec3(0.25, 0.4, 0.14);
uniform vec3 vein_col : source_color = vec3(0.16, 0.02, 0.05);
uniform float lump = 0.35;
uniform float writhe = 1.0;
uniform float pulse = 0.0;            // > 0: Körper bläht sich (Brüllen)
instance uniform float phase = 0.0;
instance uniform float t_len = 5.0;    // Länge des Tentakels (CylinderMesh-Höhe)

varying vec3 lp;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float vnoise3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

void vertex() {
	lp = VERTEX;
	if (mode == 0) {
		float n = vnoise3(VERTEX * 1.4 + vec3(TIME * 0.22 + phase)) * 0.7 + vnoise3(VERTEX * 3.6 - vec3(TIME * 0.35)) * 0.3;
		VERTEX += NORMAL * ((n - 0.42) * lump + pulse * 0.12);
	} else if (mode == 1) {
		float s = clamp(VERTEX.y / t_len + 0.5, 0.0, 1.0);    // 0 Ansatz … 1 Spitze
		float w = s * s * (3.0 - 2.0 * s);
		float t = TIME * 1.15 + phase;
		VERTEX.x += (sin(t + s * 3.6) * 0.85 + sin(t * 1.9 + s * 7.5) * 0.25) * w * writhe * t_len * 0.22;
		VERTEX.z += (cos(t * 0.8 + s * 3.1 + phase * 1.7) * 0.8 + sin(t * 2.3 + s * 6.0) * 0.2) * w * writhe * t_len * 0.22;
		VERTEX.y -= w * 0.12 * t_len * (0.5 + 0.5 * sin(t * 0.7 + phase));
	} else {
		float n = vnoise3(VERTEX * 2.5 + vec3(phase));
		VERTEX += NORMAL * (n - 0.5) * 0.12;
	}
}

void fragment() {
	float n = vnoise3(lp * 5.0);
	float n2 = vnoise3(lp * 17.0 + vec3(3.1));
	float vein = 1.0 - smoothstep(0.0, 0.05, abs(vnoise3(lp * 2.2 + vec3(7.7)) - 0.5));
	vec3 col = base_col * (0.65 + 0.7 * n);
	col = mix(col, vein_col, vein * 0.55);
	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.45, n2);           // nass glänzend, stellenweise matt
	SPECULAR = 0.65;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = sheen_col * fres * 0.18 + vein_col * vein * 0.08;
	NORMAL_MAP = normalize(vec3((n - 0.5) * 1.2, (n2 - 0.5) * 1.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.4;
}

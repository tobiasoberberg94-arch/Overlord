// Gletschereis: dunkles Tiefenblau im Inneren, helle Ränder (Fresnel), Luftblasen und feine Risse in Schichten,
// glatte Oberfläche mit leichten Facetten und Klarlack-Glanz, Pulverschnee auf Oberseiten; schwaches Durchscheinen
// statt Eigenleuchten.
shader_type spatial;
uniform vec3 deep : source_color = vec3(0.025, 0.13, 0.26);
uniform vec3 surf : source_color = vec3(0.5, 0.7, 0.86);
uniform float snow_cover = 0.7;
// vereister Fels: Originaltextur und Normalen des Felsens bleiben als Struktur unter dem Eis sichtbar
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_base = false;
uniform bool has_nrm = false;
uniform float crystal = 0.0;     // 1 = Eiskristall: Längsmaserung, Spitze heller, Kanten glimmen
uniform float patchy = 0.0;      // 1 = Schnee in Verwehungen statt auf allen Oberseiten (gefrorener See)
uniform float glow = 0.0;        // magische Kristalle: schwaches Leuchten von innen

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float vn(vec3 p) { vec3 i = floor(p), f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z); }

varying vec3 wp;
varying vec3 wn;
varying float lh;
void vertex() {
	lh = VERTEX.y * length(MODEL_MATRIX[1].xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float n = vn(wp * 0.45) * 0.55 + vn(wp * 1.7) * 0.3 + vn(wp * 6.0) * 0.15;
	// Schichtung (waagerechte Bänder) und Risse
	float band = smoothstep(0.35, 0.65, vn(vec3(wp.x * 0.15, wp.y * 2.2, wp.z * 0.15)));
	float c1 = vn(wp * 0.9 + 3.1) * 0.78 + vn(wp * 3.7 + 1.3) * 0.22;
	float crack = (1.0 - smoothstep(0.0, 0.008, abs(c1 - 0.5))) * smoothstep(0.45, 0.75, vn(wp * 0.3));
	float bub = step(0.994, hash(floor(wp * 22.0))) * (1.0 - fres) * (1.0 - patchy);
	vec3 col = mix(deep, surf, clamp(fres * 0.85 + n * 0.25 + band * 0.1, 0.0, 1.0));
	if (has_base) {
		// Felsstruktur unter klarem Eis: dunkle Fugen bleiben dunkel, helle Flächen werden bläulich-weiß
		vec3 b = texture(base_tex, UV).rgb;
		float bl = dot(b, vec3(0.299, 0.587, 0.114));
		vec3 under = mix(deep * 1.3, mix(surf, vec3(0.78, 0.86, 0.94), 0.35), smoothstep(0.08, 0.55, bl));
		col = mix(under, col, clamp(fres * 0.7, 0.0, 0.6));
	}
	if (crystal > 0.0) {
		// Längsmaserung entlang der Kristallachse, zur Spitze heller und klarer
		float streak = vn(vec3(wp.x * 5.0, lh * 0.35, wp.z * 5.0));
		col = mix(col, col * mix(0.75, 1.25, streak), crystal);
		col = mix(col, mix(surf, vec3(0.85, 0.95, 1.0), 0.45), smoothstep(1.0, 7.0, lh) * 0.35 * crystal);
		col += vec3(0.55, 0.75, 0.9) * pow(fres, 1.6) * 0.35 * crystal;
	}
	col *= mix(0.6, 1.08, smoothstep(0.0, 4.5, lh));                 // am Fuß dunkler, Spitzen heller
	col += vec3(0.4, 0.55, 0.65) * (crack * 0.12 + bub * 0.25);
	// Pulverschnee auf Oberseiten
	float up = smoothstep(0.55, 0.85, wn.y + (n - 0.5) * 0.3);
	if (patchy > 0.0) {
		// Verwehungen: große, weiche Flecken mit zerfaserten Rändern, dazwischen blankes Eis
		float drift = vn(wp * 0.16) * 0.6 + vn(wp * 0.55) * 0.28 + vn(wp * 2.4) * 0.12;
		up *= mix(1.0, smoothstep(0.5, 0.62, drift), patchy);
	}
	col = mix(col, vec3(0.86, 0.9, 0.96), up * snow_cover);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.06, 0.22, n), 0.85, up * snow_cover);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	CLEARCOAT = 1.0 - up * snow_cover;
	CLEARCOAT_ROUGHNESS = 0.04;
	// Facetten: leichte Normalenstörung
	vec3 e = vec3(0.07, 0.0, 0.0);
	float s0 = vn(wp * 1.3);
	vec3 gr = vec3(vn(wp * 1.3 + e.xyy) - s0, vn(wp * 1.3 + e.yxy) - s0, vn(wp * 1.3 + e.yyx) - s0) / 0.07;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(gr * 0.04, 0.0)).xyz);
	if (has_nrm) {
		NORMAL_MAP = texture(base_nrm, UV).rgb;
		NORMAL_MAP_DEPTH = 0.9;
	}
	BACKLIGHT = deep * 1.6;
	EMISSION = deep * 0.06 * (1.0 - fres) + surf * glow * (0.35 + 0.65 * fres);
	// Glitzern im Schnee (blickabhängig, funkelt beim Gehen)
	float glint = step(0.9965, hash(floor(wp * 34.0) + floor(VIEW * 6.0) * 7.0));
	EMISSION += vec3(0.9, 0.95, 1.0) * glint * up * snow_cover * 0.6;
}

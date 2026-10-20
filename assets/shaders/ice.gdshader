// Gletschereis: dunkles Tiefenblau im Inneren, helle Ränder (Fresnel), Luftblasen und feine Risse in Schichten,
// glatte Oberfläche mit leichten Facetten und Klarlack-Glanz, Pulverschnee auf Oberseiten; schwaches Durchscheinen
// statt Eigenleuchten.
shader_type spatial;
uniform vec3 deep : source_color = vec3(0.025, 0.13, 0.26);
uniform vec3 surf : source_color = vec3(0.5, 0.7, 0.86);
uniform float snow_cover = 0.7;

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
	float c1 = vn(wp * 0.9 + 3.1);
	float crack = (1.0 - smoothstep(0.0, 0.008, abs(c1 - 0.5))) * smoothstep(0.45, 0.75, vn(wp * 0.3));
	float bub = step(0.994, hash(floor(wp * 22.0))) * (1.0 - fres);
	vec3 col = mix(deep, surf, clamp(fres * 0.85 + n * 0.25 + band * 0.1, 0.0, 1.0));
	col *= mix(0.6, 1.08, smoothstep(0.0, 4.5, lh));                 // am Fuß dunkler, Spitzen heller
	col += vec3(0.4, 0.55, 0.65) * (crack * 0.12 + bub * 0.25);
	// Pulverschnee auf Oberseiten
	float up = smoothstep(0.55, 0.85, wn.y + (n - 0.5) * 0.3);
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
	BACKLIGHT = deep * 1.6;
	EMISSION = deep * 0.06 * (1.0 - fres);
}

// Reif/Schnee als Überzug: nach oben zeigende Flächen werden weiß bestäubt. breakup > 0 lässt den Schnee
// fleckig aufbrechen (Steinplatten, Sockel: der Stein schaut zwischen den Verwehungen hervor).
shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform float amount = 0.7;
uniform float breakup = 0.0;
varying vec3 wn;
varying vec3 wp;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float vn(vec3 p) { vec3 i = floor(p), f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z); }

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float up = smoothstep(0.25, 0.75, wn.y);
	float a = up * amount;
	if (breakup > 0.0) {
		float n = vn(wp * 0.55) * 0.55 + vn(wp * 2.1) * 0.3 + vn(wp * 7.0) * 0.15;
		a *= smoothstep(breakup - 0.12, breakup + 0.12, n);
	}
	ALBEDO = vec3(0.86, 0.9, 0.96);
	ALPHA = a;
	ROUGHNESS = 0.8;
}

// Fließende Lava: zwei verschobene Rauschebenen, glühende Risse, dunkle Kruste, leichtes Wabern.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.06);
uniform vec3 core : source_color = vec3(1.0, 0.85, 0.35);
uniform vec3 crust : source_color = vec3(0.09, 0.03, 0.02);
uniform float glow = 4.0;
uniform float speed = 0.04;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 0.7 + wp.x * 0.3 + wp.z * 0.2) * 0.03;
}
void fragment() {
	vec2 p = wp.xz * 0.12;
	float n1 = fbm(p + vec2(TIME * speed, TIME * speed * 0.6));
	float n2 = fbm(p * 1.7 - vec2(TIME * speed * 0.8, 0.0));
	float n = n1 * 0.6 + n2 * 0.4;
	float cracks = smoothstep(0.42, 0.62, n);
	vec3 c = mix(crust, hot, cracks);
	c = mix(c, core, smoothstep(0.66, 0.8, n));
	ALBEDO = c * 0.3;
	EMISSION = c * glow * (0.35 + cracks);
	ROUGHNESS = mix(0.95, 0.4, cracks);
}

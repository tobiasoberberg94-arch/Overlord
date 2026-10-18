// Gletschereis: kaltes Blau, Tiefe über Fresnel, Risse, glänzend.
shader_type spatial;
uniform vec3 deep : source_color = vec3(0.12, 0.38, 0.62);
uniform vec3 surf : source_color = vec3(0.72, 0.9, 1.0);
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vn(vec3 p) { vec3 i = floor(p), f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z); }
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float n = vn(wp * 0.6) * 0.7 + vn(wp * 2.3) * 0.3;
	float crack = smoothstep(0.48, 0.5, n) - smoothstep(0.5, 0.52, n);
	vec3 c = mix(deep, surf, clamp(fres + n * 0.35, 0.0, 1.0));
	ALBEDO = c + crack * 0.4;
	ROUGHNESS = 0.08 + n * 0.15;
	METALLIC = 0.1;
	SPECULAR = 0.9;
	EMISSION = deep * 0.25 * (1.0 - fres) + vec3(0.6, 0.85, 1.0) * fres * 0.35;
}

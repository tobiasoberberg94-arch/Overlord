// Schnee: weiß mit bläulichen Mulden, feine Körnung, Glitzern im Licht.
shader_type spatial;
uniform vec3 snow : source_color = vec3(0.93, 0.96, 1.0);
uniform vec3 shade : source_color = vec3(0.62, 0.74, 0.92);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vn(wp.xz * 0.15) * 0.6 + vn(wp.xz * 0.7) * 0.3 + vn(wp.xz * 3.0) * 0.1;
	ALBEDO = mix(shade, snow, smoothstep(0.25, 0.75, n));
	ROUGHNESS = 0.75;
	float g = hash(floor(wp.xz * 40.0));
	SPECULAR = 0.5;
	EMISSION = vec3(step(0.997, g)) * 0.6;
	NORMAL_MAP = normalize(vec3((vn(wp.xz * 6.0) - 0.5) * 0.4 + 0.5, (vn(wp.zx * 6.0) - 0.5) * 0.4 + 0.5, 1.0));
}

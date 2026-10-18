// Wasserflächen (Sumpf, Teiche, Seen): zwei laufende Wellen-Normalen, Fresnel-Spiegelung des Himmels,
// Lichtbrechung über den Bildschirm-Hintergrund, Tiefenfärbung (je tiefer, desto trüber) und Schaum am Ufer.
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec3 shallow : source_color = vec3(0.16, 0.22, 0.12);
uniform vec3 deep : source_color = vec3(0.03, 0.06, 0.04);
uniform float murk = 1.6;            // wie schnell das Wasser mit der Tiefe trüb wird
uniform float wave_speed = 0.035;
uniform float refraction = 0.025;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
vec2 grad(vec2 p) {
	float e = 0.05;
	return vec2(vnoise(p + vec2(e, 0)) - vnoise(p - vec2(e, 0)), vnoise(p + vec2(0, e)) - vnoise(p - vec2(0, e))) / (2.0 * e);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 g = grad(p * 0.35 + TIME * wave_speed * vec2(1.0, 0.6)) * 0.6 + grad(p * 1.3 - TIME * wave_speed * 2.2 * vec2(0.4, 1.0)) * 0.25;
	vec3 n_world = normalize(vec3(-g.x, 6.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	// Tiefe des Wassers an diesem Pixel
	float d_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d_raw, 1.0);
	vec4 v = INV_PROJECTION_MATRIX * ndc;
	float scene_depth = -v.z / v.w;
	float water_depth = clamp(scene_depth - (-VERTEX.z), 0.0, 20.0);
	float t = 1.0 - exp(-water_depth * murk);
	vec2 off = g * refraction * clamp(water_depth, 0.0, 1.0);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	vec3 col = mix(behind * shallow * 2.2, deep, t);
	// Schaum/Schlick am Ufer
	float foam = (1.0 - smoothstep(0.0, 0.18, water_depth)) * (0.5 + 0.5 * vnoise(p * 6.0 + TIME * 0.3));
	col = mix(col, vec3(0.42, 0.44, 0.36), foam * 0.45);
	ALBEDO = col;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.0);
	ALPHA = 1.0;
	RIM = fres * 0.25;
}

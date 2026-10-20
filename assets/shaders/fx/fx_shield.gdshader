// Schutzbarriere: Kugel mit Wabenmuster, Fresnel-Rand und Einschlagwelle; zerspringt bei crack → 1.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
instance uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.38, 1.0);
instance uniform float energy = 2.0;
instance uniform float fade = 1.0;
instance uniform vec3 hit_dir = vec3(0.0, 0.0, 1.0);
instance uniform float hit_t = 0.0;        // 1 = gerade getroffen, klingt auf 0 ab
instance uniform float crack = 0.0;        // 0 = intakt … 1 = zersprungen

varying vec3 obj;

float hex_edge(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void vertex() {
	obj = normalize(VERTEX);
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.4);
	float e = hex_edge(UV * vec2(28.0, 14.0));
	float hex = 1.0 - smoothstep(0.0, 0.09, e);
	float d = acos(clamp(dot(obj, normalize(hit_dir)), -1.0, 1.0));
	float wave = (1.0 - hit_t) * 2.6;
	float ripple = exp(-pow((d - wave) * 4.0, 2.0)) * hit_t + exp(-d * 5.0) * hit_t * hit_t;
	float n = texture(noise_tex, UV * vec2(6.0, 3.0) + vec2(TIME * 0.1, TIME * 0.05)).r;
	float sweep = smoothstep(0.92, 1.0, fract(UV.y * 1.5 - TIME * 0.35)) * 0.4;
	float cr = 0.0;
	if (crack > 0.0) {
		float c = texture(noise_tex, UV * vec2(5.0, 2.5)).b;
		cr = smoothstep(0.82, 0.95, c) * crack * 3.0;
	}
	float a = fres * 0.75 + hex * (0.07 + fres * 0.55 + ripple * 1.5) * (0.6 + 0.6 * n) + ripple * 0.9 + sweep * hex * 0.6 + 0.015 + cr;
	a *= fade * (1.0 - smoothstep(0.6, 1.0, crack) * (1.0 - cr));
	ALBEDO = mix(tint.rgb, vec3(1.0), clamp(ripple * 0.6 + cr * 0.3, 0.0, 1.0)) * energy * (1.0 + ripple * 2.0);
	ALPHA = clamp(a, 0.0, 1.0);
}

// Negative Energie: schwarzer, wirbelnder Kern mit violett glühendem Rand (deckend – additiv kann nicht schwärzen).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float wobble = 0.1;
instance uniform vec4 core_col : source_color = vec4(0.02, 0.0, 0.04, 1.0);
instance uniform vec4 rim_col : source_color = vec4(0.62, 0.2, 1.0, 1.0);
instance uniform float energy = 4.0;
instance uniform float fade = 1.0;

varying vec3 obj;

vec2 sph(vec3 d) {
	return vec2(atan(d.x, d.z) / 6.2831853 + 0.5, d.y * 0.5 + 0.5);
}

void vertex() {
	obj = normalize(VERTEX);
	float n = textureLod(noise_tex, sph(obj) * vec2(2.0, 1.0) + vec2(-TIME * 0.4, 0.0), 0.0).r;
	VERTEX += NORMAL * (n - 0.5) * wobble;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec2 uv = sph(obj);
	float swirl = texture(noise_tex, uv * vec2(4.0, 2.0) + vec2(TIME * 0.5, TIME * 0.2)).b;
	float rim = clamp(fres + smoothstep(0.7, 0.95, swirl) * 0.35, 0.0, 1.0);
	ALBEDO = mix(core_col.rgb, rim_col.rgb * energy, rim);
	ALPHA = clamp((0.85 + fres * 0.15) * fade, 0.0, 1.0);
}

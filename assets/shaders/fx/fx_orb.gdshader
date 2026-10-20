// Energiekugel (Feuerkugel-Kern, Eis-, Blut-, Heiligkugel, Herz beim Herzgriff): additiv, HDR,
// wirbelndes Rauschen über die Kugel, heller Kern, farbiger Rand; optional pulsierende Adern.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float noise_scale = 2.0;
uniform float noise_speed = 0.6;
uniform float wobble = 0.08;
uniform float rim_power = 2.0;
uniform float veins = 0.0;
instance uniform vec4 core_col : source_color = vec4(1.0, 0.9, 0.55, 1.0);
instance uniform vec4 rim_col : source_color = vec4(1.0, 0.3, 0.05, 1.0);
instance uniform float energy = 4.0;
instance uniform float fade = 1.0;
instance uniform float pulse = 0.0;

varying vec3 obj;

vec2 sph(vec3 d) {
	return vec2(atan(d.x, d.z) / 6.2831853 + 0.5, d.y * 0.5 + 0.5);
}

void vertex() {
	obj = normalize(VERTEX);
	float n = textureLod(noise_tex, sph(obj) * vec2(2.0, 1.0) + vec2(TIME * 0.3, 0.0), 0.0).r;
	VERTEX += NORMAL * (n - 0.5) * wobble * (1.0 + pulse);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec2 uv = sph(obj);
	float n = texture(noise_tex, uv * vec2(noise_scale * 2.0, noise_scale) + vec2(TIME * noise_speed, -TIME * noise_speed * 1.3)).r;
	float n2 = texture(noise_tex, uv * vec2(noise_scale * 4.0, noise_scale * 2.0) - vec2(TIME * noise_speed * 1.7, TIME * noise_speed * 0.4)).g;
	float heat = clamp((1.0 - fres) * 0.75 + (n - 0.5) * 0.7 + (n2 - 0.5) * 0.35, 0.0, 1.0);
	vec3 c = mix(rim_col.rgb, core_col.rgb, heat);
	if (veins > 0.0) {
		float v = texture(noise_tex, uv * vec2(3.0, 1.5) + vec2(0.0, TIME * 0.05)).b;
		c = mix(c, rim_col.rgb * 0.25, smoothstep(0.75, 0.95, v) * veins);
	}
	ALBEDO = c * energy * (0.75 + heat * 0.6 + pulse * 0.8);
	ALPHA = clamp((0.3 + 0.7 * heat + fres * 0.4) * fade, 0.0, 1.0);
}

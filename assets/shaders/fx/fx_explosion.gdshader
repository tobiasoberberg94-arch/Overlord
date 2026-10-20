// Explosion: aufquellende, verformte Kugel; Farbe von Weißglut über Orange und Rot zu Rauch, löst sich zum Ende
// in Rauchfetzen auf. t (0…1) = Lebenszeit, die Farbstufen kommen als Instanz-Parameter (Feuer, Eis, Heilig, Blut).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
instance uniform float t = 0.0;
instance uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.75, 1.0);
instance uniform vec4 mid : source_color = vec4(1.0, 0.5, 0.1, 1.0);
instance uniform vec4 cool : source_color = vec4(0.55, 0.08, 0.02, 1.0);
instance uniform vec4 smoke : source_color = vec4(0.12, 0.1, 0.09, 1.0);
instance uniform float energy = 6.0;
instance uniform float seed = 0.0;

varying vec3 obj;

vec2 sph(vec3 d) {
	return vec2(atan(d.x, d.z) / 6.2831853 + 0.5, d.y * 0.5 + 0.5);
}

void vertex() {
	obj = normalize(VERTEX);
	vec2 uv = sph(obj) * vec2(3.0, 1.5) + vec2(seed, seed * 0.7);
	float n = textureLod(noise_tex, uv, 0.0).r * 0.65 + textureLod(noise_tex, uv * 2.0 + t * 0.4, 0.0).g * 0.35;
	VERTEX += NORMAL * (n - 0.45) * (0.35 + t * 0.5);
}

void fragment() {
	vec2 uv = sph(obj) * vec2(3.0, 1.5) + vec2(seed, seed * 0.7);
	float n = texture(noise_tex, uv + vec2(0.0, -t * 0.6)).r;
	float n2 = texture(noise_tex, uv * 2.7 - vec2(t * 0.8, 0.0)).g;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float heat = clamp(1.15 - t * 1.6 + (n - 0.5) * 0.9 + (n2 - 0.5) * 0.4 - fres * 0.35, 0.0, 1.0);
	vec3 c;
	if (heat > 0.66) {
		c = mix(mid.rgb, hot.rgb, (heat - 0.66) / 0.34);
	} else if (heat > 0.33) {
		c = mix(cool.rgb, mid.rgb, (heat - 0.33) / 0.33);
	} else {
		c = mix(smoke.rgb, cool.rgb, heat / 0.33);
	}
	float glow = heat * heat * energy;
	ALBEDO = c * (0.35 + glow);
	float dissolve = smoothstep(t * 1.05 - 0.15, t * 1.05 + 0.05, n * 0.8 + n2 * 0.3);
	ALPHA = clamp(dissolve * (1.0 - fres * 0.5) * (1.0 - smoothstep(0.85, 1.0, t)) * smoothstep(0.02, 0.3, heat + 0.12 - t * 0.1), 0.0, 1.0);
}

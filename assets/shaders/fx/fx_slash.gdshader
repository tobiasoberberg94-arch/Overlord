// Hiebspur: gebogenes Band entlang der Klingenbahn (UV.x = Verlauf des Schwungs, UV.y = innen → Klingenspitze).
// head läuft während der aktiven Angriffsphase von 0 nach 1 (+ Schweiflänge); dahinter verblasst die Spur.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
instance uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
instance uniform float head = 0.0;
instance uniform float tail = 0.55;
instance uniform float energy = 3.0;
instance uniform float fade = 1.0;

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float behind = head - x;
	float trail = smoothstep(tail, 0.0, behind) * smoothstep(-0.03, 0.0, behind);
	float body = smoothstep(0.0, 0.45, y) * (0.28 + 0.72 * y * y);
	float core = exp(-pow((y - 0.88) / 0.075, 2.0));
	float streak = texture(noise_tex, vec2(x * 2.5 - head * 1.8, y * 0.7)).r;
	float fine = texture(noise_tex, vec2(x * 7.0 - head * 4.0, y * 2.5)).g;
	// am Kopf der Spur am hellsten
	float lead = smoothstep(0.25, 0.0, behind) * smoothstep(-0.03, 0.0, behind);
	float a = trail * (body * 0.72 + core) * (0.6 + 0.5 * streak) * (0.85 + 0.3 * fine) + lead * core * 0.6;
	a *= smoothstep(1.0, 0.97, y);
	vec3 c = mix(tint.rgb, vec3(1.0), clamp(core * trail * 0.6 + lead * 0.3, 0.0, 1.0));
	ALBEDO = c * energy * (0.8 + core * 1.6 + lead * 0.8);
	ALPHA = clamp(a * fade * tint.a, 0.0, 1.0);
}

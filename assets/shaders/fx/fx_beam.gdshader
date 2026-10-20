// Lichtsäule / Strahl (Läuterungslanze, Superrang-Zauber, Ki-Stoß): offener Zylinder, heller Kern zur Kamera hin,
// längs laufendes Rauschen, weich auslaufende Enden.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
instance uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.6, 1.0);
instance uniform float energy = 5.0;
instance uniform float fade = 1.0;
instance uniform float scroll = 2.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float core = pow(facing, 4.0);
	float n = texture(noise_tex, vec2(UV.x * 3.0, UV.y * 2.0 - TIME * scroll)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 6.0 + 0.3, UV.y * 5.0 - TIME * scroll * 1.6)).g;
	float ends = smoothstep(0.0, 0.06, UV.y) * smoothstep(1.0, 0.8, UV.y);
	float a = (core * (0.5 + 0.45 * n) + facing * 0.35 * (n * 0.7 + n2 * 0.5)) * ends * fade;
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.55) * energy * (0.45 + n * 0.6 + n2 * 0.35);
	ALPHA = clamp(a * tint.a, 0.0, 1.0);
}

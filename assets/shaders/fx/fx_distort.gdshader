// Hitzeflimmern und Druckwellen: bricht das Bild hinter einer Kugel/Ringfläche (Bildschirm-Textur).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform float strength = 0.035;
instance uniform float fade = 1.0;

void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float m = sin(clamp(f, 0.0, 1.0) * 3.14159);
	vec2 off = NORMAL.xy * strength * m * fade;
	ALBEDO = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	ALPHA = smoothstep(0.0, 0.25, m) * fade;
}

// Blitz-Band (zur Kamera gedrehter Streifen, Form kommt vom Skript): weißer Kern, farbiger Schein.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform vec4 tint : source_color = vec4(0.55, 0.75, 1.0, 1.0);
instance uniform float energy = 6.0;
instance uniform float fade = 1.0;

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	float core = exp(-d * d * 40.0);
	float halo = exp(-d * d * 5.0);
	ALBEDO = (vec3(1.0) * core + tint.rgb * halo * 0.8) * energy;
	ALPHA = clamp((core + halo * 0.55) * fade, 0.0, 1.0);
}

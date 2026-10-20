// Nachbild (Sprünge, Blitzschritt, Vampirsprung): leuchtende Silhouette mit Fresnel-Rand, verblasst.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

instance uniform vec4 tint : source_color = vec4(0.7, 0.3, 1.0, 1.0);
instance uniform float fade = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb * (0.25 + fres * 2.4);
	ALPHA = clamp(fade * (0.18 + fres * 0.8), 0.0, 1.0);
}

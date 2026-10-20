// Leuchtende Bodenmarken (Magiekreise, Druckringe, Glut): additiv, HDR – leuchten im Dunkeln und erzeugen Glanz.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://assets/shaders/fx/fx_ground.gdshaderinc"

void fragment() {
	vec4 c = ground_pattern(gp, TIME);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}

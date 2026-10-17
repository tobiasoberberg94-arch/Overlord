// Gras, Blumen und Büsche aus den Ortsmodellen: Alpha-Schnitt, beidseitig, wiegt sich im Wind
// (Ausschlag wächst mit der Höhe über dem Boden; jede Instanz eigene Phase).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform float roughness = 0.85;
uniform float alpha_cut = 0.4;
uniform float wind = 0.05;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float t = TIME * 1.6 + wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += (sin(t) + 0.4 * sin(t * 2.3)) * wind * h;
	VERTEX.z += cos(t * 0.8) * wind * 0.6 * h;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	if (c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	// Licht scheint leicht durch die Blätter
	BACKLIGHT = c.rgb * 0.35;
}

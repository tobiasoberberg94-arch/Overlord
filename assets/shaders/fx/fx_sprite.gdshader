// Leuchtende Partikel (Funken, Glut, Magiefunken, Lichtblitze): additiv, unbeleuchtet, HDR.
// Partikelfarbe aus der Farbrampe des Emitters: R = Helligkeit, G = Weißglut (0 = Tönung, 1 = weiß), A = Deckkraft.
// Die Tönung kommt je Emitter als Instanz-Parameter (eine Vorlage für alle Farben, kein Neukompilieren).
// Weiche Kanten an Geometrie über den Tiefenpuffer; optional 2×2-Bildatlas (Bild über INSTANCE_CUSTOM.z).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float energy = 3.0;
uniform float soft_dist = 0.15;
uniform bool atlas = false;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
instance uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.25, 1.0);
instance uniform float boost = 1.0;

varying float frame;

void vertex() {
	frame = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 uv = UV;
	if (atlas) {
		float f = floor(clamp(frame, 0.0, 0.999) * 4.0);
		uv = uv * 0.5 + vec2(mod(f, 2.0), floor(f * 0.5)) * 0.5;
	}
	vec4 t = texture(tex, uv);
	float soft = 1.0;
	if (soft_dist > 0.0) {
		float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		soft = clamp((-v.z / v.w + VERTEX.z) / soft_dist, 0.0, 1.0);
	}
	vec3 c = mix(tint.rgb, vec3(1.0), clamp(COLOR.g, 0.0, 1.0)) * COLOR.r * energy * boost;
	ALBEDO = c * t.rgb;
	ALPHA = clamp(COLOR.a * t.a * tint.a * soft, 0.0, 1.0);
}

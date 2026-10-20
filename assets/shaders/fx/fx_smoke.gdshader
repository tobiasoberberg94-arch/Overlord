// Rauch, Staub, Blutnebel, Frostdunst: beleuchtete, weich auslaufende Wolken (2×2-Atlas, Bild je Partikel zufällig).
// Partikelfarbe: R = Helligkeit, A = Deckkraft; Tönung je Emitter als Instanz-Parameter. Optional Glut von innen
// (Feuerrauch), Durchscheinen gegen das Licht.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled, diffuse_lambert_wrap, shadows_disabled;

uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float soft_dist = 0.6;
uniform bool atlas = true;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
instance uniform vec4 tint : source_color = vec4(0.6, 0.55, 0.5, 1.0);
instance uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 0.0);

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
	float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float soft = clamp((-v.z / v.w + VERTEX.z) / soft_dist, 0.0, 1.0);
	// nahe der Kamera ausblenden (Rauch direkt vor der Linse wirkt wie ein Fleck)
	soft *= smoothstep(0.3, 1.4, -VERTEX.z);
	ALBEDO = tint.rgb * t.rgb * COLOR.r;
	ALPHA = clamp(COLOR.a * t.a * tint.a * soft, 0.0, 1.0);
	EMISSION = glow.rgb * glow.a * t.a * COLOR.a * (1.0 - COLOR.g);
	BACKLIGHT = tint.rgb * 0.35;
	ROUGHNESS = 1.0;
}

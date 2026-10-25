// Gate (Ainz' Teleportzauber): senkrechte Ellipse aus wirbelnder Finsternis mit ausgefranstem, violett glühendem Rand.
// Dreht sich um die Hochachse zur Kamera (wie ein Fenster in einen anderen Ort, nie von der Kante zu sehen).
// UV 0..1 auf einem Quad; Rand und Wirbel aus fx_noise, leichte Lichtbrechung des Hintergrunds am Rand.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 rim_color : source_color = vec4(0.62, 0.3, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.015, 0.0, 0.03, 1.0);
uniform float rim_energy = 2.1;
uniform float swirl_speed = 0.06;
uniform float open = 1.0;                 // 0 = geschlossen, 1 = ganz offen (Auf- und Zugehen)

void vertex() {
	// Billboard um die Y-Achse
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	// ausgefranster Rand: zwei Rauschlagen entlang des Umfangs, langsam wandernd
	float n1 = texture(noise_tex, vec2(a * 3.0 + TIME * 0.03, TIME * 0.05)).r;
	float n2 = texture(noise_tex, vec2(a * 9.0 - TIME * 0.07, 0.37 + TIME * 0.09)).r;
	float edge = (0.80 + (n1 - 0.5) * 0.16 + (n2 - 0.5) * 0.07) * open;
	float outer = edge + 0.07;
	if (r > outer + 0.05) {
		discard;
	}
	// Wirbel: Polar-UV, nach innen gesogen und gedreht
	float twist = a + TIME * swirl_speed + (1.0 - r) * 0.35;
	vec2 sw = vec2(twist * 2.0, r * 1.4 - TIME * 0.11);
	float s1 = texture(noise_tex, sw).r;
	float s2 = texture(noise_tex, sw * vec2(2.0, 2.3) + vec2(0.41, 0.17)).r;
	float swirl = s1 * 0.6 + s2 * 0.4;
	float inside = 1.0 - smoothstep(edge - 0.02, edge + 0.02, r);
	// Kern fast schwarz, zum Rand hin violette Schlieren
	vec3 col = core_color.rgb;
	col += rim_color.rgb * 0.22 * pow(swirl, 2.2) * smoothstep(0.15, edge, r);
	// glühender Rand mit flackernden Zungen
	float rim = smoothstep(edge - 0.12, edge, r) * (1.0 - smoothstep(edge, outer, r));
	float tongues = smoothstep(0.45, 0.85, n2) * (1.0 - smoothstep(edge, outer + 0.05, r)) * step(edge - 0.02, r);
	col += rim_color.rgb * (rim * rim_energy + tongues * rim_energy * 0.6);
	// außerhalb des Randes: Hintergrund leicht verzerrt (Hitzeflimmern der Magie)
	float halo = (1.0 - inside) * (1.0 - smoothstep(edge, outer + 0.05, r));
	vec2 off = (vec2(s1, s2) - 0.5) * 0.012 * halo;
	vec3 bg = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	ALBEDO = mix(bg, col, clamp(inside + rim + tongues, 0.0, 1.0));
	// steht die Kamera im Gate (Ankunft davor, Kamera dahinter), blendet es aus statt das Bild zu füllen
	float cam_fade = smoothstep(1.6, 4.0, length(VERTEX));
	ALPHA = clamp(inside + halo * 0.9 + rim, 0.0, 1.0) * cam_fade;
}

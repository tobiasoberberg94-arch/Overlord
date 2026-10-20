// Kleine Tiere/Teilchen als Partikel (Schmetterlinge, fallendes Laub): zur Kamera gedrehte Karte mit
// Form aus der Textur. Schmetterlinge schlagen mit den Flügeln (Karte wird schmal/breit), Laub taumelt.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float flap = 1.0;          // 1 = Flügelschlag, 0 = Taumeln
uniform float flap_speed = 14.0;

varying vec4 v_col;

void vertex() {
	float id = float(INSTANCE_ID);
	float sc = length(MODEL_MATRIX[0].xyz);
	if (flap > 0.5) {
		float f = abs(sin(TIME * flap_speed + id * 1.73));
		VERTEX.x *= 0.12 + 0.88 * f;
	} else {
		float a = TIME * (1.2 + fract(id * 0.37) * 2.0) + id;
		VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
		VERTEX.x *= 0.35 + 0.65 * abs(cos(a * 0.7));
	}
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mw * mat4(vec4(sc, 0.0, 0.0, 0.0), vec4(0.0, sc, 0.0, 0.0), vec4(0.0, 0.0, sc, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	v_col = COLOR;
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * v_col.rgb;
	// direkt vor der Kamera ausblenden (sonst fliegen große schwarze Blätter durchs Bild)
	ALPHA = t.a * smoothstep(1.2, 2.8, length(VERTEX));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.8;
	BACKLIGHT = ALBEDO * 0.8;
	EMISSION = ALBEDO * 0.05;
}

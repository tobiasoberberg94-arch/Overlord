// Flamme (Feuerschalen, Fackeln, Kamine, Lagerfeuer): Flammenzunge auf einem Quad, unten breit, oben spitz, seitlich
// flackernd und nach oben züngelnd (zwei Rauschlagen aus fx_noise). Dreht sich um die Hochachse zur Kamera, additiv.
// Je Flamme ein anderer Takt über den Instanz-Parameter seed; Farben je Material (warm oder violett, blau …).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 col_core : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform vec4 col_outer : source_color = vec4(1.0, 0.36, 0.08, 1.0);
uniform float energy = 1.6;
instance uniform float seed = 0.0;

void vertex() {
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float y = 1.0 - UV.y;                       // 0 unten … 1 oben
	float t = TIME * 1.7 + seed * 9.0;
	float n1 = texture(noise_tex, vec2(UV.x * 0.7 + seed * 0.37, y * 0.8 - t * 0.55)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 1.6 - seed * 0.21, y * 1.5 - t * 1.05)).r;
	float x = (UV.x - 0.5) * 2.0;
	x += (n1 - 0.5) * 0.55 * y;                 // oben stärker zur Seite flackern
	float w = mix(0.62, 0.02, pow(y, 0.85));    // Tropfenform: unten breit, oben spitz
	float body = 1.0 - smoothstep(w * 0.45, w, abs(x));
	body *= smoothstep(0.0, 0.1, y);
	body *= 1.0 - smoothstep(0.5, 0.95, y + (n2 - 0.5) * 0.45);   // gezackte Spitze, Zungen reißen ab
	float core = (1.0 - smoothstep(0.0, w * 0.6, abs(x))) * (1.0 - smoothstep(0.15, 0.7, y));
	vec3 c = mix(col_outer.rgb, col_core.rgb, clamp(core * 1.2, 0.0, 1.0));
	float a = clamp(body * (0.75 + 0.25 * n2), 0.0, 1.0);
	ALBEDO = c * energy * a;
	ALPHA = a;
}

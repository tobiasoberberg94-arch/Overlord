// Wasserflächen (Sumpf, Teiche, Seen): zwei laufende Wellen-Normalen, Fresnel-Spiegelung des Himmels,
// Lichtbrechung über den Bildschirm-Hintergrund, Tiefenfärbung (je tiefer, desto trüber) und Schaum am Ufer.
// Story »Frost über dem Sumpf«: freeze_radius > 0 lässt das Wasser von freeze_center aus zu Eis gefrieren
// (Risse, Reif, eingeschlossene Luftblasen, eine leuchtende Frostfront am Rand).
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec3 shallow : source_color = vec3(0.12, 0.15, 0.08);
uniform vec3 deep : source_color = vec3(0.02, 0.035, 0.02);
uniform float murk = 1.6;            // wie schnell das Wasser mit der Tiefe trüb wird
uniform float wave_speed = 0.035;
uniform float refraction = 0.025;
uniform float algae_amount = 1.0;    // Algen/Entengrütze (Sumpf 1, Fluss wenig)
uniform float reflect = 1.0;         // Spiegelung (unter Baumkronen weniger Himmel)
uniform vec3 freeze_center = vec3(0.0);
uniform float freeze_radius = 0.0;   // 0 = kein Eis
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 wpos;

// Hash ohne sin(): bei großen Weltkoordinaten (Flüsse, Seen) sonst blockige Artefakte
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
vec2 grad(vec2 p) {
	float e = 0.05;
	return vec2(vnoise(p + vec2(e, 0)) - vnoise(p - vec2(e, 0)), vnoise(p + vec2(0, e)) - vnoise(p - vec2(0, e))) / (2.0 * e);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 g = grad(p * 0.35 + TIME * wave_speed * vec2(1.0, 0.6)) * 0.6 + grad(p * 1.3 - TIME * wave_speed * 2.2 * vec2(0.4, 1.0)) * 0.25;
	vec3 n_world = normalize(vec3(-g.x, 6.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	// Tiefe des Wassers an diesem Pixel
	float d_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d_raw, 1.0);
	vec4 v = INV_PROJECTION_MATRIX * ndc;
	float scene_depth = -v.z / v.w;
	float water_depth = clamp(scene_depth - (-VERTEX.z), 0.0, 20.0);
	float t = 1.0 - exp(-water_depth * murk);
	vec2 off = g * refraction * clamp(water_depth, 0.0, 1.0);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	vec3 col = mix(behind * shallow * 2.2, deep, t);
	// Schaum/Schlick am Ufer
	float foam = (1.0 - smoothstep(0.0, 0.18, water_depth)) * (0.5 + 0.5 * vnoise(p * 6.0 + TIME * 0.3));
	col = mix(col, vec3(0.42, 0.44, 0.36), foam * 0.45);
	// Algen/Entengrütze in Flecken: matt, grün – das Wasser spiegelt nur dazwischen
	float algae = smoothstep(0.52, 0.7, vnoise(p * 0.18) * 0.65 + vnoise(p * 0.9) * 0.35) * algae_amount;
	col = mix(col, vec3(0.09, 0.12, 0.035) * mix(0.8, 1.2, vnoise(p * 3.0)), algae);
	float rough = mix(0.22, 0.85, algae);
	float spec = mix(0.32, 0.1, algae) * reflect;
	vec3 emit = vec3(0.0);
	if (freeze_radius > 0.0) {
		float fd = distance(wpos.xz, freeze_center.xz);
		float edge_n = vnoise(p * 0.25) * 3.0;                         // ausgefranste Frostfront
		float ice = 1.0 - smoothstep(freeze_radius - 1.5 - edge_n, freeze_radius - edge_n, fd);
		if (ice > 0.0) {
			// Eis: milchiges Blauweiß, darunter dunkle Tiefe; Risse als Netz, Reif in Flecken, Luftblasen
			float cr1 = abs(vnoise(p * 0.55) - 0.5);
			float cr2 = abs(vnoise(p * 1.7 + 7.3) - 0.5);
			float crack = (1.0 - smoothstep(0.0, 0.025, cr1)) * 0.8 + (1.0 - smoothstep(0.0, 0.018, cr2)) * 0.45;
			float frost = smoothstep(0.35, 0.8, vnoise(p * 0.9 + 3.1) * 0.7 + vnoise(p * 4.0) * 0.3);
			float bubbles = step(0.93, vnoise(p * 9.0)) * 0.5;
			// klares Eis: dunkle Tiefe scheint durch, bläulich, darauf Reif in Flecken, helle Risse
			vec3 ice_col = mix(vec3(0.09, 0.17, 0.23), vec3(0.36, 0.52, 0.64), 0.3 + 0.35 * vnoise(p * 0.12));
			ice_col = mix(col * 0.5 + vec3(0.05, 0.1, 0.14), ice_col, 0.6);
			ice_col = mix(ice_col, vec3(0.8, 0.88, 0.95), frost * 0.5 + bubbles);
			ice_col = mix(ice_col, vec3(0.92, 0.97, 1.0), crack * 0.8);
			col = mix(col, ice_col, ice);
			rough = mix(rough, mix(0.05, 0.5, frost), ice);
			spec = mix(spec, 0.65, ice);
			NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, ice * 0.85));
			// leuchtende Frostfront, solange sich das Eis ausbreitet
			float front = (1.0 - smoothstep(0.0, 6.0, abs(fd - (freeze_radius - edge_n - 0.8)))) * ice;
			emit = vec3(0.45, 0.8, 1.0) * front * 1.6;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = spec;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = emit;
	ALPHA = 1.0;
	RIM = fres * 0.15 * (1.0 - algae) * reflect;
}

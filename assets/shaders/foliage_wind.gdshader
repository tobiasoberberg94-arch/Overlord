// Laub, Rinde, Gras und Büsche aus den Ortsmodellen: Alpha-Schnitt, beidseitig, wiegt sich im Wind
// (Ausschlag wächst mit der Höhe über dem Boden; jede Instanz eigene Phase).
// Natürlichere Farben: jede Pflanze bekommt ihren eigenen Farbton und eine eigene Helligkeit; stilisiertes
// Herbstlaub (orange) wird zu sattem Grün umgefärbt (ein kleiner Teil darf Herbst bleiben); helle Birkenrinde
// wird bei den meisten Bäumen dunkler; Licht scheint durch die Blätter (Gegenlicht), Kronen innen dunkler.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform float roughness = 0.85;
uniform float alpha_cut = 0.4;
uniform float wind = 0.05;
uniform float leaf = 1.0;            // 1 = Blatt/Halm (Alpha-Schnitt), 0 = Rinde/Holz
uniform float recolor = 0.0;         // 1 = orange Herbstfarbe zu Grün umfärben
uniform float pale_bark = 0.0;       // 1 = helle Rinde (Birke): bei ~75 % der Bäume abdunkeln
uniform float autumn_share = 0.06;   // Anteil der umgefärbten Bäume, die Herbstlaub behalten
uniform float variation = 1.0;       // Stärke der Farbabweichung je Pflanze
uniform float height_hint = 8.0;     // grobe Pflanzenhöhe (für Kronen-Verdunklung)
uniform float leaf_gain = 1.0;       // Helligkeitsausgleich der Laubtextur
uniform float leaf_sat = 1.0;        // Sättigungsausgleich
uniform float grassy = 0.0;          // 1 = stilisiertes Gras → natürliche Graspalette (mit trockenen Halmen)

varying float v_rnd;
varying float v_rnd2;
varying float v_h;

float hash1(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float iid = float(INSTANCE_ID);
	v_rnd = hash1(floor(wp * 4.0) + vec3(iid * 1.371, iid * 0.173, 0.37));
	v_rnd2 = hash1(floor(wp * 4.0).zxy + vec3(11.1, iid * 2.113, iid * 0.611));
	wp += vec3(iid * 7.13, 0.0, iid * 3.71);
	float h = max(VERTEX.y, 0.0);
	v_h = h;
	float t = TIME * 1.6 + wp.x * 0.35 + wp.z * 0.27;
	float gust = 0.7 + 0.3 * sin(TIME * 0.4 + wp.x * 0.02);
	VERTEX.x += (sin(t) + 0.4 * sin(t * 2.3)) * wind * h * gust;
	VERTEX.z += cos(t * 0.8) * wind * 0.6 * h * gust;
}

vec3 sat(vec3 c, float s) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(l), c, s);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	vec3 col = c.rgb;
	if (leaf > 0.5) {
		col = sat(col * leaf_gain, leaf_sat);
		if (grassy > 0.5) {
			float l = dot(texture(albedo_tex, UV).rgb, vec3(0.2126, 0.7152, 0.0722));
			vec3 g_dark = vec3(0.03, 0.05, 0.012);
			vec3 g_lite = mix(vec3(0.17, 0.26, 0.06), vec3(0.3, 0.3, 0.12), v_rnd * 0.6);
			col = mix(g_dark, g_lite, smoothstep(0.05, 0.75, l) * mix(0.6, 1.0, UV.y < 0.5 ? 1.0 : 0.85));
			col = mix(col, vec3(0.42, 0.37, 0.19), step(0.82, v_rnd2) * 0.55);
		} else if (recolor > 0.5 && v_rnd2 > autumn_share) {
			// Herbst → Grün: Helligkeit/Struktur des Blattes behalten, Farbe aus einer natürlichen Grünpalette
			float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
			vec3 dark = vec3(0.035, 0.065, 0.018);
			vec3 light = mix(vec3(0.19, 0.29, 0.06), vec3(0.26, 0.31, 0.08), v_rnd);
			col = mix(dark, light, smoothstep(0.02, 0.55, l));
		}
		// je Pflanze: Farbton zwischen Blaugrün und Gelbgrün, Helligkeit ±
		vec3 shift = mix(vec3(0.92, 1.0, 1.06), vec3(1.10, 1.04, 0.86), v_rnd);
		col *= mix(vec3(1.0), shift, variation) * mix(1.0, mix(0.78, 1.12, v_rnd2), variation);
		col = sat(col, 1.06);
		// Krone innen/unten dunkler (Selbstverschattung), Spitzen heller
		float crown = clamp(v_h / max(height_hint, 0.5), 0.0, 1.0);
		col *= mix(0.72, 1.06, crown);
	} else {
		if (pale_bark > 0.5 && v_rnd2 > 0.25) {
			col = col * mix(vec3(0.42, 0.36, 0.30), vec3(0.55, 0.47, 0.38), v_rnd);
		}
		col *= mix(0.85, 1.1, v_rnd) ;
	}
	ALBEDO = col;
	// Mipmaps mitteln die Blattmaske weich → ferne Blätter fallen unter die Schwelle und Kronen wirken kahl.
	// Ausgleich je Mipstufe (vgl. Golus, „Anti-aliased Alpha Test“): Deckung bleibt in jeder Entfernung erhalten.
	float a = c.a;
	if (leaf > 0.5) {
		float mip = textureQueryLod(albedo_tex, UV).y;
		a *= 1.0 + max(mip, 0.0) * 0.32;
	}
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ROUGHNESS = roughness;
	SPECULAR = leaf > 0.5 ? 0.35 : 0.25;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	// Licht scheint durch die Blätter (gelbgrünes Gegenlicht)
	BACKLIGHT = leaf > 0.5 ? col * vec3(0.75, 0.85, 0.45) : vec3(0.0);
}

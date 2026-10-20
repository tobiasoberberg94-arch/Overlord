// Gelände aus Fotoscans (Poly Haven, CC0): vier Schichten in Weltkoordinaten –
//   base  (Gras/Waldboden), alt (zweiter Boden, großflächig eingestreut), path (Wege aus der Wegmaske im
//   Farbattribut), rock (Fels an steilen Hängen, dreiseitig projiziert).
// Gegen sichtbare Kachelung: jede Schicht zweifach mit verschiedener Größe/Drehung gelesen und per Rauschen
// gemischt, dazu großflächige Helligkeits- und Farbflecken. Übergänge folgen der Höhe der Texturen.
shader_type spatial;

uniform sampler2D base_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_ao : filter_linear_mipmap, repeat_enable;
uniform sampler2D alt_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D alt_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D alt_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float base_size = 3.2;       // Meter je Texturwiederholung
uniform float alt_size = 3.6;
uniform float path_size = 2.6;
uniform float rock_size = 7.0;
uniform float dirt_size = 2.9;
uniform bool use_dirt = false;       // Grün-Kanal der Wegmaske: festgetretene Erde (Höfe, Gassen)
uniform float alt_amount = 0.45;     // Anteil des zweiten Bodens
uniform vec3 base_tint : source_color = vec3(1.0);
uniform vec3 alt_tint : source_color = vec3(1.0);
uniform vec3 path_tint : source_color = vec3(1.0);
uniform vec3 rock_tint : source_color = vec3(1.0);
uniform float slope_start = 0.80;    // Normale.y, ab der Fels beginnt
uniform float slope_full = 0.62;
uniform bool use_mask = true;
uniform vec3 far_col : source_color = vec3(0.11, 0.2, 0.05);   // Farbe des Grasfelds
uniform float far_mix = 0.0;          // wie stark der Boden in der Ferne die Grasfarbe annimmt
uniform float far_start = 28.0;
uniform float far_end = 70.0;
uniform float grass_cover = 0.0;      // Grasnarbe unter dem Grasfeld: Boden zwischen den Halmen dunkel-grün statt kahl

varying vec3 wpos;
varying vec3 wnrm;
varying float vmask;
varying float vdirt;

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
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.07 + 13.1; a *= 0.5; }
	return v;
}
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vmask = COLOR.r;
	vdirt = COLOR.g;
}

// zweifach gelesen (normal + gedreht/vergrößert), per Rauschen gemischt
vec4 two(sampler2D t, vec2 p, float size, float mixv) {
	vec4 a = texture(t, p / size);
	vec4 b = texture(t, (rot(1.7) * p) / (size * 1.83) + 0.31);
	return mix(a, b, mixv);
}

void fragment() {
	vec2 p = wpos.xz;
	float n_tile = smoothstep(0.3, 0.7, fbm(p * 0.045));
	float n_alt = fbm(p * 0.018 + 4.0);
	float n_macro = fbm(p * 0.006 + 9.0);

	vec4 bd = two(base_diff, p, base_size, n_tile);
	vec4 ad = two(alt_diff, p, alt_size, 1.0 - n_tile);
	vec3 bn = texture(base_nor, p / base_size).rgb;
	vec3 an = texture(alt_nor, p / alt_size).rgb;
	float br = texture(base_rough, p / base_size).r;
	float ar = texture(alt_rough, p / alt_size).r;
	float bao = texture(base_ao, p / base_size).r;

	// zweiter Boden nach Rauschen + Texturhöhe (helle Stellen „liegen oben“)
	float hb = dot(bd.rgb, vec3(0.33));
	float ha = dot(ad.rgb, vec3(0.33));
	float w_alt = smoothstep(0.5 - 0.12, 0.5 + 0.12, n_alt + (ha - hb) * 0.6 + (alt_amount - 0.5));
	vec3 col = mix(bd.rgb * base_tint * mix(0.85, 1.0, bao), ad.rgb * alt_tint, w_alt);
	vec3 nm = mix(bn, an, w_alt);
	float rg = mix(br, ar, w_alt);

	// in mittlerer Entfernung (wo die Halme ausblenden) die Farbe des Grasfelds annehmen
	if (far_mix > 0.0) {
		float d = length(wpos - CAMERA_POSITION_WORLD);
		float fw = smoothstep(far_start, far_end, d) * far_mix;
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
		col = mix(col, far_col * mix(0.75, 1.35, smoothstep(0.05, 0.35, l)) * mix(0.9, 1.1, n_tile), fw * (1.0 - w_alt * 0.5));
	}

	// Höfe, Gassen, Trampelpfade: festgetretene Erde
	if (use_dirt) {
		vec4 dd = two(dirt_diff, p, dirt_size, n_tile);
		float hd = dot(dd.rgb, vec3(0.33));
		float w_dirt = smoothstep(0.3, 0.62, vdirt + (fbm(p * 0.42 + 7.0) - 0.5) * 0.5 + (hd - hb) * 0.3);
		col = mix(col, dd.rgb, w_dirt);
		nm = mix(nm, texture(dirt_nor, p / dirt_size).rgb, w_dirt);
		rg = mix(rg, texture(dirt_rough, p / dirt_size).r, w_dirt);
	}

	// Grasnarbe: wo Gras wächst, sieht man zwischen den Halmen Wurzelfilz und Schatten statt nackter Erde
	if (grass_cover > 0.0) {
		float patchy = smoothstep(0.25, 0.65, fbm(p * 0.09 + 11.0));
		float cover = grass_cover * mix(0.55, 1.0, patchy) * (1.0 - w_alt * 0.35);
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
		vec3 sod = far_col * mix(0.42, 0.75, smoothstep(0.03, 0.3, l)) * mix(0.85, 1.12, fbm(p * 0.6));
		col = mix(col, sod, cover);
		rg = mix(rg, 0.95, cover * 0.6);
	}

	// Wege
	if (use_mask) {
		float breakup = fbm(p * 0.35) - 0.5;
		vec4 pd = two(path_diff, p, path_size, n_tile);
		float hp = dot(pd.rgb, vec3(0.33));
		float w_path = smoothstep(0.32, 0.62, vmask + breakup * 0.45 + (hp - hb) * 0.35);
		col = mix(col, pd.rgb * path_tint, w_path);
		nm = mix(nm, texture(path_nor, p / path_size).rgb, w_path);
		rg = mix(rg, texture(path_rough, p / path_size).r, w_path);
	}

	// Fels an steilen Hängen (dreiseitig projiziert)
	float slope = wnrm.y;
	float w_rock = smoothstep(slope_start, slope_full, slope + (fbm(p * 0.2) - 0.5) * 0.08);
	if (w_rock > 0.001) {
		vec3 bw = pow(abs(wnrm), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 rx = texture(rock_diff, wpos.zy / rock_size).rgb;
		vec3 ry = texture(rock_diff, wpos.xz / rock_size).rgb;
		vec3 rz = texture(rock_diff, wpos.xy / rock_size).rgb;
		vec3 rc = (rx * bw.x + ry * bw.y + rz * bw.z) * rock_tint;
		vec3 rnm = texture(rock_nor, (bw.x > bw.z ? wpos.zy : wpos.xy) / rock_size).rgb;
		col = mix(col, rc, w_rock);
		nm = mix(nm, rnm, w_rock);
		rg = mix(rg, 0.8, w_rock);
	}

	// großflächige Farb-/Helligkeitsflecken gegen Eintönigkeit
	col *= mix(0.86, 1.1, n_macro);
	col = mix(col, col * vec3(1.06, 1.0, 0.86), smoothstep(0.55, 0.8, fbm(p * 0.01 + 2.0)) * 0.5);

	ALBEDO = col;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = clamp(rg, 0.35, 1.0);
	SPECULAR = 0.35;
}

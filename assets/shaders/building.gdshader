// Bauwerke mit Fotoscan-Oberflächen (Poly Haven, CC0). Grundlage bleibt das Originalmaterial des Bauteils
// (Albedo/Normal im UV-Raum – Fenster, Gesimse, Ornamente bleiben erhalten). Dazu kommen:
//  * Fotostruktur in Weltkoordinaten, dreiseitig projiziert: Poren, Körnung, Risse. Flächen ohne eigene Textur
//    (Platzhalter aus dem Export) bekommen das Foto ganz (photo_mix = 1).
//  * Umfärben: türkise Märchendächer → Schiefer oder Ziegel (je Gebäude anders), Stein → Naturton des Ortes,
//    leichte Abweichung je Gebäude, großflächige Flecken.
//  * Verwitterung: Schmutz/Feuchte am Sockel (Höhe über dem Gelände aus einer globalen Höhenkarte),
//    Regenspuren an Wänden, Moos und Flechten auf Oberseiten, Staub. Stärke je Ort über globale Parameter.
shader_type spatial;
render_mode cull_disabled;

// --- Originalmaterial
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float normal_depth = 1.0;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float specular = 0.4;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float base_lum = 0.25;           // mittlere (lineare) Helligkeit der Originaltextur

// --- Fotostruktur
uniform sampler2D photo_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D photo_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D photo_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float photo_size = 2.0;          // Meter je Wiederholung
uniform float photo_mix = 0.0;           // 1 = Foto ersetzt die Oberfläche
uniform float detail = 0.4;              // Helligkeitsdetail des Fotos auf dem Original
uniform float detail_normal = 0.5;       // Reliefdetail des Fotos
uniform float photo_lum = 0.25;          // mittlere (lineare) Helligkeit des Fotos
uniform vec3 photo_tint : source_color = vec3(1.0);

// --- Farbe
uniform int recolor = 0;                 // 1 = Märchendach → Schiefer/Ziegel, 2 = Naturton
uniform vec3 tone : source_color = vec3(0.7, 0.66, 0.6);
uniform float tone_amount = 0.0;
uniform float variation = 0.07;          // Abweichung je Gebäude
uniform float facade = 0.0;              // 1 = helle Putzfassade: Farbe je Haus

// --- Verwitterung
uniform float weather = 1.0;             // 0 = sauber (gepflegte Innenräume, Metall)
uniform float moss_bias = 0.0;           // + mehr Moos (Dächer, Mauerkronen)

// --- Glut (Lavahölle): glühende Adern in den Fugen des Gesteins, nahe dem Boden stärker, pulsierend
uniform float lava_glow = 0.0;
uniform vec3 lava_col : source_color = vec3(1.0, 0.2, 0.015);

global uniform sampler2D overlord_ground_h;
global uniform vec4 overlord_ground_rect;   // Ursprung xz, Maßstab xz – Maßstab 0: keine Karte
global uniform float overlord_floor_y;      // Bodenhöhe ohne Karte (Innenräume)
global uniform vec4 overlord_weather;       // x Moos, y Staub, z Regenspuren, w Sockelschmutz
global uniform vec4 overlord_roofs;         // Häufigkeit: dunkler Schiefer, grauer Schiefer, roter Ziegel, brauner Ziegel

varying vec3 wpos;
varying flat vec2 bh;

// Kalkanstriche der Putzfassaden: Creme, Weiß, Ocker, Altrosa, Hellgrau, Sand
const vec3 FACADE[6] = vec3[6](vec3(0.86, 0.82, 0.71), vec3(0.9, 0.89, 0.85), vec3(0.84, 0.71, 0.48),
	vec3(0.85, 0.73, 0.68), vec3(0.76, 0.76, 0.74), vec3(0.8, 0.72, 0.58));

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; }
	return v;
}
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

vec3 unpack_n(vec2 rg) {
	vec2 xy = rg * 2.0 - 1.0;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 o = MODEL_MATRIX[3].xyz;
	bh = vec2(hash(o.xz * 0.731 + o.y * 0.17), hash(o.zx * 1.37 + 11.3));
}

float ground_y(vec2 xz) {
	if (overlord_ground_rect.z == 0.0) {
		return overlord_floor_y;
	}
	vec2 uv = clamp((xz - overlord_ground_rect.xy) * overlord_ground_rect.zw, vec2(0.001), vec2(0.999));
	return textureLod(overlord_ground_h, uv, 0.0).r;
}

vec3 roof_color(float h) {
	vec4 w = overlord_roofs / max(dot(overlord_roofs, vec4(1.0)), 0.001);
	vec3 c;
	if (h < w.x) c = vec3(0.21, 0.22, 0.245);                    // dunkler Schiefer
	else if (h < w.x + w.y) c = vec3(0.33, 0.345, 0.37);         // grauer, verwitterter Schiefer
	else if (h < w.x + w.y + w.z) c = vec3(0.56, 0.29, 0.20);    // roter Ziegel
	else c = vec3(0.45, 0.31, 0.23);                             // brauner, alter Ziegel
	return lin(c);
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(60.0, 140.0, dist);     // feine Details nur in der Nähe

	// --- Original (UV-Raum)
	vec2 uv = UV * uv_scale + uv_offset;
	vec3 base = albedo_col.rgb;
	if (has_albedo) {
		base *= texture(albedo_tex, uv).rgb;
	}
	vec3 n_orig = NORMAL;
	if (has_normal) {
		vec3 nm = unpack_n(texture(normal_tex, uv).rg);
		n_orig = normalize(mix(NORMAL, TANGENT * nm.x + BINORMAL * nm.y + NORMAL * nm.z, normal_depth));
	}
	vec3 wn_orig = normalize((INV_VIEW_MATRIX * vec4(n_orig, 0.0)).xyz);

	// --- Fotostruktur, dreiseitig (Bildoberkante = oben)
	vec3 bw = pow(abs(wn), vec3(6.0));
	bw /= (bw.x + bw.y + bw.z);
	vec2 ux = vec2(wpos.z, -wpos.y) / photo_size;
	vec2 uy = vec2(wpos.x, -wpos.z) / photo_size;
	vec2 uz = vec2(wpos.x, -wpos.y) / photo_size;
	vec3 pc = texture(photo_diff, ux).rgb * bw.x + texture(photo_diff, uy).rgb * bw.y + texture(photo_diff, uz).rgb * bw.z;
	pc *= photo_tint;
	vec3 tx = unpack_n(texture(photo_nor, ux).rg);
	vec3 ty = unpack_n(texture(photo_nor, uy).rg);
	vec3 tz = unpack_n(texture(photo_nor, uz).rg);
	// Whiteout-Mischung in Weltkoordinaten
	tx = vec3(tx.xy + wn.zy, abs(tx.z) * wn.x);
	ty = vec3(ty.xy + wn.xz, abs(ty.z) * wn.y);
	tz = vec3(tz.xy + wn.xy, abs(tz.z) * wn.z);
	vec3 wn_photo = normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);
	vec2 udom = bw.y > max(bw.x, bw.z) ? uy : (bw.x > bw.z ? ux : uz);
	float pr = texture(photo_rough, udom).r;

	// --- Farbe
	vec3 col = base;
	float bl = lum(base) / max(base_lum, 0.01);           // Helligkeit relativ zum Mittel der Textur
	if (recolor == 1) {
		// Märchendach → Schiefer/Ziegel: Form (Helligkeit) der Schindeln bleibt, Farbe je Gebäude
		vec3 rc = roof_color(bh.x);
		float tile = mix(0.82, 1.15, vnoise(wpos.xz * 2.7 + wpos.y * 1.9));   // einzelne Platten heller/dunkler
		col = rc * pow(max(bl, 0.0), 1.35) * tile;
	} else if (recolor == 2 && tone_amount > 0.0) {
		vec3 t = tone;
		float amt = tone_amount;
		if (facade > 0.5) {
			// helle Putzfassaden: Kalkanstrich je Haus (Creme, Weiß, Ocker, Altrosa, Hellgrau, Sand)
			int k = clamp(int(floor(bh.y * 6.0)), 0, 5);
			t = lin(FACADE[k]);
			amt = 0.7;
		}
		vec3 toned = t * (lum(base) / max(lum(t), 0.001));
		col = mix(base, toned, amt);
	}
	// Fotodetail (Helligkeit + etwas Farbe) bzw. Ersatz
	float pl = lum(pc) / max(photo_lum, 0.01);
	vec3 detailed = col * mix(1.0, pl, detail * mix(0.5, 1.0, near));
	detailed = mix(detailed, detailed * (pc / max(vec3(photo_lum), vec3(0.01))) / max(pl, 0.05), 0.12 * detail);
	col = mix(detailed, pc, photo_mix);

	// Abweichung je Gebäude + großflächige Flecken
	col *= 1.0 + (bh.y - 0.5) * 2.0 * variation;
	col *= mix(vec3(1.03, 1.0, 0.95), vec3(0.96, 1.0, 1.04), bh.x * 0.6 + 0.2);
	col *= mix(0.88, 1.07, fbm(wpos.xz * 0.045 + wpos.y * 0.06));

	float rough = mix(roughness, pr, photo_mix);
	rough = clamp(rough + (pr - 0.5) * 0.35 * detail * (1.0 - photo_mix), 0.08, 1.0);
	if (recolor == 1) {
		rough = mix(rough, 0.72, 0.5);
	}

	// --- Verwitterung
	float wx = weather;
	if (wx > 0.001) {
		float hab = wpos.y - ground_y(wpos.xz);
		float up = smoothstep(0.45, 0.9, wn.y);
		float vert = 1.0 - smoothstep(0.3, 0.75, abs(wn.y));
		float n_big = fbm(wpos.xz * 0.21 + wpos.y * 0.13);

		// Sockel: Erde, Feuchte, Spritzwasser
		float zone = 0.4 + 1.1 * overlord_weather.w;
		float g = (1.0 - smoothstep(0.0, zone * (0.55 + 0.9 * n_big), hab)) * overlord_weather.w;
		g *= mix(1.0, 0.4, up);
		col = mix(col, col * vec3(0.64, 0.6, 0.53), g * 0.75 * wx);
		float splash = (1.0 - smoothstep(0.0, 0.25 + 0.25 * n_big, hab)) * overlord_weather.w;
		col = mix(col, lin(vec3(0.34, 0.29, 0.22)) * mix(0.75, 1.1, vnoise(wpos.xz * 3.1 + wpos.y)), splash * 0.35 * wx * (1.0 - up * 0.6));
		rough = mix(rough, 0.95, g * 0.4 * wx);

		// Regenspuren an senkrechten Flächen
		float hc = abs(wn.x) > abs(wn.z) ? wpos.z : wpos.x;
		float st = vnoise(vec2(hc * 2.3, wpos.y * 0.11 + vnoise(vec2(hc * 0.45, 3.0)) * 1.7));
		float streak = smoothstep(0.5, 0.86, st) * smoothstep(0.35, 0.7, fbm(vec2(hc * 0.11, wpos.y * 0.05) + 5.0));
		col *= 1.0 - streak * vert * overlord_weather.z * 0.32 * wx * mix(0.4, 1.0, near);

		// Moos/Flechten: Oberseiten, feuchte Sockel, dunkle Fugen
		float cav = 1.0 - smoothstep(0.55, 1.05, bl * mix(1.0, pl, 0.5));
		float mm = fbm(wpos.xz * 0.43 + wpos.y * 0.31 + 2.0);
		float moss = smoothstep(0.5, 0.74, mm + up * 0.22 + cav * 0.18 + (1.0 - smoothstep(0.0, 1.4, hab)) * 0.14 + moss_bias);
		moss *= mix(0.3, 1.0, max(up, cav * 0.6)) * overlord_weather.x * wx;
		vec3 moss_col = lin(mix(vec3(0.20, 0.25, 0.08), vec3(0.29, 0.31, 0.12), vnoise(wpos.xz * 1.7 + wpos.y)));
		col = mix(col, moss_col * mix(0.75, 1.2, pl), clamp(moss, 0.0, 0.9));
		rough = mix(rough, 0.97, clamp(moss, 0.0, 1.0));
		// Flechten: kleine helle Flecken
		float lich = smoothstep(0.72, 0.78, vnoise(wpos.xz * 5.3 + wpos.y * 4.1 + 9.0)) * smoothstep(0.4, 0.65, mm) * near;
		col = mix(col, lin(vec3(0.62, 0.62, 0.5)), lich * 0.35 * overlord_weather.x * wx * (0.35 + up));

		// Staub auf Oberseiten (trockene Gegenden)
		float dust = up * smoothstep(0.3, 0.7, n_big) * overlord_weather.y * wx;
		col = mix(col, lin(vec3(0.55, 0.5, 0.42)), dust * 0.4);
	}

	// --- Glut
	vec3 emis = vec3(0.0);
	if (lava_glow > 0.0) {
		float hab2 = wpos.y - ground_y(wpos.xz);
		float crev = 1.0 - smoothstep(0.1, 0.4, pl);
		float vein = smoothstep(0.52, 0.72, fbm(wpos.xz * 0.11 + wpos.y * 0.07 + 4.0));
		float low = 1.0 - smoothstep(0.5, 6.0, hab2);
		float pulse = 0.72 + 0.28 * sin(TIME * 1.6 + fbm(wpos.xz * 0.3) * 9.0);
		float glow = crev * vein * mix(0.2, 1.0, low) * pulse * lava_glow;
		emis = lava_col * glow * 1.5;
		col = mix(col, col * 0.4, clamp(vein * low, 0.0, 1.0) * 0.55);       // verkohlt rund um die Glut
	}

	// --- Relief: Original + Fotodetail (bzw. Foto ganz)
	vec3 nf = normalize(wn_orig + (wn_photo - wn) * mix(detail_normal * mix(0.4, 1.0, near), 1.0, photo_mix));

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nf, 0.0)).xyz);
	ROUGHNESS = rough;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = emis;
}

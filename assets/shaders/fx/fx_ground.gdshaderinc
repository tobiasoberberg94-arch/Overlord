// Gemeinsamer Teil der Bodenmarken (über den Boden gelegtes Gitter, siehe scripts/combat/ground_mark.gd).
// p = Gitterkoordinate in [-1, 1]² (x seitlich, y = lokales Z, vorn = −Y).
// mode: 0 Kreis-Warnung · 1 Kegel-Warnung · 2 Druckring · 3 Magiekreis (Textur) · 4 Rechteck-Warnung · 5 Glutkreis
//       6 Kegelwelle (Druckwelle nach vorn)
uniform int mode = 0;
uniform sampler2D rune_tex : hint_default_transparent, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
instance uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.1, 1.0);
instance uniform float progress = 0.0;      // Füllstand (Warnung) bzw. Ringradius (Druckring) 0…1
instance uniform float fade = 1.0;
instance uniform float arc = 90.0;          // Kegelwinkel in Grad
instance uniform float spin = 0.0;          // Drehung des Magiekreises
instance uniform float width = 0.12;        // Ringbreite (Druckring)
instance uniform float energy = 1.5;

varying vec2 gp;

void vertex() {
	gp = UV * 2.0 - 1.0;
}

vec4 ground_pattern(vec2 p, float time) {
	float r = length(p);
	float n = texture(noise_tex, p * 0.9 + vec2(time * 0.04, -time * 0.03)).r;
	float n2 = texture(noise_tex, p * 2.3 - vec2(time * 0.07, time * 0.05)).g;
	vec3 col = tint.rgb;
	float a = 0.0;
	float hot = 0.0;
	if (mode == 0 || mode == 1) {
		if (r > 1.0) {
			return vec4(0.0);
		}
		float inside = 1.0;
		float side = 0.0;
		if (mode == 1) {
			float ang = abs(atan(p.x, -p.y));
			float half_a = radians(arc) * 0.5;
			inside = 1.0 - smoothstep(half_a - 0.01, half_a + 0.01, ang);
			side = exp(-abs(ang - half_a) * max(r, 0.05) * 60.0) * step(ang, half_a + 0.05);
		}
		float rim = exp(-abs(r - 0.965) * 70.0) + exp(-abs(r - 0.965) * 14.0) * 0.35;
		float fill = clamp(progress, 0.0, 1.0);
		float covered = 1.0 - smoothstep(fill - 0.004, fill + 0.004, r);
		float lead = exp(-abs(r - fill) * 45.0) * step(r, fill + 0.08) * step(0.02, fill);
		float body = (0.16 + 0.24 * smoothstep(0.0, 1.0, r / max(fill, 0.01))) * (0.7 + 0.45 * n);
		float pulse = 1.0 + smoothstep(0.82, 1.0, fill) * 0.35 * sin(time * 26.0);
		a = (rim * 0.9 + side * 0.9 + covered * body + lead * 0.85) * inside * pulse;
		a += inside * 0.06;                                  // ganze Fläche schwach sichtbar
		hot = (rim + lead + side) * inside;
	} else if (mode == 2) {
		float r0 = progress;
		float d = (r - r0) / max(width, 0.01);
		a = exp(-d * d * 3.0) * (0.75 + 0.5 * n2) + exp(-max(r0 - r, 0.0) * 6.0) * step(r, r0) * 0.12;
		a *= step(r, 1.0) * (1.0 - smoothstep(0.85, 1.0, r0) * 0.6);
		hot = exp(-d * d * 8.0);
	} else if (mode == 3) {
		float s = sin(spin), c = cos(spin);
		vec2 q = mat2(vec2(c, -s), vec2(s, c)) * p;
		float m = texture(rune_tex, q * 0.5 + 0.5).a;
		// zweite, gegenläufige Ebene schwach darüber (Tiefe)
		vec2 q2 = mat2(vec2(c, s), vec2(-s, c)) * p * 1.12;
		float m2 = texture(rune_tex, q2 * 0.5 + 0.5).a * step(length(q2), 1.0);
		float haze = (1.0 - smoothstep(0.0, 1.0, r)) * 0.08 * (0.6 + 0.8 * n);
		a = (m + m2 * 0.22 + haze + exp(-abs(r - 0.99) * 30.0) * 0.25) * step(r, 1.02);
		hot = m;
	} else if (mode == 4) {
		vec2 e = 1.0 - abs(p);
		float border = min(e.x, e.y);
		if (border < 0.0) {
			return vec4(0.0);
		}
		float rim = exp(-border * 60.0) + exp(-border * 12.0) * 0.3;
		float along = (1.0 - p.y) * 0.5;                      // 0 = hinten (Angreifer) … 1 = vorn
		float fill = clamp(progress, 0.0, 1.0);
		float covered = 1.0 - smoothstep(fill - 0.005, fill + 0.005, along);
		float lead = exp(-abs(along - fill) * 50.0) * step(along, fill + 0.06);
		float stripes = smoothstep(0.4, 0.6, fract((p.y + p.x * 0.25) * 6.0 - time * 1.5));
		a = rim * 0.9 + covered * (0.16 + 0.12 * stripes) * (0.7 + 0.5 * n) + lead * 0.8 + 0.05;
		hot = rim + lead;
	} else if (mode == 6) {
		float ang = abs(atan(p.x, -p.y));
		float half_a = radians(arc) * 0.5;
		float inside = 1.0 - smoothstep(half_a - 0.04, half_a + 0.04, ang);
		float d = (r - progress) / max(width, 0.01);
		a = (exp(-d * d * 3.0) * (0.8 + 0.5 * n2) + exp(-max(progress - r, 0.0) * 5.0) * step(r, progress) * 0.16) * inside * step(r, 1.0);
		hot = exp(-d * d * 8.0) * inside;
	} else {
		// Glutkreis: unruhig flackernder Boden (Feuerwand, Lava, Höllenfeuer)
		if (r > 1.0) {
			return vec4(0.0);
		}
		float flick = texture(noise_tex, p * 1.6 + vec2(0.0, -time * 0.35)).b;
		a = smoothstep(1.0, 0.55, r) * (0.35 + 0.65 * flick) * (0.6 + 0.6 * n);
		hot = smoothstep(0.55, 0.95, flick) * smoothstep(1.0, 0.3, r);
	}
	vec3 rgb = col * energy * (1.0 + hot * 1.4) + vec3(hot * 0.35 * energy);
	return vec4(rgb, clamp(a, 0.0, 1.0) * fade * tint.a);
}

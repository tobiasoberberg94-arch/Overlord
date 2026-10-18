shader_type canvas_item;
// Obsidian-Glas mit Goldkante, Innenlinie, Eck-Ornamenten und optionalem Leuchten (NzPanel).
// Das Rechteck wird um `pad` größer gezeichnet, damit das Leuchten außerhalb Platz hat.

uniform vec2 size = vec2(300.0, 100.0);
uniform float pad = 16.0;
uniform float radius = 8.0;
uniform float border = 1.5;
uniform vec4 bg : source_color = vec4(0.035, 0.02, 0.06, 0.86);
uniform vec4 gold : source_color = vec4(0.83, 0.69, 0.22, 1.0);
uniform vec4 glow : source_color = vec4(0.61, 0.36, 1.0, 1.0);
uniform float glow_amt = 0.0;
uniform float corners = 1.0;
uniform float inner_line = 1.0;
uniform float fade_x = 0.0;      // 1 = Kanten links/rechts laufen weich aus (Bänder)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 full = size + vec2(pad * 2.0);
	vec2 px = UV * full - vec2(pad);            // Pixel im Panel (0..size)
	vec2 c = px - size * 0.5;
	float d = rbox(c, size * 0.5, radius);
	float aa = 1.0;
	float inside = 1.0 - smoothstep(-aa, 0.0, d);

	// Hintergrund: Verlauf, Rauschen, Vignette, schräger Glanz
	vec2 uv = px / size;
	vec3 col = bg.rgb * (1.25 - uv.y * 0.45);
	col += (hash(floor(px * 0.5)) - 0.5) * 0.018;
	float edge = clamp(-d / 40.0, 0.0, 1.0);
	col *= mix(1.25, 0.92, edge);
	col += glow.rgb * 0.05 * (1.0 - edge);
	float sheen = smoothstep(0.0, 0.5, uv.x - uv.y * 0.6 + 0.1) * smoothstep(1.0, 0.5, uv.x - uv.y * 0.6 + 0.1);
	col += vec3(0.04, 0.035, 0.05) * sheen;
	float a = bg.a * inside;

	// Goldkante mit Licht oben links
	float rim = 1.0 - smoothstep(border - aa * 0.5, border + aa * 0.5, abs(d + border * 0.5));
	vec3 goldc = gold.rgb * mix(1.25, 0.6, clamp(uv.y * 0.7 + uv.x * 0.3, 0.0, 1.0));
	col = mix(col, goldc, rim * gold.a);
	a = max(a, rim * gold.a);

	// feine Innenlinie
	if (inner_line > 0.5) {
		float dl = abs(d + 5.0);
		float il = (1.0 - smoothstep(0.3, 1.0, dl)) * 0.28;
		col = mix(col, gold.rgb, il * inside);
	}

	// Eck-Ornamente: Raute + Winkel
	if (corners > 0.5) {
		vec2 q = abs(c) - size * 0.5 + vec2(6.0);
		float dia = abs(q.x) + abs(q.y);
		float orn = 1.0 - smoothstep(3.0, 4.2, dia);
		float bracket = (1.0 - smoothstep(0.6, 1.4, min(abs(q.x + 3.0), abs(q.y + 3.0))))
			* step(q.x, 10.0) * step(q.y, 10.0) * step(-4.0, q.x) * step(-4.0, q.y)
			* step(min(q.x, q.y), -2.0);
		float o = max(orn, bracket * 0.8);
		col = mix(col, gold.rgb * 1.3, o * gold.a);
		a = max(a, o * gold.a);
	}

	// Leuchten außerhalb
	float g = glow_amt * exp(-max(d, 0.0) / 7.0) * step(0.0, d);
	col = mix(col, glow.rgb, clamp(g * (1.0 - a), 0.0, 1.0));
	a = max(a, g * 0.6);

	// weiche Bandenden
	if (fade_x > 0.5) {
		float fx = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
		a *= fx;
	}
	COLOR = vec4(col, a);
}

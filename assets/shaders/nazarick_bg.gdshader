// Hintergrund des Thronsaals: violetter Nebel, goldenes Licht vom Thron,
// Säulen und die 41 Banner der Gilde. Wird ersetzt, sobald unter
// res://assets/backgrounds/throne_room.png ein echtes Bild liegt.
shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.07, 0.03, 0.12, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.01, 0.0, 0.02, 1.0);
uniform vec4 glow_color : source_color = vec4(0.83, 0.69, 0.22, 1.0);
uniform vec4 fog_color : source_color = vec4(0.36, 0.13, 0.58, 1.0);
uniform vec4 banner_a : source_color = vec4(0.42, 0.0, 0.07, 1.0);
uniform vec4 banner_b : source_color = vec4(0.22, 0.08, 0.38, 1.0);
uniform vec2 glow_center = vec2(0.5, 0.42);
uniform float architecture = 1.0;
uniform float intensity = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.04;
	vec3 col = mix(color_top.rgb, color_bottom.rgb, smoothstep(0.0, 1.0, uv.y));

	if (architecture > 0.5) {
		// Banner zwischen den Säulen (leicht wehend)
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float x = 0.07 + fi * 0.123;
			float sway = sin(TIME * 0.6 + fi) * 0.003 * uv.y;
			float halfw = 0.028;
			float len = 0.42 + 0.04 * sin(fi * 1.7);
			float dx = abs(uv.x - x - sway);
			float tip = len - (halfw - dx) * 1.5;
			if (dx < halfw && uv.y < tip) {
				vec3 bc = mod(fi, 2.0) < 1.0 ? banner_a.rgb : banner_b.rgb;
				float shade = 0.7 + 0.3 * sin(uv.y * 40.0 + fi);
				col = mix(col, bc * shade, 0.85);
				if (halfw - dx < 0.003) col += glow_color.rgb * 0.25;
				// Gildenzeichen
				if (distance(vec2(uv.x - sway, uv.y), vec2(x, len * 0.45)) < 0.012) col += glow_color.rgb * 0.5;
			}
		}
		// Säulen
		float px[4] = float[4](0.012, 0.25, 0.75, 0.988);
		for (int i = 0; i < 4; i++) {
			float dx = abs(uv.x - px[i]);
			float wcol = 0.035;
			if (dx < wcol) {
				float edge = smoothstep(wcol, wcol - 0.004, dx);
				vec3 pc = vec3(0.05, 0.03, 0.08) * (0.6 + 0.6 * (1.0 - dx / wcol));
				col = mix(col, pc, edge);
				if (abs(dx - wcol + 0.006) < 0.0015) col += glow_color.rgb * 0.35;
			}
		}
		// Bodenspiegelung
		if (uv.y > 0.78) {
			float floor_l = smoothstep(0.78, 1.0, uv.y);
			col += glow_color.rgb * 0.05 * floor_l * (0.5 + 0.5 * sin(uv.x * 60.0));
		}
	}

	// Licht vom Thron + Strahlen
	vec2 d = (uv - glow_center) * vec2(1.7, 1.0);
	float dist = length(d);
	col += glow_color.rgb * 0.28 * intensity * exp(-dist * 3.6);
	float ang = atan(d.y, d.x);
	float rays = pow(max(0.0, sin(ang * 11.0 + t * 6.0)), 10.0) * exp(-dist * 2.2);
	col += glow_color.rgb * rays * 0.12 * intensity;

	// Wabernder Nebel
	float f = fbm(uv * vec2(3.2, 2.2) + vec2(t, -t * 0.6));
	float f2 = fbm(uv * vec2(6.0, 4.0) - vec2(t * 1.7, t));
	col += fog_color.rgb * (f * 0.22 + f2 * 0.08) * (0.3 + uv.y * 0.9);

	// Vignette
	float v = smoothstep(1.05, 0.25, distance(uv, vec2(0.5, 0.45)));
	col *= mix(0.25, 1.0, v);
	COLOR = vec4(col, 1.0);
}

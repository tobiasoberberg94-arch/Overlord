// Goldberg: dicht gepackte Münzen (Zellmuster), jede Münze leicht verkippt, metallisch mit Glitzern.
shader_type spatial;

uniform vec3 gold : source_color = vec3(1.0, 0.74, 0.28);
uniform float coin_size = 0.07;

vec2 h2(vec2 p) { p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	// dreiachsige Projektion des Münzmusters
	vec3 bw = abs(wn); bw /= (bw.x + bw.y + bw.z);
	vec2 uvs[3] = vec2[](wp.yz, wp.xz, wp.xy);
	float edge = 1.0; vec3 tilt = vec3(0.0); float spark = 0.0; float shade = 0.0;
	for (int a = 0; a < 3; a++) {
		vec2 p = uvs[a] / coin_size;
		vec2 i = floor(p); vec2 f = fract(p);
		float md = 8.0; vec2 mc = vec2(0.0);
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y)); vec2 o = h2(i + g);
			vec2 r = g + o * 0.8 - f; float d = dot(r, r);
			if (d < md) { md = d; mc = i + g; }
		}
		vec2 rnd = h2(mc + 7.0);
		float w = (a == 0) ? bw.x : ((a == 1) ? bw.y : bw.z);
		edge = min(edge, mix(1.0, smoothstep(0.05, 0.3, md), w));
		tilt += vec3(rnd - 0.5, 0.0) * w;
		spark += step(0.985, h2(mc + floor(TIME * 2.0)).x) * w;
		shade += rnd.x * w;
	}
	ALBEDO = gold * mix(0.55, 1.05, edge) * mix(0.85, 1.1, shade);
	METALLIC = 1.0;
	ROUGHNESS = mix(0.18, 0.4, 1.0 - edge);
	NORMAL_MAP = normalize(vec3(tilt.xy * 0.9 + 0.5, 1.0));
	EMISSION = gold * spark * 2.0;
}

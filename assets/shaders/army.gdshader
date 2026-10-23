// Heer als MultiMesh (scripts/story/army_crowd.gd): jeder Soldat wiegt sich leicht und kann fallen –
// in der Welle des schwarzen Windes (wave_center/wave_r) oder einzeln (INSTANCE_CUSTOM.r = Zeitpunkt des Falls,
// .g = Richtung). Gefallene verdorren: dunkler und grau. Wappenfarben je Block aus `palette` (Vertexfarbe a = 0).
// Bannerträger (banner = true): das Tuch über 2,6 m flattert im Wind.
shader_type spatial;

uniform vec3 wave_center = vec3(0.0);
uniform float wave_r = -1.0;
uniform float clock = 0.0;
uniform vec3 palette[8];
uniform bool banner = false;

varying float v_fall;
varying float v_house;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float rnd = INSTANCE_CUSTOM.b;
	vec3 v = VERTEX;
	if (banner && COLOR.a < 0.5 && v.y > 2.4) {
		float u = max(v.x - 0.05, 0.0);
		v.z += sin(TIME * 3.4 + u * 4.0 + rnd * 9.0) * 0.16 * u;
		v.y += sin(TIME * 2.1 + u * 3.0) * 0.03 * u;
	}
	float fw = 0.0;
	vec2 away = vec2(0.0, 1.0);
	if (wave_r > 0.0) {
		vec2 d = origin.xz - wave_center.xz;
		float dist = length(d);
		fw = clamp((wave_r - dist) / 6.0 - rnd * 0.5, 0.0, 1.0);
		away = dist > 0.01 ? d / dist : away;
	}
	float fi = INSTANCE_CUSTOM.r < 90000.0 ? clamp((clock - INSTANCE_CUSTOM.r) / 0.7, 0.0, 1.0) : 0.0;
	float f = max(fw, fi);
	float a = INSTANCE_CUSTOM.g * 6.2831853;
	vec2 dir = fi > fw ? vec2(cos(a), sin(a)) : away;
	f = f * f * (3.0 - 2.0 * f);
	v_fall = f;
	v_house = INSTANCE_CUSTOM.a;
	float sway = (1.0 - f) * sin(TIME * (1.1 + rnd) + rnd * 20.0) * 0.03;
	mat3 inv = transpose(mat3(MODEL_MATRIX));
	vec3 dl = normalize(inv * vec3(dir.x, 0.0, dir.y));
	vec3 axis = normalize(cross(vec3(0.0, 1.0, 0.0), dl));
	float ang = f * 1.52 + sway;
	float c = cos(ang), s = sin(ang);
	v = v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
	v.y -= f * 0.06;
	VERTEX = v;
	NORMAL = NORMAL * c + cross(axis, NORMAL) * s + axis * dot(axis, NORMAL) * (1.0 - c);
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (COLOR.a < 0.25) {
		col = palette[clamp(int(v_house + 0.5), 0, 7)];
	}
	col *= mix(1.0, 0.28, v_fall);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), v_fall * 0.75);
	ALBEDO = col;
	bool metal = COLOR.a > 0.85;
	ROUGHNESS = metal ? 0.38 : 0.82;
	METALLIC = metal ? 0.75 : 0.0;
}

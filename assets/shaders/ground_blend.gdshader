// Gelände aus tools/pipeline/loc_kit.py: Gras und Weg weich überblendet (Wegmaske im Farbattribut),
// großflächige Farbschwankung gegen sichtbare Kachelung.
shader_type spatial;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 0.8;
uniform vec3 path_tint = vec3(1.02, 0.95, 0.86);

varying float mask;

void vertex() {
	mask = COLOR.r;
}

void fragment() {
	vec3 g = texture(grass_tex, UV).rgb;
	vec3 g2 = texture(grass_tex, UV * 0.27 + vec2(0.31, 0.17)).rgb;
	float macro = texture(grass_tex, UV * 0.031).g;
	g = mix(g, g2, 0.35) * mix(0.82, 1.12, macro);
	vec3 p = texture(path_tex, UV).rgb * path_tint;
	float breakup = texture(path_tex, UV * 0.19).r - 0.5;
	float m = smoothstep(0.3, 0.7, mask + breakup * 0.55);
	ALBEDO = mix(g, p, m);
	NORMAL_MAP = mix(texture(grass_nrm, UV).rgb, texture(path_nrm, UV).rgb, m);
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.96, 0.88, m);
}

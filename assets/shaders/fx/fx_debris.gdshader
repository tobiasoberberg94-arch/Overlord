// Trümmer als Mesh-Partikel (Knochensplitter, Steinbrocken, Eisscherben, Holzspäne): beleuchtet, Tönung je Emitter,
// leichte Farbabweichung je Splitter; optional glasartig glänzend (Eis).
shader_type spatial;
render_mode cull_disabled;

instance uniform vec4 tint : source_color = vec4(0.85, 0.8, 0.7, 1.0);
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float emission = 0.0;

varying float vary;

void vertex() {
	vary = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}

void fragment() {
	ALBEDO = tint.rgb * mix(0.72, 1.12, vary);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = tint.rgb * emission;
}

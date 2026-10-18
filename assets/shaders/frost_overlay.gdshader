// Reif/Schnee als Überzug: nach oben zeigende Flächen werden weiß bestäubt.
shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform float amount = 0.7;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float up = smoothstep(0.25, 0.75, wn.y);
	ALBEDO = vec3(0.9, 0.95, 1.0);
	ALPHA = up * amount;
	ROUGHNESS = 0.7;
}

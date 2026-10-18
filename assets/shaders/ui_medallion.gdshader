shader_type canvas_item;
// Rundes Porträt-Medaillon: Ausschnitt (crop) aus dem Figuren-Render, Kreis-Maske, Goldring mit Lichtkante.

uniform vec4 crop = vec4(0.22, 0.2, 0.56, 0.42);   // x, y, w, h im Texturraum
uniform vec4 gold : source_color = vec4(0.83, 0.69, 0.22, 1.0);
uniform vec4 back : source_color = vec4(0.10, 0.05, 0.16, 1.0);
uniform float ring = 0.07;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	vec4 tex = texture(TEXTURE, crop.xy + UV * crop.zw);
	vec3 bg = back.rgb * (1.2 - d * 0.6);
	vec3 col = mix(bg, tex.rgb, tex.a);
	col *= 1.0 - smoothstep(0.55, 1.0 - ring, d) * 0.45;          // Vignette zum Rand
	float r0 = 1.0 - ring * 2.0;
	float rim = smoothstep(r0 - 0.02, r0, d) * (1.0 - smoothstep(0.98, 1.0, d));
	float light = 0.65 + 0.6 * clamp(-p.y * 0.7 - p.x * 0.3, -0.5, 1.0);
	col = mix(col, gold.rgb * light, rim);
	float inner = 1.0 - smoothstep(0.0, 0.015, abs(d - (r0 - 0.06)));
	col = mix(col, gold.rgb, inner * 0.35);
	COLOR = vec4(col, 1.0 - smoothstep(0.98, 1.0, d));
}

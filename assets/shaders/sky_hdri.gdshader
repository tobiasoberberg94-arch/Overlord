// Fotografierter Himmel (HDRI-Panorama, Poly Haven CC0): gedreht, damit die Sonne im Bild zur Spielsonne passt,
// unterhalb des Horizonts in den Dunst übergeblendet (keine schwarze Bodenhälfte), Helligkeit normiert.
// Panorama-Abbildung: u = atan(x, -z) / 2π + 0.5, v = acos(y) / π (wie Godots PanoramaSky).
shader_type sky;

uniform sampler2D panorama : filter_linear, repeat_enable;
uniform float yaw = 0.0;                  // Drehung um die Hochachse (Bogenmaß)
uniform float energy = 1.0;
uniform vec3 horizon_col : source_color = vec3(0.7, 0.74, 0.8);
uniform float horizon_blend = 0.06;       // wie weit über dem Horizont der Dunst einblendet
uniform float sun_boost = 1.0;            // Sonnenscheibe zusätzlich (für Lichtstrahlen/Bloom)
uniform float radiance_scale = 0.55;
uniform float clamp_max = 5.0;            // Foto-Sonne kappen (kommt als Richtungslicht + eigene Scheibe)      // Anteil fürs Umgebungslicht (die Sonne kommt extra als Richtungslicht)

vec3 sample_pano(vec3 d) {
	float c = cos(yaw), s = sin(yaw);
	vec3 r = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
	vec2 uv = vec2(atan(r.x, -r.z) / (2.0 * PI) + 0.5, acos(clamp(r.y, -1.0, 1.0)) / PI);
	return texture(panorama, uv).rgb;
}

void sky() {
	vec3 d = EYEDIR;
	// unterhalb des Horizonts: Spiegelung der Horizontlinie, in Dunst gehüllt
	vec3 dd = vec3(d.x, max(d.y, 0.012), d.z);
	vec3 col = min(sample_pano(normalize(dd)) * energy, vec3(clamp_max));
	float below = smoothstep(0.0, -0.08, d.y);
	vec3 haze = horizon_col * energy;
	col = mix(col, haze, clamp(below + (1.0 - smoothstep(0.0, horizon_blend, d.y)) * 0.35, 0.0, 1.0));
	if (LIGHT0_ENABLED && AT_CUBEMAP_PASS == false) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * smoothstep(0.99985, 0.99995, sd) * 4.0 * sun_boost;
	}
	if (AT_CUBEMAP_PASS) {
		col *= radiance_scale;
	}
	COLOR = col;
}

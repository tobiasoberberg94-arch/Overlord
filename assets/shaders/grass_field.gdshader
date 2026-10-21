// Gras des GrassField (scripts/world3d/grass_field.gd): Verlauf Wurzel→Spitze mit Bodenschatten,
// großflächige Farbflecken (frisch/trocken), Windböen, Durchscheinen, Glanz auf den Halmen und
// sanftes Absinken zur Sichtgrenze statt Aufploppen.
// Farbattribut: r = Höhe am Halm, g = Zufall je Halm, b = 1 bei Blütenblatt, a = Blütenfarbe.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_col : source_color = vec3(0.03, 0.05, 0.012);
uniform vec3 tip_col : source_color = vec3(0.21, 0.29, 0.08);
uniform vec3 dry_col : source_color = vec3(0.42, 0.37, 0.18);
uniform vec3 lush_col : source_color = vec3(0.11, 0.22, 0.045);
uniform float dry_amount = 0.4;
uniform float wind = 0.22;
uniform float fade_start = 40.0;
uniform float fade_end = 54.0;

varying vec3 v_col;
varying float v_h;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Instanz-Ursprung: MODEL_MATRIX enthält bei MultiMesh bereits die Instanz-Transformation. Die Instanz-ID nur
	// für Zufallswerte (Phase, Farbe) – nie in Positionen/Entfernungen (sonst sinken fast alle Büschel weg).
	vec3 origin = MODEL_MATRIX[3].xyz;
	float irnd = fract(sin(float(INSTANCE_ID) * 12.9898 + origin.x * 0.731 + origin.z * 1.37) * 43758.5453);
	float h = COLOR.r;
	v_h = h;
	// Wind: großräumige Böen, die über die Wiese laufen, plus Zittern je Halm
	float gust = sin(dot(origin.xz, vec2(0.07, 0.05)) - TIME * 1.3) * 0.5 + 0.5;
	gust = gust * gust;
	float t = TIME * 2.1 + origin.x * 0.37 + origin.z * 0.29 + COLOR.g * 6.28 + irnd * 6.28;
	vec2 bend = vec2(0.8, 0.45) * gust * 1.4 + vec2(sin(t), cos(t * 0.8)) * 0.35;
	bend *= wind * h * h;
	// Welt → Büschel: Drehung um die Hochachse mit Maßstab – statt inverse() je Vertex (teuer bei Millionen Halmen)
	mat3 m3 = mat3(MODEL_MATRIX);
	vec3 wb = vec3(bend.x, 0.0, bend.y);
	VERTEX.x += dot(m3[0], wb) / max(dot(m3[0], m3[0]), 1e-4);
	VERTEX.z += dot(m3[2], wb) / max(dot(m3[2], m3[2]), 1e-4);
	VERTEX.y -= dot(bend, bend) * 0.6;
	// zur Sichtgrenze hin einsinken
	float d = distance(CAMERA_POSITION_WORLD, origin);
	float shrink = 1.0 - smoothstep(fade_start, fade_end, d);
	VERTEX.y *= shrink;
	// Farbe
	float patch = sin(origin.x * 0.045 + 1.3) * cos(origin.z * 0.052 + 0.4) * 0.5 + 0.5;
	float patch2 = sin(origin.x * 0.21 - origin.z * 0.17) * 0.5 + 0.5;
	vec3 tip = mix(lush_col, tip_col, patch2);
	tip = mix(tip, dry_col, smoothstep(0.55, 0.95, patch) * dry_amount + COLOR.g * 0.15 * dry_amount);
	tip *= mix(0.88, 1.1, irnd);                       // jedes Büschel etwas anders hell
	// einzelne trockene bzw. dunkle Halme
	float bl = COLOR.g;
	tip = mix(tip, dry_col * 1.15, step(0.86, bl) * 0.8);
	tip *= mix(1.0, 0.68, step(bl, 0.12));
	float ao = mix(0.55, 1.0, smoothstep(0.0, 0.55, h));
	v_col = mix(base_col, tip, smoothstep(0.0, 0.9, h)) * ao * (0.85 + 0.3 * COLOR.g) * (1.0 + gust * 0.12);
	if (COLOR.b > 0.5) {
		int k = int(COLOR.a * 4.99);
		vec3 pal[5] = vec3[](vec3(0.95, 0.93, 0.86), vec3(0.98, 0.80, 0.12), vec3(0.80, 0.10, 0.10),
				vec3(0.52, 0.33, 0.86), vec3(0.96, 0.55, 0.72));
		v_col = pal[k];
	}
	// Normalen zur Wiese hin glätten (einheitliches Licht), Halmrundung bleibt
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.45));
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.72;
	SPECULAR = 0.22;
	BACKLIGHT = v_col * 0.38;
	AO = mix(0.6, 1.0, v_h);
	AO_LIGHT_AFFECT = 0.6;
}

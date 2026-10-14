// Efecto de pantalla de las habilidades de tiempo: onda expansiva, destello,
// inversión de color, tinte, aberración cromática, viñeta y scanlines.
// time_fx.gd ajusta los parámetros según la habilidad (Sandevistan o detener).
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float intensity : hint_range(0.0, 1.0) = 0.0; // efecto persistente mientras dura el congelamiento
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float wave_radius = -1.0; // < 0 desactiva la onda
uniform float wave_width = 0.16;
uniform float wave_strength = 0.05;
uniform vec2 center = vec2(0.5);
uniform float aspect = 1.7778;
uniform vec4 tint : source_color = vec4(0.62, 1.0, 0.42, 1.0);
uniform float desaturation : hint_range(0.0, 1.0) = 0.6;
uniform float scanlines : hint_range(0.0, 1.0) = 1.0;
uniform float invert : hint_range(0.0, 1.0) = 0.0; // destello en negativo

void fragment() {
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float dist = length(d);
	vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);

	// Onda expansiva: banda gaussiana alrededor del radio actual
	float ring = 0.0;
	vec2 uv = SCREEN_UV;
	if (wave_radius >= 0.0) {
		float x = (dist - wave_radius) / wave_width;
		ring = exp(-x * x * 4.0);
		vec2 offset = dir * ring * wave_strength;
		offset.x /= aspect;
		uv -= offset;
	}

	// Aberración cromática: más fuerte en la onda y hacia los bordes
	float ca = 0.004 * intensity * (0.5 + dist) + ring * 0.02;
	vec2 cad = dir * ca;
	cad.x /= aspect;
	vec3 col = vec3(
		texture(screen_texture, uv + cad).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - cad).b);

	// Corrección de color: desatura y tiñe
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(col, vec3(lum) * tint.rgb * 1.2, desaturation);
	col = mix(col, graded, intensity);

	col += tint.rgb * (ring * 0.55 + flash * 0.6);
	col = mix(col, vec3(1.0) - col, invert);

	// Viñeta y scanlines
	float vig = smoothstep(0.55, 1.15, length((SCREEN_UV - 0.5) * vec2(aspect, 1.0)));
	col *= 1.0 - vig * 0.55 * intensity;
	col *= 1.0 - intensity * scanlines * 0.07 * mod(floor(FRAGCOORD.y), 2.0);

	COLOR = vec4(col, 1.0);
}

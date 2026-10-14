// Capas del fondo de la ciudad y los elementos animados que viven en ellas.
// time_fx.gd lo ajusta según la habilidad de tiempo activa:
//   smear  (Q): estela horizontal de movimiento (solo en las capas con textura)
//   freeze (R): el fondo pasa a escala de grises al instante
shader_type canvas_item;

uniform float smear : hint_range(0.0, 1.0) = 0.0;
uniform float freeze : hint_range(0.0, 1.0) = 0.0;
uniform bool allow_smear = true; // false para lo dibujado con primitivas (drones, tráfico...)
uniform float smear_px = 8.0;

void fragment() {
	vec4 col = COLOR;
	if (allow_smear && smear > 0.0) {
		vec4 acc = col;
		float wsum = 1.0;
		for (int i = 1; i <= 4; i++) {
			float o = float(i) * smear_px * smear / 4.0 * TEXTURE_PIXEL_SIZE.x;
			float w = 1.0 - float(i) / 5.0;
			acc += texture(TEXTURE, UV + vec2(o, 0.0)) * w;
			acc += texture(TEXTURE, UV - vec2(o, 0.0)) * w;
			wsum += 2.0 * w;
		}
		col = acc / wsum;
	}
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(g), freeze);
	COLOR = col;
}

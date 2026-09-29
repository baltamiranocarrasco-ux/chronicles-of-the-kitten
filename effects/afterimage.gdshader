// Silueta de color plano para la estela: usa el alfa del sprite y el color de modulate.
shader_type canvas_item;
render_mode blend_mix;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, a * tint.a);
}

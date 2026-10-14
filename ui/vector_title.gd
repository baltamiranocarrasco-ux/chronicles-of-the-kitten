extends Node2D
## Texto con la tipografía vectorial de los hologramas (effects/hologram_ads.gd),
## con resplandor y un parpadeo leve de tubo de neón.

const HOLO := preload("res://effects/hologram_ads.gd")

@export var text := ""
@export var size := 1.6 ## escala de la rejilla de 4x6 de cada letra (px del juego)
@export var color := Color(0.4, 0.95, 1.0)
@export var centered := true

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func width() -> float:
	return text.length() * 5.2 * size - 1.2 * size


func _draw() -> void:
	var lines := PackedVector2Array()
	var x := -width() / 2.0 if centered else 0.0
	for ch in text:
		for stroke in HOLO.FONT.get(ch, []):
			for i in range(0, stroke.size() - 2, 2):
				lines.append(Vector2(x + stroke[i] * size, stroke[i + 1] * size))
				lines.append(Vector2(x + stroke[i + 2] * size, stroke[i + 3] * size))
		x += 5.2 * size
	if lines.is_empty():
		return
	var flicker := 0.92 + 0.08 * sin(_t * 37.0) * sin(_t * 5.3)
	draw_multiline(lines, Color(color, 0.18 * flicker), size * 1.6, true)
	draw_multiline(lines, Color(color, 0.35 * flicker), size * 0.7, true)
	draw_multiline(lines, Color(color.lightened(0.4), flicker), size * 0.28, true)

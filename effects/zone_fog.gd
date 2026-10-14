@tool
extends Node2D
## Penumbra de la zona baja: un degradado que oscurece las estructuras de
## abajo (de transparente arriba a casi negro abajo) con neblina de vapor
## que se desliza. Va sobre los tiles y debajo del gato y los objetos.

@export var size := Vector2(640, 160):
	set(v):
		size = v
		queue_redraw()
@export var color := Color(0.02, 0.02, 0.05)
@export var haze := Color(0.45, 0.55, 0.6)

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var steps := 12
	for i in steps:
		var y0 := size.y * i / steps
		var a := 0.35 + pow(float(i + 1) / steps, 0.9) * 0.6
		draw_rect(Rect2(0, y0, size.x, size.y / steps + 0.5), Color(color, a))
	# Bandas de neblina
	for k in 3:
		var y := size.y * (0.25 + k * 0.2)
		var x := fposmod(_t * (4.0 + k * 2.0), 80.0) - 80.0
		while x < size.x:
			draw_rect(Rect2(x, y, 50, 3 + k), Color(haze, 0.035))
			x += 80.0

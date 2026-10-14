extends Node2D
## Destello al recoger algo (batería, chip): anillo y chispas que suben.

var color := Color(0.4, 1.0, 0.6)
var _t := 0.0


func _ready() -> void:
	z_index = 4
	process_mode = PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta / Engine.time_scale
	if _t > 0.6:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / 0.6
	draw_arc(Vector2.ZERO, 3.0 + k * 16.0, 0.0, TAU, 28, Color(color, 1.0 - k), 0.8, true)
	for i in 8:
		var x := (i - 3.5) * 2.5
		draw_line(Vector2(x, -k * 20.0 - i % 3 * 2.0), Vector2(x, -k * 20.0 - i % 3 * 2.0 + 3.0),
				Color(color.lightened(0.4), 1.0 - k), 0.5, true)

@tool
extends StaticBody2D
## Tubería industrial que une dos edificios en la zona alta. Se puede caminar
## por encima (se atraviesa desde abajo). Origen = extremo izquierdo, a la
## altura de la parte de arriba del caño.

const PIPE := Color(0.24, 0.26, 0.33)
const PIPE_HI := Color(0.55, 0.58, 0.7)
const PIPE_DK := Color(0.1, 0.11, 0.15)
const RUST := Color(0.42, 0.25, 0.16)

@export var length := 96.0:
	set(v):
		length = v
		_rebuild()
@export var thickness := 8.0

var _shape := CollisionShape2D.new()


func _ready() -> void:
	_shape.one_way_collision = true
	add_child(_shape)
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	var r := RectangleShape2D.new()
	r.size = Vector2(length, 4)
	_shape.shape = r
	_shape.position = Vector2(length / 2.0, 2)
	queue_redraw()


func _draw() -> void:
	var t := thickness
	draw_rect(Rect2(0, 0, length, t), PIPE)
	draw_rect(Rect2(0, 0.6, length, 1.4), PIPE_HI)
	draw_rect(Rect2(0, t - 1.6, length, 1.6), PIPE_DK)
	# Uniones con brida cada 32 px, manchas de óxido y una válvula
	var x := 16.0
	var i := 0
	while x < length - 4:
		draw_rect(Rect2(x - 1.2, -0.8, 2.4, t + 1.6), PIPE_DK)
		draw_rect(Rect2(x - 1.2, -0.8, 0.7, t + 1.6), PIPE_HI)
		if i % 2 == 1:
			draw_rect(Rect2(x + 6, t * 0.45, 4, 2), Color(RUST, 0.8))
		x += 32.0
		i += 1
	var vx := length * 0.6
	draw_rect(Rect2(vx - 1, -4, 2, 4), PIPE_DK)
	draw_circle(Vector2(vx, -4.5), 2.4, Color(0.7, 0.2, 0.2), false, 0.8, true)
	# Soportes que bajan a los muros
	for end in [2.0, length - 4.0]:
		draw_rect(Rect2(end, t, 2, 10), PIPE_DK)

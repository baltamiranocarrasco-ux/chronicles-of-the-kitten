extends Node2D
## Cortina de minas con púas que caen sin parar (el nombre del archivo es
## histórico: antes eran castañas del bosque).
## Es tan densa que no se puede cruzar ni con cámara lenta (la densidad no
## cambia); solo congelando el tiempo (R): las Area2D congeladas no dañan y,
## al no tener cuerpo sólido, se pueden atravesar.

const HAZARD := preload("res://objects/hazard.gd")
const TEXTURE := preload("res://objects/spike_ball.png")

@export var columns := 3
@export var column_spacing := 16.0
@export var spacing := 22.0 ## distancia vertical entre castañas de una columna
@export var fall_speed := 150.0
@export var top := -168.0 ## y local donde aparecen (sobre la pantalla)
@export var bottom := 8.0 ## y local donde desaparecen (bajo el suelo)

var _t := 0.0
var _balls: Array[Area2D] = []


func _ready() -> void:
	var per_column := ceili((bottom - top) / spacing) + 1
	for c in columns:
		for i in per_column:
			var ball := Area2D.new()
			ball.set_script(HAZARD)
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 6.0
			shape.shape = circle
			ball.add_child(shape)
			var sprite := Sprite2D.new()
			sprite.texture = TEXTURE
			sprite.rotation = randf() * TAU
			ball.add_child(sprite)
			ball.set_meta("column", c)
			ball.set_meta("index", i)
			add_child(ball)
			_balls.append(ball)
	_place()


func _physics_process(delta: float) -> void:
	_t += delta
	_place()


func _place() -> void:
	var span := bottom - top
	for ball in _balls:
		var c: int = ball.get_meta("column")
		var i: int = ball.get_meta("index")
		var x := (c - (columns - 1) / 2.0) * column_spacing
		# Columnas desfasadas medio espacio para que la cortina no tenga huecos alineados
		var y := top + fposmod(_t * fall_speed + i * spacing + c * spacing * 0.5, span)
		ball.position = Vector2(x, y)
		ball.get_child(1).rotation += 0.15

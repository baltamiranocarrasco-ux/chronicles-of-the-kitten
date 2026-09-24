extends Node2D
## Mueve el objeto en un ciclo repetitivo desde su posición inicial.
## Usa el delta normal: la cámara lenta (Q) lo frena y congelar el tiempo (R)
## lo detiene, sin código extra.

enum Motion {
	SMOOTH, ## vaivén suave de ida y vuelta
	SLAM, ## espera, cae de golpe, espera y sube lento (aplastador)
}

@export var travel := Vector2(64, 0) ## desplazamiento máximo desde el origen
@export var period := 2.0 ## segundos por ciclo completo
@export var motion := Motion.SMOOTH
@export_range(0.0, 1.0) var phase_offset := 0.0 ## desfase para no ir sincronizado con otros
@export var roll_radius := 0.0 ## si es > 0, el Sprite2D gira como si rodara

var _t := 0.0
@onready var _origin := position
@onready var _sprite: Node2D = get_node_or_null("Sprite2D")


func _physics_process(delta: float) -> void:
	_t += delta
	var p := fposmod(_t / period + phase_offset, 1.0)
	var previous_x := position.x
	position = _origin + travel * _curve(p)
	if roll_radius > 0.0 and _sprite:
		_sprite.rotation += (position.x - previous_x) / roll_radius


func _curve(p: float) -> float:
	match motion:
		Motion.SLAM:
			if p < 0.35:
				return 0.0
			if p < 0.45:
				var f := (p - 0.35) / 0.1
				return f * f
			if p < 0.65:
				return 1.0
			return 1.0 - (p - 0.65) / 0.35
		_:
			return 0.5 - 0.5 * cos(p * TAU)

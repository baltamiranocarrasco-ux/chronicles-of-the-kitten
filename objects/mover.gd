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

@export_group("Slam")
## Fracciones del ciclo para SLAM (el resto del ciclo es la subida lenta)
@export_range(0.0, 1.0) var slam_hold_up := 0.35 ## esperando arriba
@export_range(0.0, 1.0) var slam_fall := 0.1 ## cayendo
@export_range(0.0, 1.0) var slam_hold_down := 0.2 ## esperando abajo

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
			var fall_end := slam_hold_up + slam_fall
			var down_end := fall_end + slam_hold_down
			if p < slam_hold_up:
				return 0.0
			if p < fall_end:
				var f := (p - slam_hold_up) / slam_fall
				return f * f
			if p < down_end:
				return 1.0
			return 1.0 - (p - down_end) / (1.0 - down_end)
		_:
			return 0.5 - 0.5 * cos(p * TAU)

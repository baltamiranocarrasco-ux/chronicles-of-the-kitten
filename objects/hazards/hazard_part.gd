extends Area2D
## Pieza de un peligro compuesto (una mina de la cortina, la hoja de una
## sierra...). Pasa el contacto al nodo padre, que decide qué hacer.

var index := 0


func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false


func touch(player: Node2D, real_delta: float) -> void:
	get_parent().touch_part(self, player, real_delta)

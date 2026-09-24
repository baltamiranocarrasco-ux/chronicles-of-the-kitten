extends Marker2D
## Punto de reaparición: se activa cuando el jugador pasa por su X.
## No usa Area2D para que también funcione con el tiempo congelado.

var _reached := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if _reached:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.x >= global_position.x:
		_reached = true
		player.spawn_position = global_position

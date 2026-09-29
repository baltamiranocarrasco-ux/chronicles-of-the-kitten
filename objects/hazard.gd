extends Area2D
## Zona peligrosa: si el jugador la toca, vuelve al último checkpoint.
## Con el tiempo congelado las Area2D no detectan nada, así que un peligro
## congelado no hace daño (pero su cuerpo sólido sigue bloqueando el paso).


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("respawn"):
		body.respawn()

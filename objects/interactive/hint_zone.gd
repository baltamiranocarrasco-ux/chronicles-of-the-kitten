extends Area2D
## Zona invisible que muestra una pista en pantalla la primera vez que el
## gato la cruza.

@export var text := ""
@export var subtitle := ""
@export var size := Vector2(24, 96)
@export var color := Color(0.4, 0.95, 1.0)
@export var seconds := 3.2

var _shown := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	add_child(cs)


func touch(player: Node2D, _real_delta: float) -> void:
	if _shown:
		return
	_shown = true
	player.hud.toast(text, seconds, color, subtitle)

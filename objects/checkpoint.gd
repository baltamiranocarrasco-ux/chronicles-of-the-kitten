extends Marker2D
## Punto de reaparición: se activa cuando el jugador pasa por su X y le
## devuelve toda la vida. Es una baliza en la azotea: roja apagada, cian al
## activarse. No usa Area2D para que también funcione con el tiempo congelado.

const OFF := Color(0.9, 0.25, 0.3)
const ON := Color(0.35, 0.95, 1.0)

var _reached := false
var _t := 0.0
var _burst := 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if _reached:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.x >= global_position.x \
			and absf(player.global_position.y - global_position.y) < 64.0:
		_reached = true
		_burst = 1.0
		player.spawn_position = global_position
		if player.has_method("heal_full"):
			player.heal_full()


func _process(delta: float) -> void:
	var real := delta / Engine.time_scale
	_t += real
	_burst = maxf(_burst - real * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	# El marcador está 16 px sobre el suelo (a la altura del centro del gato)
	var base := Vector2(-6, 16)
	var c := ON if _reached else OFF
	draw_rect(Rect2(base + Vector2(-2.5, -2), Vector2(5, 2)), Color(0.12, 0.13, 0.18))
	draw_line(base + Vector2(0, -2), base + Vector2(0, -15), Color(0.32, 0.35, 0.45), 1.2, true)
	draw_line(base + Vector2(0.4, -2), base + Vector2(0.4, -15), Color(0.6, 0.65, 0.8, 0.6), 0.3, true)
	var blink := 1.0 if _reached else (0.5 + 0.5 * signf(sin(_t * 4.0)))
	var top := base + Vector2(0, -16.5)
	draw_circle(top, 4.0, Color(c, 0.15 * blink), true, -1.0, true)
	draw_circle(top, 1.6, Color(c, blink), true, -1.0, true)
	if _burst > 0.0:
		draw_arc(top, 4.0 + (1.0 - _burst) * 22.0, 0.0, TAU, 32, Color(c, _burst), 0.8, true)

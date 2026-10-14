@tool
extends Area2D
## Terminal de energía: un enchufe corporativo en la pared. Cerca de él,
## E engancha la cola de interfaz del gato y absorbe carga: la barra de las
## habilidades se llena de golpe. Después la terminal tarda en recargarse
## (LED rojo); con el LED verde está lista.
## Origen = el enchufe (unos 10 px sobre el suelo).

const CHARGE_TIME := 0.45 ## lo que tarda el cable en enganchar y cargar
const COOLDOWN := 14.0
const READY := Color(0.4, 1.0, 0.6)
const BUSY := Color(1.0, 0.3, 0.35)
const ENERGY := Color(0.35, 0.95, 1.0)
const CASE := Color(0.16, 0.17, 0.23)
const CASE_HI := Color(0.46, 0.5, 0.62)

var _cooldown := 0.0
var _charging := 0.0
var _player: Node2D
var _near := 0.0 ## > 0 mientras el gato está cerca (muestra la E)
var _t := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 26)
	cs.shape = r
	cs.position = Vector2(0, -2)
	add_child(cs)
	if not Engine.is_editor_hint():
		process_mode = PROCESS_MODE_ALWAYS # también se usa con el tiempo detenido


func touch(player: Node2D, _real_delta: float) -> void:
	_player = player
	_near = 0.15
	if _cooldown <= 0.0 and _charging <= 0.0 and Input.is_action_just_pressed("interact"):
		_charging = CHARGE_TIME


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var real := delta / Engine.time_scale
	_t += real
	_near = maxf(_near - real, 0.0)
	_cooldown = maxf(_cooldown - real, 0.0)
	if _charging > 0.0:
		_charging -= real
		if _charging <= 0.0 and _player:
			_player.time_powers.recharge(TimePowers.MAX_ENERGY)
			_cooldown = COOLDOWN
	queue_redraw()


func _tail_pos() -> Vector2:
	# Base de la cola del gato, del lado contrario al que mira
	return to_local(_player.global_position + Vector2(-9.0 * _player.facing(), 4.0))


func _draw() -> void:
	# Caja del enchufe con tornillos y ranura de datos
	draw_rect(Rect2(-5, -6, 10, 12), CASE)
	draw_rect(Rect2(-5, -6, 10, 0.8), CASE_HI)
	draw_rect(Rect2(-2.5, -2.5, 5, 4), Color(0.05, 0.05, 0.08))
	draw_rect(Rect2(-1.5, -1.5, 0.8, 2), Color(0.35, 0.38, 0.48))
	draw_rect(Rect2(0.7, -1.5, 0.8, 2), Color(0.35, 0.38, 0.48))
	for c in [Vector2(-3.8, -4.8), Vector2(3.8, -4.8), Vector2(-3.8, 4.8), Vector2(3.8, 4.8)]:
		draw_circle(c, 0.45, CASE_HI, true, -1.0, true)
	# Cable que baja al suelo
	draw_line(Vector2(0, 6), Vector2(0, 10), Color(0.05, 0.05, 0.07), 1.0)
	var ready := _cooldown <= 0.0
	var led := READY if ready else BUSY
	var blink := 1.0 if ready else 0.5 + 0.5 * signf(sin(_t * 5.0))
	draw_circle(Vector2(0, -8.5), 2.6, Color(led, 0.2 * blink), true, -1.0, true)
	draw_circle(Vector2(0, -8.5), 0.9, Color(led, blink), true, -1.0, true)
	if not ready:
		# Arco que se completa mientras se recarga
		var k := 1.0 - _cooldown / COOLDOWN
		draw_arc(Vector2(0, -8.5), 3.6, -PI / 2, -PI / 2 + TAU * k, 16, Color(READY, 0.6), 0.5, true)
	if Engine.is_editor_hint():
		return
	if _charging > 0.0 and _player:
		# La cola se engancha: cable con pulsos de energía hacia el gato
		var a := Vector2(0, 0)
		var b := _tail_pos()
		var mid := a.lerp(b, 0.5) + Vector2(0, 6)
		var pts := PackedVector2Array()
		for k in 13:
			var u := k / 12.0
			pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		draw_polyline(pts, Color(0.04, 0.04, 0.06), 1.3, true)
		draw_polyline(pts, Color(ENERGY, 0.35), 2.6, true)
		for k in 3:
			var u := fposmod(_t * 4.0 + k / 3.0, 1.0)
			draw_circle(pts[int(u * 12)], 1.1, ENERGY.lightened(0.5), true, -1.0, true)
	elif _near > 0.0 and ready:
		# Indicación de la tecla
		var y := -16.0 + sin(_t * 4.0) * 1.0
		draw_rect(Rect2(-4, y - 4, 8, 8), Color(0.03, 0.03, 0.07, 0.75))
		draw_rect(Rect2(-4, y - 4, 8, 8), Color(ENERGY, 0.8), false, 0.5)
		draw_polyline(PackedVector2Array([Vector2(1.5, y - 2.2), Vector2(-1.5, y - 2.2), Vector2(-1.5, y + 2.2),
				Vector2(1.5, y + 2.2)]), ENERGY, 0.6, true)
		draw_line(Vector2(-1.5, y), Vector2(1.0, y), ENERGY, 0.6, true)

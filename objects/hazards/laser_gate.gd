@tool
extends Area2D
## Puerta de escáner con barrera láser (cian o magenta). Se apaga solo un
## instante por ciclo (OFF_TIME): en tiempo normal es casi imposible pasar,
## con la Q (cámara lenta) el hueco dura ~3 veces más, y con la R (tiempo
## detenido) se congela: si quedó apagada se cruza tranquilo, si quedó
## encendida sigue quemando (la luz congelada sigue ahí).
## Origen = emisor de arriba; el haz baja `height` px hasta el emisor del suelo.

const DAMAGE := 25.0
const WARN := 0.12 ## parpadeo de aviso antes de encenderse

@export var height := 32.0:
	set(v):
		height = v
		_rebuild()
@export var on_time := 1.0
@export var off_time := 0.16
@export var phase := 0.0 ## desfase del ciclo (s)
@export var color := Color(0.3, 0.95, 1.0)

var _t := 0.0
var _shape := CollisionShape2D.new()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_child(_shape)
	_rebuild()
	_t = phase


func _rebuild() -> void:
	if not is_node_ready():
		return
	var r := RectangleShape2D.new()
	r.size = Vector2(4, height - 4)
	_shape.shape = r
	_shape.position = Vector2(0, height / 2.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta


func _process(_delta: float) -> void:
	queue_redraw()


## Tiempo dentro del ciclo: [0, off_time) apagado, el resto encendido.
func _cycle() -> float:
	return fposmod(_t, on_time + off_time)


func is_on() -> bool:
	return _cycle() >= off_time


func touch(player: Node2D, _real_delta: float) -> void:
	if is_on():
		player.hurt(DAMAGE, global_position + Vector2(0, height / 2.0), &"shock")


func _draw() -> void:
	var on := is_on() or Engine.is_editor_hint()
	var cyc := _cycle()
	var warn := not on and cyc > off_time - WARN
	var top := Vector2(0, 2)
	var bottom := Vector2(0, height - 2)
	if on:
		var flicker := 0.85 + 0.15 * sin(_t * 90.0)
		draw_line(top, bottom, Color(color, 0.12 * flicker), 7.0, true)
		draw_line(top, bottom, Color(color, 0.35 * flicker), 3.0, true)
		draw_line(top, bottom, Color(color.lightened(0.6), 0.95), 0.9, true)
		# Ondulación del haz y chispas en los extremos
		for i in 6:
			var y := fposmod(_t * 60.0 + i * height / 6.0, height - 4) + 2
			draw_line(Vector2(-1.2, y), Vector2(1.2, y + 1.5), Color(Color.WHITE, 0.5), 0.3, true)
		draw_circle(bottom, 2.2, Color(color, 0.4), true, -1.0, true)
	elif warn:
		draw_line(top, bottom, Color(color, 0.25), 0.5, true)
	else:
		# Apagada: solo una guía punteada muy tenue
		var y := 4.0
		while y < height - 4:
			draw_line(Vector2(0, y), Vector2(0, y + 1.0), Color(color, 0.18), 0.4)
			y += 4.0
	_draw_emitter(Vector2.ZERO, 1.0, on)
	_draw_emitter(Vector2(0, height), -1.0, on)


func _draw_emitter(at: Vector2, dir: float, on: bool) -> void:
	# Carcasa metálica con anillo de LEDs
	var body := Rect2(at + Vector2(-5, -4 if dir > 0 else 0), Vector2(10, 4))
	draw_rect(body, Color(0.12, 0.13, 0.18))
	draw_rect(Rect2(body.position, Vector2(10, 0.8)), Color(0.45, 0.5, 0.62))
	draw_rect(Rect2(at + Vector2(-2.5, 0 if dir > 0 else -2), Vector2(5, 2)), Color(0.2, 0.22, 0.3))
	var led := color if on else Color(1.0, 0.3, 0.3)
	for i in 3:
		draw_circle(at + Vector2(-3 + i * 3, -2 * dir), 0.55, led, true, -1.0, true)

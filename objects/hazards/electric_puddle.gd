@tool
extends Area2D
## Charco de lluvia electrificado sobre una plataforma de metal: un cable
## pelado sumergido en una punta. Quita vida por segundo mientras el gato
## esté parado en el agua (sin retroceso: hay que saltarlo o cruzarlo rápido
## deslizándose). La corriente sigue aunque el tiempo esté detenido.
## Origen = borde izquierdo, a la altura de la superficie.

const DPS := 30.0
const WATER := Color(0.16, 0.22, 0.36)
const SHINE := [Color(0.35, 0.95, 1.0), Color(1.0, 0.35, 0.85)]
const ARC := Color(0.6, 0.9, 1.0)

@export var width := 48.0:
	set(v):
		width = v
		_rebuild()

var _t := 0.0
var _shape := CollisionShape2D.new()
var _arcs := [] ## {x, life}
var _drops := [] ## ondas de lluvia {x, age}
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_child(_shape)
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	var r := RectangleShape2D.new()
	r.size = Vector2(width - 4, 8)
	_shape.shape = r
	_shape.position = Vector2(width / 2.0, -4)
	queue_redraw()


func touch(player: Node2D, real_delta: float) -> void:
	player.hurt(DPS * real_delta, global_position + Vector2(width / 2.0, 0), &"tick")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _rnd.randf() < delta * 7.0:
		_arcs.append({x = _rnd.randf_range(3, width - 3), life = _rnd.randf_range(0.06, 0.16)})
	if _rnd.randf() < delta * 5.0:
		_drops.append({x = _rnd.randf_range(2, width - 2), age = 0.0})
	for a in _arcs:
		a.life -= delta
	for d in _drops:
		d.age += delta
	_arcs = _arcs.filter(func(a): return a.life > 0.0)
	_drops = _drops.filter(func(d): return d.age < 0.6)
	queue_redraw()


func _draw() -> void:
	# Película de agua con bordes redondeados y reflejos de neón
	var film := PackedVector2Array([Vector2(1, 0), Vector2(3, -1.6), Vector2(width - 3, -1.6), Vector2(width - 1, 0)])
	draw_colored_polygon(film, Color(WATER, 0.85))
	var hum := 0.55 + 0.45 * sin(_t * 23.0) * sin(_t * 7.0)
	draw_line(Vector2(3, -1.6), Vector2(width - 3, -1.6), Color(ARC, 0.5 + 0.3 * hum), 0.4, true)
	for i in 4:
		var x := fposmod(i * width / 4.0 + _t * 3.0, width - 10) + 5
		draw_line(Vector2(x, -0.8), Vector2(x + 5, -0.8), Color(SHINE[i % 2], 0.45), 0.5, true)
	draw_rect(Rect2(0, -6, width, 6), Color(ARC, 0.05 + 0.04 * hum))
	for d in _drops:
		var r: float = 0.5 + d.age * 6.0
		draw_arc(Vector2(d.x, -0.8), r, PI, TAU, 8, Color(Color.WHITE, 0.4 * (1.0 - d.age / 0.6)), 0.3, true)
	# Cable pelado sumergido
	draw_polyline(PackedVector2Array([Vector2(-6, -9), Vector2(-2, -4), Vector2(3, -1)]), Color(0.04, 0.04, 0.06), 1.4, true)
	draw_line(Vector2(3, -1), Vector2(5, -0.5), Color(0.95, 0.55, 0.3), 0.4, true)
	for a in _arcs:
		var pts := PackedVector2Array()
		var x0: float = a.x
		for k in 5:
			pts.append(Vector2(x0 + k * 1.6 - 3.2, -1.0 - _rnd.randf() * 3.5))
		draw_polyline(pts, Color(ARC, 0.6), 1.0, true)
		draw_polyline(pts, Color.WHITE, 0.3, true)

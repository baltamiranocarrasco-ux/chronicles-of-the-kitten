@tool
extends Node2D
## Cable de alta tensión colgado entre dos edificios. Algunos tramos están
## cortados y cuelgan pelados (drops): cada tanto chisporrotean con una
## descarga que electrocuta al gato si los roza (daño y lo deja aturdido).
## Antes de la descarga sueltan chispitas de aviso. Congelada con la R, una
## descarga en curso sigue electrificada.
## Origen = el extremo izquierdo del cable; `span` = el otro extremo.

const PART := preload("res://objects/hazards/hazard_part.gd")
const DAMAGE := 20.0
const CABLE := Color(0.04, 0.04, 0.06)
const CABLE_HI := Color(0.32, 0.3, 0.42)
const COPPER := Color(0.95, 0.55, 0.3)
const ARC := Color(0.6, 0.85, 1.0)
const WARN_TIME := 0.4

@export var span := Vector2(160, 0):
	set(v):
		span = v
		queue_redraw()
@export var sag := 18.0
## Tramos sueltos: [posición a lo largo del cable (0 a 1), largo en px]
@export var drops: Array = [[0.5, 36.0]]:
	set(v):
		drops = v
		_rebuild()
@export var idle_time := 1.3
@export var spark_time := 0.7
@export var phase := 0.0

var _t := 0.0
var _parts := []
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	_t = phase
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for p in _parts:
		p.queue_free()
	_parts.clear()
	for i in drops.size():
		var a := Area2D.new()
		a.set_script(PART)
		a.index = i
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(5, drops[i][1])
		cs.shape = r
		cs.position = Vector2(0, drops[i][1] / 2.0)
		a.add_child(cs)
		add_child(a)
		_parts.append(a)
	_place()
	queue_redraw()


func _point(t: float) -> Vector2:
	return span * t + Vector2(0, 4.0 * sag * t * (1.0 - t))


func _sway(i: int) -> float:
	return 0.12 * sin(_t * 1.7 + i * 2.1)


func _place() -> void:
	for i in _parts.size():
		_parts[i].position = _point(drops[i][0])
		_parts[i].rotation = _sway(i)


func _cycle() -> float:
	return fposmod(_t, idle_time + spark_time)


func is_live() -> bool:
	return _cycle() >= idle_time


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_place()
	queue_redraw()


func touch_part(part: Area2D, player: Node2D, _real_delta: float) -> void:
	if is_live():
		player.hurt(DAMAGE, part.global_position + Vector2(0, drops[part.index][1]), &"shock")


func _draw() -> void:
	var pts := PackedVector2Array()
	for k in 25:
		pts.append(_point(k / 24.0))
	draw_polyline(pts, CABLE, 1.6, true)
	draw_polyline(pts, Color(CABLE_HI, 0.5), 0.4, true)
	# Aisladores en los extremos
	for end in [Vector2.ZERO, span]:
		draw_rect(Rect2(end + Vector2(-1.5, -3), Vector2(3, 4)), Color(0.55, 0.6, 0.7))
	var live := is_live() and not Engine.is_editor_hint()
	var warn := not live and _cycle() > idle_time - WARN_TIME
	for i in drops.size():
		var top := _point(drops[i][0])
		var dir := Vector2.DOWN.rotated(_sway(i))
		var tip: Vector2 = top + dir * drops[i][1]
		var mid := top.lerp(tip, 0.5) + Vector2(dir.y, -dir.x) * 2.0
		var hang := PackedVector2Array([top, mid, tip])
		draw_polyline(hang, CABLE, 1.4, true)
		# Punta pelada: hilos de cobre abiertos
		for k in [-1.0, 0.0, 1.0]:
			draw_line(tip, tip + dir.rotated(k * 0.6) * 2.5, COPPER, 0.35, true)
		if live:
			var glow := 0.6 + 0.4 * _rnd.randf()
			draw_circle(tip, 6.0, Color(ARC, 0.18 * glow), true, -1.0, true)
			draw_polyline(hang, Color(ARC, 0.4 * glow), 2.4, true)
			for n in 3:
				_arc(tip, tip + Vector2(_rnd.randf_range(-9, 9), _rnd.randf_range(-6, 9)))
			_arc(top, tip)
		elif warn and _rnd.randf() < 0.5:
			draw_line(tip, tip + Vector2(_rnd.randf_range(-3, 3), _rnd.randf_range(-3, 3)), Color(Color.WHITE, 0.8), 0.4, true)


func _arc(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array([a])
	for k in range(1, 5):
		pts.append(a.lerp(b, k / 5.0) + Vector2(_rnd.randf_range(-2, 2), _rnd.randf_range(-2, 2)))
	pts.append(b)
	draw_polyline(pts, Color(ARC, 0.5), 1.2, true)
	draw_polyline(pts, Color(Color.WHITE, 0.9), 0.35, true)

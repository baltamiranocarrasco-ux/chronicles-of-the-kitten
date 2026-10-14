@tool
extends Node2D
## Sierra circular industrial montada en un riel de la pared. Va y viene de
## izquierda a derecha muy rápido (más rápido en el centro del recorrido).
## Daño masivo al contacto, incluso congelada (la hoja sigue afilada).
## Origen = extremo izquierdo del riel, a la altura del eje de la hoja.

const PART := preload("res://objects/hazards/hazard_part.gd")
const DAMAGE := 50.0
const STEEL := Color(0.72, 0.76, 0.86)
const STEEL_DK := Color(0.3, 0.32, 0.4)
const RAIL := Color(0.14, 0.15, 0.2)
const RAIL_HI := Color(0.42, 0.45, 0.56)
const HAZARD := Color(0.93, 0.73, 0.19)
const SPARK := Color(1.0, 0.8, 0.4)

@export var length := 96.0:
	set(v):
		length = v
		queue_redraw()
@export var period := 1.4 ## ida y vuelta (s)
@export var phase := 0.0
@export var radius := 9.0

var _t := 0.0
var _spin := 0.0
var _part: Area2D
var _sparks := [] ## {pos, vel, life}
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	_part = Area2D.new()
	_part.set_script(PART)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius - 1.5
	cs.shape = c
	_part.add_child(cs)
	add_child(_part)
	_t = phase
	_part.position = _blade_pos()


func _blade_pos() -> Vector2:
	return Vector2(length * (0.5 - 0.5 * cos(_t * TAU / period)), 0)


func _speed() -> float:
	return absf(length * 0.5 * sin(_t * TAU / period) * TAU / period)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_spin += delta * 28.0
	_part.position = _blade_pos()
	# Chispas donde la hoja roza el riel
	if _rnd.randf() < 0.7:
		var p := _blade_pos() + Vector2(0, radius * 0.6)
		var dir := -signf(sin(_t * TAU / period))
		_sparks.append({pos = p, vel = Vector2(dir * _rnd.randf_range(40, 110), _rnd.randf_range(-60, -10)),
				life = _rnd.randf_range(0.1, 0.25)})
	for s in _sparks:
		s.life -= delta
		s.vel.y += 400.0 * delta
		s.pos += s.vel * delta
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	queue_redraw()


func touch_part(part: Area2D, player: Node2D, _real_delta: float) -> void:
	player.hurt(DAMAGE, part.global_position, &"hit")


func _draw() -> void:
	# Riel atornillado a la pared, con topes de peligro en los extremos
	draw_rect(Rect2(-radius, -2, length + radius * 2, 4), RAIL)
	draw_rect(Rect2(-radius, -2, length + radius * 2, 0.8), RAIL_HI)
	var x := -radius + 6.0
	while x < length + radius - 4:
		draw_circle(Vector2(x, 0), 0.7, RAIL_HI, true, -1.0, true)
		x += 12.0
	for end in [-radius - 3.0, length + radius]:
		draw_rect(Rect2(end, -4, 3, 8), HAZARD)
		for k in 3:
			draw_line(Vector2(end, -4 + k * 3), Vector2(end + 3, -2 + k * 3), Color(0.08, 0.07, 0.1), 0.8)
	var p := _blade_pos()
	var speed := _speed()
	# Estela de movimiento cuando va rápido
	if speed > 60.0 and not Engine.is_editor_hint():
		var dir := signf(sin(_t * TAU / period))
		for k in range(1, 4):
			draw_circle(p - Vector2(dir * k * speed * 0.012, 0), radius, Color(STEEL, 0.1 / k), true, -1.0, true)
	# Carro sobre el riel
	draw_rect(Rect2(p + Vector2(-4, -3.5), Vector2(8, 7)), STEEL_DK)
	# Hoja dentada girando
	var teeth := PackedVector2Array()
	for k in 32:
		var a := _spin + k * TAU / 32.0
		var r := radius if k % 2 == 0 else radius - 1.8
		teeth.append(p + Vector2.from_angle(a + (0.12 if k % 2 == 0 else 0.0)) * r)
	draw_colored_polygon(teeth, STEEL)
	draw_circle(p, radius - 2.4, STEEL.darkened(0.15), true, -1.0, true)
	for k in 3:
		var a := _spin * 1.0 + k * TAU / 3.0
		draw_line(p + Vector2.from_angle(a) * 2.0, p + Vector2.from_angle(a) * (radius - 3.0), STEEL_DK, 0.7, true)
	draw_arc(p, radius - 1.0, -2.4, -1.2, 10, Color(Color.WHITE, 0.7), 0.5, true)
	draw_circle(p, 1.8, STEEL_DK, true, -1.0, true)
	draw_circle(p, 0.8, HAZARD, true, -1.0, true)
	for s in _sparks:
		draw_line(s.pos, s.pos - s.vel * 0.02, Color(SPARK, minf(s.life * 6.0, 1.0)), 0.5, true)

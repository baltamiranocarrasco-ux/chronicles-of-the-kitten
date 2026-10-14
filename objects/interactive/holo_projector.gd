@tool
extends Node2D
## Proyector holográfico en una azotea alta. Proyecta, más abajo, un letrero
## flotante o una estructura de alambre (wireframe) con su haz de luz.
##   Q: las partículas de polvo y lluvia del haz se encienden y dejan estela,
##      como referencia para medir saltos largos.
##   R: con el tiempo detenido el holograma se vuelve una plataforma sólida
##      de energía (solo se apoya desde arriba): sirve para llegar a zonas
##      secretas. Al volver el tiempo deja de sostener al gato.
## Origen = base del proyector sobre el techo; `target` = centro del holograma.

enum Kind { SIGN, WIREFRAME }

const HUD := preload("res://ui/hud.gd")
const HEIGHT := 12.0 ## alto del holograma
const DUST := 26

@export var target := Vector2(-40, 60):
	set(v):
		target = v
		_rebuild()
@export var kind := Kind.SIGN
@export var width := 36.0:
	set(v):
		width = v
		_rebuild()
@export var text := "OFERTA"
@export var color := Color(0.35, 0.95, 1.0)

var _t := 0.0
var _solid := 0.0 ## 0..1, transición a sólido
var _body := StaticBody2D.new()
var _shape := CollisionShape2D.new()
var _dust := [] ## posición a lo largo del haz (0..1) y lateral (-1..1)
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	_body.collision_layer = 4 # HOLO_LAYER del jugador (movment.gd)
	_body.collision_mask = 0
	_shape.one_way_collision = true
	_body.add_child(_shape)
	add_child(_body)
	_rnd.seed = hash(text) + int(target.x)
	for i in DUST:
		_dust.append(Vector3(_rnd.randf(), _rnd.randf_range(-1, 1), _rnd.randf() * TAU))
	_rebuild()
	if not Engine.is_editor_hint():
		process_mode = PROCESS_MODE_ALWAYS


func _rebuild() -> void:
	if not is_node_ready():
		return
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 4)
	_shape.shape = r
	_body.position = target + Vector2(0, -HEIGHT / 2.0 + 2.0)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var real := delta / Engine.time_scale
	var frozen := get_tree().paused
	if not frozen:
		_t += delta
	_solid = move_toward(_solid, 1.0 if frozen else 0.0, real * 8.0)
	queue_redraw()


func _lens() -> Vector2:
	return Vector2(0, -9)


func _draw() -> void:
	var slow := Engine.time_scale < 1.0 and not Engine.is_editor_hint()
	var flicker := 0.85 + 0.15 * sin(_t * 31.0) * sin(_t * 4.3)
	if _solid > 0.5:
		flicker = 1.0
	var lens := _lens()
	var left := target + Vector2(-width / 2.0, -HEIGHT / 2.0)
	var right := target + Vector2(width / 2.0, -HEIGHT / 2.0)
	# Haz en cono
	draw_polygon(PackedVector2Array([lens, right + Vector2(0, HEIGHT), left + Vector2(0, HEIGHT)]),
			PackedColorArray([Color(color, 0.28 * flicker), Color(color, 0.04), Color(color, 0.04)]))
	# Polvo y gotas suspendidos en el haz
	for d in _dust:
		var u := fposmod(d.x + _t * 0.12, 1.0)
		var edge := lens.lerp(target, u)
		var spread: float = width * 0.5 * u * d.y
		var p := edge + Vector2(spread, sin(_t + d.z) * 0.6)
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + d.z * 5.0)
		if slow:
			# Con la Q se encienden y dejan estela: puntos de referencia del salto
			var back := (target - lens).normalized() * -3.0
			draw_line(p, p + back, Color(color.lightened(0.6), 0.6), 0.5, true)
			draw_circle(p, 0.7, Color(color.lightened(0.7), 0.9 * tw), true, -1.0, true)
		else:
			draw_rect(Rect2(p, Vector2(0.4, 0.4)), Color(color.lightened(0.6), 0.45 * tw))
	if kind == Kind.SIGN:
		_draw_sign(flicker)
	else:
		_draw_wireframe(flicker)
	if _solid > 0.0:
		HUD.text(self, "SOLIDO", target + Vector2(0, -HEIGHT / 2.0 - 6.0), 0.5, Color(Color.WHITE, 0.8 * _solid), true)
	_draw_projector()


func _draw_sign(flicker: float) -> void:
	var r := Rect2(target - Vector2(width, HEIGHT) / 2.0, Vector2(width, HEIGHT))
	var fill := lerpf(0.12, 0.7, _solid)
	draw_rect(r, Color(color.darkened(0.5), fill * flicker))
	draw_rect(r, Color(color, (0.6 + 0.4 * _solid) * flicker), false, 0.6 + _solid * 0.6)
	# Líneas de escaneo
	if _solid < 1.0:
		var y := r.position.y + fposmod(_t * 18.0, HEIGHT)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(color, 0.4 * (1.0 - _solid)), 0.4)
	HUD.text(self, text, target + Vector2(0, -2.2), 0.62, Color(color.lightened(0.4), flicker), true)
	if _solid > 0.0:
		draw_line(r.position, Vector2(r.end.x, r.position.y), Color(Color.WHITE, _solid), 1.0, true)


func _draw_wireframe(flicker: float) -> void:
	# Viga de alambre en 3D que gira despacio; congelada queda maciza
	var a := _t * 0.9
	var hw := width / 2.0
	var hh := HEIGHT / 2.0
	var depth := 6.0
	var pts := []
	for z in [-depth, depth]:
		for c in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
			var x: float = c.x # gira sobre su largo: así sigue sirviendo de plataforma
			var y: float = c.y * cos(a) - z * sin(a) * 0.4
			pts.append(target + Vector2(x + z * 0.5, y))
	var lines := PackedVector2Array()
	for i in 4:
		lines.append_array([pts[i], pts[(i + 1) % 4], pts[i + 4], pts[(i + 1) % 4 + 4], pts[i], pts[i + 4]])
	# Diagonales de celosía
	for i in 4:
		lines.append_array([pts[i], pts[(i + 1) % 4 + 4]])
	if _solid > 0.0:
		var top := PackedVector2Array([target + Vector2(-hw, -hh), target + Vector2(hw, -hh),
				target + Vector2(hw, hh), target + Vector2(-hw, hh)])
		draw_colored_polygon(top, Color(color.darkened(0.4), 0.65 * _solid))
	draw_multiline(lines, Color(color, (0.5 + 0.5 * _solid) * flicker), 0.5 + 0.4 * _solid, true)
	if _solid > 0.0:
		draw_line(target + Vector2(-hw, -hh), target + Vector2(hw, -hh), Color(Color.WHITE, _solid), 1.0, true)


func _draw_projector() -> void:
	# Base sobre el techo, cuerpo inclinado hacia el holograma y anillo de LEDs
	draw_rect(Rect2(-6, -3, 12, 3), Color(0.12, 0.13, 0.18))
	draw_rect(Rect2(-6, -3, 12, 0.7), Color(0.45, 0.5, 0.62))
	var dir := (target - _lens()).normalized()
	var side := Vector2(-dir.y, dir.x)
	var lens := _lens()
	var back := lens - dir * 7.0
	draw_colored_polygon(PackedVector2Array([back + side * 3.0, lens + side * 4.0, lens - side * 4.0, back - side * 3.0]),
			Color(0.2, 0.22, 0.3))
	draw_line(Vector2(0, -3), back, Color(0.3, 0.33, 0.42), 1.6, true)
	for k in 6:
		var p := lens + side * (k / 5.0 * 7.0 - 3.5)
		draw_circle(p, 0.5, color.lightened(0.3), true, -1.0, true)
	draw_circle(lens, 2.5, Color(color, 0.25), true, -1.0, true)

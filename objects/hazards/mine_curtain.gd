@tool
extends Node2D
## Sistema de minas flotantes en cadena: una hilera de minas con púas y
## núcleo rojo que cuelgan de un cable y suben y bajan en ola. Al tocar una
## explota (daño fuerte y retroceso) y se rearma al rato.
## Con la Q el patrón se ve con calma; con la R se pasa por los huecos. Si
## rozas una con el tiempo detenido queda armada (parpadea) y estalla en
## cuanto el tiempo vuelve: mejor estar lejos.
## Origen = el cable del que cuelgan (las minas quedan debajo).

const PART := preload("res://objects/hazards/hazard_part.gd")
const EXPLOSION := preload("res://effects/explosion.gd")
const DAMAGE := 35.0
const BLAST := 24.0 ## radio de la explosión diferida (R)
const RADIUS := 5.0
const METAL := Color(0.2, 0.21, 0.27)
const METAL_HI := Color(0.55, 0.58, 0.72)
const CORE := Color(1.0, 0.16, 0.2)
const CHAIN := Color(0.32, 0.34, 0.42)

@export var count := 4:
	set(v):
		count = v
		_rebuild()
@export var spacing := 22.0
@export var drop := 40.0 ## largo medio de la cadena
@export var amplitude := 18.0 ## cuánto suben y bajan
@export var period := 1.8
@export var wave := 0.9 ## desfase entre minas vecinas (rad)
@export var respawn_time := 3.0

var _t := 0.0
var _mines := [] ## {area, dead, armed}


func _ready() -> void:
	# Se sigue dibujando con el tiempo detenido (las minas armadas parpadean);
	# el movimiento sí se detiene (ver _physics_process)
	if not Engine.is_editor_hint():
		process_mode = PROCESS_MODE_ALWAYS
	_rebuild()


func _process(_delta: float) -> void:
	queue_redraw()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for m in _mines:
		m.area.queue_free()
	_mines.clear()
	for i in count:
		var a := Area2D.new()
		a.set_script(PART)
		a.index = i
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = RADIUS
		cs.shape = c
		a.add_child(cs)
		add_child(a)
		_mines.append({area = a, dead = 0.0, armed = false})
	_place()


func _mine_pos(i: int) -> Vector2:
	return Vector2(i * spacing, drop + amplitude * sin(_t * TAU / period + i * wave))


func _place() -> void:
	for i in _mines.size():
		_mines[i].area.position = _mine_pos(i)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or get_tree().paused:
		return
	_t += delta
	_place()
	for i in _mines.size():
		var m: Dictionary = _mines[i]
		if m.armed:
			# El tiempo volvió a correr: estalla la mina que se tocó congelada
			m.armed = false
			_explode(i)
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player and player.global_position.distance_to(to_global(_mine_pos(i))) < BLAST:
				player.hurt(DAMAGE, to_global(_mine_pos(i)), &"hit")
		elif m.dead > 0.0:
			m.dead -= delta
			if m.dead <= 0.0:
				m.area.collision_layer = 8


func touch_part(part: Area2D, player: Node2D, _real_delta: float) -> void:
	var m: Dictionary = _mines[part.index]
	if m.dead > 0.0 or m.armed:
		return
	if get_tree().paused:
		m.armed = true
		queue_redraw()
		return
	_explode(part.index)
	player.hurt(DAMAGE, part.global_position, &"hit")


func _explode(i: int) -> void:
	var m: Dictionary = _mines[i]
	m.dead = respawn_time
	m.area.collision_layer = 0
	var fx := Node2D.new()
	fx.set_script(EXPLOSION)
	get_parent().add_child(fx)
	fx.global_position = to_global(_mine_pos(i))
	fx.reset_physics_interpolation()


func _draw() -> void:
	# Cable del que cuelgan
	var w := (count - 1) * spacing
	draw_line(Vector2(-12, 0), Vector2(w + 12, 0), Color(0.06, 0.06, 0.09), 1.4, true)
	for i in count:
		var m: Dictionary = _mines[i] if i < _mines.size() else {dead = 0.0, armed = false}
		var p := _mine_pos(i)
		var clamp_at := Vector2(p.x, 0)
		draw_rect(Rect2(clamp_at + Vector2(-1.5, -1.5), Vector2(3, 3)), METAL)
		# Cadena: eslabones alternados
		var top := clamp_at + Vector2(0, 1.5)
		var bottom := p - Vector2(0, RADIUS + 1.0) if m.dead <= 0.0 else p - Vector2(0, RADIUS + 8.0)
		var links := int(top.distance_to(bottom) / 2.4)
		for k in links:
			var y := top.y + k * 2.4
			if k % 2 == 0:
				draw_rect(Rect2(p.x - 0.6, y, 1.2, 2.0), CHAIN)
			else:
				draw_line(Vector2(p.x, y), Vector2(p.x, y + 2.0), CHAIN.lightened(0.2), 0.4)
		if m.dead > 0.0:
			# Rearmándose: solo un brillo tenue donde volverá a aparecer
			var back: float = 1.0 - m.dead / respawn_time
			draw_arc(p, RADIUS, -PI / 2, -PI / 2 + TAU * back, 24, Color(CORE, 0.35), 0.5, true)
			continue
		_draw_mine(p, i, m.armed)


func _draw_mine(p: Vector2, i: int, armed: bool) -> void:
	var spin := _t * 0.8 + i
	for k in 8:
		var a := spin + k * TAU / 8.0
		var dir := Vector2.from_angle(a)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([p + dir * (RADIUS + 2.6), p + dir * (RADIUS - 0.5) + side * 1.1,
				p + dir * (RADIUS - 0.5) - side * 1.1]), METAL_HI.darkened(0.2))
	draw_circle(p, RADIUS, METAL, true, -1.0, true)
	draw_arc(p, RADIUS - 0.6, PI * 1.1, PI * 1.7, 12, METAL_HI, 0.7, true)
	draw_line(p + Vector2(-RADIUS, 0), p + Vector2(RADIUS, 0), METAL.darkened(0.4), 0.6, true)
	var pulse := 0.6 + 0.4 * sin(_t * 6.0 + i)
	if armed:
		pulse = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.16) < 0.08 else 0.2
	draw_circle(p, RADIUS * 1.9, Color(CORE, 0.12 * pulse), true, -1.0, true)
	draw_circle(p, 2.0, Color(CORE, 0.6 + 0.4 * pulse), true, -1.0, true)
	draw_circle(p + Vector2(-0.5, -0.5), 0.7, Color(1, 0.8, 0.8, pulse), true, -1.0, true)

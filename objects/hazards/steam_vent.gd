@tool
extends Area2D
## Fuga de vapor a alta presión: un tubo industrial rajado que dispara
## ráfagas intermitentes de vapor hirviendo hacia arriba o hacia un lado.
## Antes de cada ráfaga silba y suelta bocanadas (aviso). Con la Q se ve el
## ritmo con calma; con la R la nube queda congelada en el aire y no quema.
## Origen = la grieta del tubo (hacia arriba: 8 px sobre el suelo; hacia un
## lado: un caño tendido sobre el techo, 5 px sobre el suelo).

enum Dir { UP, LEFT, RIGHT }

const DAMAGE := 20.0
const STEAM := Color(0.86, 0.88, 0.95)
const PIPE := Color(0.24, 0.26, 0.33)
const PIPE_HI := Color(0.52, 0.56, 0.68)
const PIPE_DK := Color(0.11, 0.12, 0.17)
const RUST := Color(0.42, 0.25, 0.16)
const WARN_TIME := 0.55

@export var direction := Dir.UP:
	set(v):
		direction = v
		_rebuild()
@export var length := 44.0: ## alcance del chorro (px)
	set(v):
		length = v
		_rebuild()
@export var idle_time := 1.6 ## tiempo sin vapor entre ráfagas
@export var burst_time := 0.9
@export var phase := 0.0

var _t := 0.0
var _puffs := [] ## {pos, vel, age, life, size}
var _spawn := 0.0
var _shape := CollisionShape2D.new()
var _soft: GradientTexture2D
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_child(_shape)
	_t = phase
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_soft = GradientTexture2D.new()
	_soft.gradient = g
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_soft.width = 32
	_soft.height = 32
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	var r := RectangleShape2D.new()
	var d := _dir()
	r.size = Vector2(10, length) if direction == Dir.UP else Vector2(length, 10)
	_shape.shape = r
	_shape.position = d * (length / 2.0 + 2.0)
	queue_redraw()


func _dir() -> Vector2:
	return [Vector2.UP, Vector2.LEFT, Vector2.RIGHT][direction]


func _cycle() -> float:
	return fposmod(_t, idle_time + burst_time)


func is_bursting() -> bool:
	return _cycle() >= idle_time


func touch(player: Node2D, _real_delta: float) -> void:
	# Con el tiempo detenido el vapor no se mueve: no quema
	if is_bursting() and not get_tree().paused:
		player.hurt(DAMAGE, global_position, &"burn")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var d := _dir()
	var side := Vector2(-d.y, d.x)
	_spawn -= delta
	if _spawn <= 0.0:
		var cyc := _cycle()
		if is_bursting():
			_spawn = 0.025
			for i in 2:
				var speed := length * _rnd.randf_range(2.6, 3.4)
				_puffs.append({pos = d * 2.0, vel = d * speed + side * _rnd.randf_range(-18, 18),
						age = 0.0, life = _rnd.randf_range(0.35, 0.55), size = _rnd.randf_range(2.0, 3.0)})
		elif cyc > idle_time - WARN_TIME:
			# Aviso: bocanadas cortas que se escapan de la grieta
			_spawn = 0.09
			_puffs.append({pos = d * 1.5, vel = d * _rnd.randf_range(12, 22) + side * _rnd.randf_range(-8, 8),
					age = 0.0, life = _rnd.randf_range(0.4, 0.7), size = _rnd.randf_range(1.0, 1.6)})
		else:
			_spawn = 0.4
			if _rnd.randf() < 0.5: # hilito de vapor en reposo
				_puffs.append({pos = d, vel = d * 6.0 + side * _rnd.randf_range(-3, 3),
						age = 0.0, life = 1.0, size = 0.8})
	for p in _puffs:
		p.age += delta
		p.vel *= 1.0 - minf(delta * 3.5, 0.9) # el chorro pierde fuerza y se abre
		p.vel.y -= 12.0 * delta # el vapor caliente sube
		p.pos += p.vel * delta
	_puffs = _puffs.filter(func(p): return p.age < p.life)
	queue_redraw()


func _draw() -> void:
	var d := _dir()
	for p in _puffs:
		var k: float = p.age / p.life
		var r: float = p.size + k * 7.0
		var a := 0.42 * (1.0 - k) * minf(p.age * 12.0, 1.0)
		draw_texture_rect(_soft, Rect2(p.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(STEAM, a))
	if is_bursting() and not Engine.is_editor_hint():
		# Núcleo del chorro, más denso cerca de la grieta
		var tip := d * length * 0.55
		draw_line(d * 2.0, tip, Color(Color.WHITE, 0.35), 3.0, true)
		draw_line(d * 2.0, d * length * 0.3, Color(Color.WHITE, 0.6), 1.4, true)
	if Engine.is_editor_hint():
		draw_line(Vector2.ZERO, d * length, Color(STEAM, 0.5), 6.0)
	_draw_pipe(d)


func _draw_pipe(d: Vector2) -> void:
	if direction == Dir.UP:
		# Caño de 8 px que sale del suelo, con una válvula y la boca rajada
		draw_rect(Rect2(-3.5, 0, 7, 8), PIPE)
		draw_rect(Rect2(-3.5, 0, 1.2, 8), PIPE_HI)
		draw_rect(Rect2(2.3, 0, 1.2, 8), PIPE_DK)
		draw_rect(Rect2(-4.5, 3, 9, 2), PIPE_DK)
		draw_rect(Rect2(-4.5, 3, 9, 0.6), PIPE_HI)
		draw_rect(Rect2(-5.5, 7, 11, 1.5), PIPE_DK)
		draw_rect(Rect2(-1.5, 5.5, 3, 1.5), RUST)
		draw_polyline(PackedVector2Array([Vector2(-2, 0.5), Vector2(-0.5, 2.5), Vector2(0.5, 1.2), Vector2(2, 3)]),
				Color(0.02, 0.02, 0.03), 0.5, true)
		draw_rect(Rect2(-3.5, -0.6, 7, 0.9), PIPE_HI)
	else:
		# Tubería horizontal que viene de la pared, con brida y la grieta en la punta
		var back := -d.x
		var r := Rect2(Vector2(minf(0, back * 26), -3.5), Vector2(26, 7))
		draw_rect(r, PIPE)
		draw_rect(Rect2(r.position, Vector2(26, 1.2)), PIPE_HI)
		draw_rect(Rect2(r.position + Vector2(0, 5.8), Vector2(26, 1.2)), PIPE_DK)
		var fx := back * 14 - 1.0
		draw_rect(Rect2(fx, -4.5, 2, 9), PIPE_DK)
		draw_rect(Rect2(fx, -4.5, 0.6, 9), PIPE_HI)
		draw_rect(Rect2(back * 7 - 1.5, 1, 3, 2.5), RUST)
		draw_polyline(PackedVector2Array([Vector2(0, -2.5), Vector2(back * 1.5, -0.5), Vector2(0, 0.8), Vector2(back * 2, 2.5)]),
				Color(0.02, 0.02, 0.03), 0.5, true)

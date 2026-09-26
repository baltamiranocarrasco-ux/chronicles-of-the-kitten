extends Node2D
## Elementos animados de las capas del fondo (dibujados por código para que
## respondan al tiempo del mundo: la Q los frena y la R los detiene en el aire).
##   LIGHTS : oficinas de las torres de cristal que se apagan y encienden
##   DRONES : luces rojas de drones que cruzan detrás de los edificios
##   TRAFFIC: autos flotantes (faros blancos, luces traseras rojas y ámbar)
##   SMOKE  : humo denso que sale de los conductos de ventilación
##   RAIN   : lluvia fina en diagonal
## Las posiciones de ventanas y conductos vienen de assets/city/city_meta.gd.
## Con la Q activa, drones y tráfico dejan una estela más larga.
## Se dibuja en la copia vecina de cada lado para repetirse igual que la capa.

enum Kind { LIGHTS, DRONES, TRAFFIC, SMOKE, RAIN }

const META := preload("res://assets/city/city_meta.gd")
const WINDOW_OFF := Color(0.05, 0.06, 0.15)
const DRONE := Color(1.0, 0.16, 0.16)
const HEADLIGHT := Color(1.0, 0.97, 0.88)
const TAIL := [Color(1.0, 0.2, 0.18), Color(1.0, 0.6, 0.2)]
const SMOKE := Color(0.62, 0.56, 0.7)
const RAIN := Color(0.75, 0.8, 1.0)
const RAIN_DIR := Vector2(-0.18, 1.0) ## ligeramente inclinada por el viento

@export var kind := Kind.LIGHTS
@export var layer_width := 384.0 ## ancho de la capa en píxeles del juego

var _t := 0.0
var _windows := [] ## {rect, period, phase}
var _movers := [] ## {x, y, speed, len, color}
var _puffs := [] ## {pos, vel, age, life, size}
var _drops := [] ## {pos, speed, len}
var _spawn := 0.0
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	_rnd.seed = 1234 + kind
	match kind:
		Kind.LIGHTS:
			for w in META.WINDOWS:
				if _rnd.randf() < 0.6:
					_windows.append({rect = Rect2(w[0], w[1], w[2], w[3]),
							period = _rnd.randf_range(4.0, 9.0), phase = _rnd.randf() * TAU})
		Kind.DRONES:
			for i in 7:
				_movers.append({x = _rnd.randf() * layer_width, y = _rnd.randf_range(50, 110),
						speed = _rnd.randf_range(14, 28) * (1 if i % 2 == 0 else -1), len = 1.2, color = DRONE})
		Kind.TRAFFIC:
			for lane in 3:
				var dir := 1 if lane % 2 == 0 else -1
				for i in 10:
					_movers.append({x = _rnd.randf() * layer_width, y = 112 + lane * 7,
							speed = _rnd.randf_range(60, 110) * dir, len = _rnd.randf_range(2.0, 3.5),
							color = TAIL[_rnd.randi() % TAIL.size()]})
		Kind.SMOKE:
			# Estado inicial ya en marcha para que no arranque sin humo
			for i in 60:
				_step_smoke(0.1)
		Kind.RAIN:
			for i in 120:
				_drops.append({pos = Vector2(_rnd.randf() * layer_width, _rnd.randf() * 216.0),
						speed = _rnd.randf_range(150, 210), len = _rnd.randf_range(2.5, 4.5)})


func _process(delta: float) -> void:
	_t += delta
	for m in _movers:
		m.x = fposmod(m.x + m.speed * delta, layer_width)
	if kind == Kind.SMOKE:
		_step_smoke(delta)
	elif kind == Kind.RAIN:
		for d in _drops:
			d.pos += RAIN_DIR * d.speed * delta
			if d.pos.y > 216.0:
				d.pos = Vector2(fposmod(d.pos.x + 216.0 * 0.18, layer_width), -d.len)
	queue_redraw()


func _step_smoke(delta: float) -> void:
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = 0.12
		for v in META.VENTS:
			_puffs.append({pos = Vector2(v[0], v[1]), vel = Vector2(_rnd.randf_range(1.5, 4.0), -_rnd.randf_range(7.0, 11.0)),
					age = 0.0, life = _rnd.randf_range(3.0, 4.5), size = _rnd.randf_range(1.5, 2.5)})
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p.age += delta
		if p.age >= p.life:
			_puffs.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel.x += 1.5 * delta # el viento lo lleva hacia un lado


func _draw() -> void:
	for copy in [-layer_width, 0.0, layer_width]:
		var shift := Vector2(copy, 0)
		match kind:
			Kind.LIGHTS:
				for w in _windows:
					# Se apagan un rato de vez en cuando, con transición suave
					var s := sin(_t * TAU / w.period + w.phase)
					var off := clampf((s - 0.55) / 0.3, 0.0, 1.0)
					if off > 0.0:
						draw_rect(Rect2(w.rect.position + shift, w.rect.size), Color(WINDOW_OFF, off * 0.92))
			Kind.DRONES, Kind.TRAFFIC:
				var trail := 4.0 if Engine.time_scale < 1.0 else 1.0
				for m in _movers:
					var back := -signf(m.speed)
					var base := Vector2(m.x, m.y) + shift
					var length: float = m.len * trail
					draw_line(base, base + Vector2(back * length, 0), Color(m.color, 0.9), 0.6, true)
					if kind == Kind.TRAFFIC:
						draw_circle(base + Vector2(-back * 0.4, 0), 0.4, HEADLIGHT, true, -1.0, true)
					elif int(_t * 2.0 + m.x) % 2 == 0:
						draw_circle(base, 0.8, Color(DRONE, 0.35), true, -1.0, true)
			Kind.SMOKE:
				for p in _puffs:
					var k: float = p.age / p.life
					var radius: float = p.size + k * 5.0
					var alpha := 0.08 * (1.0 - k) * minf(1.0, p.age * 3.0)
					draw_circle(p.pos + shift, radius, Color(SMOKE, alpha), true, -1.0, true)
			Kind.RAIN:
				for d in _drops:
					draw_line(d.pos + shift, d.pos + shift + RAIN_DIR * d.len, Color(RAIN, 0.14), 0.3, true)

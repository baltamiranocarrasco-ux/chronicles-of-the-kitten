extends Node2D
## Elementos animados de las capas del fondo (dibujados por código para que
## respondan al tiempo del mundo: la Q los frena y la R los detiene en el aire).
##   LIGHTS : ventanas de 1 px que parpadean lento (busca los colores clave
##            de las ventanas en la textura de la capa)
##   DRONES : puntos rojos que cruzan en línea recta detrás de los edificios
##   TRAFFIC: autos flotantes, líneas naranjas y rojas en carriles a media altura
##   FANS   : aspas giratorias de los ventiladores
## Con la Q activa, drones y tráfico dejan una estela más larga.
## Se dibuja en la copia vecina de cada lado para repetirse igual que la capa.

enum Kind { LIGHTS, DRONES, TRAFFIC, FANS }

const LAYER_WIDTH := 384.0
const WINDOW_YELLOW := Color8(240, 200, 90)
const WINDOW_CYAN := Color8(90, 216, 240)
const WINDOW_OFF := Color8(26, 22, 56)
const DRONE := Color(1.0, 0.16, 0.16)
const CARS := [Color(1.0, 0.55, 0.15), Color(1.0, 0.25, 0.2)]
const BLADE := Color8(92, 80, 124)
## Centros y radios de los ventiladores de bg_3_near (ver tools/generate_city.py)
const FAN_CENTERS := [Vector3(70, 104, 9), Vector3(262, 96, 11)]

@export var kind := Kind.LIGHTS
@export var texture: Texture2D ## capa donde buscar las ventanas (LIGHTS)

var _t := 0.0
var _windows := [] ## {pos, period, phase}
var _movers := [] ## {x, y, speed, len, color}


func _ready() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1234 + kind
	match kind:
		Kind.LIGHTS:
			_scan_windows(rnd)
		Kind.DRONES:
			for i in 4:
				_movers.append({x = rnd.randf() * LAYER_WIDTH, y = rnd.randf_range(55, 110),
						speed = rnd.randf_range(14, 28) * (1 if i % 2 == 0 else -1), len = 2, color = DRONE})
		Kind.TRAFFIC:
			for lane in 3:
				var dir := 1 if lane % 2 == 0 else -1
				for i in 6:
					_movers.append({x = rnd.randf() * LAYER_WIDTH, y = 112 + lane * 7,
							speed = rnd.randf_range(60, 110) * dir, len = rnd.randi_range(2, 3),
							color = CARS[rnd.randi() % CARS.size()]})


func _process(delta: float) -> void:
	_t += delta
	for m in _movers:
		m.x = fposmod(m.x + m.speed * delta, LAYER_WIDTH)
	queue_redraw()


func _draw() -> void:
	for copy in [-LAYER_WIDTH, 0.0, LAYER_WIDTH]:
		match kind:
			Kind.LIGHTS:
				for w in _windows:
					# Se apagan un rato de vez en cuando, con transición suave
					var s := sin(_t * TAU / w.period + w.phase)
					var off := clampf((s - 0.55) / 0.3, 0.0, 1.0)
					if off > 0.0:
						draw_rect(Rect2(w.pos + Vector2(copy, 0), Vector2.ONE), Color(WINDOW_OFF, off))
			Kind.DRONES, Kind.TRAFFIC:
				var trail := 3.0 if Engine.time_scale < 1.0 else 1.0
				for m in _movers:
					var length: float = m.len * trail
					var back := -signf(m.speed)
					var base := Vector2(roundf(m.x) + copy, m.y)
					draw_rect(Rect2(base, Vector2(m.len, 1)), m.color)
					if trail > 1.0:
						for i in range(1, int(length)):
							draw_rect(Rect2(base + Vector2(back * i, 0), Vector2.ONE),
									Color(m.color, 0.6 * (1.0 - i / length)))
			Kind.FANS:
				for f in FAN_CENTERS:
					var center := Vector2(f.x + copy, f.y)
					for b in 3:
						var a := _t * TAU * 1.5 + b * TAU / 3.0
						draw_line(center, center + Vector2.from_angle(a) * (f.z - 1), BLADE, 1.0)


func _scan_windows(rnd: RandomNumberGenerator) -> void:
	if texture == null:
		return
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.5 and (_same(c, WINDOW_YELLOW) or _same(c, WINDOW_CYAN)) and rnd.randf() < 0.5:
				_windows.append({pos = Vector2(x, y), period = rnd.randf_range(3.0, 7.0),
						phase = rnd.randf() * TAU})


func _same(c: Color, key: Color) -> bool:
	return absf(c.r - key.r) < 0.004 and absf(c.g - key.g) < 0.004 and absf(c.b - key.b) < 0.004

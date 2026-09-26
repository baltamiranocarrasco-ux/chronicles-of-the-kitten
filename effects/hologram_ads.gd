extends Node2D
## Hologramas publicitarios de implantes cibernéticos sobre las azoteas.
## En esta ciudad las piezas cibernéticas lo son todo, así que los anuncios
## son prótesis que giran en 3D (alambre proyectado) y cambian de producto
## cada pocos segundos con una interferencia.
##
## Los proyectores están pintados en la capa con el color clave HOLO_KEY
## (ver tools/generate_city.py); este nodo los busca en la textura y dibuja
## encima el haz, el holograma y su letrero. Usa _process pausable: la Q lo
## frena y la R lo deja congelado en el aire, como el resto del fondo.

const HOLO_KEY := Color8(1, 254, 127)
const COLORS := [Color(0.35, 0.95, 1.0), Color(1.0, 0.35, 0.85), Color(1.0, 0.72, 0.28)]
const SLOT := 6.0 ## segundos que se muestra cada producto
const SWITCH := 0.35 ## duración del colapso / despliegue al cambiar
const LIFT := 34.0 ## altura del centro del holograma sobre el proyector
const SPIN := 0.9 ## radianes por segundo
const TILT := 0.3 ## inclinación hacia la cámara

## Letrero de cada producto: [nombre, oferta]
const PRODUCTS := [
	["BRAZO MK-7", "-30%"],
	["PIERNA X2", "NUEVO"],
	["MANO PRO", "-50%"],
	["OJO 8K", "HD"],
	["COLUMNA NEO", "-20%"],
]

## Fuente de 3x5 para los letreros (cada fila son 3 bits)
const FONT := {
	"A": [7, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [7, 4, 4, 4, 7], "D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7], "H": [5, 5, 7, 5, 5], "I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 7], "K": [5, 5, 6, 5, 5],
	"L": [4, 4, 4, 4, 7], "M": [5, 7, 5, 5, 5], "N": [6, 5, 5, 5, 5], "O": [7, 5, 5, 5, 7],
	"P": [7, 5, 7, 4, 4], "R": [7, 5, 6, 5, 5], "U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2],
	"X": [5, 5, 2, 5, 5], "Z": [7, 1, 2, 4, 7], "0": [7, 5, 5, 5, 7], "2": [7, 1, 7, 4, 7],
	"3": [7, 1, 7, 1, 7], "5": [7, 4, 7, 1, 7], "7": [7, 1, 1, 1, 1], "8": [7, 5, 7, 5, 7],
	"-": [0, 0, 7, 0, 0], "%": [5, 1, 2, 4, 5], " ": [0, 0, 0, 0, 0],
}

@export var texture: Texture2D ## capa donde están pintados los proyectores

var _t := 0.0
var _width := 384.0
var _spots := [] ## {pos, color, offset}
var _models := [] ## por producto: PackedVector3Array con pares de puntos (segmentos)
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	_rnd.seed = 777
	_models = [_arm(), _leg(), _hand(), _eye(), _spine()]
	if texture == null:
		return
	_width = texture.get_width()
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			# Solo píxeles opacos: al importar, Godot rellena el color de los
			# transparentes vecinos con el de sus bordes
			if c.a > 0.5 and absf(c.r - HOLO_KEY.r) < 0.004 and absf(c.g - HOLO_KEY.g) < 0.004 and absf(c.b - HOLO_KEY.b) < 0.004:
				var i := _spots.size()
				# Cada holograma empieza en otro producto y cambia a destiempo
				_spots.append({pos = Vector2(x + 0.5, y), color = COLORS[i % COLORS.size()],
						offset = i * 2.0 + i * SLOT})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for copy in [-_width, 0.0, _width]:
		for spot in _spots:
			_draw_hologram(spot, Vector2(copy, 0))


func _draw_hologram(spot: Dictionary, shift: Vector2) -> void:
	var time: float = _t + spot.offset
	var index := int(time / SLOT) % _models.size()
	var local := fmod(time, SLOT)
	# Al cambiar de producto se aplasta en vertical y vuelve a desplegarse
	var unfold := clampf(minf(local, SLOT - local) / SWITCH, 0.0, 1.0)
	unfold = unfold * unfold * (3.0 - 2.0 * unfold)
	var col: Color = spot.color
	# Parpadeo leve y fallos ocasionales de la proyección
	var flicker := 0.85 + 0.15 * sin(time * 31.0) * sin(time * 7.3)
	var glitch := fmod(time * 0.37 + spot.offset, 3.0) < 0.08
	var base: Vector2 = spot.pos + shift
	var center := base + Vector2(0, -LIFT)
	if glitch:
		center.x += 2.0 if int(time * 60.0) % 2 == 0 else -2.0
		flicker *= 0.55

	# Haz del proyector: cono translúcido hasta la base del holograma
	var top_y := center.y + 18.0
	draw_polygon(PackedVector2Array([base, Vector2(center.x - 13, top_y), Vector2(center.x + 13, top_y)]),
			PackedColorArray([Color(col, 0.28 * flicker), Color(col, 0.02), Color(col, 0.02)]))
	draw_rect(Rect2(base - Vector2(1, 1), Vector2(2, 2)), Color(col, 0.9))
	# Anillo base
	var ring := PackedVector2Array()
	for i in 17:
		var a := i / 16.0 * TAU
		ring.append(Vector2(center.x + cos(a) * 13.0, top_y + sin(a) * 2.5))
	draw_polyline(ring, Color(col, 0.45 * flicker), -1.0)

	# Modelo en alambre: gira en Y, inclinado hacia la cámara; lo de atrás
	# se ve más tenue
	var model: PackedVector3Array = _models[index]
	var ay := time * SPIN
	var cy := cos(ay)
	var sy := sin(ay)
	var ct := cos(TILT)
	var st := sin(TILT)
	for i in range(0, model.size(), 2):
		var pts := []
		var depth := 0.0
		for p in [model[i], model[i + 1]]:
			var x: float = p.x * cy + p.z * sy
			var z: float = -p.x * sy + p.z * cy
			var y: float = p.y * ct - z * st
			z = p.y * st + z * ct
			depth += z
			pts.append(center + Vector2(x, y * unfold))
		var near := clampf(0.5 + depth / 40.0, 0.25, 1.0)
		draw_line(pts[0], pts[1], Color(col, 0.85 * near * flicker), -1.0)

	# Estática mientras cambia de producto
	if unfold < 0.95:
		for i in 14:
			var p := center + Vector2(_rnd.randf_range(-16, 16), _rnd.randf_range(-20, 20) * (1.0 - unfold))
			draw_rect(Rect2(p.floor(), Vector2.ONE), Color(col, 0.7 * (1.0 - unfold)))

	# Letrero: nombre del producto y oferta que parpadea
	var label: Array = PRODUCTS[index]
	var text_a := Color(col, 0.9 * unfold * flicker)
	_draw_text(label[0], center + Vector2(0, -30), text_a)
	if int(time * 2.0) % 2 == 0:
		_draw_text(label[1], center + Vector2(0, -24), Color(1.0, 0.92, 0.4, unfold * flicker))


func _draw_text(text: String, at: Vector2, color: Color) -> void:
	var x := roundf(at.x - (text.length() * 4 - 1) / 2.0)
	var y := roundf(at.y)
	for ch in text:
		var rows: Array = FONT.get(ch, FONT[" "])
		for r in 5:
			for b in 3:
				if rows[r] >> (2 - b) & 1:
					draw_rect(Rect2(x + b, y + r, 1, 1), color)
		x += 4


# --- modelos 3D (segmentos; y crece hacia abajo, ~40 px de alto) --------------

func _box(out: PackedVector3Array, c: Vector3, s: Vector3, basis := Basis()) -> void:
	var h := s / 2.0
	var corners := []
	for i in 8:
		var v := Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1))
		corners.append(c + basis * v)
	for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		out.append(corners[e[0]])
		out.append(corners[e[1]])


func _ring(out: PackedVector3Array, c: Vector3, r: float, axis: Vector3, n := 10) -> void:
	# Círculo perpendicular al eje dado
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	for i in n:
		var a := i / float(n) * TAU
		var b := (i + 1) / float(n) * TAU
		out.append(c + (u * cos(a) + v * sin(a)) * r)
		out.append(c + (u * cos(b) + v * sin(b)) * r)


func _cyl(out: PackedVector3Array, a: Vector3, b: Vector3, r: float, n := 8) -> void:
	var axis := (b - a).normalized()
	_ring(out, a, r, axis, n)
	_ring(out, b, r, axis, n)
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	for i in 4:
		var ang := i / 4.0 * TAU
		var o := (u * cos(ang) + v * sin(ang)) * r
		out.append(a + o)
		out.append(b + o)


func _seg(out: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	out.append(a)
	out.append(b)


func _arm() -> PackedVector3Array:
	var m := PackedVector3Array()
	_cyl(m, Vector3(-5, -17, 0), Vector3(5, -17, 0), 5)             # hombro
	_box(m, Vector3(0, -7, 0), Vector3(7, 12, 7))                     # brazo
	_seg(m, Vector3(5, -13, 2), Vector3(5, -1, 2))                    # pistón
	_cyl(m, Vector3(-4, 1, 0), Vector3(4, 1, 0), 3.5)                 # codo
	var fore := Basis(Vector3.RIGHT, -0.5)
	_box(m, Vector3(0, 8, 3.5), Vector3(5, 12, 5), fore)             # antebrazo
	_box(m, Vector3(0, 16, 8), Vector3(7, 5, 3), fore)               # palma
	for fx in [-2.5, 0.0, 2.5]:
		_seg(m, Vector3(fx, 18, 10), Vector3(fx, 22, 13))             # dedos
	return m


func _leg() -> PackedVector3Array:
	var m := PackedVector3Array()
	_cyl(m, Vector3(-5, -19, 0), Vector3(5, -19, 0), 4)              # cadera
	_box(m, Vector3(0, -9, 0), Vector3(8, 16, 8))                     # muslo
	_cyl(m, Vector3(-4, 1, 0), Vector3(4, 1, 0), 3.5)                 # rodilla
	_box(m, Vector3(0, 10, -1), Vector3(5, 14, 5))                    # canilla
	_seg(m, Vector3(-3, 3, -4), Vector3(-3, 15, -4))                  # pistón
	_seg(m, Vector3(3, 3, -4), Vector3(3, 15, -4))
	_ring(m, Vector3(0, 18, -1), 2.5, Vector3.RIGHT, 8)               # tobillo
	_box(m, Vector3(0, 21, 3), Vector3(6, 3, 12))                     # pie
	return m


func _hand() -> PackedVector3Array:
	var m := PackedVector3Array()
	_box(m, Vector3(0, 4, 0), Vector3(11, 11, 3))                     # palma
	_cyl(m, Vector3(0, 10, 0), Vector3(0, 17, 0), 3.5, 8)             # muñeca
	for i in 4:
		var x := -4.0 + i * 2.7
		var spread := (i - 1.5) * 1.2
		var h := 15.0 if i in [1, 2] else 12.0
		var knuckle := Vector3(x, -2, 0)
		var mid := Vector3(x + spread * 0.5, -2 - h * 0.55, 0.5)
		var tip := Vector3(x + spread, -2 - h, 2.0)
		_seg(m, knuckle, mid)
		_seg(m, mid, tip)
		_box(m, mid, Vector3(1.5, 1.5, 1.5))                          # articulaciones
	_seg(m, Vector3(5.5, 5, 0), Vector3(10, 0, 1.5))                  # pulgar
	_box(m, Vector3(10, 0, 1.5), Vector3(1.5, 1.5, 1.5))
	_seg(m, Vector3(10, 0, 1.5), Vector3(12, -5, 3))
	return m


func _eye() -> PackedVector3Array:
	var m := PackedVector3Array()
	var r := 13.0
	for lat in [-0.5, 0.0, 0.5]:
		_ring(m, Vector3(0, r * sin(lat), 0), r * cos(lat), Vector3.UP, 14)
	for lon in 4:
		var axis := Vector3(cos(lon * PI / 4.0), 0, sin(lon * PI / 4.0))
		_ring(m, Vector3.ZERO, r, axis, 14)
	# Iris, pupila y retícula al frente
	_ring(m, Vector3(0, 0, r * 0.93), 5.0, Vector3.BACK, 12)
	_ring(m, Vector3(0, 0, r * 0.98), 2.0, Vector3.BACK, 8)
	_seg(m, Vector3(-4, 0, r + 1), Vector3(4, 0, r + 1))
	_seg(m, Vector3(0, -4, r + 1), Vector3(0, 4, r + 1))
	# Nervio óptico cableado
	_seg(m, Vector3(0, 0, -r), Vector3(0, 6, -r - 6))
	_seg(m, Vector3(0, 6, -r - 6), Vector3(0, 18, -r - 7))
	return m


func _spine() -> PackedVector3Array:
	var m := PackedVector3Array()
	for i in 8:
		var y := -19.0 + i * 5.2
		var z := sin(i / 7.0 * PI) * 3.0                               # curva en S suave
		_box(m, Vector3(0, y, z), Vector3(8, 3, 6))                   # vértebra
		_seg(m, Vector3(0, y, z - 3), Vector3(0, y + 1, z - 7))       # apófisis
		if i < 7:
			var zn := sin((i + 1) / 7.0 * PI) * 3.0
			_seg(m, Vector3(3, y + 1.5, z + 3), Vector3(3, y + 3.7, zn + 3))    # fibra óptica
			_seg(m, Vector3(-3, y + 1.5, z + 3), Vector3(-3, y + 3.7, zn + 3))
	return m

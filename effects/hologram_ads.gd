extends Node2D
## Hologramas publicitarios de implantes cibernéticos sobre las azoteas.
## En esta ciudad las piezas cibernéticas lo son todo: los anuncios son
## prótesis en 3D de alambre fino (estilo plano CAD) que giran sobre el haz
## de un proyector, con piezas que se mueven, y cambian de producto cada 6 s
## colapsando en una línea de luz con estática. Entre los productos aparece
## el aviso de retiro del propio gato (SUJETO K-7 · DESCARTADO).
##
## Los proyectores están pintados en bg_3_mid y sus posiciones vienen de
## assets/city/city_meta.gd. Usa _process pausable: la Q lo frena (y deja
## estela) y la R lo congela a mitad de giro; el material del fondo lo pasa
## a escala de grises.

const META := preload("res://assets/city/city_meta.gd")
const COLORS := [Color(0.3, 0.92, 1.0), Color(1.0, 0.3, 0.85), Color(1.0, 0.64, 0.22)]
const RECALL_COLOR := Color(1.0, 0.22, 0.2)
const SLOT := 6.0 ## segundos que se muestra cada anuncio
const SWITCH := 0.45 ## duración del colapso / despliegue al cambiar
const LIFT := 36.0 ## altura del centro del holograma sobre el cabezal del proyector
const SPIN := 0.8 ## radianes por segundo
const TILT := 0.28 ## inclinación hacia la cámara
const LINE := 0.45 ## grosor de las líneas (px del juego; ~1.3 px en pantalla)
const CULL := 110.0 ## margen para no dibujar hologramas fuera de cámara

## Anuncios: [nombre, oferta]; el último es el aviso del gato
const ADS := [
	["BRAZO MK-7", "-30%"],
	["PIERNA X2", "NUEVO"],
	["MANO PRO", "-50%"],
	["OJO 8K", "HD"],
	["COLUMNA NEO", "-20%"],
	["SUJETO K-7", "DESCARTADO"],
]
const RECALL := 5
const CAT_SHEET := preload("res://assets/cat/cat_sheet.png")
const CAT_COLS := 8 ## columnas de la hoja del gato (el primer cuadro es el reposo)
const CARD := 96 ## lado de la tarjeta holográfica del gato, en píxeles de textura

## Tipografía vectorial angular (rejilla de 4x6, trazos)
const FONT := {
	"A": [[0, 6, 0, 2, 1, 0, 3, 0, 4, 2, 4, 6], [0, 3.5, 4, 3.5]],
	"B": [[0, 0, 3, 0, 4, 1, 4, 2, 3, 3, 0, 3], [3, 3, 4, 4, 4, 5, 3, 6, 0, 6, 0, 0]],
	"C": [[4, 0, 1, 0, 0, 1, 0, 5, 1, 6, 4, 6]],
	"D": [[0, 0, 3, 0, 4, 1, 4, 5, 3, 6, 0, 6, 0, 0]],
	"E": [[4, 0, 0, 0, 0, 6, 4, 6], [0, 3, 3, 3]],
	"H": [[0, 0, 0, 6], [4, 0, 4, 6], [0, 3, 4, 3]],
	"I": [[1, 0, 3, 0], [2, 0, 2, 6], [1, 6, 3, 6]],
	"J": [[4, 0, 4, 5, 3, 6, 1, 6, 0, 5]],
	"K": [[0, 0, 0, 6], [4, 0, 1, 3, 0, 3], [1, 3, 4, 6]],
	"L": [[0, 0, 0, 6, 4, 6]],
	"M": [[0, 6, 0, 0, 2, 2.5, 4, 0, 4, 6]],
	"N": [[0, 6, 0, 0, 4, 6, 4, 0]],
	"O": [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0]],
	"P": [[0, 6, 0, 0, 3, 0, 4, 1, 4, 2, 3, 3, 0, 3]],
	"R": [[0, 6, 0, 0, 3, 0, 4, 1, 4, 2, 3, 3, 0, 3], [2, 3, 4, 6]],
	"S": [[4, 0, 1, 0, 0, 1, 0, 2, 1, 3, 3, 3, 4, 4, 4, 5, 3, 6, 0, 6]],
	"T": [[0, 0, 4, 0], [2, 0, 2, 6]],
	"U": [[0, 0, 0, 5, 1, 6, 3, 6, 4, 5, 4, 0]],
	"V": [[0, 0, 2, 6, 4, 0]],
	"X": [[0, 0, 4, 6], [4, 0, 0, 6]],
	"Z": [[0, 0, 4, 0, 0, 6, 4, 6]],
	"0": [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0], [3, 1.5, 1, 4.5]],
	"2": [[0, 1, 1, 0, 3, 0, 4, 1, 4, 2, 0, 6, 4, 6]],
	"3": [[0, 0, 4, 0, 2, 2.5, 3, 2.5, 4, 3.5, 4, 5, 3, 6, 0, 6]],
	"5": [[4, 0, 0, 0, 0, 3, 3, 3, 4, 4, 4, 5, 3, 6, 0, 6]],
	"7": [[0, 0, 4, 0, 1.5, 6]],
	"8": [[1, 0, 3, 0, 4, 1, 4, 2, 3, 3, 1, 3, 0, 2, 0, 1, 1, 0], [1, 3, 0, 4, 0, 5, 1, 6, 3, 6, 4, 5, 4, 4, 3, 3]],
	"-": [[1, 3, 3, 3]],
	"%": [[0, 6, 4, 0], [0, 0, 1, 0, 1, 1, 0, 1, 0, 0], [3, 5, 4, 5, 4, 6, 3, 6, 3, 5]],
}
const FONT_SCALE := 0.72

@export var layer_width := 384.0 ## ancho de la capa en píxeles del juego (lo asigna el nivel)

var _t := 0.0
var _spots := [] ## {pos, offset, dust, rain}
var _rnd := RandomNumberGenerator.new()
var _glow_tex: GradientTexture2D
var _cat_holo: ImageTexture


func _ready() -> void:
	_rnd.seed = 777
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 64
	_glow_tex.height = 64
	_cat_holo = _make_cat_hologram()
	for i in META.PROJECTORS.size():
		var p: Array = META.PROJECTORS[i]
		var dust := []
		for k in 22:
			dust.append(Vector3(_rnd.randf_range(-1, 1), _rnd.randf(), _rnd.randf() * TAU))
		var rain := []
		for k in 14:
			rain.append(Vector2(_rnd.randf_range(-16, 16), _rnd.randf()))
		# Cada proyector empieza en otro anuncio y cambia a destiempo
		_spots.append({pos = Vector2(p[0], p[1]), offset = i * (SLOT * 1.5 + 1.3), dust = dust, rain = rain})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var cam_x := cam.get_screen_center_position().x if cam else 0.0
	for copy in [-layer_width, 0.0, layer_width]:
		for spot in _spots:
			var shift := Vector2(copy, 0)
			if absf(to_global(spot.pos + shift).x - cam_x) > 192.0 + CULL:
				continue
			_draw_hologram(spot, shift)


func _draw_hologram(spot: Dictionary, shift: Vector2) -> void:
	var time: float = _t + spot.offset
	var index := int(time / SLOT) % ADS.size()
	var local := fmod(time, SLOT)
	var unfold := clampf(minf(local, SLOT - local) / SWITCH, 0.0, 1.0)
	unfold = unfold * unfold * (3.0 - 2.0 * unfold)
	var col: Color = RECALL_COLOR if index == RECALL else COLORS[index % COLORS.size()]

	# Tubo fluorescente defectuoso: parpadeos cortos a ráfagas y, a veces, un
	# salto de imagen que deja una copia desplazada un instante
	var flicker := 0.9 + 0.1 * sin(time * 43.0)
	var burst := fmod(time * 0.31 + spot.offset * 0.7, 4.0)
	if burst < 0.25 and int(time * 30.0) % 3 == 0:
		flicker *= 0.25
	var jump := fmod(time * 0.23 + spot.offset, 5.0) < 0.06

	var head: Vector2 = spot.pos + shift
	var center := head + Vector2(0, -LIFT)
	var beam_top := center.y + 20.0

	# Luz difusa del holograma sobre las nubes y los edificios cercanos
	var spill := 62.0
	draw_texture_rect(_glow_tex, Rect2(center - Vector2(spill, spill), Vector2(spill, spill) * 2), false,
			Color(col, 0.16 * flicker * (0.4 + 0.6 * unfold)))

	_draw_beam(spot, head, center, beam_top, col, flicker, time)

	if index == RECALL:
		_draw_recall(center, time, unfold, flicker, col)
	else:
		var trail := 5 if Engine.time_scale < 1.0 else 0
		# Con la Q: estela de poses anteriores (motion blur de luz)
		for k in range(trail, 0, -1):
			_draw_model(index, center, time - k * 0.05, unfold, Color(col, 0.22 * (1.0 - k / 6.0)), true)
		_draw_model(index, center, time, unfold, Color(col, flicker), false)
		if jump:
			_draw_model(index, center + Vector2(3, -1), time, unfold, Color(col, 0.35), true)

	# Colapso: una sola línea de luz brillante y ráfaga de estática
	if unfold < 0.98:
		var w := 22.0 * (1.0 - unfold * 0.6)
		draw_line(center + Vector2(-w, 0), center + Vector2(w, 0), Color(col.lightened(0.5), 0.95 * (1.0 - unfold)), 0.8, true)
		draw_line(center + Vector2(-w, 0), center + Vector2(w, 0), Color(col, 0.3 * (1.0 - unfold)), 2.5, true)
		for i in 10:
			var y := center.y + _rnd.randf_range(-22, 22) * (1.0 - unfold * 0.5)
			var x := center.x + _rnd.randf_range(-20, 12)
			draw_line(Vector2(x, y), Vector2(x + _rnd.randf_range(3, 14), y), Color(col, 0.5 * (1.0 - unfold)), 0.3, true)
		for i in 24:
			var p := center + Vector2(_rnd.randf_range(-20, 20), _rnd.randf_range(-22, 22))
			draw_rect(Rect2(p, Vector2(0.4, 0.4)), Color(col.lightened(0.3), 0.8 * (1.0 - unfold)))

	_draw_label(ADS[index], center + Vector2(22, -20), col, unfold * flicker, time, index == RECALL)


func _draw_beam(spot: Dictionary, head: Vector2, center: Vector2, top_y: float, col: Color, flicker: float, time: float) -> void:
	var half := 14.0
	# Cono translúcido con un núcleo más brillante
	draw_polygon(PackedVector2Array([head, Vector2(center.x - half, top_y), Vector2(center.x + half, top_y)]),
			PackedColorArray([Color(col, 0.3 * flicker), Color(col, 0.03), Color(col, 0.03)]))
	draw_polygon(PackedVector2Array([head, Vector2(center.x - half * 0.35, top_y), Vector2(center.x + half * 0.35, top_y)]),
			PackedColorArray([Color(col, 0.22 * flicker), Color(col, 0.0), Color(col, 0.0)]))
	var height := head.y - top_y
	# Partículas de polvo que flotan dentro del haz
	for d in spot.dust:
		var v := fmod(d.y + time * 0.08, 1.0)
		var y := head.y - v * height
		var x: float = center.x + d.x * half * v * 0.9 + sin(time + d.z) * 0.6
		var twinkle := 0.5 + 0.5 * sin(time * 3.0 + d.z * 5.0)
		draw_rect(Rect2(x, y, 0.35, 0.35), Color(col.lightened(0.6), 0.55 * twinkle * (1.0 - v * 0.5)))
	# Gotas de lluvia que brillan al atravesar la luz
	for r in spot.rain:
		var v := fmod(r.y + time * 1.4, 1.0)
		var y := top_y - 10.0 + v * (height + 20.0)
		var x: float = center.x + r.x - v * 3.0
		var inside := clampf(1.0 - absf(x - center.x) / maxf(1.0, half * (head.y - y) / height), 0.0, 1.0)
		if inside > 0.0 and y < head.y:
			draw_line(Vector2(x, y), Vector2(x - 0.5, y + 2.2), Color(col.lightened(0.7), 0.7 * inside), 0.3, true)
	# Anillo LED continuo en la base, con luz difusa
	var ring := PackedVector2Array()
	for i in 25:
		var a := i / 24.0 * TAU
		ring.append(head + Vector2(cos(a) * 5.0, sin(a) * 1.3 + 0.6))
	draw_polyline(ring, Color(col, 0.18 * flicker), 2.2, true)
	draw_polyline(ring, Color(col.lightened(0.4), 0.9 * flicker), 0.45, true)


# --- modelos ---------------------------------------------------------------------

func _draw_model(index: int, center: Vector2, time: float, unfold: float, col: Color, ghost: bool) -> void:
	var m := PackedVector3Array()
	var dots := PackedVector3Array() ## pulsos de luz
	match index:
		0: _arm(m, time)
		1: _leg(m, time)
		2: _hand(m, time)
		3: _eye(m, time)
		4: _spine(m, dots, time)
	var ay := time * SPIN
	var cy := cos(ay)
	var sy := sin(ay)
	var ct := cos(TILT)
	var st := sin(TILT)
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	for i in range(0, m.size(), 2):
		var a := _project(m[i], cy, sy, ct, st)
		var b := _project(m[i + 1], cy, sy, ct, st)
		var pa := center + Vector2(a.x, a.y * unfold)
		var pb := center + Vector2(b.x, b.y * unfold)
		if a.z + b.z >= 0.0:
			front.append(pa)
			front.append(pb)
		else:
			back.append(pa)
			back.append(pb)
	if ghost:
		if front.size():
			draw_multiline(front, col, 1.2, true)
		return
	# Cara trasera: 50 % de opacidad y un tono más oscuro
	if back.size():
		draw_multiline(back, Color(col.darkened(0.35), col.a * 0.5), LINE, true)
	if front.size():
		draw_multiline(front, Color(col, col.a * 0.2), LINE * 3.5, true) # halo
		draw_multiline(front, Color(col.lightened(0.15), col.a * 0.95), LINE, true)
	for d in dots:
		var p := _project(d, cy, sy, ct, st)
		draw_circle(center + Vector2(p.x, p.y * unfold), 0.7, Color(1, 1, 1, col.a), true, -1.0, true)
		draw_circle(center + Vector2(p.x, p.y * unfold), 1.6, Color(col, col.a * 0.35), true, -1.0, true)


func _project(p: Vector3, cy: float, sy: float, ct: float, st: float) -> Vector3:
	var x := p.x * cy + p.z * sy
	var z := -p.x * sy + p.z * cy
	var y := p.y * ct - z * st
	z = p.y * st + z * ct
	return Vector3(x, y, z)


func _box(m: PackedVector3Array, c: Vector3, s: Vector3, basis := Basis()) -> void:
	var h := s / 2.0
	var k := []
	for i in 8:
		k.append(c + basis * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		m.append(k[e[0]])
		m.append(k[e[1]])


func _ring(m: PackedVector3Array, c: Vector3, r: float, axis: Vector3, n := 12, turn := 0.0) -> void:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	for i in n:
		var a := turn + i / float(n) * TAU
		var b := turn + (i + 1) / float(n) * TAU
		m.append(c + (u * cos(a) + v * sin(a)) * r)
		m.append(c + (u * cos(b) + v * sin(b)) * r)


func _cyl(m: PackedVector3Array, a: Vector3, b: Vector3, r: float, n := 10) -> void:
	var axis := (b - a).normalized()
	_ring(m, a, r, axis, n)
	_ring(m, b, r, axis, n)
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	for i in 6:
		var ang := i / 6.0 * TAU
		var o := (u * cos(ang) + v * sin(ang)) * r
		m.append(a + o)
		m.append(b + o)


func _seg(m: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	m.append(a)
	m.append(b)


func _finger(m: PackedVector3Array, base: Vector3, lengths: Array, curl: float, dir := Vector3.DOWN * -1.0) -> void:
	# Dedo articulado: cada falange se dobla 'curl' radianes hacia la palma
	var p := base
	var d := dir.normalized()
	var angle := 0.0
	for L in lengths:
		angle += curl
		var step: Vector3 = Basis(Vector3.RIGHT, angle) * d * L
		_seg(m, p, p + step)
		_box(m, p, Vector3(1.0, 1.0, 1.0))          # nudillo
		p += step


func _arm(m: PackedVector3Array, t: float) -> void:
	var elbow := -0.35 - 0.35 * (0.5 + 0.5 * sin(t * 1.3))
	_cyl(m, Vector3(-5, -18, 0), Vector3(5, -18, 0), 5)                 # hombro
	_box(m, Vector3(0, -8, 0), Vector3(7, 13, 7))                        # brazo
	var fore := Basis(Vector3.RIGHT, elbow)
	var pivot := Vector3(0, 1, 0)
	# Pistón hidráulico: camisa fija y vástago de cromo que se desliza
	var sleeve_a := Vector3(0, -14, 5)
	var rod_end := pivot + fore * Vector3(0, 6, 4)
	var mid := sleeve_a.lerp(rod_end, 0.5)
	_cyl(m, sleeve_a, mid, 1.1, 6)
	_seg(m, mid, rod_end)
	_cyl(m, Vector3(-4, 1, 0), Vector3(4, 1, 0), 3.5)                   # codo
	_box(m, pivot + fore * Vector3(0, 7, 0), Vector3(5, 12, 5), fore)    # antebrazo
	var wrist := pivot + fore * Vector3(0, 14, 0)
	_box(m, wrist + fore * Vector3(0, 2, 0), Vector3(7, 4, 3), fore)     # palma
	for i in 4:                                                          # nudillos individuales
		var curl := 0.2 + 0.35 * (0.5 + 0.5 * sin(t * 2.2 + i * 0.8))
		var base := wrist + fore * Vector3(-2.7 + i * 1.8, 4.5, 0)
		_finger(m, base, [2.2, 1.8, 1.4], curl, fore * Vector3.DOWN * -1.0)


func _leg(m: PackedVector3Array, t: float) -> void:
	var squash := 0.5 + 0.5 * sin(t * 2.0)                               # amortiguación
	_cyl(m, Vector3(-5, -20, 0), Vector3(5, -20, 0), 4)                 # cadera
	_box(m, Vector3(0, -10, 0), Vector3(8, 16, 8))                       # muslo
	_cyl(m, Vector3(-4, 0, 0), Vector3(4, 0, 0), 3.5)                   # rodilla
	var shin_top := 3.0
	var ankle := 16.0 - squash * 2.0
	_box(m, Vector3(0, (shin_top + ankle) / 2, -1), Vector3(4.5, ankle - shin_top, 4.5))
	# Muelle helicoidal alrededor de la canilla que se comprime
	var turns := 6
	var prev := Vector3.ZERO
	for i in turns * 10 + 1:
		var k := i / float(turns * 10)
		var a := k * turns * TAU
		var p := Vector3(cos(a) * 3.8, shin_top + 1 + k * (ankle - shin_top - 2), -1 + sin(a) * 3.8)
		if i > 0:
			_seg(m, prev, p)
		prev = p
	# Pistones del talón
	_cyl(m, Vector3(0, ankle - 5, -5), Vector3(0, ankle - 1, -5), 1.0, 6)
	_seg(m, Vector3(0, ankle - 1, -5), Vector3(0, ankle + 3, -4))
	_ring(m, Vector3(0, ankle + 1, -1), 2.5, Vector3.RIGHT, 10)          # tobillo
	_box(m, Vector3(0, ankle + 4, 3), Vector3(6, 3, 12))                 # pie
	for x in [-2.0, 0.0, 2.0]:
		_seg(m, Vector3(x, ankle + 5, 9), Vector3(x, ankle + 5.5, 11))   # dedos


func _hand(m: PackedVector3Array, t: float) -> void:
	var grip := 0.5 + 0.5 * sin(t * 1.4)                                 # abre y cierra
	_box(m, Vector3(0, 3, 0), Vector3(11, 11, 3))                        # palma
	# Micro-servomotores visibles en la palma
	for sx in [-3.0, 0.0, 3.0]:
		_cyl(m, Vector3(sx, 2, 1.6), Vector3(sx, 2, 2.6), 1.1, 8)
		_seg(m, Vector3(sx, 2, 2.6), Vector3(sx, -2.5, 1.6))
	_cyl(m, Vector3(0, 9, 0), Vector3(0, 16, 0), 3.5, 10)                # muñeca
	for i in 4:
		var x := -4.2 + i * 2.8
		var L := [4.0, 3.2, 2.4] if i in [1, 2] else [3.4, 2.8, 2.0]
		_finger(m, Vector3(x, -2.5, 0), L, 0.1 + grip * 0.55)
	_finger(m, Vector3(5.5, 4, 0.5), [3.0, 2.5], 0.2 + grip * 0.5, Vector3(1, -1, 0.3))


func _eye(m: PackedVector3Array, t: float) -> void:
	var r := 13.0
	for lat in [-0.8, -0.4, 0.0, 0.4, 0.8]:
		_ring(m, Vector3(0, r * sin(lat), 0), r * cos(lat), Vector3.UP, 18)
	for lon in 6:
		_ring(m, Vector3.ZERO, r, Vector3(cos(lon * PI / 6.0), 0, sin(lon * PI / 6.0)), 18)
	# Iris mecánico: capas de anillos con muescas que giran en sentidos opuestos
	var front := Vector3(0, 0, r)
	for layer in 3:
		var rr := 6.0 - layer * 1.7
		var z := r * 0.92 + layer * 0.35
		var turn := t * (1.6 if layer % 2 == 0 else -2.2)
		_ring(m, Vector3(0, 0, z), rr, Vector3.BACK, 16, turn)
		for k in 6:
			var a := turn + k * TAU / 6.0
			_seg(m, Vector3(cos(a) * rr, sin(a) * rr, z), Vector3(cos(a) * (rr - 1.0), sin(a) * (rr - 1.0), z))
	# Retícula de escaneo que recorre el frente
	var scan := sin(t * 1.7) * 3.0
	_seg(m, front + Vector3(-5, scan, 1), front + Vector3(5, scan, 1))
	_seg(m, front + Vector3(0, -5, 1), front + Vector3(0, 5, 1))
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner := front + Vector3(c.x * 4, c.y * 4, 1)
		_seg(m, corner, corner - Vector3(c.x * 1.5, 0, 0))
		_seg(m, corner, corner - Vector3(0, c.y * 1.5, 0))
	# Nervio óptico cableado
	_seg(m, Vector3(0, 0, -r), Vector3(1, 7, -r - 5))
	_seg(m, Vector3(1, 7, -r - 5), Vector3(0, 19, -r - 6))


func _spine(m: PackedVector3Array, dots: PackedVector3Array, t: float) -> void:
	var n := 8
	var fibers := [[], []]
	for i in n:
		var y := -19.0 + i * 5.3
		var z := sin(i / float(n - 1) * PI) * 3.0                          # curva en S suave
		_box(m, Vector3(0, y, z), Vector3(8, 3, 6))                        # vértebra
		_seg(m, Vector3(0, y, z - 3), Vector3(0, y + 1.2, z - 7))          # apófisis
		_seg(m, Vector3(-4, y, z), Vector3(-6.5, y + 0.8, z - 1))          # transversas
		_seg(m, Vector3(4, y, z), Vector3(6.5, y + 0.8, z - 1))
		fibers[0].append(Vector3(2.5, y, z + 3))
		fibers[1].append(Vector3(-2.5, y, z + 3))
	for f in fibers:
		for i in f.size() - 1:
			_seg(m, f[i], f[i + 1])
	# Pulsos de luz que viajan por los filamentos
	for f in fibers.size():
		for k in 2:
			var pos := fmod(t * 0.7 + k * 0.5 + f * 0.25, 1.0) * (n - 1)
			var i := int(pos)
			var a: Vector3 = fibers[f][i]
			var b: Vector3 = fibers[f][mini(i + 1, n - 1)]
			dots.append(a.lerp(b, pos - i))


# --- aviso de retiro del gato ------------------------------------------------------

func _draw_recall(center: Vector2, time: float, unfold: float, flicker: float, col: Color) -> void:
	var turn := cos(time * SPIN * 1.3)
	var sx := signf(turn) * maxf(absf(turn), 0.08)
	draw_set_transform(center + Vector2(0, -2), 0.0, Vector2(sx, unfold) / 3.0)
	draw_texture(_cat_holo, -Vector2(CARD, CARD) / 2.0, Color(col, 0.95 * flicker))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if int(time * 3.0) % 3 != 0:
		var h := 10.0 * unfold
		draw_line(center + Vector2(-13, h), center + Vector2(13, -h), Color(col, 0.9 * flicker), 0.6, true)
		draw_line(center + Vector2(-13, h), center + Vector2(13, -h), Color(col, 0.25 * flicker), 2.0, true)


func _make_cat_hologram() -> ImageTexture:
	# Silueta del gato con bordes marcados y líneas de barrido, a CARD px de
	# lado (el pixel art se amplía, el gato en alta resolución se usa tal cual)
	# para que se vea nítida con el filtrado suave del fondo
	var src := CAT_SHEET.get_image()
	if src.is_compressed():
		src.decompress()
	var frame := src.get_width() / CAT_COLS
	src = src.get_region(Rect2i(0, 0, frame, frame))
	src.resize(CARD, CARD, Image.INTERPOLATE_NEAREST if frame < CARD else Image.INTERPOLATE_BILINEAR)
	var edge_step := CARD / 32
	var img := Image.create(CARD, CARD, false, Image.FORMAT_RGBA8)
	for y in CARD:
		for x in CARD:
			var p := src.get_pixel(x, y)
			if p.a < 0.5:
				continue
			var edge := false
			for d in [Vector2i(edge_step, 0), Vector2i(-edge_step, 0), Vector2i(0, edge_step), Vector2i(0, -edge_step)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= CARD or n.y >= CARD or src.get_pixelv(n).a < 0.5:
					edge = true
			var a := 1.0 if edge else clampf(0.3 + p.get_luminance() * 1.5, 0.3, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * (0.5 if y % 3 == 2 else 1.0)))
	return ImageTexture.create_from_image(img)


# --- letreros ------------------------------------------------------------------------

func _draw_label(ad: Array, at: Vector2, col: Color, alpha: float, time: float, recall: bool) -> void:
	if alpha <= 0.01:
		return
	var name_w := _text_width(ad[0])
	# Marco de interfaz: esquinas y una línea guía hacia el holograma
	var box := Rect2(at + Vector2(-2, -2), Vector2(name_w + 4, 11))
	var c := Color(col, 0.6 * alpha)
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var sx := 1.0 if corner.x == box.position.x else -1.0
		var sy := 1.0 if corner.y == box.position.y else -1.0
		draw_line(corner, corner + Vector2(sx * 2.5, 0), c, 0.35, true)
		draw_line(corner, corner + Vector2(0, sy * 2.5), c, 0.35, true)
	draw_line(box.position + Vector2(0, 6), box.position + Vector2(-8, 12), Color(col, 0.35 * alpha), 0.3, true)
	_draw_text(ad[0], at, Color(col.lightened(0.2), alpha))
	if int(time * 2.0) % 2 == 0:
		var offer := Color(1.0, 0.9, 0.9) if recall else Color(1.0, 0.92, 0.45)
		_draw_text(ad[1], at + Vector2(0, 5.5), Color(offer, alpha))


func _text_width(text: String) -> float:
	return text.length() * 5.2 * FONT_SCALE - 1.2 * FONT_SCALE


func _draw_text(text: String, at: Vector2, color: Color) -> void:
	var lines := PackedVector2Array()
	var x := at.x
	for ch in text:
		for stroke in FONT.get(ch, []):
			for i in range(0, stroke.size() - 2, 2):
				lines.append(Vector2(x + stroke[i] * FONT_SCALE, at.y + stroke[i + 1] * FONT_SCALE * 0.75))
				lines.append(Vector2(x + stroke[i + 2] * FONT_SCALE, at.y + stroke[i + 3] * FONT_SCALE * 0.75))
		x += 5.2 * FONT_SCALE
	if lines.size():
		draw_multiline(lines, Color(color, color.a * 0.25), 1.1, true)   # resplandor
		draw_multiline(lines, color, 0.32, true)

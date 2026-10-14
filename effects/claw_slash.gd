extends Node2D
## Arco del zarpazo: tres garras de plasma que barren de arriba hacia
## adelante y abajo, más grande que el cuadro del gato (hijo del jugador).
## Usa tiempo real, igual que el gato: con la Q se ve a velocidad normal y
## con la R también se dibuja.

const COLOR := Color(0.45, 0.95, 1.0)
const CORE := Color(0.92, 1.0, 1.0)
const HIT := Color(1.0, 0.55, 0.9)
const DELAY := 0.07 ## espera a que la pata empiece a bajar (animación "attack")
const SWEEP := 0.09 ## lo que tarda en barrer el arco
const FADE := 0.14
const START := -1.35 ## ángulo inicial (arriba) y final (abajo, delante), en radianes
const END := 0.75
const RADIUS := 17.0
const CENTER := Vector2(5, 2) ## centro del arco respecto del gato, mirando a la derecha
const STEPS := 14

var _t := -1.0
var _dir := 1.0
var _sparks := [] ## destellos donde golpea: {pos, life}


func _ready() -> void:
	z_index = 2
	owner.attacked.connect(_on_attacked)
	owner.hit_landed.connect(_on_hit_landed)


func _on_attacked(dir: float) -> void:
	_t = 0.0
	_dir = dir


func _on_hit_landed(target: Node2D) -> void:
	var at := target.global_position.lerp(global_position + Vector2(14 * _dir, 2), 0.55)
	_sparks.append({pos = to_local(at), life = 0.18})


func _process(delta: float) -> void:
	var real := delta / Engine.time_scale
	if _t >= 0.0:
		_t += real
		if _t > DELAY + SWEEP + FADE:
			_t = -1.0
	for i in range(_sparks.size() - 1, -1, -1):
		_sparks[i].life -= real
		if _sparks[i].life <= 0.0:
			_sparks.remove_at(i)
	if _t >= 0.0 or not _sparks.is_empty():
		queue_redraw()


func _draw() -> void:
	for s in _sparks:
		var k: float = s.life / 0.18
		var r := 3.0 + (1.0 - k) * 7.0
		for i in 6:
			var a := i * TAU / 6.0 + 0.3
			draw_line(s.pos + Vector2.from_angle(a) * r * 0.4, s.pos + Vector2.from_angle(a) * r,
					Color(HIT, k), 0.9, true)
		draw_circle(s.pos, 2.2 * k, Color(CORE, k), true, -1.0, true)
	if _t < DELAY:
		return
	var p := clampf((_t - DELAY) / SWEEP, 0.0, 1.0)
	var fade := 1.0 - clampf((_t - DELAY - SWEEP) / FADE, 0.0, 1.0)
	var head := lerpf(START, END, ease(p, 0.5))
	# La cola del arco se acorta mientras se desvanece
	var tail := lerpf(START, head, 1.0 - fade * 0.85) if p >= 1.0 else maxf(START, head - 1.6)
	for claw in 3:
		var radius := RADIUS - claw * 3.2
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in STEPS + 1:
			var k := float(i) / STEPS
			var a := lerpf(tail, head, k)
			pts.append(Vector2(CENTER.x * _dir + cos(a) * radius * _dir, CENTER.y + sin(a) * radius))
			cols.append(Color(COLOR, k * k * fade * 0.45))
		# Resplandor ancho debajo y núcleo claro encima
		draw_polyline_colors(pts, cols, 2.6, true)
		for i in cols.size():
			cols[i] = Color(CORE, cols[i].a / 0.45)
		draw_polyline_colors(pts, cols, 0.7, true)

extends Node2D
## Efectos sobre el gato al recibir daño (hijo del jugador):
##   shock: arcos eléctricos alrededor del cuerpo mientras está aturdido
##   burn : jirones de vapor que suben
##   tick : chispas en las patas (charcos electrificados)
##   muerte: estallido de chispas
## Usa tiempo real, como el gato.

const SHOCK := Color(0.6, 0.95, 1.0)
const BURN := Color(1.0, 0.85, 0.75)
const SPARK := Color(1.0, 0.9, 0.5)

var _kind := &""
var _left := 0.0
var _wisps := [] ## {pos, vel, life}
var _sparks := [] ## {pos, vel, life}
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 3
	owner.hurt_taken.connect(_on_hurt)
	owner.died.connect(_on_died)


func _on_hurt(kind: StringName, _amount: float) -> void:
	_kind = kind
	match kind:
		&"shock":
			_left = 0.5
		&"burn":
			_left = 0.6
			for i in 8:
				_wisps.append({pos = Vector2(_rnd.randf_range(-9, 9), _rnd.randf_range(-6, 10)),
						vel = Vector2(_rnd.randf_range(-6, 6), _rnd.randf_range(-30, -14)), life = _rnd.randf_range(0.5, 0.9)})
		&"tick":
			_left = 0.12
			if _rnd.randf() < 0.5:
				_sparks.append({pos = Vector2(_rnd.randf_range(-10, 10), 14),
						vel = Vector2(_rnd.randf_range(-40, 40), _rnd.randf_range(-70, -30)), life = 0.25})
		_:
			_left = 0.2


func _on_died() -> void:
	for i in 24:
		var v := Vector2.from_angle(_rnd.randf() * TAU) * _rnd.randf_range(40, 140)
		_sparks.append({pos = Vector2(0, 4), vel = v, life = _rnd.randf_range(0.3, 0.7)})


func _process(delta: float) -> void:
	var real := delta / Engine.time_scale
	_left = maxf(_left - real, 0.0)
	for w in _wisps:
		w.life -= real
		w.pos += w.vel * real
	for s in _sparks:
		s.life -= real
		s.vel.y += 300.0 * real
		s.pos += s.vel * real
	_wisps = _wisps.filter(func(w): return w.life > 0.0)
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	queue_redraw()


func _draw() -> void:
	if _kind == &"shock" and _left > 0.0:
		# Arcos quebrados que saltan entre puntos del cuerpo
		for i in 3:
			var a := Vector2(_rnd.randf_range(-11, 11), _rnd.randf_range(-8, 12))
			var b := Vector2(_rnd.randf_range(-11, 11), _rnd.randf_range(-8, 12))
			var pts := PackedVector2Array([a])
			for k in range(1, 5):
				pts.append(a.lerp(b, k / 5.0) + Vector2(_rnd.randf_range(-2.5, 2.5), _rnd.randf_range(-2.5, 2.5)))
			pts.append(b)
			draw_polyline(pts, Color(SHOCK, 0.35), 1.6, true)
			draw_polyline(pts, Color(Color.WHITE, 0.95), 0.4, true)
	for w in _wisps:
		draw_circle(w.pos, 2.0 + (0.9 - w.life) * 4.0, Color(BURN, 0.25 * w.life), true, -1.0, true)
	for s in _sparks:
		draw_line(s.pos, s.pos - s.vel * 0.025, Color(SPARK, minf(s.life * 4.0, 1.0)), 0.6, true)

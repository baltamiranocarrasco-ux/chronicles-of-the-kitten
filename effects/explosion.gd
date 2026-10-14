extends Node2D
## Explosión de una mina: destello, onda, chispas y humo. Va con el tiempo
## del mundo (la Q la frena, la R la congela).

const CORE := Color(1.0, 0.95, 0.8)
const FIRE := Color(1.0, 0.45, 0.2)
const SMOKE := Color(0.25, 0.22, 0.28)

var radius := 22.0
var _t := 0.0
var _sparks := [] ## {pos, vel, life}
var _smoke := [] ## {pos, vel, life, size}


func _ready() -> void:
	z_index = 4
	for i in 22:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(60, 220)
		_sparks.append({pos = Vector2.ZERO, vel = v, life = randf_range(0.2, 0.5)})
	for i in 8:
		_smoke.append({pos = Vector2(randf_range(-4, 4), randf_range(-4, 4)),
				vel = Vector2(randf_range(-14, 14), randf_range(-22, -6)), life = randf_range(0.7, 1.1),
				size = randf_range(4, 7)})


func _process(delta: float) -> void:
	_t += delta
	for s in _sparks:
		s.life -= delta
		s.vel *= 1.0 - minf(delta * 3.0, 0.9)
		s.vel.y += 120.0 * delta
		s.pos += s.vel * delta
	for m in _smoke:
		m.life -= delta
		m.pos += m.vel * delta
		m.size += delta * 9.0
	if _t > 1.2:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for m in _smoke:
		if m.life > 0.0:
			draw_circle(m.pos, m.size, Color(SMOKE, 0.35 * minf(m.life, 1.0)), true, -1.0, true)
	var k := clampf(_t / 0.25, 0.0, 1.0)
	if k < 1.0:
		draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * k), Color(FIRE, 0.45 * (1.0 - k)), true, -1.0, true)
		draw_circle(Vector2.ZERO, radius * 0.5 * (1.0 - k), Color(CORE, 1.0 - k), true, -1.0, true)
	var ring := clampf(_t / 0.35, 0.0, 1.0)
	if ring < 1.0:
		draw_arc(Vector2.ZERO, radius * (0.5 + ring), 0.0, TAU, 32, Color(CORE, 0.8 * (1.0 - ring)), 1.0, true)
	for s in _sparks:
		if s.life > 0.0:
			draw_line(s.pos, s.pos - s.vel * 0.03, Color(FIRE.lightened(0.3), minf(s.life * 4.0, 1.0)), 0.7, true)

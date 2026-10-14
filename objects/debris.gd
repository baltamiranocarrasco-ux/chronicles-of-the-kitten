extends Node2D
## Pedazos que saltan de una caja al golpearla o romperla (los crea
## objects/crate.gd). Chispas en el metal, polvo en el cartón. Van con el
## tiempo del mundo: la Q los frena y la R los deja en el aire.

const GRAVITY := 520.0
const SPARK := Color(1.0, 0.75, 0.4)
const DUST := Color(0.55, 0.5, 0.48)

var _pieces := [] ## {pos, vel, rot, spin, size, color, life, max}
var _sparks := [] ## {pos, vel, life}
var _dust := [] ## {pos, vel, life, size}
var _floor := 0.0 ## rebotan en lo que había debajo de la caja


func setup(size: Vector2, colors: Array, dir: float, pieces: int, hit_only: bool, metal: bool,
		floor_y: float) -> void:
	_floor = floor_y
	var push := dir if dir != 0.0 else 1.0
	for i in pieces:
		var w := randf_range(1.5, 4.5)
		_pieces.append({
			pos = Vector2(randf_range(-size.x, size.x), randf_range(-size.y, size.y)) * 0.35,
			vel = Vector2(push * randf_range(20, 130) + randf_range(-40, 40), randf_range(-190, -60)),
			rot = randf() * TAU, spin = randf_range(-14, 14),
			size = Vector2(w, w * randf_range(0.3, 0.9)),
			color = colors[randi() % colors.size()], life = randf_range(0.7, 1.2), max = 1.2,
		})
	var sparks := (7 if hit_only else 16) if metal else 0
	for i in sparks:
		var v := Vector2.from_angle(randf_range(-2.6, -0.5)) * randf_range(70, 200)
		v.x = absf(v.x) * push
		_sparks.append({pos = Vector2(-push * size.x * 0.4, randf_range(-3, 3)), vel = v, life = randf_range(0.15, 0.35)})
	var dust := (4 if hit_only else 10) if not metal else (0 if hit_only else 5)
	for i in dust:
		_dust.append({pos = Vector2(randf_range(-size.x, size.x) * 0.4, randf_range(-2, size.y * 0.4)),
				vel = Vector2(randf_range(-20, 20) + push * 10, randf_range(-18, -4)),
				life = randf_range(0.5, 0.9), size = randf_range(2.0, 4.0)})


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	for p in _pieces:
		p.life -= delta
		p.vel.y += GRAVITY * delta
		p.pos += p.vel * delta
		p.rot += p.spin * delta
		if p.pos.y > _floor and p.vel.y > 0.0:
			p.pos.y = _floor
			p.vel = Vector2(p.vel.x * 0.5, -p.vel.y * 0.3)
			p.spin *= 0.5
	for s in _sparks:
		s.life -= delta
		s.vel.y += GRAVITY * 0.6 * delta
		s.pos += s.vel * delta
	for d in _dust:
		d.life -= delta
		d.pos += d.vel * delta
		d.size += delta * 5.0
	_pieces = _pieces.filter(func(p): return p.life > 0.0)
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	_dust = _dust.filter(func(d): return d.life > 0.0)
	if _pieces.is_empty() and _sparks.is_empty() and _dust.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	for d in _dust:
		draw_circle(d.pos, d.size, Color(DUST, 0.25 * minf(d.life * 2.0, 1.0)), true, -1.0, true)
	for p in _pieces:
		var alpha := minf(p.life * 3.0, 1.0)
		draw_set_transform(p.pos, p.rot)
		draw_rect(Rect2(-p.size / 2.0, p.size), Color(p.color, alpha))
		draw_rect(Rect2(-p.size / 2.0, Vector2(p.size.x, 0.6)), Color(p.color.lightened(0.35), alpha))
	draw_set_transform(Vector2.ZERO)
	for s in _sparks:
		var k: float = clampf(s.life / 0.25, 0.0, 1.0)
		draw_line(s.pos, s.pos - s.vel * 0.03, Color(SPARK, k), 0.7, true)

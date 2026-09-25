extends Node2D
## Energía de las habilidades dibujada en el lomo del gato (interfaz diegética):
## una tira de fibra óptica de BLOCKS bloques que se apaga desde el cuello
## hacia la cola. Sin assets: todo se dibuja con _draw().
##   Q: se consume suave (bloque a bloque con brillo parcial), tinte lima.
##   R: los bloques pagados se apagan de golpe con chispas eléctricas.
##   Sobrecarga: la tira parpadea en rojo y las patas sueltan humo.
## La altura del lomo se lee del propio sprite en cada cuadro, así que se
## adapta sola a otra hoja de sprites si el lomo cae en SPINE_COLUMNS.

const BLOCKS := 5
## Columnas (del cuadro mirando a la derecha) de cada bloque, del cuello a la
## cola. Con el gato provisorio solo el tramo 10-16 es lomo limpio (a la
## derecha empieza la cabeza y a la izquierda asoma la cola). Al cambiar de
## sprite, ajustar estas columnas al tramo de lomo del nuevo dibujo.
const SPINE_COLUMNS := [16, 15, 14, 13, 12]
const BLOCK_WIDTH := 1

const LIT := Color(0.35, 0.95, 1.0)
const LIT_SLOW := Color(0.62, 1.0, 0.42)
const LIT_STOP := Color(0.85, 0.93, 1.0)
const OFF := Color(0.08, 0.16, 0.2)
const OVERLOAD := Color(1.0, 0.25, 0.2)
const OVERLOAD_DIM := Color(0.35, 0.06, 0.05)
const SPARK := Color(0.9, 1.0, 1.0)
const SMOKE := Color(0.75, 0.75, 0.78)

@export var powers_path: NodePath = ^"../TimePowers"
@export var sprite_path: NodePath = ^"../Sprite2D"

var _back_rows := {} ## frame -> Array[int] con la fila del lomo por bloque
var _sparks := [] ## {pos, vel, life, max}
var _smoke := [] ## {pos, vel, life, max, size}
var _smoke_timer := 0.0
var _flash := {} ## bloque -> tiempo restante del destello al pagar el Za Warudo

@onready var powers: TimePowers = get_node(powers_path)
@onready var sprite: Sprite2D = get_node(sprite_path)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	z_index = 2
	_scan_back_rows()
	powers.stop_cost_paid.connect(_on_stop_cost_paid)


func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale
	for key in _flash.keys():
		_flash[key] -= real_delta
		if _flash[key] <= 0.0:
			_flash.erase(key)
	_update_particles(_sparks, real_delta, 0.0)
	_update_particles(_smoke, real_delta, -8.0)
	if powers.is_overloaded():
		_smoke_timer -= real_delta
		if _smoke_timer <= 0.0:
			_smoke_timer = 0.07
			_spawn_smoke()
	queue_redraw()


func _draw() -> void:
	var overloaded := powers.is_overloaded()
	var blink := int(Time.get_ticks_msec() / 150) % 2 == 0
	var lit := LIT
	match powers.mode:
		TimePowers.Mode.SLOW:
			lit = LIT_SLOW
		TimePowers.Mode.STOP:
			lit = LIT_STOP
	var per_block := TimePowers.MAX_ENERGY / BLOCKS
	for i in BLOCKS:
		var rect := _block_rect(i)
		if rect.size == Vector2.ZERO:
			continue
		var color: Color
		if overloaded:
			color = OVERLOAD if blink else OVERLOAD_DIM
		elif _flash.has(i):
			color = SPARK
		else:
			# El bloque 0 (cuello) guarda la energía más alta: es el primero en apagarse
			var fill := clampf((powers.energy - (BLOCKS - 1 - i) * per_block) / per_block, 0.0, 1.0)
			color = OFF.lerp(lit, fill)
		draw_rect(rect, color)
	for s in _sparks:
		var a: float = s.life / s.max
		draw_line(s.pos, s.pos + s.vel.normalized() * 2.0, Color(SPARK, a), 1.0)
	for p in _smoke:
		var a: float = 0.7 * p.life / p.max
		draw_rect(Rect2(p.pos, Vector2(p.size, p.size)), Color(SMOKE, a))


# --- lomo --------------------------------------------------------------------

func _scan_back_rows() -> void:
	var image := sprite.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var fw := image.get_width() / sprite.hframes
	var fh := image.get_height() / sprite.vframes
	for frame in sprite.hframes * sprite.vframes:
		var ox := (frame % sprite.hframes) * fw
		var oy := (frame / sprite.hframes) * fh
		var rows := []
		for col in SPINE_COLUMNS:
			var top := -1
			for y in fh:
				var opaque := false
				for dx in BLOCK_WIDTH:
					if image.get_pixel(ox + col + dx, oy + y).a > 0.5:
						opaque = true
				if opaque:
					top = y
					break
			rows.append(top)
		_back_rows[frame] = rows


func _block_rect(i: int) -> Rect2:
	var rows: Array = _back_rows.get(sprite.frame, [])
	if rows.is_empty() or rows[i] < 0:
		return Rect2()
	var fw := sprite.texture.get_width() / sprite.hframes
	var fh := sprite.texture.get_height() / sprite.vframes
	var col: int = SPINE_COLUMNS[i]
	if sprite.flip_h:
		col = fw - col - BLOCK_WIDTH
	# Una fila bajo el contorno, sobre el pelaje
	var top_left := Vector2(col, rows[i] + 1) - Vector2(fw, fh) / 2.0 + sprite.offset + sprite.position
	return Rect2(top_left, Vector2(BLOCK_WIDTH, 1))


# --- efectos -----------------------------------------------------------------

func _on_stop_cost_paid(before: float, after: float) -> void:
	var per_block := TimePowers.MAX_ENERGY / BLOCKS
	for i in BLOCKS:
		var threshold := (BLOCKS - 1 - i) * per_block
		# Bloques que tenían carga y quedaron vacíos: destello y chispas
		if before > threshold and after < threshold + per_block * 0.5:
			_flash[i] = 0.12
			var rect := _block_rect(i)
			for n in 4:
				_sparks.append({
					pos = rect.get_center(),
					vel = Vector2.from_angle(randf() * TAU) * randf_range(25.0, 60.0),
					life = randf_range(0.15, 0.35), max = 0.35,
				})


func _spawn_smoke() -> void:
	var feet_y := sprite.offset.y + sprite.position.y + 12.0
	for foot_x in [-7.0, 6.0]:
		if randf() < 0.6:
			var life := randf_range(0.5, 0.9)
			_smoke.append({
				pos = Vector2(foot_x + randf_range(-2.0, 2.0), feet_y),
				vel = Vector2(randf_range(-6.0, 6.0), randf_range(-22.0, -12.0)),
				life = life, max = life, size = randf_range(1.0, 2.0),
			})


func _update_particles(list: Array, real_delta: float, gravity: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]
		p.life -= real_delta
		if p.life <= 0.0:
			list.remove_at(i)
			continue
		p.vel.y += gravity * real_delta
		p.pos += p.vel * real_delta

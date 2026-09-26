extends Node2D
## Interfaz diegética del gato cíborg, dibujada sobre el sprite (sin assets):
##  - Espina temporo-lumínica: los píxeles del lomo pintados con los colores
##    clave de tools/cyber_cat.py forman BLOCKS segmentos, que se apagan desde
##    el cuello (SPINE_NECK) hacia la cola. Sigue al gato en cualquier pose.
##      reposo: cian que pulsa lento como una respiración
##      Q: magenta neón, se consume segmento a segmento
##      R: descarga blanco-violeta; los segmentos pagados se apagan de golpe con chispas
##      sobrecarga: parpadeo rojo y humo en las patas
##  - Ojo cibernético (LENS_KEY): rojo apagado; en cian mientras hay una
##    habilidad activa, con un haz y una retícula al activarla.

const BLOCKS := 5
const SPINE_KEY := Color8(64, 224, 224)
const SPINE_NECK := Color8(66, 226, 226)
const LENS_KEY := Color8(178, 24, 36)

const IDLE_LIT := Color(0.3, 0.95, 0.95)
const SLOW_LIT := Color(1.0, 0.22, 0.85)
const STOP_LIT := Color(0.92, 0.86, 1.0)
const OFF := Color(0.06, 0.1, 0.14)
const OVERLOAD := Color(1.0, 0.2, 0.18)
const OVERLOAD_DIM := Color(0.3, 0.05, 0.05)
const SPARK := Color(0.95, 0.9, 1.0)
const SMOKE := Color(0.72, 0.72, 0.76)
const LENS_ON := Color(0.35, 0.95, 1.0)
const PULSE_PERIOD := 2.4 ## segundos por "respiración" de la espina en reposo
const RETICLE_TIME := 0.8 ## duración del haz de retícula al activar una habilidad

@export var powers_path: NodePath = ^"../TimePowers"
@export var sprite_path: NodePath = ^"../Sprite2D"

var _spine := {} ## frame -> Array de BLOCKS listas de píxeles (Vector2i) del cuello a la cola
var _lens := {} ## frame -> Array de píxeles de la lente
var _sparks := [] ## {pos, vel, life, max}
var _smoke := [] ## {pos, vel, life, max, size}
var _smoke_timer := 0.0
var _flash := {} ## segmento -> tiempo restante del destello al pagar el Za Warudo
var _reticle := 0.0

@onready var powers: TimePowers = get_node(powers_path)
@onready var sprite: Sprite2D = get_node(sprite_path)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	z_index = 2
	_scan_sheet()
	powers.stop_cost_paid.connect(_on_stop_cost_paid)
	powers.mode_changed.connect(_on_mode_changed)


func _on_mode_changed(mode: TimePowers.Mode) -> void:
	if mode != TimePowers.Mode.NONE:
		_reticle = RETICLE_TIME


func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale
	for key in _flash.keys():
		_flash[key] -= real_delta
		if _flash[key] <= 0.0:
			_flash.erase(key)
	_reticle = maxf(_reticle - real_delta, 0.0)
	_update_particles(_sparks, real_delta, 0.0)
	_update_particles(_smoke, real_delta, -8.0)
	if powers.is_overloaded():
		_smoke_timer -= real_delta
		if _smoke_timer <= 0.0:
			_smoke_timer = 0.07
			_spawn_smoke()
	queue_redraw()


func _draw() -> void:
	_draw_spine()
	_draw_lens()
	for s in _sparks:
		draw_line(s.pos, s.pos + s.vel.normalized() * 2.0, Color(SPARK, s.life / s.max), 1.0)
	for p in _smoke:
		draw_rect(Rect2(p.pos, Vector2(p.size, p.size)), Color(SMOKE, 0.7 * p.life / p.max))


func _draw_spine() -> void:
	var groups: Array = _spine.get(sprite.frame, [])
	if groups.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var blink := int(now / 0.15) % 2 == 0
	var lit := IDLE_LIT
	match powers.mode:
		TimePowers.Mode.SLOW:
			lit = SLOW_LIT
		TimePowers.Mode.STOP:
			lit = STOP_LIT
		_:
			# Reposo: pulso lento como una respiración
			lit = IDLE_LIT.darkened(0.25 * (0.5 + 0.5 * sin(now * TAU / PULSE_PERIOD)))
	var per_block := TimePowers.MAX_ENERGY / BLOCKS
	for i in groups.size():
		var color: Color
		if powers.is_overloaded():
			color = OVERLOAD if blink else OVERLOAD_DIM
		elif _flash.has(i):
			color = SPARK
		else:
			# El segmento 0 (cuello) guarda la energía más alta: es el primero en apagarse
			var fill := clampf((powers.energy - (BLOCKS - 1 - i) * per_block) / per_block, 0.0, 1.0)
			color = OFF.lerp(lit, fill)
		for px in groups[i]:
			draw_rect(Rect2(_to_local_px(px), _px_size()), color)


func _draw_lens() -> void:
	var pixels: Array = _lens.get(sprite.frame, [])
	if pixels.is_empty() or (powers.mode == TimePowers.Mode.NONE and _reticle <= 0.0):
		return
	for px in pixels:
		draw_rect(Rect2(_to_local_px(px), _px_size()), LENS_ON)
	if _reticle <= 0.0:
		return
	# Haz y retícula flotante frente al ojo
	var a := _reticle / RETICLE_TIME
	var dir := -1.0 if sprite.flip_h else 1.0
	var eye: Vector2 = _to_local_px(pixels[pixels.size() / 2]) + _px_size() / 2.0
	for d in range(2, 9, 2):
		draw_rect(Rect2(eye + Vector2(dir * d - 0.5, -0.5), Vector2.ONE), Color(LENS_ON, a * 0.8))
	var c := eye + Vector2(dir * 11, 0)
	for corner in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		draw_rect(Rect2(c + corner - Vector2(0.5, 0.5), Vector2.ONE), Color(LENS_ON, a))
	draw_rect(Rect2(c - Vector2(0.5, 0.5), Vector2.ONE), Color(LENS_ON, a * 0.6))


# --- lectura de la hoja ------------------------------------------------------

func _scan_sheet() -> void:
	var image := sprite.texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var width := image.get_width()
	var fw := width / sprite.hframes
	var fh := image.get_height() / sprite.vframes
	var spine_key := _key(SPINE_KEY)
	var neck_key := _key(SPINE_NECK)
	var lens_key := _key(LENS_KEY)
	for frame in sprite.hframes * sprite.vframes:
		var ox := (frame % sprite.hframes) * fw
		var oy := (frame / sprite.hframes) * fh
		var spine: Array[Vector2i] = []
		var neck := Vector2i(-1, -1)
		var lens: Array[Vector2i] = []
		for y in fh:
			var row := ((oy + y) * width + ox) * 4
			for x in fw:
				var i := row + x * 4
				if data[i + 3] < 128:
					continue
				var c := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
				if c == neck_key:
					neck = Vector2i(x, y)
					spine.append(neck)
				elif c == spine_key:
					spine.append(Vector2i(x, y))
				elif c == lens_key:
					lens.append(Vector2i(x, y))
		_lens[frame] = lens
		if spine.size() >= BLOCKS:
			_spine[frame] = _split_spine(spine, neck)


func _key(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


func _split_spine(pixels: Array[Vector2i], neck: Vector2i) -> Array:
	# Del cuello a la cola: por distancia al píxel del cuello (o de derecha a
	# izquierda si el cuadro no lo tiene)
	if neck.x >= 0:
		pixels.sort_custom(func(a, b): return a.distance_squared_to(neck) < b.distance_squared_to(neck))
	else:
		pixels.sort_custom(func(a, b): return a.x > b.x)
	var groups := []
	for i in BLOCKS:
		groups.append(pixels.slice(i * pixels.size() / BLOCKS, (i + 1) * pixels.size() / BLOCKS))
	return groups


# Posición local (respecto al jugador) de un píxel de la hoja en el cuadro
# actual; funciona con cualquier escala del sprite (pixel art o alta resolución)
func _to_local_px(px: Vector2i) -> Vector2:
	var fw := sprite.texture.get_width() / sprite.hframes
	var fh := sprite.texture.get_height() / sprite.vframes
	var x := fw - 1 - px.x if sprite.flip_h else px.x
	return (Vector2(x, px.y) - Vector2(fw, fh) / 2.0 + sprite.offset) * sprite.scale + sprite.position


func _px_size() -> Vector2:
	return sprite.scale


# --- efectos -----------------------------------------------------------------

func _on_stop_cost_paid(before: float, after: float) -> void:
	var groups: Array = _spine.get(sprite.frame, [])
	var per_block := TimePowers.MAX_ENERGY / BLOCKS
	for i in groups.size():
		var threshold := (BLOCKS - 1 - i) * per_block
		# Segmentos que tenían carga y quedaron vacíos: destello y chispas
		if before > threshold and after < threshold + per_block * 0.5:
			_flash[i] = 0.12
			for px in groups[i]:
				_sparks.append({
					pos = _to_local_px(px) + _px_size() / 2.0,
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

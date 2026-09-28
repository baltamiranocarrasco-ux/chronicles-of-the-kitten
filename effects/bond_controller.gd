extends Node2D
## Relación con el gato a través del mouse (hijo del jugador).
## Según la confianza guardada en CatBond reacciona distinto al cursor:
##   hostil (< 20)      : si acercas el cursor bufa y lanza un zarpazo (arañazos
##                        en pantalla, solo visuales). Si dejas el cursor quieto
##                        cerca, sin tocarlo, va ganando confianza.
##   desconfiado (< 50) : retrocede con las orejas aplastadas; igual que antes,
##                        la paciencia (cursor quieto cerca) suma.
##   tolerante (< 80)   : se deja acariciar (ronronea); si sigues demasiado,
##                        avisa (orejas atrás, cola azotando) y si insistes muerde.
##   apegado (>= 80)    : mira al cursor, da cabezazos, se deja acariciar mucho
##                        más (corazones) y duerme panza arriba.
## Restan confianza: pasar el cursor rápido por encima, hacer clic sobre él
## (sobre todo dormido) e ignorar su aviso. Nada de esto afecta al juego:
## el zarpazo no hace daño ni frena al gato.

const REACT := 16.0 ## distancia del cursor al gato a la que reacciona (px del juego)
const NEAR := 42.0 ## hasta aquí cuenta como "quedarse cerca" sin molestarlo
const STILL_SPEED := 25.0 ## cursor quieto por debajo de esta velocidad (px/s)
const FAST_SPEED := 380.0 ## pasar el cursor más rápido que esto por encima lo asusta
const PATIENCE_TIME := 2.5 ## segundos de cursor quieto cerca para ganar confianza
const PATIENCE_GAIN := 1.0
const PET_GAIN := 1.2 ## por segundo de caricia
const CALM_SLEEP_TIME := 30.0 ## dormir sin que lo molesten también suma
const CALM_SLEEP_GAIN := 1.0
const FAST_LOSS := 3.0
const CLICK_LOSS := 2.0
const WAKE_LOSS := 4.0
const BITE_LOSS := 2.0
const SWIPE_COOLDOWN := 1.8
const WARN_TIME := 0.9 ## lo que dura el aviso antes de morder

const SCRATCH := Color(1.0, 0.25, 0.3)
const PURR := Color(0.8, 0.9, 1.0)
const HEART := Color(1.0, 0.45, 0.7)

## Solo para pruebas: si no es null, se usa en vez de la posición real del mouse
var debug_mouse = null
var click_pending := false ## clic izquierdo pendiente (también lo usan las pruebas)

var _mouse_prev := Vector2.INF
var _speed := 0.0
var _patience := 0.0
var _cooldown := 0.0
var _pet_time := 0.0
var _pet_limit := 4.0
var _warn_left := 0.0
var _calm_sleep := 0.0
var _headbutt_wait := 0.0
var _marks := [] ## arañazos: {pos, life}
var _fx := [] ## ondas de ronroneo y corazones: {pos, vel, life, max, heart}

@onready var player: CharacterBody2D = owner
@onready var sprite: Sprite2D = owner.get_node("Sprite2D")


func _ready() -> void:
	# La R congela también esto (el gato congelado no reacciona)
	process_mode = PROCESS_MODE_PAUSABLE
	z_index = 3
	_pet_limit = _new_pet_limit()
	_set_cursor()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_pending = true


func _process(delta: float) -> void:
	var real := delta / Engine.time_scale
	var mouse := _mouse()
	if _mouse_prev != Vector2.INF:
		_speed = lerpf(_speed, mouse.distance_to(_mouse_prev) / maxf(real, 0.0001), 0.35)
	_mouse_prev = mouse
	var clicked := click_pending
	click_pending = false
	_cooldown = maxf(_cooldown - real, 0.0)
	_headbutt_wait = maxf(_headbutt_wait - real, 0.0)
	_update_fx(real)

	var dist := _distance_to_cat(mouse)
	var over := dist <= 0.0

	# Dormido: hacer clic lo despierta de mal humor; dejarlo en paz suma
	if player.is_asleep():
		_reset_petting()
		if clicked and over:
			player.wake_by_click()
			CatBond.change(-WAKE_LOSS * (0.25 if CatBond.is_bonded() else 1.0))
		elif not over and _speed < STILL_SPEED:
			# Dejarlo dormir tranquilo (cursor lejos o quieto) también suma
			_calm_sleep += real
			if _calm_sleep >= CALM_SLEEP_TIME:
				_calm_sleep = 0.0
				CatBond.change(CALM_SLEEP_GAIN)
		return
	_calm_sleep = 0.0

	if not player.can_react():
		_reset_petting()
		return

	# Cursor brusco por encima o clic: lo asusta (menos si ya confía)
	if over and _speed > FAST_SPEED and _cooldown <= 0.0:
		if CatBond.is_bonded():
			# Ya confía: un movimiento brusco solo lo incomoda un poco
			CatBond.change(-FAST_LOSS * 0.3)
			_cooldown = 1.0
		else:
			CatBond.change(-FAST_LOSS)
			_scare(mouse)
		return
	if clicked and over and not CatBond.is_bonded():
		CatBond.change(-CLICK_LOSS)
		_scare(mouse)
		return

	if CatBond.is_hostile():
		_hostile(mouse, dist, real)
	elif CatBond.is_wary():
		_wary(mouse, dist, real)
	else:
		_friendly(mouse, dist, over, real)


# --- niveles ---------------------------------------------------------------

func _hostile(mouse: Vector2, dist: float, real: float) -> void:
	if dist < REACT:
		if _cooldown <= 0.0:
			_scare(mouse)
		return
	_patience_near(dist, real)


func _wary(mouse: Vector2, dist: float, real: float) -> void:
	if dist < REACT + 4.0:
		# Retrocede mirando al cursor con las orejas aplastadas
		player.face(signf(mouse.x - sprite.global_position.x))
		player.play_mood(&"flinch")
		return
	if player.mood() == &"flinch":
		player.end_mood()
	_patience_near(dist, real)


func _friendly(mouse: Vector2, dist: float, over: bool, real: float) -> void:
	var bonded := CatBond.is_bonded()
	if _warn_left > 0.0:
		_warn_left -= real
		if _warn_left <= 0.0:
			if over and not bonded:
				# Ignoraste el aviso: muerde
				CatBond.change(-BITE_LOSS)
				_scare(mouse)
			_reset_petting()
			_cooldown = 2.0
		return
	if over and _cooldown <= 0.0 and _speed < FAST_SPEED:
		# Caricia
		player.keep_awake()
		player.play_mood(&"pet")
		if _pet_time == 0.0:
			_pet_limit = _new_pet_limit() # según la confianza de ahora
		_pet_time += real
		CatBond.change(PET_GAIN * real)
		_emit_affection(real, bonded)
		if _pet_time >= _pet_limit:
			# Sobreestimulado: avisa antes de morder
			player.play_mood(&"warn")
			_warn_left = WARN_TIME
		return
	if player.mood() == &"pet":
		player.end_mood()
	_pet_time = maxf(_pet_time - real * 0.5, 0.0)
	if bonded and dist < NEAR:
		# Apegado: mira al cursor y a veces se acerca a darle un cabezazo
		player.face(signf(mouse.x - sprite.global_position.x))
		if dist < REACT and _speed < STILL_SPEED and _headbutt_wait <= 0.0:
			_headbutt_wait = 3.0
			player.play_mood(&"headbutt")
			CatBond.change(0.5)
	elif not bonded:
		_patience_near(dist, real)


func _patience_near(dist: float, real: float) -> void:
	# Dejar que él se acostumbre: cursor quieto cerca, sin tocarlo
	if dist < NEAR and _speed < STILL_SPEED:
		_patience += real
		if _patience >= PATIENCE_TIME:
			_patience = 0.0
			CatBond.change(PATIENCE_GAIN)
	else:
		_patience = maxf(_patience - real, 0.0)


func _scare(mouse: Vector2) -> void:
	# Zarpazo hacia el cursor; si lo alcanza deja arañazos (solo visuales)
	player.face(signf(mouse.x - sprite.global_position.x))
	player.play_mood(&"swipe")
	_cooldown = SWIPE_COOLDOWN
	_reset_petting()
	if _distance_to_cat(mouse) < REACT + 6.0:
		_marks.append({pos = mouse, life = 0.7})


func _reset_petting() -> void:
	_pet_time = 0.0
	_warn_left = 0.0
	_pet_limit = _new_pet_limit()


func _new_pet_limit() -> float:
	# Cuánto aguanta caricias antes de avisar (mucho más si confía)
	return randf_range(12.0, 18.0) if CatBond.is_bonded() else randf_range(3.0, 6.0)


# --- geometría ------------------------------------------------------------------

func _mouse() -> Vector2:
	return debug_mouse if debug_mouse != null else get_global_mouse_position()


## Distancia del punto al gato (cuerpo y cabeza); <= 0 si está encima.
func _distance_to_cat(p: Vector2) -> float:
	var center := sprite.global_position
	var f: float = player.facing()
	var body := center + Vector2(f, 5.0)
	var d_body := (Vector2((p.x - body.x) / 10.0, (p.y - body.y) / 6.0).length() - 1.0) * 6.0
	var head := center + Vector2(7.5 * f, -2.0)
	var d_head := p.distance_to(head) - 5.5
	return minf(d_body, d_head)


# --- efectos ----------------------------------------------------------------------

func _emit_affection(real: float, bonded: bool) -> void:
	if randf() > real * (2.5 if bonded else 3.0):
		return
	var head := sprite.global_position + Vector2(7.0 * player.facing(), -8.0)
	var life := randf_range(0.8, 1.2)
	_fx.append({pos = head + Vector2(randf_range(-3, 3), 0), vel = Vector2(randf_range(-4, 4), -12),
			life = life, max = life, heart = bonded})


func _update_fx(real: float) -> void:
	for list in [_marks, _fx]:
		for i in range(list.size() - 1, -1, -1):
			var e: Dictionary = list[i]
			e.life -= real
			if e.life <= 0.0:
				list.remove_at(i)
			elif e.has("vel"):
				e.pos += e.vel * real
	queue_redraw()


func _draw() -> void:
	for m in _marks:
		# Tres arañazos diagonales que se desvanecen
		var a: float = m.life / 0.7
		var p: Vector2 = to_local(m.pos)
		for k in 3:
			var o := Vector2(k * 2.2 - 2.2, 0)
			draw_line(p + o + Vector2(-3, -4), p + o + Vector2(3, 4), Color(SCRATCH, 0.9 * a), 0.6, true)
			draw_line(p + o + Vector2(-3, -4), p + o + Vector2(3, 4), Color(SCRATCH, 0.3 * a), 1.6, true)
	for e in _fx:
		var a: float = e.life / e.max
		var p: Vector2 = to_local(e.pos)
		if e.heart:
			var c := Color(HEART, a)
			draw_circle(p + Vector2(-0.7, 0), 0.8, c, true, -1.0, true)
			draw_circle(p + Vector2(0.7, 0), 0.8, c, true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-1.5, 0.2), p + Vector2(1.5, 0.2), p + Vector2(0, 2.0)]), c)
		else:
			# Ondas de ronroneo
			draw_arc(p, 1.6, -PI * 0.8, -PI * 0.2, 6, Color(PURR, 0.8 * a), 0.35, true)
			draw_arc(p, 2.8, -PI * 0.8, -PI * 0.2, 8, Color(PURR, 0.5 * a), 0.35, true)


func _set_cursor() -> void:
	# Mira cian en lugar de la flecha del sistema
	var size := 21
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Color(0.45, 0.95, 1.0)
	var mid := size / 2
	for i in size:
		var gap := absi(i - mid) <= 2
		if not gap:
			img.set_pixel(i, mid, c)
			img.set_pixel(mid, i, c)
	img.set_pixel(mid, mid, c)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(mid, mid))

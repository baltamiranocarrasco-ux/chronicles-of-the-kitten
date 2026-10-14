extends CharacterBody2D

const SPEED = 130.0
const SPRINT_SPEED = 185.0 # con Shift
const SLIDE_SPEED = 215.0 # velocidad al empezar a deslizarse (Ctrl mientras corre)
const SLIDE_FRICTION = 250.0 # frenado del deslizamiento, px/s²
const SLIDE_COOLDOWN = 0.35
const JUMP_VELOCITY = -320.0 # ~52 px de altura con la gravedad por defecto (980)
const SLEEP_AFTER = 8.0 # segundos quieto antes de dar vueltas y acostarse

# Zarpazo (clic izquierdo o J). Los tiempos siguen la animación "attack":
# el golpe cuenta mientras la pata baja con las garras (cuadros 2 y 3).
const ATTACK_TIME = 0.33
const ATTACK_HIT_FROM = 0.08
const ATTACK_HIT_TO = 0.18
const ATTACK_BUFFER = 0.15 # un clic un poco antes de terminar el anterior no se pierde
const ATTACK_MOVE = 0.45 # en el suelo avanza más lento mientras golpea
const ATTACK_DAMAGE = 1
const ATTACK_BOX = Vector2(26, 22) # zona del golpe, delante del gato
const ATTACK_BOX_OFFSET = Vector2(15, 3)
const PUSH_FORCE = 6.0 # empuje al caminar contra objetos sueltos (cajas)

# Vida y daño. Los peligros son Area2D en la capa HAZARD_LAYER con un método
# touch(player, real_delta) que decide si hacen daño (ver objects/hazards/).
const MAX_HEALTH = 100.0
const INVULN_TIME = 1.0 # tras un golpe, sin recibir otro
const KNOCKBACK = Vector2(150, -170)
const DEATH_TIME = 0.7
const HAZARD_LAYER = 8 # capa 4: peligros
const PICKUP_LAYER = 16 # capa 5: recargas, pistas y meta (también con touch())
const HOLO_LAYER = 4 # capa 3: hologramas que se vuelven sólidos con el tiempo detenido
const TOUCH_BOX = Vector2(18, 18) # zona del cuerpo que recibe daño
const TOUCH_OFFSET = Vector2(0, 4)
const HURT_COLORS = {&"hit": Color(1.0, 0.35, 0.35), &"burn": Color(1.0, 0.65, 0.35),
		&"shock": Color(0.55, 0.95, 1.0), &"tick": Color(0.65, 0.9, 1.0)}

signal attacked(dir: float) ## empezó un zarpazo (effects/claw_slash.gd dibuja el arco)
signal hit_landed(target: Node2D) ## el zarpazo golpeó algo
signal health_changed(value: float, max_value: float)
signal hurt_taken(kind: StringName, amount: float)
signal died

enum State {
	NORMAL,
	SETTLING, ## da vueltas y se acuesta
	SLEEPING,
	ANGRY, ## lo despertaron: arquea el lomo y no obedece hasta terminar
	MOOD, ## reacciona al mouse (effects/bond_controller.gd); moverse lo interrumpe
}

var state := State.NORMAL
var idle_time := 0.0
var sliding := false
var slide_cooldown := 0.0
var attack_time := -1.0 ## tiempo desde que empezó el zarpazo; < 0 si no ataca
var _attack_buffer := 0.0
var _attack_hits := {} ## lo que ya golpeó este zarpazo (un golpe por objeto)
var _attack_shape := RectangleShape2D.new()
@export var fall_limit := 40.0 ## más abajo de esto (vacíos entre edificios) muere
var health := MAX_HEALTH
var stun_time := 0.0 ## sin control (golpe o descarga eléctrica)
var last_hurt := &"hit"
var _invuln := 0.0
var _knock := 0.0 ## mientras dura, el retroceso se frena de a poco
var _dying := 0.0
var _flash := 0.0
var _touch_shape := RectangleShape2D.new()
## Desplazamiento del sprite mientras da vueltas antes de dormir (lo anima
## "settle"). Es solo visual: el cuerpo no se mueve. Mirando a la izquierda
## se invierte, igual que el dibujo.
var settle_offset := 0.0:
	set(value):
		settle_offset = value
		if is_node_ready():
			sprite2D.position.x = value * (-1.0 if sprite2D.flip_h else 1.0)

@onready var animationplayer = $AnimationPlayer
@onready var sprite2D = $Sprite2D
@onready var time_powers: TimePowers = $TimePowers
@onready var bond = $BondController
@onready var hud = $HUD

@onready var spawn_position: Vector2 = global_position

func _ready() -> void:
	animationplayer.animation_finished.connect(_on_animation_finished)
	_attack_shape.size = ATTACK_BOX
	_touch_shape.size = TOUCH_BOX
	# Con el tiempo detenido los hologramas se vuelven plataformas sólidas
	time_powers.mode_changed.connect(func(mode):
		collision_mask = 1 | (HOLO_LAYER if mode == TimePowers.Mode.STOP else 0))

func _physics_process(delta: float) -> void:
	# El gato ignora la cámara lenta (Sandevistan): usa tiempo real y el
	# mundo, que sí va lento, queda más lento que él.
	var time_boost := 1.0 / Engine.time_scale
	animationplayer.speed_scale = time_boost

	if not is_on_floor():
		velocity += get_gravity() * delta * time_boost

	var real_delta := delta * time_boost
	var direction := Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	# Con el cursor sobre el gato el clic es para él (bond_controller), no un ataque
	var attack_pressed: bool = Input.is_action_just_pressed("attack") \
			and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and bond.is_mouse_over())
	_invuln = maxf(_invuln - real_delta, 0.0)
	_knock = maxf(_knock - real_delta, 0.0)
	stun_time = maxf(stun_time - real_delta, 0.0)
	if _dying > 0.0:
		_dying -= real_delta
		if _dying <= 0.0:
			respawn()
			return
	if stun_time > 0.0 or _dying > 0.0:
		direction = 0.0
		jump_pressed = false
		attack_pressed = false
	_update_rest_state(delta * time_boost, direction, jump_pressed or attack_pressed)
	if state != State.NORMAL:
		direction = 0.0
		jump_pressed = false
		attack_pressed = false
	_update_attack(delta * time_boost, attack_pressed)

	var sprinting := Input.is_action_pressed("sprint") and direction != 0.0
	# La sobrecarga de las habilidades de tiempo deja al gato más lento
	var speed_mult := TimePowers.OVERLOAD_SPEED if time_powers.is_overloaded() else 1.0
	# Golpear caminando frena; corriendo (Shift) o deslizándose no se pierde el impulso
	if is_attacking() and is_on_floor() and not sprinting and not sliding:
		speed_mult *= ATTACK_MOVE
	_update_slide(delta * time_boost, direction, sprinting, speed_mult)

	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false # el salto conserva la velocidad del deslizamiento en el aire

	if sliding:
		pass # la velocidad la maneja _update_slide
	elif _knock > 0.0 and direction == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 420.0 * real_delta)
	elif direction:
		var target := (SPRINT_SPEED if sprinting else SPEED) * speed_mult
		# En el aire no se pierde el impulso de un deslizamiento o una carrera
		var airborne := not is_on_floor() or velocity.y < 0.0 # incluye el cuadro del salto
		if airborne and signf(velocity.x) == signf(direction):
			target = maxf(target, absf(velocity.x))
		velocity.x = direction * target
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# move_and_slide usa el delta escalado: se compensa solo la velocidad propia
	# (la de una plataforma móvil bajo el gato sigue yendo lenta, como debe)
	velocity *= time_boost
	move_and_slide()
	velocity /= time_boost
	_push_loose_objects()
	if _dying <= 0.0:
		_touch_areas(real_delta)
	if state == State.NORMAL:
		animations(direction, sprinting)

	if global_position.y > fall_limit and _dying <= 0.0:
		respawn() # cayó a un vacío entre edificios

	# Mientras da el zarpazo no se da vuelta
	if is_attacking():
		pass
	elif direction == 1:
		sprite2D.flip_h = false
	elif direction == -1:
		sprite2D.flip_h = true

func respawn() -> void:
	global_position = spawn_position
	reset_physics_interpolation() # teletransporte: sin arrastre visual
	velocity = Vector2.ZERO
	sliding = false
	_set_state(State.NORMAL)
	attack_time = -1.0
	_attack_buffer = 0.0
	stun_time = 0.0
	_knock = 0.0
	_dying = 0.0
	_invuln = INVULN_TIME # un instante de protección al reaparecer
	heal_full()

# Ctrl mientras corre (Shift) en el suelo: se desliza en la dirección en que
# mira, frenando hasta la velocidad de carrera. No se puede girar mientras dura.
func _update_slide(real_delta: float, direction: float, sprinting: bool, speed_mult: float) -> void:
	slide_cooldown = maxf(slide_cooldown - real_delta, 0.0)
	if sliding:
		var facing := -1.0 if sprite2D.flip_h else 1.0
		var speed := absf(velocity.x) - SLIDE_FRICTION * real_delta
		if not is_on_floor() or speed <= SPEED * speed_mult or state != State.NORMAL:
			sliding = false
			slide_cooldown = SLIDE_COOLDOWN
		else:
			velocity.x = facing * speed
		return
	if (state == State.NORMAL and sprinting and is_on_floor() and slide_cooldown <= 0.0
			and Input.is_action_just_pressed("slide")):
		sliding = true
		velocity.x = signf(direction) * SLIDE_SPEED * speed_mult

# Tras SLEEP_AFTER segundos quieto da vueltas y se duerme. Si lo intentan
# mover mientras se acuesta o duerme, se enoja antes de volver a obedecer.
# Las habilidades de tiempo (Q/R) no lo despiertan.
func _update_rest_state(real_delta: float, direction: float, jump_pressed: bool) -> void:
	var wants_to_move := direction != 0.0 or jump_pressed
	match state:
		State.NORMAL:
			if wants_to_move or not is_on_floor() or _any_action_pressed():
				idle_time = 0.0
			else:
				idle_time += real_delta
				if idle_time >= SLEEP_AFTER:
					_set_state(State.SETTLING)
		State.SETTLING, State.SLEEPING:
			if not is_on_floor():
				_set_state(State.NORMAL)
			elif wants_to_move:
				_set_state(State.ANGRY)
		State.MOOD:
			# El jugador siempre tiene prioridad sobre las reacciones al mouse
			if wants_to_move or not is_on_floor() or _any_action_pressed():
				_set_state(State.NORMAL)

func _any_action_pressed() -> bool:
	for action in ["slow_time", "stop_time", "interact", "move_up", "move_down", "sprint", "slide"]:
		if Input.is_action_just_pressed(action):
			return true
	return false

func _set_state(new_state: State) -> void:
	state = new_state
	idle_time = 0.0
	if state != State.NORMAL:
		attack_time = -1.0
	if state != State.SETTLING:
		settle_offset = 0.0
	match state:
		State.SETTLING:
			animationplayer.play("settle")
		State.SLEEPING:
			# Con mucha confianza duerme panza arriba
			animationplayer.play("sleep_belly" if CatBond.is_bonded() else "sleep")
		State.ANGRY:
			animationplayer.play("angry")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"settle" and state == State.SETTLING:
		_set_state(State.SLEEPING)
	elif anim_name == &"angry" and state == State.ANGRY:
		_set_state(State.NORMAL)
	elif state == State.MOOD:
		_set_state(State.NORMAL) # terminó una reacción que no se repite

# --- reacciones al mouse (las usa effects/bond_controller.gd) ------------------

## Quieto en el suelo y sin estar durmiendo ni enojado: puede reaccionar.
func can_react() -> bool:
	return (state == State.NORMAL or state == State.MOOD) and is_on_floor() \
			and absf(velocity.x) < 1.0 and not sliding

## Reproduce una reacción (zarpazo, retroceder, dejarse acariciar...).
func play_mood(anim: StringName) -> void:
	if not can_react():
		return
	if state != State.MOOD:
		state = State.MOOD
		idle_time = 0.0
	if animationplayer.current_animation != anim:
		animationplayer.play(anim)

func end_mood() -> void:
	if state == State.MOOD:
		_set_state(State.NORMAL)

func mood() -> StringName:
	return animationplayer.current_animation if state == State.MOOD else &""

## Mira hacia un lado (-1 izquierda, 1 derecha) si está quieto.
func face(dir: float) -> void:
	if can_react() and dir != 0.0:
		sprite2D.flip_h = dir < 0.0

func facing() -> float:
	return -1.0 if sprite2D.flip_h else 1.0

func is_asleep() -> bool:
	return state == State.SETTLING or state == State.SLEEPING

## Hacer clic sobre el gato dormido lo despierta enojado.
func wake_by_click() -> void:
	if is_asleep():
		_set_state(State.ANGRY)

## Mientras lo acarician no se va a dormir.
func keep_awake() -> void:
	idle_time = 0.0

func animations(direction, sprinting := false):
	if is_attacking():
		return # "attack" se reproduce entera
	if _dying > 0.0 or stun_time > 0.0:
		animationplayer.play("flinch" if _dying <= 0.0 else "fall")
		return
	if sliding:
		animationplayer.play("slide")
	elif is_on_floor():
		if direction == 0:
			animationplayer.play("idle")
		else:
			# Al correr con Shift las patas se mueven más rápido
			animationplayer.play("run", -1, SPRINT_SPEED / SPEED if sprinting else 1.0)
	else:
		if velocity.y < 0:
			animationplayer.play("jump")
		elif velocity.y > 0:
			animationplayer.play("fall")

# --- zarpazo -------------------------------------------------------------------

func is_attacking() -> bool:
	return attack_time >= 0.0

func _update_attack(real_delta: float, pressed: bool) -> void:
	if pressed:
		_attack_buffer = ATTACK_BUFFER
	else:
		_attack_buffer = maxf(_attack_buffer - real_delta, 0.0)
	if is_attacking():
		attack_time += real_delta
		if attack_time >= ATTACK_HIT_FROM and attack_time - real_delta <= ATTACK_HIT_TO:
			_attack_query()
		if attack_time >= ATTACK_TIME:
			attack_time = -1.0
	if not is_attacking() and _attack_buffer > 0.0 and state == State.NORMAL:
		_attack_buffer = 0.0
		attack_time = 0.0
		idle_time = 0.0
		_attack_hits.clear()
		animationplayer.play("attack")
		animationplayer.seek(0.0, true)
		attacked.emit(facing())

## Busca lo que está dentro de la zona del golpe. Es una consulta directa al
## espacio físico (no un Area2D), así que también funciona con el tiempo
## detenido (R): los golpes se acumulan y se aplican al reanudarse.
func _attack_query() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _attack_shape
	query.transform = Transform2D(0.0, global_position + ATTACK_BOX_OFFSET * Vector2(facing(), 1.0))
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target = hit.collider
		if target == null or not target.has_method("take_hit"):
			continue
		var id: int = target.get_instance_id()
		if _attack_hits.has(id):
			continue
		_attack_hits[id] = true
		target.take_hit(Vector2(facing(), 0.0), ATTACK_DAMAGE)
		hit_landed.emit(target)

## El gato empuja un poco los objetos sueltos (cajas) al caminar contra ellos.
func _push_loose_objects() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody2D
		if body and absf(c.get_normal().x) > 0.5:
			body.apply_central_impulse(-c.get_normal() * PUSH_FORCE)

# --- vida y daño -------------------------------------------------------------------

## Recibe daño. kind: &"hit" golpe (retroceso), &"burn" quemadura,
## &"shock" descarga (aturde más tiempo) o &"tick" daño continuo (sin
## retroceso ni invulnerabilidad, p. ej. charcos electrificados).
func hurt(amount: float, from: Vector2, kind: StringName = &"hit") -> void:
	if _dying > 0.0:
		return
	if kind != &"tick":
		if _invuln > 0.0:
			return
		_invuln = INVULN_TIME
		var dir := signf(global_position.x - from.x)
		if dir == 0.0:
			dir = -facing()
		velocity = Vector2(dir * KNOCKBACK.x, KNOCKBACK.y)
		_knock = 0.4
		stun_time = 0.5 if kind == &"shock" else 0.22
		sliding = false
		attack_time = -1.0
		if state != State.NORMAL:
			_set_state(State.NORMAL)
	last_hurt = kind
	_flash = 1.0
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, MAX_HEALTH)
	hurt_taken.emit(kind, amount)
	if health <= 0.0:
		_die()

func heal_full() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)

func is_dying() -> bool:
	return _dying > 0.0

func _die() -> void:
	_dying = DEATH_TIME
	velocity = Vector2(0.0, -140.0)
	attack_time = -1.0
	died.emit()

## Peligros, recargas, pistas y meta que toca el cuerpo. Consulta directa al
## espacio físico: funciona también con el tiempo detenido.
func _touch_areas(real_delta: float) -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _touch_shape
	query.transform = Transform2D(0.0, global_position + TOUCH_OFFSET)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	query.collision_mask = HAZARD_LAYER | PICKUP_LAYER
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var area = hit.collider
		if area and area.has_method("touch"):
			area.touch(self, real_delta)
		if _dying > 0.0:
			return

func _process(delta: float) -> void:
	# Destello del color del daño y parpadeo mientras es invulnerable
	_flash = maxf(_flash - delta / Engine.time_scale * 4.0, 0.0)
	var c := Color.WHITE.lerp(HURT_COLORS.get(last_hurt, Color.RED), _flash)
	if _invuln > 0.0 and fmod(_invuln, 0.14) < 0.06:
		c.a = 0.35
	if _dying > 0.0:
		c = Color(1.0, 0.4, 0.4, clampf(_dying / DEATH_TIME, 0.0, 1.0))
	sprite2D.modulate = c

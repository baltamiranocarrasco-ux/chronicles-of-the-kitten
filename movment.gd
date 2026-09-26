extends CharacterBody2D

const SPEED = 130.0
const SPRINT_SPEED = 185.0 # con Shift
const SLIDE_SPEED = 215.0 # velocidad al empezar a deslizarse (Ctrl mientras corre)
const SLIDE_FRICTION = 250.0 # frenado del deslizamiento, px/s²
const SLIDE_COOLDOWN = 0.35
const JUMP_VELOCITY = -320.0 # ~52 px de altura con la gravedad por defecto (980)
const FALL_LIMIT = 40.0 # si cae más abajo (fosos), reaparece
const SLEEP_AFTER = 8.0 # segundos quieto antes de dar vueltas y acostarse

enum State {
	NORMAL,
	SETTLING, ## da vueltas y se acuesta
	SLEEPING,
	ANGRY, ## lo despertaron: arquea el lomo y no obedece hasta terminar
}

var state := State.NORMAL
var idle_time := 0.0
var sliding := false
var slide_cooldown := 0.0
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

@onready var spawn_position: Vector2 = global_position

func _ready() -> void:
	animationplayer.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	# El gato ignora la cámara lenta (Sandevistan): usa tiempo real y el
	# mundo, que sí va lento, queda más lento que él.
	var time_boost := 1.0 / Engine.time_scale
	animationplayer.speed_scale = time_boost

	if not is_on_floor():
		velocity += get_gravity() * delta * time_boost

	var direction := Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	_update_rest_state(delta * time_boost, direction, jump_pressed)
	if state != State.NORMAL:
		direction = 0.0
		jump_pressed = false

	var sprinting := Input.is_action_pressed("sprint") and direction != 0.0
	# La sobrecarga de las habilidades de tiempo deja al gato más lento
	var speed_mult := TimePowers.OVERLOAD_SPEED if time_powers.is_overloaded() else 1.0
	_update_slide(delta * time_boost, direction, sprinting, speed_mult)

	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false # el salto conserva la velocidad del deslizamiento en el aire

	if sliding:
		pass # la velocidad la maneja _update_slide
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
	if state == State.NORMAL:
		animations(direction, sprinting)

	if global_position.y > FALL_LIMIT:
		respawn()

	if direction == 1:
		sprite2D.flip_h = false
	elif direction == -1:
		sprite2D.flip_h = true

func respawn() -> void:
	global_position = spawn_position
	reset_physics_interpolation() # teletransporte: sin arrastre visual
	velocity = Vector2.ZERO
	sliding = false
	_set_state(State.NORMAL)

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

func _any_action_pressed() -> bool:
	for action in ["slow_time", "stop_time", "interact", "move_up", "move_down", "sprint", "slide"]:
		if Input.is_action_just_pressed(action):
			return true
	return false

func _set_state(new_state: State) -> void:
	state = new_state
	idle_time = 0.0
	if state != State.SETTLING:
		settle_offset = 0.0
	match state:
		State.SETTLING:
			animationplayer.play("settle")
		State.SLEEPING:
			animationplayer.play("sleep")
		State.ANGRY:
			animationplayer.play("angry")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"settle" and state == State.SETTLING:
		_set_state(State.SLEEPING)
	elif anim_name == &"angry" and state == State.ANGRY:
		_set_state(State.NORMAL)

func animations(direction, sprinting := false):
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

extends CharacterBody2D

const SPEED = 130.0
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

@onready var animationplayer = $AnimationPlayer
@onready var sprite2D = $Sprite2D

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

	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# move_and_slide usa el delta escalado: se compensa solo la velocidad propia
	# (la de una plataforma móvil bajo el gato sigue yendo lenta, como debe)
	velocity *= time_boost
	move_and_slide()
	velocity /= time_boost
	if state == State.NORMAL:
		animations(direction)

	if global_position.y > FALL_LIMIT:
		respawn()

	if direction == 1:
		sprite2D.flip_h = false
	elif direction == -1:
		sprite2D.flip_h = true

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_set_state(State.NORMAL)

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
	for action in ["slow_time", "stop_time", "interact", "move_up", "move_down"]:
		if Input.is_action_just_pressed(action):
			return true
	return false

func _set_state(new_state: State) -> void:
	state = new_state
	idle_time = 0.0
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

func animations(direction):
	if is_on_floor():
		if direction == 0:
			animationplayer.play("idle")
		else:
			animationplayer.play("run")
	else:
		if velocity.y < 0:
			animationplayer.play("jump")
		elif velocity.y > 0:
			animationplayer.play("fall")

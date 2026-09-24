extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -320.0 # ~52 px de altura con la gravedad por defecto (980)
const FALL_LIMIT = 40.0 # si cae más abajo (fosos), reaparece
const SLOW_TIME_SCALE = 0.3

@onready var animationplayer = $AnimationPlayer
@onready var sprite2D = $Sprite2D
@onready var time_stop_fx = $TimeStopFX

@onready var spawn_position: Vector2 = global_position

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("stop_time"):
		set_time_frozen(not get_tree().paused)
	elif Input.is_action_just_pressed("slow_time"):
		set_time_frozen(false)
		toggle_time_scale(SLOW_TIME_SCALE)

	move_and_slide()
	animations(direction)

	if global_position.y > FALL_LIMIT:
		respawn()

	if direction == 1:
		sprite2D.flip_h = false
	elif direction == -1:
		sprite2D.flip_h = true

# Congela el mundo pausando el árbol de escena. El jugador (process_mode
# Always) sigue moviéndose, como con el Sandevistan.
func set_time_frozen(frozen: bool) -> void:
	if get_tree().paused == frozen:
		return
	if frozen:
		Engine.time_scale = 1.0
	get_tree().paused = frozen
	time_stop_fx.set_active(frozen)

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO

func toggle_time_scale(target_scale: float) -> void:
	if Engine.time_scale == target_scale:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = target_scale

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

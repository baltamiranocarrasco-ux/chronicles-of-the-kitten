extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -320.0 # ~52 px de altura con la gravedad por defecto (980)
const FALL_LIMIT = 40.0 # si cae más abajo (fosos), reaparece

@onready var animationplayer = $AnimationPlayer
@onready var sprite2D = $Sprite2D

@onready var spawn_position: Vector2 = global_position

func _physics_process(delta: float) -> void:
	# El gato ignora la cámara lenta (Sandevistan): usa tiempo real y el
	# mundo, que sí va lento, queda más lento que él.
	var time_boost := 1.0 / Engine.time_scale
	animationplayer.speed_scale = time_boost

	if not is_on_floor():
		velocity += get_gravity() * delta * time_boost

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# move_and_slide usa el delta escalado: se compensa solo la velocidad propia
	# (la de una plataforma móvil bajo el gato sigue yendo lenta, como debe)
	velocity *= time_boost
	move_and_slide()
	velocity /= time_boost
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

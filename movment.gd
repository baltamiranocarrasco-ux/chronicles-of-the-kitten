extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const SLOW_TIME_SCALE = 0.3

@onready var animationplayer = $AnimationPlayer
@onready var sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("stop_time"):
		toggle_time_scale(0.0)
	elif Input.is_action_just_pressed("slow_time"):
		toggle_time_scale(SLOW_TIME_SCALE)

	move_and_slide()
	animations(direction)

	if direction == 1:
		sprite2D.flip_h = false
	elif direction == -1:
		sprite2D.flip_h = true

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

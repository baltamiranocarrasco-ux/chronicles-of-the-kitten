@tool
extends RigidBody2D
## Caja que el gato puede romper a zarpazos (movment.gd llama a take_hit).
##   METAL: contenedor de acero, resiste 3 golpes; cada uno deja arañazos y
##          lo empuja un poco.
##   BOX  : caja de cartón, se rompe de un golpe.
## Es un cuerpo rígido: cae, se apila, rueda y el gato la empuja al caminar.
## Con el tiempo detenido (R) los golpes se guardan y se aplican todos juntos
## al reanudarse.

enum Kind { METAL, BOX }

const DEBRIS := preload("res://objects/debris.gd")
const SETTINGS := {
	Kind.METAL: {
		texture = preload("res://objects/crate_metal.png"), frames = 3, size = Vector2(16, 16),
		hp = 3, mass = 3.0, knock = Vector2(70, -60),
		colors = [Color(0.23, 0.25, 0.33), Color(0.48, 0.52, 0.64), Color(0.16, 0.17, 0.24), Color(0.92, 0.73, 0.19)],
	},
	Kind.BOX: {
		texture = preload("res://objects/crate_box.png"), frames = 1, size = Vector2(14, 11),
		hp = 1, mass = 0.6, knock = Vector2(160, -110),
		colors = [Color(0.5, 0.36, 0.23), Color(0.63, 0.47, 0.31), Color(0.34, 0.24, 0.15), Color(0.77, 0.67, 0.46)],
	},
}
const DETAIL := 3.0 ## la textura tiene el triple de detalle (ver tools/generate_crates.py)
const FLASH := Color(2.2, 2.4, 2.6)

@export var kind := Kind.METAL:
	set(value):
		kind = value
		if is_node_ready():
			_configure()

var hp := 1
var _pending_damage := 0
var _pending_dir := Vector2.ZERO
var _shake := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_configure()
	if Engine.is_editor_hint():
		# En el editor solo se muestra (con su dibujo y tamaño correctos)
		set_process(false)
		set_physics_process(false)


func _configure() -> void:
	var s: Dictionary = SETTINGS[kind]
	hp = s.hp
	mass = s.mass
	sprite.texture = s.texture
	sprite.hframes = s.frames
	sprite.scale = Vector2.ONE / DETAIL
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# El temblor mueve el sprite fuera del paso de física: sin interpolar
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Forma propia de cada caja (no compartida entre instancias)
	var shape := RectangleShape2D.new()
	shape.size = s.size
	$CollisionShape2D.shape = shape
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.05
	physics_material_override = mat
	# Con muchos golpes seguidos no se pone a girar como una moneda
	angular_damp = 3.0


func take_hit(dir: Vector2, damage: int) -> void:
	sprite.modulate = FLASH
	if get_tree().paused:
		# Tiempo detenido: el golpe queda marcado y se aplica al volver
		_pending_damage += damage
		_pending_dir += dir
		return
	_apply_hit(dir, damage)


func _physics_process(_delta: float) -> void:
	if _pending_damage > 0:
		var damage := _pending_damage
		var dir := _pending_dir.normalized() if _pending_dir != Vector2.ZERO else Vector2.RIGHT
		_pending_damage = 0
		_pending_dir = Vector2.ZERO
		_apply_hit(dir * minf(damage, 3), damage)


func _process(delta: float) -> void:
	# Vuelve a su color y deja de temblar
	sprite.modulate = sprite.modulate.lerp(Color.WHITE, minf(delta * 14.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		sprite.position = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * _shake * 8.0
	else:
		sprite.position = Vector2.ZERO


func _apply_hit(dir: Vector2, damage: int) -> void:
	var s: Dictionary = SETTINGS[kind]
	hp -= damage
	if hp <= 0:
		_break(dir)
		return
	_spawn_debris(dir, 5, true)
	sprite.frame = mini(s.hp - hp, s.frames - 1)
	_shake = 0.15
	apply_central_impulse(Vector2(dir.x * s.knock.x, s.knock.y) * mass)
	apply_torque_impulse(dir.x * 40.0 * mass)


func _break(dir: Vector2) -> void:
	_spawn_debris(dir, 14, false)
	queue_free()


func _spawn_debris(dir: Vector2, pieces: int, sparks_only: bool) -> void:
	var d := Node2D.new()
	d.set_script(DEBRIS)
	d.setup(SETTINGS[kind].size, SETTINGS[kind].colors, dir.x, pieces, sparks_only, kind == Kind.METAL,
			_floor_below())
	get_parent().add_child(d)
	d.global_position = global_position
	d.reset_physics_interpolation() # aparece ahí, sin deslizarse desde el origen


## Distancia al suelo (o a lo que tenga debajo), para que los pedazos reboten ahí.
func _floor_below() -> float:
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 200))
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.position.y - global_position.y if hit else 200.0

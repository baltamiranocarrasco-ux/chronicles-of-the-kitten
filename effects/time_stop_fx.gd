extends Node2D
## Efecto visual al congelar el tiempo (estilo Sandevistan):
## onda expansiva, tinte de pantalla y estela de imágenes de colores del gato.
## Corre con el árbol pausado (PROCESS_MODE_ALWAYS), igual que el jugador.

const TRAIL_COLORS: Array[Color] = [
	Color(0.55, 1.0, 0.3),
	Color(1.0, 0.95, 0.3),
	Color(1.0, 0.35, 0.75),
	Color(0.35, 0.9, 1.0),
]
const TRAIL_INTERVAL := 0.045
const TRAIL_LIFETIME := 0.45
const TRAIL_ALPHA := 0.7
const TRAIL_MIN_DISTANCE := 3.0
const PLAYER_Z := 1 # mismo z_index que el Sprite2D del jugador
const AFTERIMAGE_MATERIAL := preload("res://effects/afterimage_material.tres")

@export var sprite_path: NodePath = ^"../Sprite2D"

var active := false

@onready var sprite: Sprite2D = get_node(sprite_path)

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _trail_timer := 0.0
var _trail_index := 0
var _last_trail_pos := Vector2.INF


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# El filtro se dibuja en el mundo (no en un CanvasLayer) para que el gato
	# y su estela (z_index = PLAYER_Z) queden encima y conserven sus colores.
	_rect = ColorRect.new()
	_rect.top_level = true
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://effects/time_stop.gdshader")
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_last_trail_pos = Vector2.INF
	_update_center()
	_rect.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	if on:
		_material.set_shader_parameter("wave_radius", 0.0)
		_tween_param("wave_radius", 2.2, 0.7) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween_param("intensity", 1.0, 0.25)
		_material.set_shader_parameter("flash", 0.8)
		_tween_param("flash", 0.0, 0.3)
		_camera_punch()
	else:
		_material.set_shader_parameter("wave_radius", 1.2)
		_tween_param("wave_radius", 0.0, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween_param("intensity", 0.0, 0.35)
		_tween.chain().tween_callback(_on_deactivated)


func _tween_param(param: String, to: float, duration: float) -> MethodTweener:
	var current = _material.get_shader_parameter(param)
	var from: float = current if current != null else 0.0
	return _tween.tween_method(func(v: float): _material.set_shader_parameter(param, v), from, to, duration)


func _on_deactivated() -> void:
	_material.set_shader_parameter("wave_radius", -1.0)
	_rect.visible = active


func _process(delta: float) -> void:
	if _rect.visible:
		_update_center()
	if not active:
		return
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = TRAIL_INTERVAL
		if sprite.global_position.distance_to(_last_trail_pos) >= TRAIL_MIN_DISTANCE:
			_spawn_afterimage()


func _update_center() -> void:
	var size := get_viewport_rect().size
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	_rect.global_position = to_world.origin
	_rect.size = size * to_world.get_scale()
	var screen_pos := sprite.get_global_transform_with_canvas().origin
	_material.set_shader_parameter("center", screen_pos / size)
	_material.set_shader_parameter("aspect", size.x / size.y)


func _spawn_afterimage() -> void:
	_last_trail_pos = sprite.global_position
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.material = AFTERIMAGE_MATERIAL
	var color := TRAIL_COLORS[_trail_index % TRAIL_COLORS.size()]
	color.a = TRAIL_ALPHA
	ghost.modulate = color
	ghost.z_index = PLAYER_Z
	ghost.process_mode = PROCESS_MODE_ALWAYS
	_trail_index += 1
	# Justo antes del jugador en el árbol: se dibuja detrás del gato
	owner.add_sibling(ghost)
	owner.get_parent().move_child(ghost, owner.get_index())
	ghost.global_position = sprite.global_position
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	fade.tween_callback(ghost.queue_free)


func _camera_punch() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var punch := create_tween()
	punch.tween_property(cam, "zoom", Vector2(1.08, 1.08), 0.08)
	punch.tween_property(cam, "zoom", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
